// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManaged } from "@openzeppelin/contracts/access/manager/AccessManaged.sol";
import { Errors } from "../lib/Errors.sol";

/// @title IPGraphACL
/// @notice This contract is used to manage access to the IPGraph contract.
/// It allows the access manager to whitelist addresses that can allow or disallow access to the IPGraph contract.
/// It allows whitelisted addresses to allow or disallow access to the IPGraph contract.
/// IPGraph precompiled check if the IPGraphACL contract allows access to the IPGraph.
contract IPGraphACL is AccessManaged {
    // keccak256(abi.encode(uint256(keccak256("story-protocol.IPGraphACL")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IP_GRAPH_ACL_SLOT = 0xaf99b37fdaacca72ee7240cb1435cc9e498aee6ef4edc19c8cc0cd787f4e6800;

    /// @notice Whitelisted addresses that can allow or disallow access to the IPGraph contract.
    mapping(address => bool) public whitelist;

    modifier onlyWhitelisted() {
        if (!whitelist[msg.sender]) {
            revert Errors.IPGraphACL__NotWhitelisted(msg.sender);
        }
        _;
    }

    constructor(address accessManager) AccessManaged(accessManager) {}

    /// @notice Allow access to the IPGraph contract.
    function allow() external onlyWhitelisted {
        bytes32 slot = IP_GRAPH_ACL_SLOT;
        bool value = true;

        assembly {
            sstore(slot, value)
        }
    }

    /// @notice Disallow access to the IPGraph contract.
    function disallow() external onlyWhitelisted {
        bytes32 slot = IP_GRAPH_ACL_SLOT;
        bool value = false;

        assembly {
            sstore(slot, value)
        }
    }

    /// @notice Check if access to the IPGraph contract is allowed.
    function isAllowed() external view returns (bool) {
        bytes32 slot = IP_GRAPH_ACL_SLOT;
        bool value;

        assembly {
            value := sload(slot)
        }

        return value;
    }

    /// @notice Whitelist an address that can allow or disallow access to the IPGraph contract.
    /// @param addr The address to whitelist.
    function whitelistAddress(address addr) external restricted {
        whitelist[addr] = true;
    }

    /// @notice Revoke whitelisted address.
    /// @param addr The address to revoke.
    function revokeWhitelistedAddress(address addr) external restricted {
        whitelist[addr] = false;
    }

    /// @notice Check if an address is whitelisted.
    /// @param addr The address to check.
    function isWhitelisted(address addr) external view returns (bool) {
        return whitelist[addr];
    }
}
