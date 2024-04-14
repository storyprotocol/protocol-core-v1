// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable-v4/security/ReentrancyGuardUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { ERC20SnapshotUpgradeable } from "@openzeppelin/contracts-upgradeable-v4/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable-v4/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable-v4/token/ERC20/IERC20Upgradeable.sol";

import { IRoyaltyPolicyLAP } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { IDisputeModule } from "../../../interfaces/modules/dispute/IDisputeModule.sol";
import { IIpRoyaltyVault } from "../../../interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { ArrayUtils } from "../../../lib/ArrayUtils.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Ip Royalty Vault
/// @notice Defines the logic for claiming royalty tokens and revenue tokens for a given IP
contract IpRoyaltyVault is IIpRoyaltyVault, ERC20SnapshotUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Storage structure for the IpRoyaltyVault
    /// @param ipId The ip id to whom this royalty vault belongs to
    /// @param unclaimedRoyaltyTokens The amount of unclaimed royalty tokens
    /// @param lastSnapshotTimestamp The last snapshotted timestamp
    /// @param ancestorsVaultAmount The amount of revenue token in the ancestors vault
    /// @param isCollectedByAncestor Indicates whether the ancestor has collected the royalty tokens
    /// @param claimVaultAmount Amount of revenue token in the claim vault
    /// @param claimableAtSnapshot Amount of revenue token claimable at a given snapshot
    /// @param unclaimedAtSnapshot Amount of unclaimed revenue tokens at the snapshot
    /// @param isClaimedAtSnapshot Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    /// @param tokens The list of revenue tokens in the vault
    /// @custom:storage-location erc7201:story-protocol.IpRoyaltyVault
    struct IpRoyaltyVaultStorage {
        address ipId;
        uint32 unclaimedRoyaltyTokens;
        uint256 lastSnapshotTimestamp;
        mapping(address token => uint256 amount) ancestorsVaultAmount;
        mapping(address ancestorIpId => bool) isCollectedByAncestor;
        mapping(address token => uint256 amount) claimVaultAmount;
        mapping(uint256 snapshotId => mapping(address token => uint256 amount)) claimableAtSnapshot;
        mapping(uint256 snapshotId => uint32 tokenAmount) unclaimedAtSnapshot;
        mapping(uint256 snapshotId => mapping(address claimer => mapping(address token => bool))) isClaimedAtSnapshot;
        EnumerableSet.AddressSet tokens;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.IpRoyaltyVault")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IpRoyaltyVaultStorageLocation =
        0xe1c3e3b0c445d504edb1b9e6fa2ca4fab60584208a4bc973fe2db2b554d1df00;

    /// @notice LAP royalty policy address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;

    /// @notice Dispute module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    modifier whenNotPaused() {
        // DEV NOTE: If we upgrade RoyaltyPolicyLAP to not pausable, we need to remove this.
        if (PausableUpgradeable(address(ROYALTY_POLICY_LAP)).paused()) revert Errors.IpRoyaltyVault__EnforcedPause();
        _;
    }

    /// @notice Constructor
    /// @param royaltyPolicyLAP The address of the royalty policy LAP
    /// @param disputeModule The address of the dispute module
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyPolicyLAP, address disputeModule) {
        if (royaltyPolicyLAP == address(0)) revert Errors.IpRoyaltyVault__ZeroRoyaltyPolicyLAP();
        if (disputeModule == address(0)) revert Errors.IpRoyaltyVault__ZeroDisputeModule();

        ROYALTY_POLICY_LAP = IRoyaltyPolicyLAP(royaltyPolicyLAP);
        DISPUTE_MODULE = IDisputeModule(disputeModule);

        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param name The name of the royalty token
    /// @param symbol The symbol of the royalty token
    /// @param supply The total supply of the royalty token
    /// @param unclaimedTokens The amount of unclaimed royalty tokens reserved for ancestors
    /// @param ipIdAddress The ip id the royalty vault belongs to
    function initialize(
        string memory name,
        string memory symbol,
        uint32 supply,
        uint32 unclaimedTokens,
        address ipIdAddress
    ) external initializer {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        $.ipId = ipIdAddress;
        $.lastSnapshotTimestamp = block.timestamp;
        $.unclaimedRoyaltyTokens = unclaimedTokens;

        _mint(address(this), unclaimedTokens);
        _mint(ipIdAddress, supply - unclaimedTokens);

        __ReentrancyGuard_init();
        __ERC20Snapshot_init();
        __ERC20_init(name, symbol);
    }

    /// @notice Returns the number royalty token decimals
    function decimals() public view override returns (uint8) {
        return 6;
    }
    /// @notice Adds a new revenue token to the vault
    /// @param token The address of the revenue token
    /// @dev Only callable by the royalty policy LAP
    /// @return Whether the token was added successfully
    function addIpRoyaltyVaultTokens(address token) external returns (bool) {
        if (msg.sender != address(ROYALTY_POLICY_LAP)) revert Errors.IpRoyaltyVault__NotRoyaltyPolicyLAP();
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();
        return $.tokens.add(token);
    }

    /// @notice Snapshots the claimable revenue and royalty token amounts
    /// @return snapshotId The snapshot id
    function snapshot() external whenNotPaused returns (uint256) {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        if (block.timestamp - $.lastSnapshotTimestamp < ROYALTY_POLICY_LAP.getSnapshotInterval())
            revert Errors.IpRoyaltyVault__SnapshotIntervalTooShort();

        uint256 snapshotId = _snapshot();
        $.lastSnapshotTimestamp = block.timestamp;

        uint32 unclaimedTokens = $.unclaimedRoyaltyTokens;
        $.unclaimedAtSnapshot[snapshotId] = unclaimedTokens;

        address[] memory tokenList = $.tokens.values();

        for (uint256 i = 0; i < tokenList.length; i++) {
            uint256 tokenBalance = IERC20Upgradeable(tokenList[i]).balanceOf(address(this));
            if (tokenBalance == 0) {
                $.tokens.remove(tokenList[i]);
                continue;
            }

            uint256 newRevenue = tokenBalance - $.claimVaultAmount[tokenList[i]] - $.ancestorsVaultAmount[tokenList[i]];
            if (newRevenue == 0) continue;

            uint256 ancestorsTokens = (newRevenue * unclaimedTokens) / totalSupply();
            $.ancestorsVaultAmount[tokenList[i]] += ancestorsTokens;

            uint256 claimableTokens = newRevenue - ancestorsTokens;
            $.claimableAtSnapshot[snapshotId][tokenList[i]] = claimableTokens;
            $.claimVaultAmount[tokenList[i]] += claimableTokens;
        }

        emit SnapshotCompleted(snapshotId, block.timestamp, unclaimedTokens);

        return snapshotId;
    }

    /// @notice Calculates the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function claimableRevenue(
        address account,
        uint256 snapshotId,
        address token
    ) external view whenNotPaused returns (uint256) {
        return _claimableRevenue(account, snapshotId, token);
    }

    /// @notice Allows token holders to claim revenue token based on the token balance at certain snapshot
    /// @param snapshotId The snapshot id
    /// @param tokenList The list of revenue tokens to claim
    function claimRevenueByTokenBatch(
        uint256 snapshotId,
        address[] calldata tokenList
    ) external nonReentrant whenNotPaused {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        for (uint256 i = 0; i < tokenList.length; i++) {
            uint256 claimableToken = _claimableRevenue(msg.sender, snapshotId, tokenList[i]);
            if (claimableToken == 0) continue;

            $.isClaimedAtSnapshot[snapshotId][msg.sender][tokenList[i]] = true;
            $.claimVaultAmount[tokenList[i]] -= claimableToken;
            IERC20Upgradeable(tokenList[i]).safeTransfer(msg.sender, claimableToken);

            emit RevenueTokenClaimed(msg.sender, tokenList[i], claimableToken);
        }
    }

    /// @notice Allows token holders to claim by a list of snapshot ids based on the token balance at certain snapshot
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) external whenNotPaused {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        uint256 claimableToken;
        for (uint256 i = 0; i < snapshotIds.length; i++) {
            claimableToken += _claimableRevenue(msg.sender, snapshotIds[i], token);
            $.isClaimedAtSnapshot[snapshotIds[i]][msg.sender][token] = true;
        }

        $.claimVaultAmount[token] -= claimableToken;
        IERC20Upgradeable(token).safeTransfer(msg.sender, claimableToken);

        emit RevenueTokenClaimed(msg.sender, token, claimableToken);
    }

    /// @notice Allows ancestors to claim the royalty tokens and any accrued revenue tokens
    /// @param ancestorIpId The ip id of the ancestor to whom the royalty tokens belong to
    function collectRoyaltyTokens(address ancestorIpId) external nonReentrant whenNotPaused {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        (, , , address[] memory ancestors, uint32[] memory ancestorsRoyalties) = ROYALTY_POLICY_LAP.getRoyaltyData(
            $.ipId
        );

        if (DISPUTE_MODULE.isIpTagged($.ipId)) revert Errors.IpRoyaltyVault__IpTagged();
        if ($.isCollectedByAncestor[ancestorIpId]) revert Errors.IpRoyaltyVault__AlreadyClaimed();

        // check if the address being claimed to is an ancestor
        (uint32 index, bool isIn) = ArrayUtils.indexOf(ancestors, ancestorIpId);
        if (!isIn) revert Errors.IpRoyaltyVault__ClaimerNotAnAncestor();

        // transfer royalty tokens to the ancestor
        IERC20Upgradeable(address(this)).safeTransfer(ancestorIpId, ancestorsRoyalties[index]);

        // collect accrued revenue tokens (if any)
        _collectAccruedTokens(ancestorsRoyalties[index], ancestorIpId);

        $.isCollectedByAncestor[ancestorIpId] = true;
        $.unclaimedRoyaltyTokens -= ancestorsRoyalties[index];

        emit RoyaltyTokensCollected(ancestorIpId, ancestorsRoyalties[index]);
    }

    /// @notice A function to calculate the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function _claimableRevenue(address account, uint256 snapshotId, address token) internal view returns (uint256) {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        // if the ip is tagged, then the unclaimed royalties are lost
        if (DISPUTE_MODULE.isIpTagged($.ipId)) return 0;

        uint256 balance = balanceOfAt(account, snapshotId);
        uint256 totalSupply = totalSupplyAt(snapshotId) - $.unclaimedAtSnapshot[snapshotId];
        uint256 claimableToken = $.claimableAtSnapshot[snapshotId][token];
        return $.isClaimedAtSnapshot[snapshotId][account][token] ? 0 : (balance * claimableToken) / totalSupply;
    }

    /// @dev Collect the accrued tokens (if any)
    /// @param royaltyTokensToClaim The amount of royalty tokens being claimed by the ancestor
    /// @param ancestorIpId The ip id of the ancestor to whom the royalty tokens belong to
    function _collectAccruedTokens(uint256 royaltyTokensToClaim, address ancestorIpId) internal {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        address[] memory tokenList = $.tokens.values();

        for (uint256 i = 0; i < tokenList.length; ++i) {
            // the only case in which unclaimedRoyaltyTokens can be 0 is when the vault is empty and everyone claimed
            // in which case the call will revert upstream with IpRoyaltyVault__AlreadyClaimed error
            uint256 collectAmount = ($.ancestorsVaultAmount[tokenList[i]] * royaltyTokensToClaim) /
                $.unclaimedRoyaltyTokens;
            if (collectAmount == 0) continue;

            $.ancestorsVaultAmount[tokenList[i]] -= collectAmount;
            IERC20Upgradeable(tokenList[i]).safeTransfer(ancestorIpId, collectAmount);

            emit RevenueTokenClaimed(ancestorIpId, tokenList[i], collectAmount);
        }
    }

    /// @notice The ip id to whom this royalty vault belongs to
    /// @return The ip id address
    function ipId() external view returns (address) {
        return _getIpRoyaltyVaultStorage().ipId;
    }

    /// @notice The amount of unclaimed royalty tokens
    function unclaimedRoyaltyTokens() external view returns (uint32) {
        return _getIpRoyaltyVaultStorage().unclaimedRoyaltyTokens;
    }

    /// @notice The last snapshotted timestamp
    function lastSnapshotTimestamp() external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().lastSnapshotTimestamp;
    }

    /// @notice The amount of revenue token in the ancestors vault
    /// @param token The address of the revenue token
    function ancestorsVaultAmount(address token) external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().ancestorsVaultAmount[token];
    }

    /// @notice Indicates whether the ancestor has collected the royalty tokens
    /// @param ancestorIpId The ancestor ipId address
    function isCollectedByAncestor(address ancestorIpId) external view returns (bool) {
        return _getIpRoyaltyVaultStorage().isCollectedByAncestor[ancestorIpId];
    }

    /// @notice Amount of revenue token in the claim vault
    /// @param token The address of the revenue token
    function claimVaultAmount(address token) external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().claimVaultAmount[token];
    }

    /// @notice Amount of revenue token claimable at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param token The address of the revenue token
    function claimableAtSnapshot(uint256 snapshotId, address token) external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().claimableAtSnapshot[snapshotId][token];
    }

    /// @notice Amount of unclaimed revenue tokens at the snapshot
    /// @param snapshotId The snapshot id
    function unclaimedAtSnapshot(uint256 snapshotId) external view returns (uint32) {
        return _getIpRoyaltyVaultStorage().unclaimedAtSnapshot[snapshotId];
    }

    /// @notice Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param claimer The address of the claimer
    /// @param token The address of the revenue token
    function isClaimedAtSnapshot(uint256 snapshotId, address claimer, address token) external view returns (bool) {
        return _getIpRoyaltyVaultStorage().isClaimedAtSnapshot[snapshotId][claimer][token];
    }

    /// @notice The list of revenue tokens in the vault
    function tokens() external view returns (address[] memory) {
        return _getIpRoyaltyVaultStorage().tokens.values();
    }

    /// @dev Returns the storage struct of the IpRoyaltyVault
    function _getIpRoyaltyVaultStorage() private pure returns (IpRoyaltyVaultStorage storage $) {
        assembly {
            $.slot := IpRoyaltyVaultStorageLocation
        }
    }
}
