// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IAncestorsVaultLAP } from "../../../interfaces/modules/royalty/policies/IAncestorsVaultLAP.sol";
import { ILiquidSplitClone } from "../../../interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { ILiquidSplitMain } from "../../../interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { IRoyaltyPolicyLAP } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { ArrayUtils } from "../../../lib/ArrayUtils.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Liquid Absolute Percentage Policy Ancestors Vault
/// @notice The ancestors vault allows parents and grandparents to claim their share of
///         the royalty nfts of their children and grandchildren along with any accrued royalties.
contract AncestorsVaultLAP is IAncestorsVaultLAP, ERC1155Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The liquid split royalty policy address
    IRoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;

    /// @notice Indicates if a given ancestor address has already claimed
    mapping(address ipId => mapping(address claimerIpId => bool)) public isClaimed;

    constructor(address royaltyPolicyLAP) {
        if (royaltyPolicyLAP == address(0)) revert Errors.AncestorsVaultLAP__ZeroRoyaltyPolicyLAP();

        ROYALTY_POLICY_LAP = IRoyaltyPolicyLAP(royaltyPolicyLAP);
    }

    /// @notice Claims all available royalty nfts and accrued royalties for an ancestor of a given ipId
    /// @param ipId The ipId of the ancestors vault to claim from
    /// @param claimerIpId The claimer ipId is the ancestor address that wants to claim
    /// @param ancestors The ancestors for the selected ipId
    /// @param ancestorsRoyalties The royalties of the ancestors for the selected ipId
    /// @param tokens The ERC20 tokens to withdraw
    function claim(
        address ipId,
        address claimerIpId,
        address[] calldata ancestors,
        uint32[] calldata ancestorsRoyalties,
        ERC20[] calldata tokens
    ) external nonReentrant {
        (, address splitClone, address ancestorsVault, , bytes32 ancestorsHash) = ROYALTY_POLICY_LAP.royaltyData(ipId);

        if (isClaimed[ipId][claimerIpId]) revert Errors.AncestorsVaultLAP__AlreadyClaimed();
        if (address(this) != ancestorsVault) revert Errors.AncestorsVaultLAP__InvalidClaimer();
        if (keccak256(abi.encodePacked(ancestors, ancestorsRoyalties)) != ancestorsHash)
            revert Errors.AncestorsVaultLAP__InvalidAncestorsHash();

        // transfer the rnfts to the claimer accrued royalties to the claimer IpId address
        _transferRnftsAndAccruedTokens(claimerIpId, splitClone, ancestors, ancestorsRoyalties, tokens);

        isClaimed[ipId][claimerIpId] = true;

        emit Claimed(ipId, claimerIpId, tokens);
    }

    /// @dev Transfers the Royalty NFTs and accrued tokens to the claimer
    /// @param claimerIpId The claimer ipId
    /// @param splitClone The split clone address
    /// @param ancestors The ancestors of the IP
    /// @param ancestorsRoyalties The royalties of each of the ancestors
    /// @param tokens The ERC20 tokens to withdraw
    function _transferRnftsAndAccruedTokens(
        address claimerIpId,
        address splitClone,
        address[] calldata ancestors,
        uint32[] calldata ancestorsRoyalties,
        ERC20[] calldata tokens
    ) internal {
        (uint32 index, bool isIn) = ArrayUtils.indexOf(ancestors, claimerIpId);
        if (!isIn) revert Errors.AncestorsVaultLAP__ClaimerNotAnAncestor();

        // transfer the rnfts from the ancestors vault to the claimer split clone
        // the rnfts that are meant for the ancestors were transferred to the ancestors vault at its deployment
        // and each ancestor can claim their share of the rnfts only once
        ILiquidSplitClone rnft = ILiquidSplitClone(splitClone);
        uint256 totalUnclaimedRnfts = rnft.balanceOf(address(this), 0);
        uint32 rnftAmountToTransfer = ancestorsRoyalties[index];
        rnft.safeTransferFrom(address(this), claimerIpId, 0, rnftAmountToTransfer, "");

        // transfer the accrued tokens to the claimer IpId address
        _claimAccruedTokens(rnftAmountToTransfer, totalUnclaimedRnfts, claimerIpId, tokens);
    }

    /// @dev Claims the accrued tokens (if any)
    /// @param rnftClaimAmount The amount of rnfts to claim
    /// @param totalUnclaimedRnfts The total unclaimed rnfts
    /// @param claimerIpId The claimer ipId
    /// @param tokens The ERC20 tokens to withdraw
    function _claimAccruedTokens(
        uint256 rnftClaimAmount,
        uint256 totalUnclaimedRnfts,
        address claimerIpId,
        ERC20[] calldata tokens
    ) internal {
        ILiquidSplitMain splitMain = ILiquidSplitMain(ROYALTY_POLICY_LAP.LIQUID_SPLIT_MAIN());

        for (uint256 i = 0; i < tokens.length; ++i) {
            // When withdrawing ERC20, 0xSplits sets the value to 1 to have warm storage access.
            // But this still means 0 amount left. So, in the check below, we use `> 1`.
            if (splitMain.getERC20Balance(address(this), tokens[i]) > 1)
                revert Errors.AncestorsVaultLAP__ERC20BalanceNotZero();

            IERC20 IToken = IERC20(tokens[i]);
            uint256 tokenBalance = IToken.balanceOf(address(this));
            // when totalUnclaimedRnfts is 0, claim() call will revert as expected behaviour so no need to check for it
            uint256 tokenClaimAmount = (tokenBalance * rnftClaimAmount) / totalUnclaimedRnfts;

            IToken.safeTransfer(claimerIpId, tokenClaimAmount);
        }
    }
}
