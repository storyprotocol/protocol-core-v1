// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import { BaseModule } from "../BaseModule.sol";
import { VaultController } from "./policies/VaultController.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { IExternalRoyaltyPolicyBase } from "../../interfaces/modules/royalty/policies/IExternalRoyaltyPolicyBase.sol";
import { IGroupIPAssetRegistry } from "../../interfaces/registries/IGroupIPAssetRegistry.sol";
import { IIpRoyaltyVault } from "../../interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "../../interfaces/modules/licensing/ILicensingModule.sol";
import { IIPAssetRegistry } from "../../interfaces/registries/IIPAssetRegistry.sol";
import { Errors } from "../../lib/Errors.sol";
import { ROYALTY_MODULE_KEY } from "../../lib/modules/Module.sol";
import { IPGraphACL } from "../../access/IPGraphACL.sol";

/// @title Story Protocol Royalty Module
/// @notice The Story Protocol royalty module governs the way derivatives pay royalties to their ancestors
contract RoyaltyModule is IRoyaltyModule, VaultController, ReentrancyGuardUpgradeable, BaseModule, UUPSUpgradeable {
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @notice Ip graph precompile contract address
    address public constant IP_GRAPH = address(0x0101);

    /// @notice Returns the percentage scale - represents 100%
    uint32 public constant MAX_PERCENT = 100_000_000;

    /// @notice Returns the canonical protocol-wide licensing module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice Returns the protocol-wide dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Returns the canonical protocol-wide IPAssetRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice IPGraphACL address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IPGraphACL public immutable IP_GRAPH_ACL;

    /// @dev Storage structure for the RoyaltyModule
    /// @param maxParents The maximum number of parents an IP asset can have
    /// @param maxAncestors The maximum number of ancestors an IP asset can have
    /// @param maxAccumulatedRoyaltyPolicies The maximum number of accumulated royalty policies an IP asset can have
    /// @param isWhitelistedRoyaltyPolicy Indicates if a royalty policy is whitelisted
    /// @param isWhitelistedRoyaltyToken Indicates if a royalty token is whitelisted
    /// @param isRegisteredExternalRoyaltyPolicy Indicates if an external royalty policy is registered
    /// @param ipRoyaltyVaults The royalty vault address for a given IP asset (if any)
    /// @param isIpRoyaltyVault Indicates if an address is a royalty vault
    /// @param globalRoyaltyStack Sum of royalty stack from each whitelisted royalty policy for a given IP asset
    /// @param accumulatedRoyaltyPolicies The accumulated royalty policies for a given IP asset
    /// @param totalRevenueTokensReceived The total lifetime revenue tokens received for a given IP asset
    /// @param totalRevenueTokensAccounted The total revenue tokens received by a given IP asset while a given royalty
    /// policy is whitelisted. If a royalty policy is whitelisted since the beginning then the value will be equal to
    /// the total revenue tokens received over the lifetime of the IP asset. But whenever a payment is made to an
    /// IP asset while a royalty policy is blacklisted then that payment will not be accounted for that royalty policy.
    /// @param treasury The treasury address
    /// @param royaltyFeePercent The royalty fee percentage
    /// @param totalPolicyRtsRequiredToLink The total royalty tokens required to link for a given IP asset and a given
    /// royalty policy
    /// @custom:storage-location erc7201:story-protocol.RoyaltyModule
    // solhint-disable max-line-length
    struct RoyaltyModuleStorage {
        uint256 maxParents;
        uint256 maxAncestors;
        uint256 maxAccumulatedRoyaltyPolicies;
        mapping(address royaltyPolicy => bool isWhitelisted) isWhitelistedRoyaltyPolicy;
        mapping(address token => bool) isWhitelistedRoyaltyToken;
        mapping(address royaltyPolicy => bool) isRegisteredExternalRoyaltyPolicy;
        mapping(address ipId => address ipRoyaltyVault) ipRoyaltyVaults;
        mapping(address ipRoyaltyVault => bool) isIpRoyaltyVault;
        mapping(address ipId => uint32) globalRoyaltyStack;
        mapping(address ipId => EnumerableSet.AddressSet) accumulatedRoyaltyPolicies;
        mapping(address ipId => mapping(address token => uint256)) totalRevenueTokensReceived;
        mapping(address ipId => mapping(address token => mapping(address royaltyPolicy => uint256))) totalRevenueTokensAccounted;
        address treasury;
        uint32 royaltyFeePercent;
        mapping(address ipId => mapping(address royaltyPolicy => uint32)) totalPolicyRtsRequiredToLink;
    }
    // solhint-enable max-line-length

    // keccak256(abi.encode(uint256(keccak256("story-protocol.RoyaltyModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyModuleStorageLocation =
        0x98dd2c34f21d19fd1d178ed731f3db3d03e0b4e39f02dbeb040e80c9427a0300;

    string public constant override name = ROYALTY_MODULE_KEY;

    /// @notice Constructor
    /// @param licensingModule The address of the licensing module
    /// @param disputeModule The address of the dispute module
    /// @param licenseRegistry The address of the license registry
    /// @param ipAssetRegistry The address of the ip asset registry
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address licensingModule,
        address disputeModule,
        address licenseRegistry,
        address ipAssetRegistry,
        address ipGraphAcl
    ) {
        if (licensingModule == address(0)) revert Errors.RoyaltyModule__ZeroLicensingModule();
        if (disputeModule == address(0)) revert Errors.RoyaltyModule__ZeroDisputeModule();
        if (licenseRegistry == address(0)) revert Errors.RoyaltyModule__ZeroLicenseRegistry();
        if (ipAssetRegistry == address(0)) revert Errors.RoyaltyModule__ZeroIpAssetRegistry();
        if (ipGraphAcl == address(0)) revert Errors.RoyaltyModule__ZeroIpGraphAcl();

        LICENSING_MODULE = ILicensingModule(licensingModule);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        IP_ASSET_REGISTRY = IGroupIPAssetRegistry(ipAssetRegistry);
        IP_GRAPH_ACL = IPGraphACL(ipGraphAcl);

        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    /// @param accumulatedRoyaltyPoliciesLimit The maximum number of accumulated royalty policies an IP asset can have
    function initialize(address accessManager, uint256 accumulatedRoyaltyPoliciesLimit) external initializer {
        if (accessManager == address(0)) revert Errors.RoyaltyModule__ZeroAccessManager();
        if (accumulatedRoyaltyPoliciesLimit == 0) revert Errors.RoyaltyModule__ZeroAccumulatedRoyaltyPoliciesLimit();

        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        $.maxAccumulatedRoyaltyPolicies = accumulatedRoyaltyPoliciesLimit;

        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Modifier to enforce that the caller is the licensing module
    modifier onlyLicensingModule() {
        if (msg.sender != address(LICENSING_MODULE)) revert Errors.RoyaltyModule__NotAllowedCaller();
        _;
    }

    /// @notice Sets the treasury address
    /// @dev Enforced to be only callable by the protocol admin
    /// @param treasury The address of the treasury
    function setTreasury(address treasury) external restricted {
        if (treasury == address(0)) revert Errors.RoyaltyModule__ZeroTreasury();

        _getRoyaltyModuleStorage().treasury = treasury;

        emit TreasurySet(treasury);
    }

    /// @notice Sets the royalty fee percentage
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyFeePercent The royalty fee percentage
    function setRoyaltyFeePercent(uint32 royaltyFeePercent) external restricted {
        if (royaltyFeePercent > MAX_PERCENT) revert Errors.RoyaltyModule__AboveMaxPercent();

        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if ($.treasury == address(0)) revert Errors.RoyaltyModule__ZeroTreasury();

        $.royaltyFeePercent = royaltyFeePercent;

        emit RoyaltyFeePercentSet(royaltyFeePercent);
    }

    /// @notice Sets the royalty limits
    /// @dev Enforced to be only callable by the protocol admin
    /// @param accumulatedRoyaltyPoliciesLimit The maximum number of accumulated royalty policies an IP asset can have
    function setRoyaltyLimits(uint256 accumulatedRoyaltyPoliciesLimit) external restricted {
        if (accumulatedRoyaltyPoliciesLimit == 0) revert Errors.RoyaltyModule__ZeroAccumulatedRoyaltyPoliciesLimit();

        _getRoyaltyModuleStorage().maxAccumulatedRoyaltyPolicies = accumulatedRoyaltyPoliciesLimit;

        emit RoyaltyLimitsUpdated(accumulatedRoyaltyPoliciesLimit);
    }

    /// @notice Whitelist a royalty policy
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external restricted {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();
        if ($.isRegisteredExternalRoyaltyPolicy[royaltyPolicy])
            revert Errors.RoyaltyModule__PolicyAlreadyRegisteredAsExternalRoyaltyPolicy();

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

    /// @notice Registers an external royalty policy
    /// @param externalRoyaltyPolicy The address of the external royalty policy
    function registerExternalRoyaltyPolicy(address externalRoyaltyPolicy) external nonReentrant {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (
            $.isWhitelistedRoyaltyPolicy[externalRoyaltyPolicy] ||
            $.isRegisteredExternalRoyaltyPolicy[externalRoyaltyPolicy]
        ) revert Errors.RoyaltyModule__PolicyAlreadyWhitelistedOrRegistered();

        // external royalty policies contracts should inherit IExternalRoyaltyPolicy interface
        // and implement the getPolicyRtsRequiredToLink() and ERC165 supportsInterface() functions
        if (
            !ERC165Checker.supportsInterface(
                externalRoyaltyPolicy,
                IExternalRoyaltyPolicyBase.getPolicyRtsRequiredToLink.selector
            )
        ) revert Errors.RoyaltyModule__InvalidExternalRoyaltyPolicy();

        $.isRegisteredExternalRoyaltyPolicy[externalRoyaltyPolicy] = true;
        emit ExternalRoyaltyPolicyRegistered(externalRoyaltyPolicy);
    }

    /// @notice Deploys a royalty vault for a given IP asset
    /// @param ipId The ID of the IP asset
    /// @return ipRoyaltyVault The address of the deployed royalty vault
    function deployVault(address ipId) external nonReentrant whenNotPaused returns (address ipRoyaltyVault) {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if ($.ipRoyaltyVaults[ipId] != address(0)) revert Errors.RoyaltyModule__VaultAlreadyDeployed();
        if (!IIPAssetRegistry(address(IP_ASSET_REGISTRY)).isRegistered(ipId))
            revert Errors.RoyaltyModule__IpIdNotRegistered();

        address receiver = ipId;

        if (IP_ASSET_REGISTRY.isRegisteredGroup(ipId)) {
            receiver = IP_ASSET_REGISTRY.getGroupRewardPool(ipId);
            if (!IP_ASSET_REGISTRY.isWhitelistedGroupRewardPool(receiver)) {
                revert Errors.RoyaltyModule__GroupRewardPoolNotWhitelisted(ipId, receiver);
            }
        }

        ipRoyaltyVault = _deployIpRoyaltyVault(ipId, receiver);
    }

    /// @notice Executes royalty related logic on license minting
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param royaltyPolicy The royalty policy address of the license being minted
    /// @param licensePercent The license percentage of the license being minted
    /// @param externalData The external data custom to the royalty policy being minted
    function onLicenseMinting(
        address ipId,
        address royaltyPolicy,
        uint32 licensePercent,
        bytes calldata externalData
    ) external nonReentrant onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();
        if (licensePercent > MAX_PERCENT) revert Errors.RoyaltyModule__AboveMaxPercent();

        if (!$.isWhitelistedRoyaltyPolicy[royaltyPolicy] && !$.isRegisteredExternalRoyaltyPolicy[royaltyPolicy])
            revert Errors.RoyaltyModule__NotWhitelistedOrRegisteredRoyaltyPolicy();

        // deploy ipRoyaltyVault for the ipId given in case it does not exist yet
        if ($.ipRoyaltyVaults[ipId] == address(0)) {
            address receiver = ipId;
            if (IP_ASSET_REGISTRY.isRegisteredGroup(ipId)) {
                receiver = IP_ASSET_REGISTRY.getGroupRewardPool(ipId);
                if (!IP_ASSET_REGISTRY.isWhitelistedGroupRewardPool(receiver)) {
                    revert Errors.RoyaltyModule__GroupRewardPoolNotWhitelisted(ipId, receiver);
                }
            }

            _deployIpRoyaltyVault(ipId, receiver);
        }

        // for whitelisted policies calls onLicenseMinting
        if ($.isWhitelistedRoyaltyPolicy[royaltyPolicy]) {
            IRoyaltyPolicy(royaltyPolicy).onLicenseMinting(ipId, licensePercent, externalData);
        }

        emit LicensedWithRoyalty(ipId, royaltyPolicy, licensePercent, externalData);
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseRoyaltyPolicies The royalty policies of the each parent license being used to link
    /// @param licensesPercent The license percentage of the licenses of each parent being used to link
    /// @param externalData The external data custom to each the royalty policy being used to link
    /// @param maxRts The maximum number of royalty tokens that can be distributed to the external royalty policies
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        address[] calldata licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        bytes calldata externalData,
        uint32 maxRts
    ) external nonReentrant onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        if (parentIpIds.length == 0) revert Errors.RoyaltyModule__NoParentsOnLinking();

        // deploy ipRoyaltyVault for the ipId given it does not exist yet
        bool vaultExist = $.ipRoyaltyVaults[ipId] != address(0);
        address ipRoyaltyVault = !vaultExist ? _deployIpRoyaltyVault(ipId, address(this)) : $.ipRoyaltyVaults[ipId];

        // calculates the total rts required to link
        // and saves the ancestors accumulated royalty policies for the child
        uint32 totalRtsRequiredToLink = _getRtsRequiredToLink(
            ipId,
            parentIpIds,
            licenseRoyaltyPolicies,
            licensesPercent,
            maxRts
        );

        // transfers the royalty tokens to the royalty policies and
        // distributes the remaining to the ipId address or group reward pool if the ipRoyaltyVault does not exist yet
        _distributeRts(ipId, ipRoyaltyVault, totalRtsRequiredToLink, vaultExist);

        // for whitelisted policies calls onLinkToParents and calculates the global royalty stack
        _calculateGlobalRoyaltyStack(ipId, parentIpIds, licenseRoyaltyPolicies, licensesPercent, externalData);

        emit LinkedToParents(ipId, parentIpIds, licenseRoyaltyPolicies, licensesPercent, externalData);
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
        uint256 amountAfterFee = _payRoyalty(receiverIpId, msg.sender, token, amount);

        emit RoyaltyPaid(receiverIpId, payerIpId, msg.sender, token, amount, amountAfterFee);
    }

    /// @notice Allows to pay the minting fee for a license
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payLicenseMintingFee(
        address receiverIpId,
        address payerAddress,
        address token,
        uint256 amount
    ) external nonReentrant onlyLicensingModule {
        uint256 amountAfterFee = _payRoyalty(receiverIpId, payerAddress, token, amount);

        emit LicenseMintingFeePaid(receiverIpId, payerAddress, token, amount, amountAfterFee);
    }

    /// @notice Indicates if an IP asset has a specific ancestor IP asset
    /// @param ipId The ID of IP asset
    /// @param ancestorIpId The ID of the ancestor IP asset
    function hasAncestorIp(address ipId, address ancestorIpId) external returns (bool) {
        return _hasAncestorIp(ipId, ancestorIpId);
    }

    /// @notice Returns the maximum percentage - represents 100%
    function maxPercent() external pure returns (uint32) {
        return MAX_PERCENT;
    }

    /// @notice Returns the treasury address
    function treasury() external view returns (address) {
        return _getRoyaltyModuleStorage().treasury;
    }

    /// @notice Returns the royalty fee percentage
    function royaltyFeePercent() external view returns (uint32) {
        return _getRoyaltyModuleStorage().royaltyFeePercent;
    }

    /// @notice Returns the maximum number of parents an IP asset can have
    function maxParents() external view returns (uint256) {
        return _getRoyaltyModuleStorage().maxParents;
    }

    /// @notice Returns the maximum number of ancestors an IP asset can have
    function maxAncestors() external view returns (uint256) {
        return _getRoyaltyModuleStorage().maxAncestors;
    }

    /// @notice Returns the maximum number of accumulated royalty policies an IP asset can have
    function maxAccumulatedRoyaltyPolicies() external view returns (uint256) {
        return _getRoyaltyModuleStorage().maxAccumulatedRoyaltyPolicies;
    }

    /// @notice Indicates if a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @return isWhitelisted True if the royalty policy is whitelisted
    function isWhitelistedRoyaltyPolicy(address royaltyPolicy) external view returns (bool) {
        return _getRoyaltyModuleStorage().isWhitelistedRoyaltyPolicy[royaltyPolicy];
    }

    /// @notice Indicates if an external royalty policy is registered
    /// @param externalRoyaltyPolicy The address of the external royalty policy
    /// @return isRegistered True if the external royalty policy is registered
    function isRegisteredExternalRoyaltyPolicy(address externalRoyaltyPolicy) external view returns (bool) {
        return _getRoyaltyModuleStorage().isRegisteredExternalRoyaltyPolicy[externalRoyaltyPolicy];
    }

    /// @notice Indicates if a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @return isWhitelisted True if the royalty token is whitelisted
    function isWhitelistedRoyaltyToken(address token) external view returns (bool) {
        return _getRoyaltyModuleStorage().isWhitelistedRoyaltyToken[token];
    }

    /// @notice Indicates if an address is a royalty vault
    /// @param ipRoyaltyVault The address to check
    /// @return isIpRoyaltyVault True if the address is a royalty vault
    function isIpRoyaltyVault(address ipRoyaltyVault) external view returns (bool) {
        return _getRoyaltyModuleStorage().isIpRoyaltyVault[ipRoyaltyVault];
    }

    /// @notice Indicates the royalty vault for a given IP asset
    /// @param ipId The ID of IP asset
    function ipRoyaltyVaults(address ipId) external view returns (address) {
        return _getRoyaltyModuleStorage().ipRoyaltyVaults[ipId];
    }

    /// @notice Returns the global royalty stack for whitelisted royalty policies and a given IP asset
    /// @param ipId The ID of IP asset
    function globalRoyaltyStack(address ipId) external view returns (uint32) {
        return _getRoyaltyModuleStorage().globalRoyaltyStack[ipId];
    }

    /// @notice Returns the accumulated royalty policies for a given IP asset
    /// @param ipId The ID of IP asset
    function accumulatedRoyaltyPolicies(address ipId) external view returns (address[] memory) {
        return _getRoyaltyModuleStorage().accumulatedRoyaltyPolicies[ipId].values();
    }

    /// @notice Returns the total lifetime revenue tokens received for a given IP asset
    /// @param ipId The ID of IP asset
    /// @param token The token address
    function totalRevenueTokensReceived(address ipId, address token) external view returns (uint256) {
        return _getRoyaltyModuleStorage().totalRevenueTokensReceived[ipId][token];
    }

    /// @notice Returns the total revenue tokens received by a given IP asset while a given royalty
    /// policy is whitelisted. If a royalty policy is whitelisted since the beginning then the value will be equal
    /// to the total revenue tokens received over the lifetime of the IP asset. But whenever a payment is made to an
    /// IP asset while a royalty policy is blacklisted then that payment will not be accounted for that royalty policy.
    /// @param ipId The ID of IP asset
    /// @param token The token address
    /// @param royaltyPolicy The royalty policy address
    function totalRevenueTokensAccounted(
        address ipId,
        address token,
        address royaltyPolicy
    ) external view returns (uint256) {
        return _getRoyaltyModuleStorage().totalRevenueTokensAccounted[ipId][token][royaltyPolicy];
    }

    /// @notice IERC165 interface support
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IRoyaltyModule).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Deploys a new ipRoyaltyVault for the given ipId
    /// @param ipId The ID of IP asset
    /// @param receiver The address of the receiver
    /// @return The address of the deployed ipRoyaltyVault
    function _deployIpRoyaltyVault(address ipId, address receiver) internal returns (address) {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        address ipRoyaltyVault = address(new BeaconProxy(ipRoyaltyVaultBeacon(), ""));
        IIpRoyaltyVault(ipRoyaltyVault).initialize("Royalty Token", "RT", MAX_PERCENT, ipId, receiver);
        $.ipRoyaltyVaults[ipId] = ipRoyaltyVault;
        $.isIpRoyaltyVault[ipRoyaltyVault] = true;

        emit IpRoyaltyVaultDeployed(ipId, ipRoyaltyVault);

        return ipRoyaltyVault;
    }

    /// @notice Calculates the global royalty stack for whitelisted royalty policies and a given IP asset
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseRoyaltyPolicies The royalty policies of the each parent license being used to link
    /// @param licensesPercent The license percentage of the licenses of each parent being used to link
    /// @param externalData The external data custom to each the royalty policy being used to link
    function _calculateGlobalRoyaltyStack(
        address ipId,
        address[] calldata parentIpIds,
        address[] calldata licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        bytes calldata externalData
    ) internal {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        // loop is limited to accumulatedRoyaltyPoliciesLimit
        uint32 globalRoyaltyStack;
        address[] memory accRoyaltyPolicies = $.accumulatedRoyaltyPolicies[ipId].values();
        for (uint256 i = 0; i < accRoyaltyPolicies.length; i++) {
            if ($.isWhitelistedRoyaltyPolicy[accRoyaltyPolicies[i]]) {
                globalRoyaltyStack += IRoyaltyPolicy(accRoyaltyPolicies[i]).onLinkToParents(
                    ipId,
                    parentIpIds,
                    licenseRoyaltyPolicies,
                    licensesPercent,
                    externalData
                );
            } else {
                if (!$.isRegisteredExternalRoyaltyPolicy[accRoyaltyPolicies[i]])
                    revert Errors.RoyaltyModule__NotWhitelistedOrRegisteredRoyaltyPolicy();
            }
        }

        if (globalRoyaltyStack > MAX_PERCENT) revert Errors.RoyaltyModule__AboveMaxPercent();
        $.globalRoyaltyStack[ipId] = globalRoyaltyStack;
    }

    /// @notice Distributes royalty tokens to the royalty policies of the ancestors IP assets
    /// @param ipId The ID of the IP asset
    /// @param parentIpIds The parent IP assets
    /// @param licenseRoyaltyPolicies The royalty policies of the each parent license
    /// @param licensesPercent The license percentage of the licenses being minted
    /// @param maxRts The maximum number of royalty tokens that can be distributed to the external royalty policies
    /// @return totalRtsRequiredToLink The total royalty tokens required to link
    // solhint-disable code-complexity
    function _getRtsRequiredToLink(
        address ipId,
        address[] calldata parentIpIds,
        address[] calldata licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        uint32 maxRts
    ) internal returns (uint32 totalRtsRequiredToLink) {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        // this loop is limited to maxParents
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            if (parentIpIds[i] == address(0)) revert Errors.RoyaltyModule__ZeroParentIpId();
            if (licenseRoyaltyPolicies[i] == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();

            // sums the royalty tokens and add royalty policy to child if it's not contained in the parent
            // since if it's already contained then it will be transferred in the next loop already
            if (!$.accumulatedRoyaltyPolicies[parentIpIds[i]].contains(licenseRoyaltyPolicies[i])) {
                totalRtsRequiredToLink += _addToAccumulatedRoyaltyPolicies(
                    ipId,
                    parentIpIds[i],
                    licenseRoyaltyPolicies[i],
                    licensesPercent[i]
                );
            }

            // sums the royalty tokens and add all the parent royalty policies to the child
            // this loop is limited to accumulatedRoyaltyPoliciesLimit
            address[] memory accParentRoyaltyPolicies = $.accumulatedRoyaltyPolicies[parentIpIds[i]].values();
            for (uint256 j = 0; j < accParentRoyaltyPolicies.length; j++) {
                // sum the required royalty tokens to each policy
                uint32 licensePercent = accParentRoyaltyPolicies[j] == licenseRoyaltyPolicies[i]
                    ? licensesPercent[i]
                    : 0;
                // add the parent ancestor royalty policies to the child
                totalRtsRequiredToLink += _addToAccumulatedRoyaltyPolicies(
                    ipId,
                    parentIpIds[i],
                    accParentRoyaltyPolicies[j],
                    licensePercent
                );
            }
        }

        if ($.accumulatedRoyaltyPolicies[ipId].length() > $.maxAccumulatedRoyaltyPolicies)
            revert Errors.RoyaltyModule__AboveAccumulatedRoyaltyPoliciesLimit();

        if (totalRtsRequiredToLink > maxRts) revert Errors.RoyaltyModule__AboveMaxRts();
    }

    /// @notice Distributes royalty tokens to the royalty policies of the ancestors IP assets
    /// @param ipId The ID of the IP asset
    /// @param ipRoyaltyVault The address of the ipRoyaltyVault
    /// @param totalRtsRequiredToLink The total royalty tokens required to link
    /// @param vaultExist True if the ipRoyaltyVault exists/is already deployed
    function _distributeRts(
        address ipId,
        address ipRoyaltyVault,
        uint32 totalRtsRequiredToLink,
        bool vaultExist
    ) internal {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        // if the vault exists - transfers the necessary royalty tokens from the ipId address to royalty module
        // if the vault does not exist - then 100% of the royalty tokens are already in the royalty module
        if (vaultExist) IERC20(ipRoyaltyVault).safeTransferFrom(ipId, address(this), totalRtsRequiredToLink);

        // transfers the royalty tokens to the royalty policies
        address[] memory accParentRoyaltyPolicies = $.accumulatedRoyaltyPolicies[ipId].values();
        for (uint256 i = 0; i < accParentRoyaltyPolicies.length; i++) {
            uint32 rts = $.totalPolicyRtsRequiredToLink[ipId][accParentRoyaltyPolicies[i]];
            if (rts > 0) IERC20(ipRoyaltyVault).safeTransfer(accParentRoyaltyPolicies[i], rts);
        }

        // if the ipRoyaltyVault does not exist yet, then sends remaining royalty tokens to the ipId address or
        // in the case the ipId is a group then send to the group reward pool
        if (!vaultExist) {
            uint32 remainingRts = MAX_PERCENT - totalRtsRequiredToLink;
            if (remainingRts > 0) {
                address receiver = ipId;
                if (IP_ASSET_REGISTRY.isRegisteredGroup(ipId)) {
                    receiver = IP_ASSET_REGISTRY.getGroupRewardPool(ipId);
                    if (!IP_ASSET_REGISTRY.isWhitelistedGroupRewardPool(receiver))
                        revert Errors.RoyaltyModule__GroupRewardPoolNotWhitelisted(ipId, receiver);
                }
                IERC20(ipRoyaltyVault).safeTransfer(receiver, remainingRts);
            }
        }
    }

    /// @notice Adds a royalty policy to the accumulated royalty policies of an IP asset
    /// @dev Function required to avoid stack too deep error
    /// @param ipId The ID of the IP asset
    /// @param parentIpId The parent IP asset
    /// @param royaltyPolicy The address of the royalty policy
    /// @param licensePercent The license percentage
    /// @return rts The royalty tokens required to link
    function _addToAccumulatedRoyaltyPolicies(
        address ipId,
        address parentIpId,
        address royaltyPolicy,
        uint32 licensePercent
    ) internal returns (uint32 rts) {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        rts = IRoyaltyPolicy(royaltyPolicy).getPolicyRtsRequiredToLink(parentIpId, licensePercent);
        $.accumulatedRoyaltyPolicies[ipId].add(royaltyPolicy);
        $.totalPolicyRtsRequiredToLink[ipId][royaltyPolicy] += rts;
    }

    /// @notice Handles the payment of royalties
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    /// @return amountAfterFee The amount after fee
    function _payRoyalty(
        address receiverIpId,
        address payerAddress,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        if (amount == 0) revert Errors.RoyaltyModule__ZeroAmount();
        if (!$.isWhitelistedRoyaltyToken[token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();
        if (DISPUTE_MODULE.isIpTagged(receiverIpId)) revert Errors.RoyaltyModule__IpIsTagged();
        if (LICENSE_REGISTRY.isExpiredNow(receiverIpId)) revert Errors.RoyaltyModule__IpExpired();

        // pay fee to the treasury
        // if the caller is a group reward pool, then no fee is paid given that the royalty fee has already been
        // charged on the the payment to the group ip royalty vault itself. Otherwise, royalty fee for grouping
        // would be charged twice.
        uint256 feeAmount;
        if (!IP_ASSET_REGISTRY.isWhitelistedGroupRewardPool(msg.sender)) {
            uint32 royaltyFeePercent = $.royaltyFeePercent;
            feeAmount = (amount * royaltyFeePercent) / MAX_PERCENT;
            if (feeAmount > 0) IERC20(token).safeTransferFrom(payerAddress, $.treasury, feeAmount);
            // when the royaltyFeePercent is higher than zero, then payments that are too small and below the threshold
            // that would be free of charge are no longer allowed
            if (feeAmount == 0 && royaltyFeePercent > 0) revert Errors.RoyaltyModule__PaymentAmountIsTooLow();
        }

        // pay to the whitelisted royalty policies first
        uint256 amountAfterFee = amount - feeAmount;
        uint256 amountPaid = _payToWhitelistedRoyaltyPolicies(receiverIpId, payerAddress, token, amountAfterFee);

        // pay the remaining amount to the receiver vault
        uint256 remainingAmount = amountAfterFee - amountPaid;
        if (remainingAmount > 0) _payToReceiverVault(receiverIpId, payerAddress, token, remainingAmount);

        $.totalRevenueTokensReceived[receiverIpId][token] += amountAfterFee;

        return amountAfterFee;
    }

    /// @notice Transfers to each whitelisted policy its share of the total payment
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    /// @return totalAmountPaid The total amount paid to the whitelisted royalty policies
    function _payToWhitelistedRoyaltyPolicies(
        address receiverIpId,
        address payerAddress,
        address token,
        uint256 amount
    ) internal returns (uint256 totalAmountPaid) {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        // loop is limited to accumulatedRoyaltyPoliciesLimit
        address[] memory accRoyaltyPolicies = $.accumulatedRoyaltyPolicies[receiverIpId].values();
        for (uint256 i = 0; i < accRoyaltyPolicies.length; i++) {
            if ($.isWhitelistedRoyaltyPolicy[accRoyaltyPolicies[i]]) {
                uint32 royaltyStack = IRoyaltyPolicy(accRoyaltyPolicies[i]).getPolicyRoyaltyStack(receiverIpId);
                if (royaltyStack == 0) continue;

                // add the amount to the total revenue tokens accounted for the whitelisted royalty policy
                $.totalRevenueTokensAccounted[receiverIpId][token][accRoyaltyPolicies[i]] += amount;

                uint256 amountToTransfer = (amount * royaltyStack) / MAX_PERCENT;
                totalAmountPaid += amountToTransfer;

                IERC20(token).safeTransferFrom(payerAddress, accRoyaltyPolicies[i], amountToTransfer);
            }
        }
    }

    /// @notice Pays the royalty to the receiver vault
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function _payToReceiverVault(address receiverIpId, address payerAddress, address token, uint256 amount) internal {
        address receiverVault = _getRoyaltyModuleStorage().ipRoyaltyVaults[receiverIpId];
        if (receiverVault == address(0)) revert Errors.RoyaltyModule__ZeroReceiverVault();

        IIpRoyaltyVault(receiverVault).updateVaultBalance(token, amount);
        IERC20(token).safeTransferFrom(payerAddress, receiverVault, amount);
    }

    /// @notice Returns the count of ancestors for the given IP asset
    /// @param ipId The ID of the IP asset
    /// @return The number of ancestors
    function _getAncestorCount(address ipId) internal returns (uint256) {
        (bool success, bytes memory returnData) = IP_GRAPH.call(
            abi.encodeWithSignature("getAncestorIpsCount(address)", ipId)
        );
        if (!success) revert Errors.RoyaltyModule__CallFailed();
        return abi.decode(returnData, (uint256));
    }

    /// @notice Returns whether and IP is an ancestor of a given IP
    /// @param ipId The ipId to check if it has an ancestor
    /// @param ancestorIpId The ancestor ipId to check if it is an ancestor
    /// @return True if the IP has the ancestor
    function _hasAncestorIp(address ipId, address ancestorIpId) internal returns (bool) {
        (bool success, bytes memory returnData) = IP_GRAPH.call(
            abi.encodeWithSignature("hasAncestorIp(address,address)", ipId, ancestorIpId)
        );
        if (!success) revert Errors.RoyaltyModule__CallFailed();
        return abi.decode(returnData, (bool));
    }

    /// @dev Returns the storage struct of RoyaltyModule
    function _getRoyaltyModuleStorage() private pure returns (RoyaltyModuleStorage storage $) {
        assembly {
            $.slot := RoyaltyModuleStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
