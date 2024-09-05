import { IpRoyaltyVault } from "contracts/modules/royalty/policies/IpRoyaltyVault.sol";

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

contract MockIpRoyaltyVaultV2 is IpRoyaltyVault {
    /// @dev Storage structure for the MockIPRoyaltyVaultV2
    /// @custom:storage-location erc7201:story-protocol.MockIPRoyaltyVaultV2
    struct MockIPRoyaltyVaultV2Storage {
        string newState;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.MockIPRoyaltyVaultV2")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant MockIPRoyaltyVaultV2StorageLocation =
        0x2942176f94974e015a9b06f79a3a2280d18f1872591c134ba237fa184e378300;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyPolicyLAP, address disputeModule) IpRoyaltyVault(royaltyPolicyLAP, disputeModule) {
        _disableInitializers();
    }

    function set(string calldata value) external {
        _getMockIPRoyaltyVaultV2Storage().newState = value;
    }

    function get() external view returns (string memory) {
        return _getMockIPRoyaltyVaultV2Storage().newState;
    }

    /// @dev Returns the storage struct of MockIPRoyaltyVaultV2.
    function _getMockIPRoyaltyVaultV2Storage() private pure returns (MockIPRoyaltyVaultV2Storage storage $) {
        assembly {
            $.slot := MockIPRoyaltyVaultV2StorageLocation
        }
    }
}
