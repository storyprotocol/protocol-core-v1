// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ERC20Snapshot, ERC20 } from "./oppenzeppelin/ERC20Snapshot.sol";
import { IERC20 } from "./oppenzeppelin/IERC20.sol";
import { SafeERC20 } from "./oppenzeppelin/SafeERC20.sol";

import { IRoyaltyPolicyLAP } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { IIpPool } from "../../../interfaces/modules/royalty/policies/IIpPool.sol";
import { ArrayUtils } from "../../../lib/ArrayUtils.sol";
import { Errors } from "../../../lib/Errors.sol";

contract IpPool is IIpPool, ERC20Snapshot, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @notice The liquid split royalty policy address
    IRoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;

    /// @notice royalty tokens of the pool
    EnumerableSet.AddressSet private _tokens;

    /// @notice last snapshotted timestamp
    uint256 public lastSnapshotTimestamp;

    /// @notice amount of unclaimed royalty tokens
    uint256 public unclaimedRoyaltyTokens;

    /// @notice amount of revenue token in the ancestors pool
    mapping(address token => uint256 amount) public ancestorsPoolAmount;

    /// @notice Indicates if a given ancestor address has already claimed
    mapping(address ipId => mapping(address claimerIpId => bool)) public isClaimedByAncestor;

    /// @notice amount of revenue token in the claim pool
    mapping(address token => uint256 amount) public claimPoolAmount;

    /// @notice mapping from snapshot id to the amount of token claimable at the snapshot
    mapping(uint256 snapshotId => mapping(address token => uint256 amount)) public claimableAtSnapshot;

    /// @notice mapping from snapshot id to a boolean indicating whether the claimer has claimed the revenue tokens
    mapping(uint256 snapshotId => mapping(address claimer => mapping(address token => bool)))
        public isClaimedAtSnapshot;

    // TODO: change require to if
    // TODO: change to upgradeable contract
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply,
        uint256 unclaimedTokens,
        address ipId
    ) ERC20(name, symbol) {
        lastSnapshotTimestamp = block.timestamp;
        unclaimedRoyaltyTokens = unclaimedTokens;
        _mint(address(this), unclaimedTokens);
        _mint(ipId, supply - unclaimedTokens);
    }

    function updateIpPoolTokens(address token) external {
        if (msg.sender != address(ROYALTY_POLICY_LAP)) revert Errors.IpPool__NotRoyaltyPolicyLAP();
        _tokens.add(token);
    }

    /// @notice A function to calculate the amount of ETH claimable by a token holder at certain snapshot.
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @return The amount of revenue token claimable
    function claimableRevenue(address account, uint256 snapshotId, address token) public view returns (uint256) {
        uint256 balance = balanceOfAt(account, snapshotId);
        uint256 totalSupply = totalSupplyAt(snapshotId);
        uint256 claimableToken = claimableAtSnapshot[snapshotId][token];
        return isClaimedAtSnapshot[snapshotId][account][token] ? 0 : (balance * claimableToken) / totalSupply;
    }

    /// @notice A function for token holder to claim revenue token based on the token balance at certain snapshot.
    /// @param snapshotId The snapshot id
    /// @param tokens The list of royalty tokens to claim
    function claimRevenueByTokenBatch(uint256 snapshotId, address[] calldata tokens) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 claimableToken = claimableRevenue(msg.sender, snapshotId, tokens[i]);
            if (claimableToken == 0) continue;

            isClaimedAtSnapshot[snapshotId][msg.sender][tokens[i]] = true;
            claimPoolAmount[tokens[i]] -= claimableToken;
            IERC20(tokens[i]).safeTransfer(msg.sender, claimableToken);
        }
    }

    /// @notice A function to claim by a list of snapshot ids.
    /// @param snapshotIds The list of snapshot ids
    /// @param token The royalty token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) public {
        uint256 claimableToken;
        for (uint256 i = 0; i < snapshotIds.length; i++) {
            claimableToken += claimableRevenue(msg.sender, snapshotIds[i], token);
            isClaimedAtSnapshot[snapshotIds[i]][msg.sender][token] = true;
        }

        claimPoolAmount[token] -= claimableToken;
        IERC20(token).safeTransfer(msg.sender, claimableToken);
    }

    /// @notice A snapshot function that also records the deposited ETH amount at the time of the snapshot.
    /// @return The snapshot id
    function snapshot() public returns (uint256) {
        require(
            block.timestamp - lastSnapshotTimestamp > ROYALTY_POLICY_LAP.snapshotInterval(),
            "ERC7641: snapshot interval is too short"
        );
        uint256 snapshotId = _snapshot();
        lastSnapshotTimestamp = block.timestamp;

        address[] memory tokens = _tokens.values();

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(address(this));
            if (tokenBalance == 0) {
                _tokens.remove(tokens[i]);
                continue;
            }

            uint256 newRevenue = tokenBalance - claimPoolAmount[tokens[i]] - ancestorsPoolAmount[tokens[i]];
            if (newRevenue == 0) continue;

            uint256 ancestorsTokens = (newRevenue * unclaimedRoyaltyTokens) / totalSupply();
            ancestorsPoolAmount[tokens[i]] += ancestorsTokens;

            uint256 claimableTokens = newRevenue - ancestorsTokens;
            claimableAtSnapshot[snapshotId][tokens[i]] = claimableTokens;
            claimPoolAmount[tokens[i]] += claimableTokens;
        }

        return snapshotId;
    }

    function collectRoyaltyTokens(address ipId) external nonReentrant {
        (, address splitClone, , , address[] memory ancestors, uint32[] memory ancestorsRoyalties) = ROYALTY_POLICY_LAP
            .getRoyaltyData(ipId);

        if (isClaimedByAncestor[ipId][msg.sender]) revert Errors.AncestorsVaultLAP__AlreadyClaimed();
        //if (address(this) != ancestorsVault) revert Errors.AncestorsVaultLAP__InvalidVault();

        // check if the claimer is an ancestor
        (uint32 index, bool isIn) = ArrayUtils.indexOf(ancestors, msg.sender);
        if (!isIn) revert Errors.AncestorsVaultLAP__ClaimerNotAnAncestor();

        // transfer royalty tokens to the claimer
        IERC20(address(this)).safeTransfer(msg.sender, ancestorsRoyalties[index]);

        // collect accrued revenue tokens (if any)
        _collectAccruedTokens(ancestorsRoyalties[index]);

        isClaimedByAncestor[ipId][msg.sender] = true;

        emit Claimed(ipId, msg.sender);
    }

    function getPoolTokens() external view returns (address[] memory) {
        return _tokens.values();
    }

    /// @dev Collect the accrued tokens (if any)
    /// @param royaltyTokensToClaim The amount of rnfts to claim
    function _collectAccruedTokens(uint256 royaltyTokensToClaim) internal {
        address[] memory tokens = _tokens.values();

        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 collectAmount = (ancestorsPoolAmount[tokens[i]] * royaltyTokensToClaim) / unclaimedRoyaltyTokens;
            if (collectAmount == 0) continue;

            ancestorsPoolAmount[tokens[i]] -= collectAmount;
            IERC20(tokens[i]).safeTransfer(msg.sender, collectAmount);
        }
    }
}
