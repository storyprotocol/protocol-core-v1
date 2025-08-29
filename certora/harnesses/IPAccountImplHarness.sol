// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// Simplified harness that mimics IPAccountImpl behavior for testing
contract IPAccountImplHarness {
    address private _owner;
    mapping(address => bool) private _validSigners;

    // Mock constants
    address public constant ACCESS_CONTROLLER = address(0x1);
    address public constant IP_ASSET_REGISTRY = address(0x2);
    address public constant MODULE_REGISTRY = address(0x3);
    address public constant LICENSE_REGISTRY = address(0x4);

    constructor() {
        _owner = address(0x1000); // Set a default owner for testing
    }

    // Core functions for testing
    function owner() public view returns (address) {
        return _owner;
    }

    function setOwner(address newOwner) external {
        _owner = newOwner;
    }

    // Simplified execute function that mimics the access control logic
    function execute(address to, uint256 value, bytes calldata data) external payable returns (bytes memory result) {
        // Check data length (line 108-110 from original)
        if (data.length > 0 && data.length < 4) {
            revert("IPAccount__InvalidCalldata");
        }

        // Check if signer is valid (simplified version of isValidSigner)
        if (!isValidSigner(msg.sender, to, data)) {
            revert("IPAccount__InvalidSigner");
        }

        // Mock successful execution
        return "";
    }

    // Simplified isValidSigner that only allows owner
    function isValidSigner(address signer, address to, bytes calldata data) public view returns (bool) {
        return signer == _owner;
    }

    // Mock state function
    function state() external pure returns (bytes32) {
        return keccak256("mock_state");
    }

    // Mock token function
    function token() external pure returns (uint256, address, uint256) {
        return (1, address(0x5), 1);
    }
}