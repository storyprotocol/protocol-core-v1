// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IIPAccountRegistry } from "../../interfaces/registries/IIPAccountRegistry.sol";
import { ITokenWithdrawalModule } from "../../interfaces/modules/external/ITokenWithdrawalModule.sol";
import { IPAccountChecker } from "../../lib/registries/IPAccountChecker.sol";
import { TOKEN_WITHDRAWAL_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";

/// @title Token Management Module
/// @notice Module for transferring ERC20, ERC721, and ERC1155 tokens for IP Accounts.
/// @dev SECURITY RISK: An IPAccount can delegate to a frontend contract (not a registered module) to transfer tokens
/// on behalf of the IPAccount via the Token Management Module. This frontend contract can transfer any tokens that are
/// approved by the IPAccount for the Token Management Module. In other words, there's no mechanism for this module to
/// granularly control which token a caller (approved contract in this case) can transfer.
contract TokenWithdrawalModule is AccessControlled, BaseModule, ITokenWithdrawalModule {
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;

    string public constant override name = TOKEN_WITHDRAWAL_MODULE_KEY;

    constructor(address accessController) AccessControlled(accessController) {}

    /// @notice Withdraws ERC20 token from the IP account to the IP account owner.
    /// @dev When calling this function, the caller must have the permission to call `transfer` via the IP account.
    /// @dev Does not support transfer of multiple tokens at once.
    /// @param ipAccount The IP account to transfer the ERC20 token from
    /// @param tokenContract The address of the ERC20 token contract
    /// @param amount The amount of token to transfer
    function withdrawERC20(
        address payable ipAccount,
        address tokenContract,
        uint256 amount
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature("transfer(address,uint256)", IIPAccount(ipAccount).owner(), amount)
        );
    }

    /// @notice Withdraws ERC721 token from the IP account to the IP account owner.
    /// @dev When calling this function, the caller must have the permission to call `transferFrom` via the IP account.
    /// @dev Does not support batch transfers.
    /// @param ipAccount The IP account to transfer the ERC721 token from
    /// @param tokenContract The address of the ERC721 token contract
    /// @param tokenId The ID of the token to transfer
    function withdrawERC721(
        address payable ipAccount,
        address tokenContract,
        uint256 tokenId
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                ipAccount,
                IIPAccount(ipAccount).owner(),
                tokenId
            )
        );
    }

    /// @notice Withdraws ERC1155 token from the IP account to the IP account owner.
    /// @dev When calling this function, the caller must have the permission to call `safeTransferFrom` via the IP
    /// account.
    /// @dev Does not support batch transfers.
    /// @param ipAccount The IP account to transfer the ERC1155 token from
    /// @param tokenContract The address of the ERC1155 token contract
    /// @param tokenId The ID of the token to transfer
    /// @param amount The amount of token to transfer
    function withdrawERC1155(
        address payable ipAccount,
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,uint256,bytes)",
                ipAccount,
                IIPAccount(ipAccount).owner(),
                tokenId,
                amount,
                ""
            )
        );
    }
}
