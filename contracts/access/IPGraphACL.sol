// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { StorageSlot } from "@openzeppelin/contracts/utils/StorageSlot.sol";
import { Errors } from "../lib/Errors.sol";
import { IIPGraphACL } from "../interfaces/access/IIPGraphACL.sol";

/// @title IPGraphACL
/// @notice This contract is used to manage access to the IPGraph contract.
/// It allows the access manager to whitelist addresses that can allow or disallow access to the IPGraph contract.
/// It allows whitelisted addresses to allow or disallow access to the IPGraph contract.
/// IPGraph precompiled check if the IPGraphACL contract allows access to the IPGraph.
contract IPGraphACL is AccessManaged, IIPGraphACL {
    // keccak256(abi.encode(uint256(keccak256("story-protocol.IPGraphACL")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IP_GRAPH_ACL_SLOT = 0xaf99b37fdaacca72ee7240cb1435cc9e498aee6ef4edc19c8cc0cd787f4e6800;
    // keccak256(abi.encode(uint256(keccak256("story-protocol.IPGraphACL.internal")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IP_GRAPH_ACL_INTERNAL_SLOT =
        0x12f3ababaacf4ad583e6f4432db5f70a1dbfa9803ecdf84a0efbfe1521160600;

    modifier onlyWhitelisted() {
        if (!_isWhitelisted(msg.sender)) {
            revert Errors.IPGraphACL__NotWhitelisted(msg.sender);
        }
        _;
    }

    constructor(address accessManager) AccessManaged(accessManager) {}

    /// @notice Start access to the IPGraph contract from internal contracts.
    function startInternalAccess() external onlyWhitelisted {
        bytes32 slot = IP_GRAPH_ACL_INTERNAL_SLOT;
        bool value = true;

        assembly {
            tstore(slot, value)
        }
    }

    /// @notice End internal access to the IPGraph contract.
    function endInternalAccess() external onlyWhitelisted {
        bytes32 slot = IP_GRAPH_ACL_INTERNAL_SLOT;
        bool value = false;

        assembly {
            tstore(slot, value)
        }
    }

    /// @notice Check if access to the IPGraph contract is from internal contract.
    function isInternalAccess() external view returns (bool) {
        bytes32 slot = IP_GRAPH_ACL_INTERNAL_SLOT;
        bool value;

        assembly {
            value := tload(slot)
        }

        return value;
    }

    /// @notice Whitelist an address that can allow or disallow access to the IPGraph contract.
    /// @param addr The address to whitelist.
    function whitelistAddress(address addr) external restricted {
        StorageSlot.getBooleanSlot(keccak256(abi.encodePacked(addr, IP_GRAPH_ACL_SLOT))).value = true;
        emit WhitelistedAddress(addr);
    }

    /// @notice Revoke whitelisted address.
    /// @param addr The address to revoke.
    function revokeWhitelistedAddress(address addr) external restricted {
        StorageSlot.getBooleanSlot(keccak256(abi.encodePacked(addr, IP_GRAPH_ACL_SLOT))).value = false;
        emit RevokedWhitelistedAddress(addr);
    }

    /// @notice Check if an address is whitelisted.
    /// @param addr The address to check.
    function isWhitelisted(address addr) external view returns (bool) {
        return _isWhitelisted(addr);
    }

    function _isWhitelisted(address addr) internal view returns (bool) {
        return StorageSlot.getBooleanSlot(keccak256(abi.encodePacked(addr, IP_GRAPH_ACL_SLOT))).value;
    }
}
