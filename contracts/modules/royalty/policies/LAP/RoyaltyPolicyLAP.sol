// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IRoyaltyModule } from "../../../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IIpRoyaltyVault } from "../../../../interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { IDisputeModule } from "../../../../interfaces/modules/dispute/IDisputeModule.sol";
import { IRoyaltyPolicyLAP } from "../../../../interfaces/modules/royalty/policies/LAP/IRoyaltyPolicyLAP.sol";
import { ArrayUtils } from "../../../../lib/ArrayUtils.sol";
import { Errors } from "../../../../lib/Errors.sol";
import { ProtocolPausableUpgradeable } from "../../../../pause/ProtocolPausableUpgradeable.sol";
import { IPGraphACL } from "../../../../access/IPGraphACL.sol";

/// @title Liquid Absolute Percentage Royalty Policy
/// @notice Defines the logic for splitting royalties for a given ipId using a liquid absolute percentage mechanism
contract RoyaltyPolicyLAP is
    IRoyaltyPolicyLAP,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    ProtocolPausableUpgradeable
{
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the RoyaltyPolicyLAP
    /// @param royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @param unclaimedRoyaltyTokens The unclaimed royalty tokens for a given ipId
    /// @param isCollectedByAncestor Whether royalty tokens have been collected by an ancestor for a given ipId
    /// @param revenueTokenBalances The revenue token balances claimed for a given ipId and token
    /// @param snapshotsClaimed Whether a snapshot has been claimed for a given ipId and token
    /// @param snapshotsClaimedCounter The number of snapshots claimed for a given ipId and token
    /// @custom:storage-location erc7201:story-protocol.RoyaltyPolicyLAP
    struct RoyaltyPolicyLAPStorage {
        mapping(address ipId => uint32) royaltyStack;
        mapping(address ipId => uint32) unclaimedRoyaltyTokens;
        mapping(address ipId => mapping(address ancestorIpId => bool)) isCollectedByAncestor;
        mapping(address ipId => mapping(address token => uint256)) revenueTokenBalances;
        mapping(address ipId => mapping(address token => mapping(uint256 snapshotId => bool))) snapshotsClaimed;
        mapping(address ipId => mapping(address token => uint256)) snapshotsClaimedCounter;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.RoyaltyPolicyLAP")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyPolicyLAPStorageLocation =
        0x0c915ba68e2c4e37f19454bb13066f18f9db418fcefbf3c585b4b7d0fb0e0600;

    /// @notice Ip graph precompile contract address
    address public constant IP_GRAPH = address(0x1A);

    /// @notice Returns the RoyaltyModule address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice Dispute module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @notice IPGraphACL address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IPGraphACL public immutable IP_GRAPH_ACL;

    /// @dev Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != address(ROYALTY_MODULE)) revert Errors.RoyaltyPolicyLAP__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param royaltyModule The RoyaltyModule address
    /// @param disputeModule The DisputeModule address
    /// @param ipGraphAcl The IPGraphACL address
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyModule, address disputeModule, address ipGraphAcl) {
        if (royaltyModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroRoyaltyModule();
        if (disputeModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroDisputeModule();
        if (ipGraphAcl == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroIPGraphACL();

        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        IP_GRAPH_ACL = IPGraphACL(ipGraphAcl);

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

    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licensePercent The license percentage of the license being minted
    function onLicenseMinting(
        address ipId,
        uint32 licensePercent,
        bytes calldata
    ) external onlyRoyaltyModule nonReentrant {
        // check if the new license royalty is within the royalty stack limit
        if (_getRoyaltyStack(ipId) + licensePercent > ROYALTY_MODULE.totalRtSupply())
            revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licensesPercent The license percentage of the licenses being minted
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        address[] memory licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        bytes calldata
    ) external onlyRoyaltyModule nonReentrant {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();

        uint32[] memory royaltiesGroupedByParent = new uint32[](parentIpIds.length);
        address[] memory uniqueParents = new address[](parentIpIds.length);
        uint256 uniqueParentCount;

        IP_GRAPH_ACL.allow();
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            if (licenseRoyaltyPolicies[i] != address(this)) {
                // currently only parents being linked through LAP license are added to the precompile
                // so when a parent is linking through a different royalty policy, the royalty amount is set to zero
                _setRoyaltyLAP(ipId, parentIpIds[i], 0);
            } else {
                // for parents linking through LAP license, the royalty amount is set in the precompile
                (uint256 index, bool exists) = ArrayUtils.indexOf(uniqueParents, parentIpIds[i]);
                if (!exists) {
                    index = uniqueParentCount;
                    uniqueParentCount++;
                }
                royaltiesGroupedByParent[index] += licensesPercent[i];
                uniqueParents[index] = parentIpIds[i];
                _setRoyaltyLAP(ipId, parentIpIds[i], royaltiesGroupedByParent[index]);
            }
        }
        IP_GRAPH_ACL.disallow();

        // calculate new royalty stack
        uint32 newRoyaltyStack = _getRoyaltyStack(ipId);
        if (newRoyaltyStack > ROYALTY_MODULE.totalRtSupply()) revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        $.royaltyStack[ipId] = newRoyaltyStack;
        $.unclaimedRoyaltyTokens[ipId] = newRoyaltyStack;
    }

    /// @notice Collects royalty tokens to an ancestor's ip royalty vault
    /// @param ipId The ID of the IP asset
    /// @param ancestorIpId The ID of the ancestor IP asset
    function collectRoyaltyTokens(address ipId, address ancestorIpId) external nonReentrant whenNotPaused {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();

        if (DISPUTE_MODULE.isIpTagged(ipId)) revert Errors.RoyaltyPolicyLAP__IpTagged();
        if ($.isCollectedByAncestor[ipId][ancestorIpId]) revert Errors.RoyaltyPolicyLAP__AlreadyClaimed();

        // check if the address being claimed to is an ancestor
        if (!_hasAncestorIp(ipId, ancestorIpId)) revert Errors.RoyaltyPolicyLAP__ClaimerNotAnAncestor();

        // transfer royalty tokens to the ancestor vault
        uint32 rtsToTransferToAncestor = _getRoyaltyLAP(ipId, ancestorIpId);
        address ipIdIpRoyaltyVault = ROYALTY_MODULE.ipRoyaltyVaults(ipId);
        address ancestorIpRoyaltyVault = ROYALTY_MODULE.ipRoyaltyVaults(ancestorIpId);
        IERC20(ipIdIpRoyaltyVault).safeTransfer(ancestorIpRoyaltyVault, rtsToTransferToAncestor);

        // transfer revenue tokens to the ancestor vault
        address[] memory tokenList = IIpRoyaltyVault(ipIdIpRoyaltyVault).tokens();
        uint256 totalRtSupply = uint256(ROYALTY_MODULE.totalRtSupply());
        uint256 currentSnapshotId = IIpRoyaltyVault(ipIdIpRoyaltyVault).getCurrentSnapshotId();
        for (uint256 i = 0; i < tokenList.length; ++i) {
            uint256 revenueTokenBalance = $.revenueTokenBalances[ipId][tokenList[i]];
            // check if all revenue tokens have been claimed to LAP contract before the ancestor collects royalty tokens
            if (currentSnapshotId != $.snapshotsClaimedCounter[ipId][tokenList[i]]) {
                revert Errors.RoyaltyPolicyLAP__NotAllRevenueTokensHaveBeenClaimed();
            }

            if (revenueTokenBalance > 0) {
                // when unclaimedRoyaltyTokens is zero then all royalty tokens have been claimed and it is ok to revert
                uint256 revenueTokenToTransfer = (revenueTokenBalance * rtsToTransferToAncestor) /
                    $.unclaimedRoyaltyTokens[ipId];
                IERC20(tokenList[i]).safeTransfer(ancestorIpRoyaltyVault, revenueTokenToTransfer);
                IIpRoyaltyVault(ancestorIpRoyaltyVault).addIpRoyaltyVaultTokens(tokenList[i]);
                $.revenueTokenBalances[ipId][tokenList[i]] -= revenueTokenToTransfer;
            }
        }

        $.isCollectedByAncestor[ipId][ancestorIpId] = true;
        $.unclaimedRoyaltyTokens[ipId] -= rtsToTransferToAncestor;

        emit RoyaltyTokensCollected(ipId, ancestorIpId, rtsToTransferToAncestor);
    }

    /// @notice Allows claiming revenue tokens of behalf of royalty LAP royalty policy contract
    /// @param snapshotIds The snapshot IDs to claim revenue tokens for
    /// @param token The token to claim revenue tokens for
    /// @param targetIpId The target IP ID to claim revenue tokens for
    function claimBySnapshotBatchAsSelf(
        uint256[] memory snapshotIds,
        address token,
        address targetIpId
    ) external whenNotPaused nonReentrant {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();

        address targetIpVault = ROYALTY_MODULE.ipRoyaltyVaults(targetIpId);
        if (targetIpVault == address(0)) revert Errors.RoyaltyPolicyLAP__InvalidTargetIpId();

        uint256 tokensClaimed = IIpRoyaltyVault(targetIpVault).claimRevenueBySnapshotBatch(snapshotIds, token);

        // record which snapshots have been claimed for each token to ensure that revenue tokens have been
        // claimed before allowing collecting the royalty tokens
        for (uint256 i = 0; i < snapshotIds.length; i++) {
            if (!$.snapshotsClaimed[targetIpId][token][snapshotIds[i]]) {
                $.snapshotsClaimed[targetIpId][token][snapshotIds[i]] = true;
                $.snapshotsClaimedCounter[targetIpId][token]++;
            }
        }

        $.revenueTokenBalances[targetIpId][token] += tokensClaimed;
    }

    /// @notice Returns the amount of royalty tokens required to link a child to a given IP asset
    /// @param ipId The ipId of the IP asset
    /// @param licensePercent The percentage of the license
    /// @return The amount of royalty tokens required to link a child to a given IP asset
    function rtsRequiredToLink(address ipId, uint32 licensePercent) external view returns (uint32) {
        return (_getRoyaltyPolicyLAPStorage().royaltyStack[ipId] + licensePercent);
    }

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ipId to get the royalty data for
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    function royaltyStack(address ipId) external view returns (uint32) {
        return _getRoyaltyPolicyLAPStorage().royaltyStack[ipId];
    }

    /// @notice Returns the unclaimed royalty tokens for a given IP asset
    /// @param ipId The ipId to get the unclaimed royalty tokens for
    function unclaimedRoyaltyTokens(address ipId) external view returns (uint32) {
        return _getRoyaltyPolicyLAPStorage().unclaimedRoyaltyTokens[ipId];
    }

    /// @notice Returns if the royalty tokens have been collected by an ancestor for a given IP asset
    /// @param ipId The ipId to check if the royalty tokens have been collected by an ancestor
    /// @param ancestorIpId The ancestor ipId to check if the royalty tokens have been collected
    function isCollectedByAncestor(address ipId, address ancestorIpId) external view returns (bool) {
        return _getRoyaltyPolicyLAPStorage().isCollectedByAncestor[ipId][ancestorIpId];
    }

    /// @notice Returns the revenue token balances for a given IP asset
    /// @param ipId The ipId to get the revenue token balances for
    /// @param token The token to get the revenue token balances for
    function revenueTokenBalances(address ipId, address token) external view returns (uint256) {
        return _getRoyaltyPolicyLAPStorage().revenueTokenBalances[ipId][token];
    }

    /// @notice Returns whether a snapshot has been claimed for a given IP asset and token
    /// @param ipId The ipId to check if the snapshot has been claimed for
    /// @param token The token to check if the snapshot has been claimed for
    /// @param snapshot The snapshot to check if it has been claimed
    function snapshotsClaimed(address ipId, address token, uint256 snapshot) external view returns (bool) {
        return _getRoyaltyPolicyLAPStorage().snapshotsClaimed[ipId][token][snapshot];
    }

    /// @notice Returns the number of snapshots claimed for a given IP asset and token
    /// @param ipId The ipId to check if the snapshot has been claimed for
    /// @param token The token to check if the snapshot has been claimed for
    function snapshotsClaimedCounter(address ipId, address token) external view returns (uint256) {
        return _getRoyaltyPolicyLAPStorage().snapshotsClaimedCounter[ipId][token];
    }

    /// @notice Returns the royalty stack for a given IP asset
    /// @param ipId The ipId to get the royalty stack for
    /// @return The royalty stack for a given IP asset
    function _getRoyaltyStack(address ipId) internal returns (uint32) {
        (bool success, bytes memory returnData) = IP_GRAPH.call(
            abi.encodeWithSignature("getRoyaltyStack(address)", ipId)
        );
        require(success, "Call failed");
        return uint32(abi.decode(returnData, (uint256)));
    }

    /// @notice Returns whether and IP is an ancestor of a given IP
    /// @param ipId The ipId to check if it has an ancestor
    /// @param ancestorIpId The ancestor ipId to check if it is an ancestor
    /// @return True if the IP has the ancestor
    function _hasAncestorIp(address ipId, address ancestorIpId) internal returns (bool) {
        (bool success, bytes memory returnData) = IP_GRAPH.call(
            abi.encodeWithSignature("hasAncestorIp(address,address)", ipId, ancestorIpId)
        );
        require(success, "Call failed");
        return abi.decode(returnData, (bool));
    }

    /// @notice Sets the LAP royalty for a given IP asset
    /// @param ipId The ipId to set the royalty for
    /// @param parentIpId The parent ipId to set the royalty for
    /// @param royalty The LAP license royalty amount
    function _setRoyaltyLAP(address ipId, address parentIpId, uint32 royalty) internal {
        (bool success, bytes memory returnData) = IP_GRAPH.call(
            abi.encodeWithSignature("setRoyalty(address,address,uint256)", ipId, parentIpId, uint256(royalty))
        );
        require(success, "Call failed");
    }

    /// @notice Returns the royalty from LAP licenses for a given IP asset
    /// @param ipId The ipId to get the royalty for
    /// @param parentIpId The parent ipId to get the royalty for
    /// @return The LAP license royalty amount
    function _getRoyaltyLAP(address ipId, address parentIpId) internal returns (uint32) {
        (bool success, bytes memory returnData) = IP_GRAPH.call(
            abi.encodeWithSignature("getRoyalty(address,address)", ipId, parentIpId)
        );
        require(success, "Call failed");
        return uint32(abi.decode(returnData, (uint256)));
    }

    /// @notice Returns the storage struct for the RoyaltyPolicyLAP
    function _getRoyaltyPolicyLAPStorage() private pure returns (RoyaltyPolicyLAPStorage storage $) {
        assembly {
            $.slot := RoyaltyPolicyLAPStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
