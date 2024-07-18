// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { DoubleEndedQueue } from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";

contract MockIPGraph {
    using EnumerableSet for EnumerableSet.AddressSet;
    using DoubleEndedQueue for DoubleEndedQueue.Bytes32Deque;
    mapping(address childIpId => EnumerableSet.AddressSet parentIpIds) parentIps;
    mapping(address ipId => mapping(address parentIpId => uint256)) royalties;
    EnumerableSet.AddressSet ancestorIps;
    DoubleEndedQueue.Bytes32Deque queue;

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
    function setRoyalty(address ipId, address parentIpId, uint256 royaltyPercentage) external {
        royalties[ipId][parentIpId] = royaltyPercentage;
    }
    function getRoyalty(address ipId, address ancestorIpId) external returns (uint256) {
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
                    totalRoyalty += royalties[currentIpId][ancestorIpId];
                }
            }
        }
        return totalRoyalty;
    }
    function getRoyaltyStack(address ipId) external returns (uint256) {
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
                royaltyStack += royalties[currentIpId][parentIpId];
            }
        }
        return royaltyStack;
    }
    function _cleanAncestorIps() internal {
        uint256 length = ancestorIps.length();
        for (uint256 i = 0; i < length; i++) {
            ancestorIps.remove(ancestorIps.at(0));
        }
    }
    function _toBytes32(address value) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }
    function _toAddress(bytes32 value) internal pure returns (address) {
        return address(uint160(uint256(value)));
    }
}
