// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import { IIpRoyaltyVault } from "../../../interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { IRoyaltyPolicyLAP } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { ArrayUtils } from "../../../lib/ArrayUtils.sol";
import { Errors } from "../../../lib/Errors.sol";
import { ProtocolPausableUpgradeable } from "../../../pause/ProtocolPausableUpgradeable.sol";

/// @title Liquid Absolute Percentage Royalty Policy
/// @notice Defines the logic for splitting royalties for a given ipId using a liquid absolute percentage mechanism
contract RoyaltyPolicyLAP is
    IRoyaltyPolicyLAP,
    ProtocolPausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the RoyaltyPolicyLAP
    /// @param ipRoyaltyVaultBeacon The ip royalty vault beacon address
    /// @param snapshotInterval The minimum timestamp interval between snapshots
    /// @param royaltyData The royalty data for a given IP asset
    /// @custom:storage-location erc7201:story-protocol.RoyaltyPolicyLAP
    struct RoyaltyPolicyLAPStorage {
        address ipRoyaltyVaultBeacon;
        uint256 snapshotInterval;
        mapping(address ipId => LAPRoyaltyData) royaltyData;
    }

    /// @notice Ip graph precompile contract address
    address public constant IP_GRAPH_CONTRACT = address(0x1A);

    // keccak256(abi.encode(uint256(keccak256("story-protocol.RoyaltyPolicyLAP")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyPolicyLAPStorageLocation =
        0x0c915ba68e2c4e37f19454bb13066f18f9db418fcefbf3c585b4b7d0fb0e0600;

    /// @notice Returns the percentage scale - represents 100% of royalty tokens for an ip
    uint32 public constant TOTAL_RT_SUPPLY = 100000000; // 100 * 10 ** 6

    /// @notice Returns the maximum number of parents
    uint256 public constant MAX_PARENTS = 2;

    /// @notice Returns the maximum number of total ancestors.
    /// @dev The IP derivative tree is limited to 1024 ancestors
    uint256 public constant MAX_ANCESTORS = 1024;

    /// @notice Returns the RoyaltyModule address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable ROYALTY_MODULE;

    /// @notice Returns the LicensingModule address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable LICENSING_MODULE;

    /// @dev Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLAP__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param royaltyModule The RoyaltyModule address
    /// @param licensingModule The LicensingModule address
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyModule, address licensingModule) {
        if (royaltyModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroRoyaltyModule();
        if (licensingModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLicensingModule();

        ROYALTY_MODULE = royaltyModule;
        LICENSING_MODULE = licensingModule;
        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroAccessManager();
        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @dev Set the snapshot interval
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param timestampInterval The minimum timestamp interval between snapshots
    function setSnapshotInterval(uint256 timestampInterval) public restricted {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        $.snapshotInterval = timestampInterval;

        emit SnapshotIntervalSet(timestampInterval);
    }

    /// @dev Set the ip royalty vault beacon
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param beacon The ip royalty vault beacon address
    function setIpRoyaltyVaultBeacon(address beacon) public restricted {
        if (beacon == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroIpRoyaltyVaultBeacon();
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        $.ipRoyaltyVaultBeacon = beacon;

        emit IpRoyaltyVaultBeaconSet(beacon);
    }

    /// @dev Upgrades the ip royalty vault beacon
    /// @dev Enforced to be only callable by the upgrader admin
    /// @param newVault The new ip royalty vault beacon address
    function upgradeVaults(address newVault) public restricted {
        // UpgradeableBeacon already checks for newImplementation.bytecode.length > 0,
        // no need to check for zero address
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        UpgradeableBeacon($.ipRoyaltyVaultBeacon).upgradeTo(newVault);
    }

    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address ipId,
        bytes calldata licenseData,
        bytes calldata externalData
    ) external onlyRoyaltyModule nonReentrant {
        uint32 newLicenseRoyalty = abi.decode(licenseData, (uint32));
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();

        LAPRoyaltyData memory data = $.royaltyData[ipId];

        if (_getRoyaltyStack(ipId) + newLicenseRoyalty > TOTAL_RT_SUPPLY)
            revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        if (data.ipRoyaltyVault == address(0)) {
            // If the policy is already initialized, it means that the ipId setup is already done. If not, it means
            // that the license for this royalty policy is being minted for the first time parentIpIds are zero given
            // that only roots can call _initPolicy() for the first time in the function onLicenseMinting() while
            // derivatives already
            // called _initPolicy() when linking to their parents with onLinkToParents() call.
            _initPolicy(ipId, new address[](0), new bytes[](0));
        } else {
            // If the policy is already initialized and an ipId has the maximum number of ancestors
            // it can not have any derivative and therefore is not allowed to mint any license
            if (_getAncestorCount(ipId) >= MAX_ANCESTORS)
                revert Errors.RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense();
        }
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external onlyRoyaltyModule nonReentrant {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        if ($.royaltyData[ipId].isUnlinkableToParents) revert Errors.RoyaltyPolicyLAP__UnlinkableToParents();

        _initPolicy(ipId, parentIpIds, licenseData);
    }

    /// @notice Allows the caller to pay royalties to the given IP asset
    /// @param caller The caller is the address from which funds will transferred from
    /// @param ipId The ipId of the receiver of the royalties
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external onlyRoyaltyModule {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        address destination = $.royaltyData[ipId].ipRoyaltyVault;
        if (IIpRoyaltyVault(destination).addIpRoyaltyVaultTokens(token)) {
            emit RevenueTokenAddedToVault(token, destination);
        }
        IERC20(token).safeTransferFrom(caller, destination, amount);
    }

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ipId to get the royalty data for
    /// @return isUnlinkableToParents Indicates if the ipId is unlinkable to new parents
    /// @return ipRoyaltyVault The ip royalty vault address
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    function getRoyaltyData(address ipId) external view returns (bool, address, uint32) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        LAPRoyaltyData memory data = $.royaltyData[ipId];
        return (data.isUnlinkableToParents, data.ipRoyaltyVault, data.royaltyStack);
    }

    /// @notice Returns the snapshot interval
    /// @return snapshotInterval The minimum timestamp interval between snapshots
    function getSnapshotInterval() external view returns (uint256) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        return $.snapshotInterval;
    }

    /// @notice Returns the ip royalty vault beacon
    /// @return ipRoyaltyVaultBeacon The ip royalty vault beacon address
    function getIpRoyaltyVaultBeacon() external view returns (address) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        return $.ipRoyaltyVaultBeacon;
    }

    /// @dev Initializes the royalty policy for a given IP asset.
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The to initialize the policy for
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to (if any)
    /// @param licenseData The license data custom to each the royalty policy
    function _initPolicy(address ipId, address[] memory parentIpIds, bytes[] memory licenseData) internal {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();

        uint32[] memory royaltiesGroupByParent = new uint32[](parentIpIds.length);
        address[] memory uniqueParents = new address[](parentIpIds.length);
        uint256 uniqueParentCount;
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            (uint256 index, bool exists) = ArrayUtils.indexOf(uniqueParents, parentIpIds[i]);
            if (!exists) {
                index = uniqueParentCount;
                uniqueParentCount++;
            }
            royaltiesGroupByParent[index] += abi.decode(licenseData[i], (uint32));
            uniqueParents[index] = parentIpIds[i];
            _setRoyalty(ipId, parentIpIds[i], royaltiesGroupByParent[index]);
        }

        // calculate new royalty stack
        uint32 royaltyStack = _getRoyaltyStack(ipId);

        if (parentIpIds.length > MAX_PARENTS) revert Errors.RoyaltyPolicyLAP__AboveParentLimit();
        if (_getAncestorCount(ipId) > MAX_ANCESTORS) revert Errors.RoyaltyPolicyLAP__AboveAncestorsLimit();
        if (royaltyStack > TOTAL_RT_SUPPLY) revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        // set the parents as unlinkable / loop limited to 2 parents
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            $.royaltyData[parentIpIds[i]].isUnlinkableToParents = true;
        }

        // deploy ip royalty vault
        address ipRoyaltyVault = address(new BeaconProxy($.ipRoyaltyVaultBeacon, ""));
        IIpRoyaltyVault(ipRoyaltyVault).initialize("Royalty Token", "RT", TOTAL_RT_SUPPLY, royaltyStack, ipId);

        $.royaltyData[ipId] = LAPRoyaltyData({
            // whether calling via minting license or linking to parents the ipId becomes unlinkable
            isUnlinkableToParents: true,
            ipRoyaltyVault: ipRoyaltyVault,
            royaltyStack: royaltyStack
        });

        emit PolicyInitialized(ipId, ipRoyaltyVault, royaltyStack);
    }

    function _getRoyaltyStack(address ipId) internal returns (uint32) {
        (bool success, bytes memory returnData) = IP_GRAPH_CONTRACT.call(
            abi.encodeWithSignature("getRoyaltyStack(address)", ipId)
        );
        require(success, "Call failed");
        return uint32(abi.decode(returnData, (uint256)));
    }

    function _getAncestorCount(address ipId) internal returns (uint256) {
        (bool success, bytes memory returnData) = IP_GRAPH_CONTRACT.call(
            abi.encodeWithSignature("getAncestorIpsCount(address)", ipId)
        );
        require(success, "Call failed");
        return abi.decode(returnData, (uint256));
    }

    function _getRoyalty(address ipId, address parentIpId) internal returns (uint32) {
        (bool success, bytes memory returnData) = IP_GRAPH_CONTRACT.call(
            abi.encodeWithSignature("getRoyalty(address,address)", ipId, parentIpId)
        );
        require(success, "Call failed");
        return uint32(abi.decode(returnData, (uint256)));
    }

    function _setRoyalty(address ipId, address parentIpId, uint32 royalty) internal {
        (bool success, bytes memory returnData) = IP_GRAPH_CONTRACT.call(
            abi.encodeWithSignature("setRoyalty(address,address,uint256)", ipId, parentIpId, uint256(royalty))
        );
        require(success, "Call failed");
    }

    function _getRoyaltyPolicyLAPStorage() private pure returns (RoyaltyPolicyLAPStorage storage $) {
        assembly {
            $.slot := RoyaltyPolicyLAPStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
