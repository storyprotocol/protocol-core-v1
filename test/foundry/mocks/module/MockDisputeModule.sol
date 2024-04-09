// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IDisputeModule } from "../../../../contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../../../contracts/interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";
import { ShortStringOps } from "../../../../contracts/utils/ShortStringOps.sol";

contract MockDisputeModule is BaseModule, IDisputeModule {
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");

    string public constant override name = "DISPUTE_MODULE";
    uint256 public disputeCounter;
    address public baseArbitrationPolicy;

    mapping(uint256 disputeId => Dispute dispute) public disputes;
    mapping(bytes32 tag => bool allowed) public isWhitelistedDisputeTag;
    mapping(address arbitrationPolicy => bool allowed) public isWhitelistedArbitrationPolicy;
    mapping(address arbitrationPolicy => mapping(address arbitrationRelayer => bool allowed))
        public isWhitelistedArbitrationRelayer;
    mapping(address ipId => address arbitrationPolicy) public arbitrationPolicies;

    function whitelistDisputeTag(bytes32 _tag, bool _allowed) external {
        isWhitelistedDisputeTag[_tag] = _allowed;
    }

    function whitelistArbitrationPolicy(address _arbitrationPolicy, bool _allowed) external {
        isWhitelistedArbitrationPolicy[_arbitrationPolicy] = _allowed;
    }

    function whitelistArbitrationRelayer(
        address _arbitrationPolicy,
        address _arbPolicyRelayer,
        bool _allowed
    ) external {
        isWhitelistedArbitrationRelayer[_arbitrationPolicy][_arbPolicyRelayer] = _allowed;
    }

    function setBaseArbitrationPolicy(address _arbitrationPolicy) external {
        baseArbitrationPolicy = _arbitrationPolicy;
    }

    function setArbitrationPolicy(address _ipId, address _arbitrationPolicy) external {
        arbitrationPolicies[_ipId] = _arbitrationPolicy;
    }

    function raiseDispute(
        address _targetIpId,
        string memory _linkToDisputeEvidence,
        bytes32 _targetTag,
        bytes calldata
    ) public returns (uint256) {
        bytes32 linkToDisputeEvidence = ShortStringOps.stringToBytes32(_linkToDisputeEvidence);
        address arbitrationPolicy = arbitrationPolicies[_targetIpId];
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = baseArbitrationPolicy;

        uint256 disputeId_ = ++disputeCounter;

        disputes[disputeId_] = Dispute({
            targetIpId: _targetIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: arbitrationPolicy,
            linkToDisputeEvidence: linkToDisputeEvidence,
            targetTag: _targetTag,
            currentTag: IN_DISPUTE
        });

        return disputeId_;
    }

    function raiseDisputeWithCallback(
        address _targetIpId,
        string memory _linkToDisputeEvidence,
        bytes32 _targetTag,
        bytes calldata _data
    ) external returns (uint256 disputeId_) {
        disputeId_ = raiseDispute(_targetIpId, _linkToDisputeEvidence, _targetTag, _data);

        address arbitrationPolicy = arbitrationPolicies[_targetIpId];
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = baseArbitrationPolicy;
        IArbitrationPolicy(arbitrationPolicy).onRaiseDispute(msg.sender, _data);
    }

    function setDisputeJudgement(uint256 _disputeId, bool _decision, bytes calldata) public {
        Dispute memory dispute = disputes[_disputeId];
        disputes[_disputeId].currentTag = _decision ? dispute.targetTag : bytes32(0);
    }

    function setDisputeJudgementWithCallback(uint256 _disputeId, bool _decision, bytes calldata _data) external {
        setDisputeJudgement(_disputeId, _decision, _data);

        Dispute memory dispute = disputes[_disputeId];
        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeJudgement(_disputeId, _decision, _data);
    }

    function cancelDispute(uint256 _disputeId, bytes calldata) public {
        disputes[_disputeId].currentTag = bytes32(0);
    }

    function cancelDisputeWithCallback(uint256 _disputeId, bytes calldata _data) external {
        cancelDispute(_disputeId, _data);

        Dispute memory dispute = disputes[_disputeId];
        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeCancel(msg.sender, _disputeId, _data);
    }

    function resolveDispute(uint256 _disputeId, bytes calldata _data) external {
        disputes[_disputeId].currentTag = bytes32(0);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IDisputeModule).interfaceId || super.supportsInterface(interfaceId);
    }

    // These methods are not really used in the mock. They are just here to satisfy the interface.

    function isIpTagged(address) external pure returns (bool) {
        return false;
    }
}
