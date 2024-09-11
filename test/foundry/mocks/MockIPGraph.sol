// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

contract MockIPGraph {
    using EnumerableSet for EnumerableSet.AddressSet;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;

    uint256 public constant POLICY_KIND_LAP = 0;
    uint256 public constant POLICY_KIND_LRP = 1;
    uint32 public constant HUNDRED_PERCENT = 100000000; // 100 * 10 ** 6

    mapping(address childIpId => EnumerableSet.AddressSet parentIpIds) parentIps;
    mapping(address parentIpId => address childIpId) childMap;
    mapping(address ipId => mapping(address parentIpId => uint256 percent)) royaltiesLap;
    mapping(address ipId => mapping(address parentIpId => uint256 percent)) royaltiesLrp;
    mapping(address ipId => mapping(address parentIdId => mapping(uint256 policyKind => uint256 percent))) royalties;
    mapping(address ipId => mapping(uint256 policyKind => uint256)) royaltyStacks;
    EnumerableSet.AddressSet ancestorIps;
    DoubleEndedQueue.Bytes32Deque queue;
    DoubleEndedQueue.Bytes32Deque lrpQueue;

    function addParentIp(address ipId, address[] calldata parentIpIds) external {
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            parentIps[ipId].add(parentIpIds[i]);
        }
    }
    function hasParentIp(address ipId, address parent) external view returns (bool) {
        return parentIps[ipId].contains(parent);
    }
    function getParentIps(address ipId) external view returns (address[] memory) {
        return parentIps[ipId].values();
    }
    function getParentIpsCount(address ipId) external view returns (uint256) {
        return parentIps[ipId].length();
    }
    function hasAncestorIp(address ipId, address ancestor) external returns (bool) {
        _cleanAncestorIps();
        queue.pushFront(_toBytes32(ipId));
        while (queue.length() > 0) {
            address currentIpId = _toAddress(queue.popFront());
            for (uint256 i = 0; i < parentIps[currentIpId].length(); i++) {
                address parentIpId = parentIps[currentIpId].at(i);
                if (parentIpId == ancestor) {
                    return true;
                }
                if (!ancestorIps.contains(parentIpId)) {
                    ancestorIps.add(parentIpId);
                    queue.pushFront(_toBytes32(parentIpId));
                }
            }
        }
        return false;
    }
    function getAncestorIpsCount(address ipId) external returns (uint256) {
        _cleanAncestorIps();
        queue.pushFront(_toBytes32(ipId));
        while (queue.length() > 0) {
            address currentIpId = _toAddress(queue.popFront());
            for (uint256 i = 0; i < parentIps[currentIpId].length(); i++) {
                address parentIpId = parentIps[currentIpId].at(i);
                if (!ancestorIps.contains(parentIpId)) {
                    ancestorIps.add(parentIpId);
                    queue.pushFront(_toBytes32(parentIpId));
                }
            }
        }
        return ancestorIps.length();
    }
    function getAncestorIps(
        address ipId,
        uint256 startIndex,
        uint256 pageSize
    ) external view returns (address[] memory) {
        return new address[](0);
    }

    function setRoyalty(address ipId, address parentIpId, uint256 policyKind, uint256 royaltyPercentage) external {
        _setRoyalty(ipId, parentIpId, policyKind, royaltyPercentage);
    }

    function getRoyalty(address ipId, address ancestorIpId, uint256 policyKind) external returns (uint256) {
        return _getRoyalty(ipId, ancestorIpId, policyKind);
    }

    function getRoyaltyStack(address ipId, uint256 policyKind) external returns (uint256) {
        return _getRoyaltyStack(ipId, policyKind);
    }

    function _setRoyalty(address ipId, address parentIpId, uint256 policyKind, uint256 royaltyPercentage) internal {
        if (policyKind == POLICY_KIND_LAP) royaltiesLap[ipId][parentIpId] = royaltyPercentage;
        if (policyKind == POLICY_KIND_LRP) royaltiesLrp[ipId][parentIpId] = royaltyPercentage;
    }

    function _getRoyalty(address ipId, address ancestorIpId, uint256 policyKind) internal returns (uint256) {
        uint256 totalRoyalty = 0;
        if (policyKind == POLICY_KIND_LAP) {
            totalRoyalty = _getRoyaltyLap(ipId, ancestorIpId);
        }
        if (policyKind == POLICY_KIND_LRP) {
            totalRoyalty = _getRoyaltyLrp(ipId, ancestorIpId);
        }

        return totalRoyalty;
    }

    // solhint-disable-next-line code-complexity
    function _getRoyaltyLrp(address ipId, address ancestorIpId) internal returns (uint256 result) {
        result = 0;
        _cleanAncestorIps();
        queue.pushFront(_toBytes32(ipId));
        while (queue.length() > 0) {
            address currentIpId = _toAddress(queue.popFront());
            if (currentIpId == ancestorIpId) {
                break;
            }
            if (parentIps[currentIpId].length() == 0) {
                continue;
            }
            for (uint256 i = 0; i < parentIps[currentIpId].length(); i++) {
                address parentIpId = parentIps[currentIpId].at(i);
                childMap[parentIpId] = currentIpId;
                if (!ancestorIps.contains(parentIpId)) {
                    ancestorIps.add(parentIpId);
                    queue.pushFront(_toBytes32(parentIpId));
                }
            }
        }
        address currentIpId = ancestorIpId;
        while (currentIpId != ipId) {
            lrpQueue.pushFront(_toBytes32(currentIpId));
            address childIpId = childMap[currentIpId];
            currentIpId = childIpId;
        }
        currentIpId = ipId;
        if (lrpQueue.length() > 0) {
            address parentIpId = _toAddress(lrpQueue.popFront());
            result = royaltiesLrp[currentIpId][parentIpId];
            currentIpId = parentIpId;
            while (lrpQueue.length() > 0) {
                parentIpId = _toAddress(lrpQueue.popFront());
                result = (result * royaltiesLrp[currentIpId][parentIpId]) / HUNDRED_PERCENT;
            }
        }
    }

    function _getRoyaltyLap(address ipId, address ancestorIpId) internal returns (uint256) {
        uint256 totalRoyalty = 0;
        _cleanAncestorIps();
        queue.pushFront(_toBytes32(ipId));
        while (queue.length() > 0) {
            address currentIpId = _toAddress(queue.popFront());
            for (uint256 i = 0; i < parentIps[currentIpId].length(); i++) {
                address parentIpId = parentIps[currentIpId].at(i);
                if (!ancestorIps.contains(parentIpId)) {
                    ancestorIps.add(parentIpId);
                    queue.pushFront(_toBytes32(parentIpId));
                }
                if (parentIpId == ancestorIpId) {
                    totalRoyalty += royaltiesLap[currentIpId][ancestorIpId];
                }
            }
        }
        return totalRoyalty;
    }

    function _getRoyaltyStack(address ipId, uint256 policyKind) internal returns (uint256) {
        uint256 royaltyStack = 0;
        if (policyKind == POLICY_KIND_LAP) {
            royaltyStack = _getRoyaltyStackLap(ipId);
        }
        if (policyKind == POLICY_KIND_LRP) {
            royaltyStack = _getRoyaltyStackLrp(ipId);
        }
        return royaltyStack;
    }

    function _getRoyaltyStackLrp(address ipId) internal returns (uint256) {
        uint256 royaltyStack = 0;
        for (uint256 i = 0; i < parentIps[ipId].length(); i++) {
            address parentIpId = parentIps[ipId].at(i);
            royaltyStack += royaltiesLrp[ipId][parentIpId];
        }
        return royaltyStack;
    }

    function _getRoyaltyStackLap(address ipId) internal returns (uint256) {
        uint256 royaltyStack = 0;
        _cleanAncestorIps();
        queue.pushFront(_toBytes32(ipId));
        while (queue.length() > 0) {
            address currentIpId = _toAddress(queue.popFront());
            for (uint256 i = 0; i < parentIps[currentIpId].length(); i++) {
                address parentIpId = parentIps[currentIpId].at(i);
                if (!ancestorIps.contains(parentIpId)) {
                    ancestorIps.add(parentIpId);
                    queue.pushFront(_toBytes32(parentIpId));
                }
                royaltyStack += royaltiesLap[currentIpId][parentIpId];
            }
        }
        return royaltyStack;
    }

    function _cleanAncestorIps() internal {
        uint256 length = ancestorIps.length();
        for (uint256 i = 0; i < length; i++) {
            ancestorIps.remove(ancestorIps.at(0));
        }
        lrpQueue.clear();
        queue.clear();
    }
    function _toBytes32(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }
    function _toAddress(bytes32 value) internal pure returns (address) {
        return address(uint160(uint256(value)));
    }
}
