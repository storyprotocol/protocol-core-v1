// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { BaseModule } from "../BaseModule.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "../../interfaces/modules/licensing/ILicensingModule.sol";
import { Errors } from "../../lib/Errors.sol";
import { ROYALTY_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";
import { ProtocolPausableUpgradeable } from "../../pause/ProtocolPausableUpgradeable.sol";

/// @title Story Protocol Royalty Module
/// @notice The Story Protocol royalty module allows to set royalty policies an IP asset and pay royalties as a
///         derivative IP.
/// @custom:oz-upgrades-from contracts/old/v1.0.0.sol:RoyaltyModule_V1_0_0
contract RoyaltyModule is
    IRoyaltyModule,
    ProtocolPausableUpgradeable,
    ReentrancyGuardUpgradeable,
    BaseModule,
    UUPSUpgradeable
{
    using ERC165Checker for address;

    /// @notice Returns the canonical protocol-wide licensing module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Returns the protocol-wide dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @dev Storage structure for the RoyaltyModule
    /// @param isWhitelistedRoyaltyPolicy Indicates if a royalty policy is whitelisted
    /// @param isWhitelistedRoyaltyToken Indicates if a royalty token is whitelisted
    /// @param royaltyPolicies Indicates the royalty policy for a given IP asset
    /// @custom:storage-location erc7201:story-protocol.RoyaltyModule
    struct RoyaltyModuleStorage {
        /// @custom:oz-renamed-from licensingModule
        address deprecated_licensingModule;
        mapping(address royaltyPolicy => bool isWhitelisted) isWhitelistedRoyaltyPolicy;
        mapping(address token => bool) isWhitelistedRoyaltyToken;
        mapping(address ipId => address royaltyPolicy) royaltyPolicies;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.RoyaltyModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyModuleStorageLocation =
        0x98dd2c34f21d19fd1d178ed731f3db3d03e0b4e39f02dbeb040e80c9427a0300;

    string public constant override name = ROYALTY_MODULE_KEY;

    /// @notice Constructor
    /// @param disputeModule The address of the dispute module
    /// @param licenseRegistry The address of the license registry
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address licensingModule, address disputeModule, address licenseRegistry) {
        if (disputeModule == address(0)) revert Errors.RoyaltyModule__ZeroDisputeModule();
        if (licenseRegistry == address(0)) revert Errors.RoyaltyModule__ZeroLicenseRegistry();
        if (licensingModule == address(0)) revert Errors.RoyaltyModule__ZeroLicensingModule();

        LICENSING_MODULE = ILicensingModule(licensingModule);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) {
            revert Errors.RoyaltyModule__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Modifier to enforce that the caller is the licensing module
    modifier onlyLicensingModule() {
        if (msg.sender != address(LICENSING_MODULE)) revert Errors.RoyaltyModule__NotAllowedCaller();
        _;
    }

    /// @notice Whitelist a royalty policy
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external restricted {
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();

        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        $.isWhitelistedRoyaltyPolicy[royaltyPolicy] = allowed;

        emit RoyaltyPolicyWhitelistUpdated(royaltyPolicy, allowed);
    }

    /// @notice Whitelist a royalty token
    /// @dev Enforced to be only callable by the protocol admin
    /// @param token The token address
    /// @param allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address token, bool allowed) external restricted {
        if (token == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyToken();

        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        $.isWhitelistedRoyaltyToken[token] = allowed;

        emit RoyaltyTokenWhitelistUpdated(token, allowed);
    }

    /// @notice Executes royalty related logic on license minting
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param royaltyPolicy The royalty policy address of the license being minted
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address ipId,
        address royaltyPolicy,
        bytes calldata licenseData,
        bytes calldata externalData
    ) external nonReentrant onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        if (!$.isWhitelistedRoyaltyPolicy[royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        address royaltyPolicyIpId = $.royaltyPolicies[ipId];

        // if the node is a root node, then royaltyPolicyIpId will be address(0) and any type of royalty type can be
        // selected to mint a license if the node is a derivative node, then the any minted licenses by the derivative
        // node should have the same royalty policy as the parent node and a derivative node set its royalty policy
        // immutably in onLinkToParents() function below
        if (royaltyPolicyIpId != royaltyPolicy && royaltyPolicyIpId != address(0))
            revert Errors.RoyaltyModule__CanOnlyMintSelectedPolicy();

        IRoyaltyPolicy(royaltyPolicy).onLicenseMinting(ipId, licenseData, externalData);
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param royaltyPolicy The common royalty policy address of all the licenses being burned
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address royaltyPolicy,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external nonReentrant onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (!$.isWhitelistedRoyaltyPolicy[royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();
        if (parentIpIds.length == 0) revert Errors.RoyaltyModule__NoParentsOnLinking();

        for (uint32 i = 0; i < parentIpIds.length; i++) {
            address parentRoyaltyPolicy = $.royaltyPolicies[parentIpIds[i]];
            // if the parent node has a royalty policy set, then the derivative node should have the same royalty
            // policy if the parent node does not have a royalty policy set, then the derivative node can set any type
            // of royalty policy as long as the children ip obtained and is burning all licenses with that royalty type
            // from each parent (was checked in licensing module before calling this function)
            if (parentRoyaltyPolicy != royaltyPolicy && parentRoyaltyPolicy != address(0))
                revert Errors.RoyaltyModule__IncompatibleRoyaltyPolicy();
        }

        $.royaltyPolicies[ipId] = royaltyPolicy;

        IRoyaltyPolicy(royaltyPolicy).onLinkToParents(ipId, parentIpIds, licenseData, externalData);
    }

    /// @notice Allows the function caller to pay royalties to the receiver IP asset on behalf of the payer IP asset.
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerIpId The ipId that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(
        address receiverIpId,
        address payerIpId,
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (!$.isWhitelistedRoyaltyToken[token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();

        IDisputeModule dispute = DISPUTE_MODULE;
        if (dispute.isIpTagged(receiverIpId) || dispute.isIpTagged(payerIpId))
            revert Errors.RoyaltyModule__IpIsTagged();

        address payerRoyaltyPolicy = $.royaltyPolicies[payerIpId];
        // if the payer does not have a royalty policy set, then the payer is not a derivative ip and does not pay
        // royalties while the receiver ip can have a zero royalty policy since that could mean it is an ip a root
        if (payerRoyaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();
        if (!$.isWhitelistedRoyaltyPolicy[payerRoyaltyPolicy])
            revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        if (LICENSE_REGISTRY.isExpiredNow(receiverIpId)) revert Errors.RoyaltyModule__IpIsExpired();

        IRoyaltyPolicy(payerRoyaltyPolicy).onRoyaltyPayment(msg.sender, receiverIpId, token, amount);

        emit RoyaltyPaid(receiverIpId, payerIpId, msg.sender, token, amount);
    }

    /// @notice Allows to pay the minting fee for a license
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param licenseRoyaltyPolicy The royalty policy of the license being minted
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payLicenseMintingFee(
        address receiverIpId,
        address payerAddress,
        address licenseRoyaltyPolicy,
        address token,
        uint256 amount
    ) external onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (!$.isWhitelistedRoyaltyToken[token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();
        if (DISPUTE_MODULE.isIpTagged(receiverIpId)) revert Errors.RoyaltyModule__IpIsTagged();
        if (licenseRoyaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();
        if (!$.isWhitelistedRoyaltyPolicy[licenseRoyaltyPolicy])
            revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();
        if (LICENSE_REGISTRY.isExpiredNow(receiverIpId)) revert Errors.RoyaltyModule__IpIsExpired();

        IRoyaltyPolicy(licenseRoyaltyPolicy).onRoyaltyPayment(payerAddress, receiverIpId, token, amount);

        emit LicenseMintingFeePaid(receiverIpId, payerAddress, token, amount);
    }

    /// @notice Indicates if a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @return isWhitelisted True if the royalty policy is whitelisted
    function isWhitelistedRoyaltyPolicy(address royaltyPolicy) external view returns (bool) {
        return _getRoyaltyModuleStorage().isWhitelistedRoyaltyPolicy[royaltyPolicy];
    }

    /// @notice Indicates if a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @return isWhitelisted True if the royalty token is whitelisted
    function isWhitelistedRoyaltyToken(address token) external view returns (bool) {
        return _getRoyaltyModuleStorage().isWhitelistedRoyaltyToken[token];
    }

    /// @notice Indicates the royalty policy for a given IP asset
    /// @param ipId The ID of IP asset
    /// @return royaltyPolicy The address of the royalty policy
    function royaltyPolicies(address ipId) external view returns (address) {
        return _getRoyaltyModuleStorage().royaltyPolicies[ipId];
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IRoyaltyModule).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of RoyaltyModule.
    function _getRoyaltyModuleStorage() private pure returns (RoyaltyModuleStorage storage $) {
        assembly {
            $.slot := RoyaltyModuleStorageLocation
        }
    }
}
