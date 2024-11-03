// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IDisputeModule } from "../../../interfaces/modules/dispute/IDisputeModule.sol";
import { IRoyaltyModule } from "../../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IIpRoyaltyVault } from "../../../interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { IGroupIPAssetRegistry } from "../../../interfaces/registries/IGroupIPAssetRegistry.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Ip Royalty Vault
/// @notice Defines the logic for claiming revenue tokens for a given IP
/// @dev [CAUTION]
///      Do not transfer ERC20 tokens directly to the ip royalty vault as they can be lost if the poolInfo
///      is not updated along with an ERC20 transfer.
///      Use appropriate callpaths that can update the poolInfo when an ERC20 transfer to the vault is made.
contract IpRoyaltyVault is IIpRoyaltyVault, ERC20Upgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the IpRoyaltyVault
    /// @param ipId The ip id to whom this royalty vault belongs to
    /// @param lastSnapshotTimestamp [DEPRECATED] The last snapshotted timestamp
    /// @param pendingVaultAmount [DEPRECATED] Amount of revenue token pending to be snapshotted
    /// @param claimVaultAmount [DEPRECATED] Amount of revenue token in the claim vault
    /// @param claimableAtSnapshot [DEPRECATED] Amount of revenue token claimable at a given snapshot
    /// @param isClaimedAtSnapshot [DEPRECATED] Indicates whether the claimer has claimed the token at a given snapshot
    /// @param tokens The list of revenue tokens in the vault
    /// @param poolInfo The accumulated balance of revenue tokens in the vault
    /// @param claimerInfo The revenue debt of the claimer
    /// @custom:storage-location erc7201:story-protocol.IpRoyaltyVault
    struct IpRoyaltyVaultStorage {
        address ipId;
        uint40 lastSnapshotTimestamp;
        mapping(address token => uint256 amount) pendingVaultAmount;
        mapping(address token => uint256 amount) claimVaultAmount;
        mapping(uint256 snapshotId => mapping(address token => uint256 amount)) claimableAtSnapshot;
        mapping(uint256 snapshotId => mapping(address claimer => mapping(address token => bool))) isClaimedAtSnapshot;
        EnumerableSet.AddressSet tokens;
        mapping(address token => uint256 accBalance) poolInfo;
        mapping(address token => mapping(address claimer => uint256 revenueDebt)) claimerInfo;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.IpRoyaltyVault")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IpRoyaltyVaultStorageLocation =
        0xe1c3e3b0c445d504edb1b9e6fa2ca4fab60584208a4bc973fe2db2b554d1df00;

    /// @notice Grouping module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable GROUPING_MODULE;

    /// @notice IP Asset Registry address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Dispute module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @notice Royalty module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    modifier whenNotPaused() {
        // DEV NOTE: If we upgrade RoyaltyModule to not pausable, we need to remove this.
        if (PausableUpgradeable(address(ROYALTY_MODULE)).paused()) revert Errors.IpRoyaltyVault__EnforcedPause();
        _;
    }

    /// @notice Constructor
    /// @param disputeModule The address of the dispute module
    /// @param royaltyModule The address of the royalty module
    /// @param ipAssetRegistry The address of the group IP asset registry
    /// @param groupingModule The address of the grouping module
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address disputeModule, address royaltyModule, address ipAssetRegistry, address groupingModule) {
        if (disputeModule == address(0)) revert Errors.IpRoyaltyVault__ZeroDisputeModule();
        if (royaltyModule == address(0)) revert Errors.IpRoyaltyVault__ZeroRoyaltyModule();
        if (ipAssetRegistry == address(0)) revert Errors.IpRoyaltyVault__ZeroIpAssetRegistry();
        if (groupingModule == address(0)) revert Errors.IpRoyaltyVault__ZeroGroupingModule();

        DISPUTE_MODULE = IDisputeModule(disputeModule);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        IP_ASSET_REGISTRY = IGroupIPAssetRegistry(ipAssetRegistry);
        GROUPING_MODULE = groupingModule;

        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param name The name of the royalty token
    /// @param symbol The symbol of the royalty token
    /// @param supply The total supply of the royalty token
    /// @param ipIdAddress The ip id the royalty vault belongs to
    /// @param rtReceiver The address of the royalty token receiver
    function initialize(
        string memory name,
        string memory symbol,
        uint32 supply,
        address ipIdAddress,
        address rtReceiver
    ) external initializer {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        $.ipId = ipIdAddress;
        $.lastSnapshotTimestamp = uint40(block.timestamp);

        _mint(rtReceiver, supply);

        __ReentrancyGuard_init();
        __ERC20_init(name, symbol);
    }

    /// @notice Returns the number royalty token decimals
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Updates the vault balance with the new amount of revenue token
    /// @param token The address of the revenue token
    /// @param amount The amount of revenue token to add
    /// @dev Only callable by the royalty module or whitelisted royalty policy
    function updateVaultBalance(address token, uint256 amount) external {
        if (msg.sender != address(ROYALTY_MODULE) && !ROYALTY_MODULE.isWhitelistedRoyaltyPolicy(msg.sender))
            revert Errors.IpRoyaltyVault__NotAllowedToAddTokenToVault();
        _updateVaultBalance(token, amount);
    }

    /// @notice Allows token holders to claim revenue token
    /// @param token The revenue tokens to claim
    /// @param claimer The address of the claimer
    /// @return The amount of revenue tokens claimed
    function claimRevenueOnBehalf(
        address token,
        address claimer
    ) external nonReentrant whenNotPaused returns (uint256) {
        address[] memory tokenList = new address[](1);
        tokenList[0] = token;
        return _claimRevenueOnBehalf(tokenList, claimer)[0];
    }

    /// @notice Allows token holders to claim a batch of revenue tokens
    /// @param tokenList The list of revenue tokens to claim
    /// @param claimer The address of the claimer
    /// @return The amount of revenue tokens claimed of each token
    function claimRevenueOnBehalfByTokenBatch(
        address[] calldata tokenList,
        address claimer
    ) external nonReentrant whenNotPaused returns (uint256[] memory) {
        return _claimRevenueOnBehalf(tokenList, claimer);
    }

    /// @notice Allows to claim revenue tokens on behalf of the ip royalty vault
    /// @param tokenList The list of revenue tokens to claim
    /// @param targetIpId The target ip id to claim revenue tokens from
    function claimByTokenBatchAsSelf(address[] calldata tokenList, address targetIpId) external whenNotPaused {
        address targetIpVault = ROYALTY_MODULE.ipRoyaltyVaults(targetIpId);
        if (targetIpVault == address(0)) revert Errors.IpRoyaltyVault__InvalidTargetIpId();

        // ensures that the target ipId is from a descendant ip which in turn ensures that
        // all accumulated royalty policies from the ancestor ip have been checked when
        // a payment was made to said descendant ip
        if (!ROYALTY_MODULE.hasAncestorIp(targetIpId, _getIpRoyaltyVaultStorage().ipId))
            revert Errors.IpRoyaltyVault__VaultDoesNotBelongToAnAncestor();

        uint256[] memory claimedAmounts = IIpRoyaltyVault(targetIpVault).claimRevenueOnBehalfByTokenBatch(
            tokenList,
            address(this)
        );

        // only tokens that have claimable revenue higher than zero will be added to the vault
        for (uint256 i = 0; i < tokenList.length; i++) {
            _updateVaultBalance(tokenList[i], claimedAmounts[i]);
        }
    }

    /// @notice Get total amount of revenue token claimable by a token holder
    /// @param claimer The address of the token holder
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function claimableRevenue(address claimer, address token) external view whenNotPaused returns (uint256) {
        return _claimableRevenue(claimer, token);
    }

    /// @notice The ip id to whom this royalty vault belongs to
    function ipId() external view returns (address) {
        return _getIpRoyaltyVaultStorage().ipId;
    }

    /// @notice Returns list of revenue tokens in the vault
    function tokens() external view returns (address[] memory) {
        return (_getIpRoyaltyVaultStorage().tokens).values();
    }

    /// @notice Adds a new revenue token to the vault
    /// @param token The address of the revenue token
    function _updateVaultBalance(address token, uint256 amount) internal {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        if (!ROYALTY_MODULE.isWhitelistedRoyaltyToken(token))
            revert Errors.IpRoyaltyVault__NotWhitelistedRoyaltyToken();
        if (amount == 0) revert Errors.IpRoyaltyVault__ZeroAmount();

        $.tokens.add(token);
        $.poolInfo[token] += amount;

        emit RevenueTokenAddedToVault(token, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from == address(0)) {
            super._update(from, to, amount);
            return;
        }
        if (from == to) revert Errors.IpRoyaltyVault__SameFromToAddress(address(this), from);
        // when transferring RoyaltyTokens (Vault) from a user to another user:
        // 1. clear pending rewards of the (from) user
        // 2. clear pending rewards of the (to) another user, if pending rewards of another user is not zero
        // 3. update the rewardDebt of the (to) another user to accBalancePerShare * userAmount
        // 4. update the rewardDebt of the (from) user to accBalancePerShare * userAmount
        // 5. transfer the RoyaltyTokens (Vault) from the (from) user to the (to) another user
        if (balanceOf(from) == 0) revert Errors.IpRoyaltyVault__ZeroBalance(address(this), from);
        if (balanceOf(from) < amount) revert Errors.IpRoyaltyVault__InsufficientBalance(address(this), from, amount);

        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();
        address[] memory tokenList = $.tokens.values();
        uint256 totalSupply = totalSupply();
        for (uint256 i = 0; i < tokenList.length; i++) {
            address token = tokenList[i];
            _clearPendingRewards(from, token);
            _clearPendingRewards(to, token);
            $.claimerInfo[token][to] = ($.poolInfo[token] * (balanceOf(to) + amount)) / totalSupply;
            $.claimerInfo[token][from] = ($.poolInfo[token] * (balanceOf(from) - amount)) / totalSupply;
        }

        super._update(from, to, amount);
    }

    function _clearPendingRewards(address user, address token) internal returns (uint256 pending) {
        pending = _claimableRevenue(user, token);
        if (pending > 0) {
            IERC20(token).safeTransfer(user, pending);
        }
    }

    function _claimRevenueOnBehalf(address[] memory tokenList, address claimer) internal returns (uint256[] memory) {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        if (ROYALTY_MODULE.isIpRoyaltyVault(claimer) && msg.sender != claimer)
            revert Errors.IpRoyaltyVault__VaultsMustClaimAsSelf();

        if (IP_ASSET_REGISTRY.isWhitelistedGroupRewardPool(claimer) && msg.sender != GROUPING_MODULE)
            revert Errors.IpRoyaltyVault__GroupPoolMustClaimViaGroupingModule();

        uint256[] memory claimedAmounts = new uint256[](tokenList.length);
        for (uint256 i = 0; i < tokenList.length; i++) {
            claimedAmounts[i] = _clearPendingRewards(claimer, tokenList[i]);
            if (claimedAmounts[i] == 0) revert Errors.IpRoyaltyVault__NoClaimableTokens();
            $.claimerInfo[tokenList[i]][claimer] += claimedAmounts[i];

            emit RevenueTokenClaimed(claimer, tokenList[i], claimedAmounts[i]);
        }

        return claimedAmounts;
    }

    function _claimableRevenue(address claimer, address token) internal view returns (uint256) {
        // accBalance // accumulate revenue tokens in the vault
        // totalSupply = totalSupply() // totalSupply of RoyaltyTokens of the vault (IpRoyaltyVault)
        // accBalancePerShare = accBalance / totalSupply
        // userAmount = balanceOf(user) // user amount of RoyaltyTokens (IpRoyaltyVault),
        // means how many share the user has
        // pending = (accBalancePerShare * userAmount) - userRewardInfo[token][user].rewardDebt
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();
        uint256 accBalance = $.poolInfo[token];
        uint256 userAmount = balanceOf(claimer);
        uint256 rewardDebt = $.claimerInfo[token][claimer];
        return (accBalance * userAmount) / totalSupply() - rewardDebt;
    }

    /// @dev Returns the storage struct of IpRoyaltyVault
    function _getIpRoyaltyVaultStorage() private pure returns (IpRoyaltyVaultStorage storage $) {
        assembly {
            $.slot := IpRoyaltyVaultStorageLocation
        }
    }
}
