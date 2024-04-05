// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IModule } from "../../interfaces/modules/base/IModule.sol";
import { ILicensingModuleV2 } from "../../interfaces/modules/licensing/ILicensingModuleV2.sol";
import { IIPAccountRegistry } from "../../interfaces/registries/IIPAccountRegistry.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { ILicenseRegistryV2 } from "../../interfaces/registries/ILicenseRegistryV2.sol";
import { Errors } from "../../lib/Errors.sol";
import { Licensing } from "../../lib/Licensing.sol";
import { IPAccountChecker } from "../../lib/registries/IPAccountChecker.sol";
import { RoyaltyModule } from "../../modules/royalty/RoyaltyModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { LICENSING_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";
import { GovernableUpgradeable } from "../../governance/GovernableUpgradeable.sol";
import { ILicenseTemplate } from "contracts/interfaces/modules/licensing/ILicenseTemplate.sol";
import { IMintingFeeModule } from "contracts/interfaces/modules/licensing/IMintingFeeModule.sol";
import { IPAccountStorageOps } from "../../lib/IPAccountStorageOps.sol";
import { IHookModule } from "../../interfaces/modules/base/IHookModule.sol";
import { ILicenseNFT } from "../../interfaces/registries/ILicenseNFT.sol";

// TODO: consider disabling operators/approvals on creation
/// @title Licensing Module
/// @notice Licensing module is the main entry point for the licensing system. It is responsible for:
/// - Attaching license terms to IP assets
/// - Minting license Tokens
/// - Registering derivatives
contract LicensingModuleV2 is
    AccessControlled,
    ILicensingModuleV2,
    BaseModule,
    ReentrancyGuardUpgradeable,
    GovernableUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

    /// @inheritdoc IModule
    string public constant override name = LICENSING_MODULE_KEY;

    /// @notice Returns the canonical protocol-wide RoyaltyModule
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    RoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistryV2 public immutable LICENSE_REGISTRY;

    /// @notice Returns the dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    ILicenseNFT public immutable LICENSE_NFT;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicensingModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicensingModuleStorageLocation =
        0x0f7178cb62e4803c52d40f70c08a6f88d6ee1af1838d58e0c83a222a6c3d3100;

    /// Constructor
    /// @param accessController The address of the AccessController contract
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract
    /// @param royaltyModule The address of the RoyaltyModule contract
    /// @param registry The address of the LicenseRegistry contract
    /// @param disputeModule The address of the DisputeModule contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address royaltyModule,
        address registry,
        address disputeModule,
        address licenseNFT
    ) AccessControlled(accessController, ipAccountRegistry) {
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
        LICENSE_REGISTRY = ILicenseRegistryV2(registry);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        LICENSE_NFT = ILicenseNFT(licenseNFT);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param governance The address of the governance contract
    function initialize(address governance) public initializer {
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __GovernableUpgradeable_init(governance);
    }

    /// @notice Attaches license terms to an IP.
    /// the function must be called by the IP owner or an authorized operator.
    /// @param ipId The IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    function attachLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external verifyPermission(ipId) {
        _verifyIpNotDisputed(ipId);
        LICENSE_REGISTRY.attachLicenseTermsToIp(ipId, licenseTemplate, licenseTermsId);
        emit LicenseTermsAttached(msg.sender, ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Mints license tokens for the license terms attached to an IP.
    /// The license tokens are minted to the receiver.
    /// The license terms must be attached to the IP before calling this function.
    /// But it can mint license token of default license terms without attaching the default license terms,
    /// since it is attached to all IPs by default.
    /// IP owners can mint license tokens for their IPs for arbitrary license terms
    /// without attaching the license terms to IP.
    /// It might require the caller pay the minting fee, depending on the license terms or configured by the iP owner.
    /// The minting fee is paid in the minting fee token specified in the license terms or configured by the IP owner.
    /// IP owners can configure the minting fee of their IPs or
    /// configure the minting fee module to determine the minting fee.
    /// IP owners can configure the receiver check module to determine the receiver of the minted license tokens.
    /// @param originalIpId The licensor IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver.
    /// @param royaltyContext The context of the royalty.
    /// @return startLicenseTokenId The start ID of the minted license tokens.
    /// @return endLicenseTokenId The end ID of the minted license tokens.
    function mintLicenseTokens(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external returns (uint256 startLicenseTokenId, uint256 endLicenseTokenId) {
        if (amount == 0) {
            revert Errors.LicensingModule__MintAmountZero();
        }
        if (receiver == address(0)) {
            revert Errors.LicensingModule__ReceiverZeroAddress();
        }

        _verifyIpNotDisputed(originalIpId);

        Licensing.MintingLicenseConfig memory mlc = LICENSE_REGISTRY.verifyMintLicenseToken(
            originalIpId,
            licenseTemplate,
            licenseTermsId,
            _hasPermission(originalIpId)
        );
        if (mlc.receiverCheckModule != address(0)) {
            if (!IHookModule(mlc.receiverCheckModule).verify(receiver, mlc.receiverCheckData)) {
                revert Errors.LicensingModule__ReceiverCheckFailed(receiver);
            }
        }

        _payMintingFee(originalIpId, licenseTemplate, licenseTermsId, amount, royaltyContext, mlc);

        ILicenseTemplate(licenseTemplate).verifyMintLicenseToken(licenseTermsId, receiver, originalIpId, amount);

        (startLicenseTokenId, endLicenseTokenId) = LICENSE_NFT.mintLicenseTokens(
            originalIpId,
            licenseTemplate,
            licenseTermsId,
            amount,
            msg.sender,
            receiver
        );

        emit LicenseTokensMinted(
            msg.sender,
            originalIpId,
            licenseTemplate,
            licenseTermsId,
            amount,
            receiver,
            startLicenseTokenId,
            endLicenseTokenId
        );
    }

    /// @notice Registers a derivative directly with original IP's license terms, without needing license tokens,
    /// and attaches the license terms of the original IPs to the derivative IP.
    /// The license terms must be attached to the original IP before calling this function.
    /// All IPs attached default license terms by default.
    /// The derivative IP owner must be the caller or an authorized operator.
    /// @dev The derivative IP is registered with license terms minted from the original IP's license terms.
    /// @param derivativeIpId The derivative IP ID.
    /// @param originalIpIds The original IP IDs.
    /// @param licenseTermsIds The IDs of the license terms that the original IP supports.
    /// @param licenseTemplate The address of the license template of the license terms Ids.
    /// @param royaltyContext The context of the royalty.
    function registerDerivative(
        address derivativeIpId,
        address[] calldata originalIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        bytes calldata royaltyContext
    ) external nonReentrant verifyPermission(derivativeIpId) {
        if (originalIpIds.length != licenseTermsIds.length) {
            revert Errors.LicensingModule__LicenseTermsLengthMismatch(originalIpIds.length, licenseTermsIds.length);
        }
        if (originalIpIds.length == 0) {
            revert Errors.LicensingModule__NoOriginalIp();
        }

        _verifyIpNotDisputed(derivativeIpId);

        // Check the compatibility of all license terms (specified by 'licenseTermsIds') across all original IPs.
        // All license terms must be compatible with each other.
        // Verify that the derivative IP is permitted under all license terms from the original IPs.
        address derivativeIpOwner = IIPAccount(payable(derivativeIpId)).owner();
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        if (!lct.verifyRegisterDerivativeForAll(derivativeIpId, originalIpIds, licenseTermsIds, derivativeIpOwner)) {
            revert Errors.LicensingModule__LicenseNotCompatibleForDerivative(derivativeIpId);
        }

        // Ensure none of the original IPs have expired.
        // Confirm that each original IP has the license terms attached as specified by 'licenseTermsIds'
        // or default license terms.
        // Ensure the derivative IP is not included in the list of original IPs.
        // Validate that none of the original IPs are disputed.
        // If any of the above conditions are not met, revert the transaction. If all conditions are met, proceed.
        // Attach all license terms from the original IPs to the derivative IP.
        // Set the derivative IP as a derivative of the original IPs.
        // Set the expiration timestamp for the derivative IP by invoking the license template to calculate
        // the earliest expiration time among all license terms.
        LICENSE_REGISTRY.registerDerivativeIp(derivativeIpId, originalIpIds, licenseTemplate, licenseTermsIds);
        // Process the payment for the minting fee.
        (address commonRoyaltyPolicy, bytes[] memory royaltyDatas) = _payMintingFeeForAll(
            originalIpIds,
            licenseTermsIds,
            licenseTemplate,
            derivativeIpOwner,
            royaltyContext
        );
        // emit event
        emit DerivativeRegistered(msg.sender, derivativeIpId, originalIpIds, licenseTermsIds, licenseTemplate);

        if (commonRoyaltyPolicy != address(0)) {
            ROYALTY_MODULE.onLinkToParents(
                derivativeIpId,
                commonRoyaltyPolicy,
                originalIpIds,
                royaltyDatas,
                royaltyContext
            );
        }
    }

    /// @notice Registers a derivative with license tokens.
    /// the derivative IP is registered with license tokens minted from the original IP's license terms.
    /// the license terms of the original IPs issued with license tokens are attached to the derivative IP.
    /// the caller must be the derivative IP owner or an authorized operator.
    /// @param derivativeIpId The derivative IP ID.
    /// @param licenseTokenIds The IDs of the license tokens.
    /// @param royaltyContext The context of the royalty.
    function registerDerivativeWithLicenseTokens(
        address derivativeIpId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext
    ) external nonReentrant verifyPermission(derivativeIpId) {
        if (licenseTokenIds.length == 0) {
            revert Errors.LicensingModule__NoLicenseToken();
        }

        // Ensure the license token has not expired.
        // Confirm that the license token has not been revoked.
        // Validate that the owner of the derivative IP is also the owner of the license tokens.
        address derivativeIpOwner = IIPAccount(payable(derivativeIpId)).owner();
        (address licenseTemplate, address[] memory originalIpIds, uint256[] memory licenseTermsIds) = LICENSE_NFT
            .validateLicenseTokensForDerivative(derivativeIpId, derivativeIpOwner, licenseTokenIds);

        _verifyIpNotDisputed(derivativeIpId);

        // Verify that the derivative IP is permitted under all license terms from the original IPs.
        // Check the compatibility of all licenses
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        if (!lct.verifyRegisterDerivativeForAll(derivativeIpId, originalIpIds, licenseTermsIds, derivativeIpOwner)) {
            revert Errors.LicensingModule__LicenseTokenNotCompatibleForDerivative(derivativeIpId, licenseTokenIds);
        }

        // Verify that none of the original IPs have expired.
        // Validate that none of the original IPs are disputed.
        // Ensure that the derivative IP does not have any existing licenses attached.
        // Validate that the derivative IP is not included in the list of original IPs.
        // Confirm that the derivative IP does not already have any original IPs.
        // If any of the above conditions are not met, revert the transaction. If all conditions are met, proceed.
        // Attach all license terms from the original IPs to the derivative IP.
        // Set the derivative IP as a derivative of the original IPs.
        // Set the expiration timestamp for the derivative IP to match the earliest expiration time of
        // all license terms.
        LICENSE_REGISTRY.registerDerivativeIp(derivativeIpId, originalIpIds, licenseTemplate, licenseTermsIds);

        // Confirm that the royalty policies defined in all license terms of the original IPs are identical.
        address commonRoyaltyPolicy = address(0);
        bytes[] memory royaltyDatas = new bytes[](originalIpIds.length);
        for (uint256 i = 0; i < originalIpIds.length; i++) {
            (address royaltyPolicy, bytes memory royaltyData, , ) = lct.getRoyaltyPolicy(licenseTermsIds[i]);
            royaltyDatas[i] = royaltyData;
            if (i == 0) {
                commonRoyaltyPolicy = royaltyPolicy;
            } else if (royaltyPolicy != commonRoyaltyPolicy) {
                revert Errors.LicensingModule__IncompatibleRoyaltyPolicy(royaltyPolicy, commonRoyaltyPolicy);
            }
        }

        // Notify the royalty module
        if (commonRoyaltyPolicy != address(0)) {
            ROYALTY_MODULE.onLinkToParents(
                derivativeIpId,
                commonRoyaltyPolicy,
                originalIpIds,
                royaltyDatas,
                royaltyContext
            );
        }
        // burn license tokens
        LICENSE_NFT.burnLicenseTokens(derivativeIpOwner, licenseTokenIds);
        emit DerivativeRegisteredWithLicenseTokens(
            msg.sender,
            derivativeIpId,
            licenseTokenIds,
            originalIpIds,
            licenseTermsIds,
            licenseTemplate
        );
    }

    /// @dev pay minting fee for all original IPs
    /// This function is called by registerDerivative
    /// It pays the minting fee for all original IPs through the royalty module
    /// finally returns the common royalty policy and data for the original IPs
    function _payMintingFeeForAll(
        address[] calldata originalIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        address derivativeIpOwner,
        bytes calldata royaltyContext
    ) private returns (address commonRoyaltyPolicy, bytes[] memory royaltyDatas) {
        commonRoyaltyPolicy = address(0);
        royaltyDatas = new bytes[](licenseTermsIds.length);

        // pay minting fee for all original IPs
        for (uint256 i = 0; i < originalIpIds.length; i++) {
            uint256 lcId = licenseTermsIds[i];
            Licensing.MintingLicenseConfig memory mlc = LICENSE_REGISTRY.getMintingLicenseConfig(
                originalIpIds[i],
                licenseTemplate,
                lcId
            );
            // check derivativeIpOwner is qualified with check receiver module
            if (mlc.receiverCheckModule != address(0)) {
                if (!IHookModule(mlc.receiverCheckModule).verify(derivativeIpOwner, mlc.receiverCheckData)) {
                    revert Errors.LicensingModule__ReceiverCheckFailed(derivativeIpOwner);
                }
            }
            (address royaltyPolicy, bytes memory royaltyData) = _payMintingFee(
                originalIpIds[i],
                licenseTemplate,
                lcId,
                1,
                royaltyContext,
                mlc
            );
            royaltyDatas[i] = royaltyData;
            // royaltyPolicy must be the same for all original IPs and royaltyPolicy could be 0
            // Using the first royaltyPolicy as the commonRoyaltyPolicy, all other royaltyPolicy must be the same
            if (i == 0) {
                commonRoyaltyPolicy = royaltyPolicy;
            } else if (royaltyPolicy != commonRoyaltyPolicy) {
                revert Errors.LicensingModule__IncompatibleRoyaltyPolicy(royaltyPolicy, commonRoyaltyPolicy);
            }
        }
    }

    /// @dev pay minting fee for an original IP
    /// This function is called by mintLicenseTokens and registerDerivative
    /// It initialize royalty module and pays the minting fee for the original IP through the royalty module
    /// finally returns the royalty policy and data for the original IP
    /// @param originalIpId The original IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    /// @param amount The amount of license tokens to mint.
    /// @param royaltyContext The context of the royalty.
    /// @param mlc The minting license config
    /// @return royaltyPolicy The address of the royalty policy.
    function _payMintingFee(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        bytes calldata royaltyContext,
        Licensing.MintingLicenseConfig memory mlc
    ) private returns (address royaltyPolicy, bytes memory royaltyData) {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        uint256 mintingFee = 0;
        address currencyToken = address(0);
        (royaltyPolicy, royaltyData, mintingFee, currencyToken) = lct.getRoyaltyPolicy(licenseTermsId);

        if (royaltyPolicy != address(0)) {
            ROYALTY_MODULE.onLicenseMinting(originalIpId, royaltyPolicy, royaltyData, royaltyContext);
            uint256 tmf = _getTotalMintingFee(mlc, originalIpId, licenseTemplate, licenseTermsId, mintingFee, amount);
            // pay minting fee
            if (tmf > 0) {
                ROYALTY_MODULE.payLicenseMintingFee(originalIpId, msg.sender, royaltyPolicy, currencyToken, tmf);
            }
        }
    }

    /// @dev get total minting fee
    /// There are 3 places to get the minting fee: license terms, MintingLicenseConfig, MintingFeeModule
    /// The order of priority is MintingFeeModule > MintingLicenseConfig >  > license terms
    /// @param mintingLicenseConfig The minting license config
    /// @param licensorIpId The licensor IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    /// @param mintingFeeSetByLicenseTerms The minting fee set by the license terms.
    /// @param amount The amount of license tokens to mint.
    function _getTotalMintingFee(
        Licensing.MintingLicenseConfig memory mintingLicenseConfig,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 mintingFeeSetByLicenseTerms,
        uint256 amount
    ) private view returns (uint256) {
        if (!mintingLicenseConfig.isSet) return mintingFeeSetByLicenseTerms * amount;
        if (mintingLicenseConfig.mintingFeeModule == address(0)) return mintingLicenseConfig.mintingFee * amount;
        return
            IMintingFeeModule(mintingLicenseConfig.mintingFeeModule).getMintingFee(
                licensorIpId,
                licenseTemplate,
                licenseTermsId,
                amount
            );
    }

    /// @dev Verifies if the IP is disputed
    function _verifyIpNotDisputed(address ipId) private view {
        //TODO: check original IP not expired
        if (DISPUTE_MODULE.isIpTagged(ipId)) {
            revert Errors.LicensingModule__DisputedIpId();
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyProtocolAdmin {}
}
