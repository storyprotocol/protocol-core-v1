// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/// @title MetaTx
/// @dev This library provides functions for handling meta transactions in the Story Protocol.
library MetaTx {
    /// @dev Version of the EIP712 domain.
    string public constant EIP712_DOMAIN_VERSION = "1";
    /// @dev Hash of the EIP712 domain version.
    bytes32 public constant EIP712_DOMAIN_VERSION_HASH = keccak256(bytes(EIP712_DOMAIN_VERSION));
    /// @dev EIP712 domain type hash.
    bytes32 public constant EIP712_DOMAIN =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /// @dev Execute type hash.
    bytes32 public constant EXECUTE =
        keccak256("Execute(address to,uint256 value,bytes data,bytes32 nonce,uint256 deadline)");

    /// @dev Structure for the Execute type.
    struct Execute {
        address to;
        uint256 value;
        bytes data;
        bytes32 nonce;
        uint256 deadline;
    }

    /// @dev Calculates the EIP712 domain separator for the current contract.
    /// @return The EIP712 domain separator.
    function calculateDomainSeparator() internal view returns (bytes32) {
        return calculateDomainSeparator(address(this));
    }

    /// @dev Calculates the EIP712 domain separator for a given IP account.
    /// @param ipAccount The IP account for which to calculate the domain separator.
    /// @return The EIP712 domain separator.
    function calculateDomainSeparator(address ipAccount) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN,
                    keccak256("Story Protocol IP Account"),
                    EIP712_DOMAIN_VERSION_HASH,
                    block.chainid,
                    ipAccount
                )
            );
    }

    /// @dev Calculates the EIP712 struct hash of an Execute.
    /// @param execute The Execute to hash.
    /// @return The EIP712 struct hash of the Execute.
    function getExecuteStructHash(Execute memory execute) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MetaTx.EXECUTE,
                    execute.to,
                    execute.value,
                    keccak256(execute.data),
                    execute.nonce,
                    execute.deadline
                )
            );
    }
}
