// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IRoyaltyModule } from "../../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IDisputeModule } from "../../../../contracts/interfaces/modules/dispute/IDisputeModule.sol";
// solhint-disable-next-line max-line-length
import { IGraphAwareRoyaltyPolicy } from "../../../../contracts/interfaces/modules/royalty/policies/IGraphAwareRoyaltyPolicy.sol";

contract MockRoyaltyPolicyLAP is IGraphAwareRoyaltyPolicy {
    struct RoyaltyPolicyLAPStorage {
        mapping(address ipId => uint32) royaltyStack;
    }

    bytes32 private constant RoyaltyPolicyLAPStorageLocation =
        0x0c915ba68e2c4e37f19454bb13066f18f9db418fcefbf3c585b4b7d0fb0e0600;

    uint256 public constant MAX_PARENTS = 100;
    uint256 public constant MAX_ANCESTORS = 100;
    address public constant LICENSING_MODULE = address(0);
    address public constant IP_GRAPH = address(0);
    IRoyaltyModule public constant ROYALTY_MODULE = IRoyaltyModule(address(0));
    IDisputeModule public constant DISPUTE_MODULE = IDisputeModule(address(0));

    constructor() {}

    function onLicenseMinting(address ipId, uint32 licensePercent, bytes calldata externalData) external {}

    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        address[] calldata ancestorsRules,
        uint32[] memory licensesPercent,
        bytes calldata externalData
    ) external returns (uint32) {}

    function getPolicyRtsRequiredToLink(address ipId, uint32 licensePercent) external view returns (uint32) {}
    function getPolicyRoyaltyStack(address ipId) external view returns (uint32) {
        return _getRoyaltyPolicyLAPStorage().royaltyStack[ipId];
    }
    function collectRoyaltyTokens(address ipId, address ancestorIpId) external {}
    function claimBySnapshotBatchAsSelf(uint256[] memory snapshotIds, address token, address targetIpId) external {}
    function unclaimedRoyaltyTokens(address ipId) external view returns (uint32) {}
    function isCollectedByAncestor(address ipId, address ancestorIpId) external view returns (bool) {}
    function revenueTokenBalances(address ipId, address token) external view returns (uint256) {}
    function snapshotsClaimed(address ipId, address token, uint256 snapshot) external view returns (bool) {}
    function snapshotsClaimedCounter(address ipId, address token) external view returns (uint256) {}
    function transferToVault(address ipId, address ancestorIpId, address token, uint256 amount) external {}
    function getPolicyRoyalty(address ipId, address ancestorIpId) external view returns (uint32) {}
    function getAncestorPercent(address ipId, address ancestorIpId) external view returns (uint32) {}
    function getTransferredTokens(address ipId, address ancestorIpId, address token) external view returns (uint256) {}

    function _getRoyaltyPolicyLAPStorage() private pure returns (RoyaltyPolicyLAPStorage storage $) {
        assembly {
            $.slot := RoyaltyPolicyLAPStorageLocation
        }
    }
}
