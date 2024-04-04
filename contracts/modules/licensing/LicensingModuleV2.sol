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

    function attachLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external verifyPermission(ipId) {
        _verifyIpNotDisputed(ipId);
        LICENSE_REGISTRY.attachLicenseTermsToIp(ipId, licenseTemplate, licenseTermsId);
        emit LicenseTermsAttached(msg.sender, ipId, licenseTemplate, licenseTermsId);
    }

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

        Licensing.MintingLicenseSpec memory mlc = LICENSE_REGISTRY.verifyMintLicenseToken(
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

        address derivativeIpOwner = IIPAccount(payable(derivativeIpId)).owner();
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        if (!lct.verifyRegisterDerivativeForAll(derivativeIpId, originalIpIds, licenseTermsIds, derivativeIpOwner)) {
            revert Errors.LicensingModule__LicenseNotCompatibleForDerivative(derivativeIpId);
        }

        LICENSE_REGISTRY.registerDerivativeIp(derivativeIpId, originalIpIds, licenseTemplate, licenseTermsIds);
        // pay minting fee
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

    function registerDerivativeWithLicenseTokens(
        address derivativeIpId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext
    ) external nonReentrant verifyPermission(derivativeIpId) {
        if (licenseTokenIds.length == 0) {
            revert Errors.LicensingModule__NoLicenseToken();
        }

        address derivativeIpOwner = IIPAccount(payable(derivativeIpId)).owner();
        (address licenseTemplate, address[] memory originalIpIds, uint256[] memory licenseTermsIds) = LICENSE_NFT
            .validateLicenseTokensForDerivative(derivativeIpId, derivativeIpOwner, licenseTokenIds);

        _verifyIpNotDisputed(derivativeIpId);

        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        if (!lct.verifyRegisterDerivativeForAll(derivativeIpId, originalIpIds, licenseTermsIds, derivativeIpOwner)) {
            revert Errors.LicensingModule__LicenseTokenNotCompatibleForDerivative(derivativeIpId, licenseTokenIds);
        }

        LICENSE_REGISTRY.registerDerivativeIp(derivativeIpId, originalIpIds, licenseTemplate, licenseTermsIds);

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

    function _payMintingFeeForAll(
        address[] calldata originalIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        address derivativeIpOwner,
        bytes calldata royaltyContext
    ) private returns (address commonRoyaltyPolicy, bytes[] memory royaltyDatas) {
        commonRoyaltyPolicy = address(0);
        royaltyDatas = new bytes[](licenseTermsIds.length);

        for (uint256 i = 0; i < originalIpIds.length; i++) {
            uint256 lcId = licenseTermsIds[i];
            Licensing.MintingLicenseSpec memory mlc = LICENSE_REGISTRY.getMintingLicenseSpec(
                originalIpIds[i],
                licenseTemplate,
                lcId
            );
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

            if (i == 0) {
                commonRoyaltyPolicy = royaltyPolicy;
            } else if (royaltyPolicy != commonRoyaltyPolicy) {
                revert Errors.LicensingModule__IncompatibleRoyaltyPolicy(royaltyPolicy, commonRoyaltyPolicy);
            }
        }
    }

    function _payMintingFee(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        bytes calldata royaltyContext,
        Licensing.MintingLicenseSpec memory mlc
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

    function _getTotalMintingFee(
        Licensing.MintingLicenseSpec memory mintingLicenseSpec,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 mintingFeeSetByLicenseTerms,
        uint256 amount
    ) private view returns (uint256) {
        if (!mintingLicenseSpec.isSet) return mintingFeeSetByLicenseTerms * amount;
        if (mintingLicenseSpec.mintingFeeModule == address(0)) return mintingLicenseSpec.mintingFee * amount;
        return
            IMintingFeeModule(mintingLicenseSpec.mintingFeeModule).getTotalMintingFee(
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
