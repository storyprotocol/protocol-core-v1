// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { ERC20Snapshot, ERC20 } from "@openzeppelin/contracts-v4/token/ERC20/extensions/ERC20Snapshot.sol";
import { SafeERC20 } from "@openzeppelin/contracts-v4/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts-v4/token/ERC20/IERC20.sol";

import { IRoyaltyPolicyLAP } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { IIpPool } from "../../../interfaces/modules/royalty/policies/IIpPool.sol";
import { ArrayUtils } from "../../../lib/ArrayUtils.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Ip Pool
/// @notice Defines the logic for claiming royalty tokens and revenue tokens for a given IP
contract IpPool is IIpPool, ERC20Snapshot, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @notice LAP royalty policy address
    IRoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;

    /// @notice Ip id to whom this pool belongs to
    address public immutable IP_ID;

    /// @notice Amount of unclaimed royalty tokens
    uint32 public unclaimedRoyaltyTokens;

    /// @notice Last snapshotted timestamp
    uint256 public lastSnapshotTimestamp;

    /// @notice Amount of revenue token in the ancestors pool
    mapping(address token => uint256 amount) public ancestorsPoolAmount;

    /// @notice Indicates if a given ancestor address has already claimed
    mapping(address claimerIpId => bool) public isClaimedByAncestor;

    /// @notice Amount of revenue token in the claim pool
    mapping(address token => uint256 amount) public claimPoolAmount;

    /// @notice Amount of tokens claimable at a given snapshot
    mapping(uint256 snapshotId => mapping(address token => uint256 amount)) public claimableAtSnapshot;

    /// @notice Amount of unclaimed tokens at the snapshot
    mapping(uint256 snapshotId => uint32 tokenAmount) public unclaimedAtSnapshot;

    /// @notice Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    mapping(uint256 snapshotId => mapping(address claimer => mapping(address token => bool)))
        public isClaimedAtSnapshot;

    /// @notice Royalty tokens of the pool
    EnumerableSet.AddressSet private _tokens;

    // TODO: change to beacon upgradeable contract
    /// @notice The constructor of the IpPool
    /// @param name The name of the pool token
    /// @param symbol The symbol of the pool token
    /// @param royaltyPolicyLAP The address of the royalty policy LAP
    /// @param supply The total supply of the pool token
    /// @param unclaimedTokens The amount of unclaimed tokens reserved for ancestors
    /// @param ipId The ip id the pool belongs to
    constructor(
        string memory name,
        string memory symbol,
        address royaltyPolicyLAP,
        uint32 supply,
        uint32 unclaimedTokens,
        address ipId
    ) ERC20(name, symbol) {
        if (ipId == address(0)) revert Errors.IpPool__ZeroIpId();
        if (royaltyPolicyLAP == address(0)) revert Errors.IpPool__ZeroRoyaltyPolicyLAP();

        ROYALTY_POLICY_LAP = IRoyaltyPolicyLAP(royaltyPolicyLAP);
        IP_ID = ipId;
        lastSnapshotTimestamp = block.timestamp;
        unclaimedRoyaltyTokens = unclaimedTokens;

        _mint(address(this), unclaimedTokens);
        _mint(ipId, supply - unclaimedTokens);
    }

    /// @notice Adds a new revenue token to the pool
    /// @param token The address of the revenue token
    /// @dev Only callable by the royalty policy LAP
    function updateIpPoolTokens(address token) external {
        if (msg.sender != address(ROYALTY_POLICY_LAP)) revert Errors.IpPool__NotRoyaltyPolicyLAP();
        _tokens.add(token);
    }

    /// @notice Snapshots the claimable revenue and royalty token amounts
    /// @return snapshotId The snapshot id
    function snapshot() external returns (uint256) {
        if (block.timestamp - lastSnapshotTimestamp < ROYALTY_POLICY_LAP.getSnapshotInterval())
            revert Errors.IpPool__SnapshotIntervalTooShort();

        uint256 snapshotId = _snapshot();
        lastSnapshotTimestamp = block.timestamp;

        uint32 unclaimedTokens = unclaimedRoyaltyTokens;
        unclaimedAtSnapshot[snapshotId] = unclaimedTokens;

        address[] memory tokens = _tokens.values();

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenBalance = IERC20(tokens[i]).balanceOf(address(this));
            if (tokenBalance == 0) {
                _tokens.remove(tokens[i]);
                continue;
            }

            uint256 newRevenue = tokenBalance - claimPoolAmount[tokens[i]] - ancestorsPoolAmount[tokens[i]];
            if (newRevenue == 0) continue;

            uint256 ancestorsTokens = (newRevenue * unclaimedTokens) / totalSupply();
            ancestorsPoolAmount[tokens[i]] += ancestorsTokens;

            uint256 claimableTokens = newRevenue - ancestorsTokens;
            claimableAtSnapshot[snapshotId][tokens[i]] = claimableTokens;
            claimPoolAmount[tokens[i]] += claimableTokens;
        }

        emit SnapshotCompleted(snapshotId, block.timestamp, unclaimedTokens);

        return snapshotId;
    }

    /// @notice Calculates the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function claimableRevenue(address account, uint256 snapshotId, address token) external view returns (uint256) {
        return _claimableRevenue(account, snapshotId, token);
    }

    /// @notice Allows token holders to claim revenue token based on the token balance at certain snapshot
    /// @param snapshotId The snapshot id
    /// @param tokens The list of revenue tokens to claim
    function claimRevenueByTokenBatch(uint256 snapshotId, address[] calldata tokens) external nonReentrant {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 claimableToken = _claimableRevenue(msg.sender, snapshotId, tokens[i]);
            if (claimableToken == 0) continue;

            isClaimedAtSnapshot[snapshotId][msg.sender][tokens[i]] = true;
            claimPoolAmount[tokens[i]] -= claimableToken;
            IERC20(tokens[i]).safeTransfer(msg.sender, claimableToken);
        }
    }

    /// @notice Allows token holders to claim by a list of snapshot ids based on the token balance at certain snapshot
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) external {
        uint256 claimableToken;
        for (uint256 i = 0; i < snapshotIds.length; i++) {
            claimableToken += _claimableRevenue(msg.sender, snapshotIds[i], token);
            isClaimedAtSnapshot[snapshotIds[i]][msg.sender][token] = true;
        }

        claimPoolAmount[token] -= claimableToken;
        IERC20(token).safeTransfer(msg.sender, claimableToken);
    }

    /// @notice Allows ancestors to claim the royalty tokens and any accrued revenue tokens
    /// @param claimerIpId The ip id of the claimer
    function collectRoyaltyTokens(address claimerIpId) external nonReentrant {
        (, , , address[] memory ancestors, uint32[] memory ancestorsRoyalties) = ROYALTY_POLICY_LAP.getRoyaltyData(
            IP_ID
        );

        if (isClaimedByAncestor[claimerIpId]) revert Errors.IpPool__AlreadyClaimed();

        // check if the claimer is an ancestor
        (uint32 index, bool isIn) = ArrayUtils.indexOf(ancestors, claimerIpId);
        if (!isIn) revert Errors.IpPool__ClaimerNotAnAncestor();

        // transfer royalty tokens to the claimer
        IERC20(address(this)).safeTransfer(claimerIpId, ancestorsRoyalties[index]);

        // collect accrued revenue tokens (if any)
        _collectAccruedTokens(ancestorsRoyalties[index], claimerIpId);

        isClaimedByAncestor[claimerIpId] = true;
        unclaimedRoyaltyTokens -= ancestorsRoyalties[index];

        emit Claimed(claimerIpId);
    }

    /// @notice Returns the list of revenue tokens in the pool
    /// @return The list of revenue tokens
    function getPoolTokens() external view returns (address[] memory) {
        return _tokens.values();
    }

    /// @notice A function to calculate the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function _claimableRevenue(address account, uint256 snapshotId, address token) internal view returns (uint256) {
        uint256 balance = balanceOfAt(account, snapshotId);
        uint256 totalSupply = totalSupplyAt(snapshotId) - unclaimedAtSnapshot[snapshotId];
        uint256 claimableToken = claimableAtSnapshot[snapshotId][token];
        return isClaimedAtSnapshot[snapshotId][account][token] ? 0 : (balance * claimableToken) / totalSupply;
    }

    /// @dev Collect the accrued tokens (if any)
    /// @param royaltyTokensToClaim The amount of royalty tokens being claimed by the ancestor
    /// @param claimerIpId The ip id of the claimer
    function _collectAccruedTokens(uint256 royaltyTokensToClaim, address claimerIpId) internal {
        address[] memory tokens = _tokens.values();

        for (uint256 i = 0; i < tokens.length; ++i) {
            // the only case in which unclaimedRoyaltyTokens can be 0 is when the pool is empty and everyone claimed
            // in which case the call will revert upstream with IpPool__AlreadyClaimed error
            uint256 collectAmount = (ancestorsPoolAmount[tokens[i]] * royaltyTokensToClaim) / unclaimedRoyaltyTokens;
            if (collectAmount == 0) continue;

            ancestorsPoolAmount[tokens[i]] -= collectAmount;
            IERC20(tokens[i]).safeTransfer(claimerIpId, collectAmount);
        }
    }
}
