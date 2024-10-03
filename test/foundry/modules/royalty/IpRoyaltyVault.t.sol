// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contracts
import { IpRoyaltyVault } from "../../../../contracts/modules/royalty/policies/IpRoyaltyVault.sol";
// solhint-disable-next-line max-line-length
import { IIpRoyaltyVault } from "../../../../contracts/interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

// tests
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TestIpRoyaltyVault is BaseTest {
    function setUp() public override {
        super.setUp();

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(LINK), true);
        vm.stopPrank();
    }

    function test_IpRoyaltyVault_decimals() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();

        assertEq(ipRoyaltyVault.decimals(), 6);
    }

    function test_IpRoyaltyVault_updateVaultBalance_revert_NotRoyaltyModule() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.expectRevert(Errors.IpRoyaltyVault__NotAllowedToAddTokenToVault.selector);
        ipRoyaltyVault.updateVaultBalance(address(USDC), 1);
    }

    function test_IpRoyaltyVault_updateVaultBalance_revert_NotWhitelistedRoyaltyToken() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        vm.expectRevert(Errors.IpRoyaltyVault__NotWhitelistedRoyaltyToken.selector);
        ipRoyaltyVault.updateVaultBalance(address(0), 1);
        vm.stopPrank();
    }

    function test_IpRoyaltyVault_updateVaultBalance_revert_ZeroAmount() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        vm.expectRevert(Errors.IpRoyaltyVault__ZeroAmount.selector);
        ipRoyaltyVault.updateVaultBalance(address(USDC), 0);
    }

    function test_IpRoyaltyVault_updateVaultBalance() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));

        vm.expectEmit(true, true, true, true, address(ipRoyaltyVault));
        emit IIpRoyaltyVault.RevenueTokenAddedToVault(address(USDC), 1);

        ipRoyaltyVault.updateVaultBalance(address(USDC), 1);
        vm.stopPrank();

        assertEq(ipRoyaltyVault.tokens().length, 1);
        assertEq(ipRoyaltyVault.tokens()[0], address(USDC));
        assertEq(ipRoyaltyVault.pendingVaultAmount(address(USDC)), 1);
    }

    function test_IpRoyaltyVault_constructor_revert_ZeroDisputeModule() public {
        vm.expectRevert(Errors.IpRoyaltyVault__ZeroDisputeModule.selector);
        IpRoyaltyVault vault = new IpRoyaltyVault(address(0), address(royaltyModule));
    }

    function test_IpRoyaltyVault_constructor_revert_ZeroRoyaltyModule() public {
        vm.expectRevert(Errors.IpRoyaltyVault__ZeroRoyaltyModule.selector);
        IpRoyaltyVault vault = new IpRoyaltyVault(address(disputeModule), address(0));
    }

    function test_IpRoyaltyVault_constructor() public {
        IpRoyaltyVault vault = new IpRoyaltyVault(address(disputeModule), address(royaltyModule));
        assertEq(address(vault.DISPUTE_MODULE()), address(disputeModule));
        assertEq(address(vault.ROYALTY_MODULE()), address(royaltyModule));
    }

    function test_IpRoyaltyVault_initialize() public {
        // mint license for IP80
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(80), address(royaltyPolicyLRP), uint32(10 * 10 ** 6), "");

        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(80));

        uint256 ipId80IpIdBalance = IERC20(ipRoyaltyVault).balanceOf(address(80));

        assertEq(ERC20(ipRoyaltyVault).name(), "Royalty Token");
        assertEq(ERC20(ipRoyaltyVault).symbol(), "RT");
        assertEq(ERC20(ipRoyaltyVault).totalSupply(), royaltyModule.maxPercent());
        assertEq(IIpRoyaltyVault(ipRoyaltyVault).ipId(), address(80));
        assertEq(IIpRoyaltyVault(ipRoyaltyVault).lastSnapshotTimestamp(), block.timestamp);
        assertEq(ipId80IpIdBalance, royaltyModule.maxPercent());
    }

    function test_IpRoyaltyVault_snapshot_InsufficientTimeElapsedSinceLastSnapshot() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IIpRoyaltyVault ipRoyaltyVault = IIpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.expectRevert(Errors.IpRoyaltyVault__InsufficientTimeElapsedSinceLastSnapshot.selector);
        ipRoyaltyVault.snapshot();
    }

    function test_IpRoyaltyVault_snapshot_revert_Paused() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IIpRoyaltyVault ipRoyaltyVault = IIpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.stopPrank();
        vm.prank(u.admin);
        royaltyModule.pause();

        vm.expectRevert(Errors.IpRoyaltyVault__EnforcedPause.selector);
        ipRoyaltyVault.snapshot();
    }

    function test_IpRoyaltyVault_snapshot_revert_NoNewRevenueSinceLastSnapshot() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();

        vm.warp(block.timestamp + 7 days + 1);

        vm.expectRevert(Errors.IpRoyaltyVault__NoNewRevenueSinceLastSnapshot.selector);
        ipRoyaltyVault.snapshot();
    }

    function test_IpRoyaltyVault_snapshot() public {
        // payment is made to vault
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(2), royaltyAmount); // 100k USDC
        LINK.mint(address(2), royaltyAmount); // 100k LINK
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);
        LINK.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(LINK), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);

        uint256 usdcClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(USDC));
        uint256 linkClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(LINK));
        uint256 usdcPendingVaultBefore = ipRoyaltyVault.pendingVaultAmount(address(USDC));
        uint256 linkPendingVaultBefore = ipRoyaltyVault.pendingVaultAmount(address(LINK));

        vm.expectEmit(true, true, true, true, address(ipRoyaltyVault));
        emit IIpRoyaltyVault.SnapshotCompleted(1, block.timestamp);

        ipRoyaltyVault.snapshot();

        assertEq(ipRoyaltyVault.claimVaultAmount(address(USDC)), royaltyAmount);
        assertEq(ipRoyaltyVault.claimVaultAmount(address(LINK)), royaltyAmount);
        assertEq(ipRoyaltyVault.claimVaultAmount(address(USDC)) - usdcClaimVaultBefore, royaltyAmount);
        assertEq(ipRoyaltyVault.claimVaultAmount(address(LINK)) - linkClaimVaultBefore, royaltyAmount);
        assertEq(ipRoyaltyVault.lastSnapshotTimestamp(), block.timestamp);
        assertEq(ipRoyaltyVault.claimableAtSnapshot(1, address(USDC)), royaltyAmount);
        assertEq(ipRoyaltyVault.claimableAtSnapshot(1, address(LINK)), royaltyAmount);
        assertEq(usdcPendingVaultBefore - ipRoyaltyVault.pendingVaultAmount(address(USDC)), royaltyAmount);
        assertEq(linkPendingVaultBefore - ipRoyaltyVault.pendingVaultAmount(address(LINK)), royaltyAmount);

        // users claim all USDC
        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);
        vm.startPrank(address(2));
        ipRoyaltyVault.claimRevenueOnBehalfByTokenBatch(1, tokens, address(2));
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        // all USDC was claimed but LINK was not
        assertEq(ipRoyaltyVault.tokens().length, 1);
    }

    function test_IpRoyaltyVault_claimRevenue_revert_Paused() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IIpRoyaltyVault ipRoyaltyVault = IIpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.prank(u.admin);
        royaltyModule.pause();

        vm.expectRevert(Errors.IpRoyaltyVault__EnforcedPause.selector);
        ipRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch(new uint256[](0), address(USDC), u.admin);

        vm.expectRevert(Errors.IpRoyaltyVault__EnforcedPause.selector);
        ipRoyaltyVault.claimRevenueOnBehalfByTokenBatch(1, new address[](0), u.admin);
    }

    function test_IpRoyaltyVault_claimableRevenue() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerIpId = address(3);
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(receiverIpId, address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IIpRoyaltyVault ipRoyaltyVault = IIpRoyaltyVault(royaltyModule.ipRoyaltyVaults(receiverIpId));
        vm.stopPrank();

        // send 30% of rts to another address
        address minorityHolder = address(1);
        vm.prank(receiverIpId);
        IERC20(address(ipRoyaltyVault)).transfer(minorityHolder, 30e6);

        // payment is made to vault
        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        uint256 claimableRevenueIpId = ipRoyaltyVault.claimableRevenue(receiverIpId, 1, address(USDC));
        uint256 claimableRevenueMinHolder = ipRoyaltyVault.claimableRevenue(minorityHolder, 1, address(USDC));
        assertEq(claimableRevenueIpId, (royaltyAmount * 70e6) / 100e6);
        assertEq(claimableRevenueMinHolder, (royaltyAmount * 30e6) / 100e6);
    }

    function test_IpRoyaltyVault_claimRevenueOnBehalfByTokenBatch_revert_VaultsMustClaimAsSelf() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.expectRevert(Errors.IpRoyaltyVault__VaultsMustClaimAsSelf.selector);
        IIpRoyaltyVault(ipRoyaltyVault).claimRevenueOnBehalfByTokenBatch(1, new address[](0), address(ipRoyaltyVault));
    }

    function test_IpRoyaltyVault_claimRevenueOnBehalfByTokenBatch_revert_NoClaimableTokens() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        ipRoyaltyVault.updateVaultBalance(address(USDC), 1);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);

        vm.expectRevert(Errors.IpRoyaltyVault__NoClaimableTokens.selector);
        ipRoyaltyVault.claimRevenueOnBehalfByTokenBatch(1, tokens, u.admin);
    }

    function test_IpRoyaltyVault_claimRevenueOnBehalfByTokenBatch() public {
        // payment is made to vault
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(2), royaltyAmount); // 100k USDC
        LINK.mint(address(2), royaltyAmount); // 100k LINK
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);
        LINK.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(LINK), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        address[] memory tokens = new address[](2);
        tokens[0] = address(USDC);
        tokens[1] = address(LINK);

        uint256 userUsdcBalanceBefore = USDC.balanceOf(address(2));
        uint256 userLinkBalanceBefore = LINK.balanceOf(address(2));
        uint256 contractUsdcBalanceBefore = USDC.balanceOf(address(ipRoyaltyVault));
        uint256 contractLinkBalanceBefore = LINK.balanceOf(address(ipRoyaltyVault));
        uint256 usdcClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(USDC));
        uint256 linkClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(LINK));

        vm.startPrank(address(2));

        uint256 expectedAmount = royaltyAmount;

        vm.expectEmit(true, true, true, true, address(ipRoyaltyVault));
        emit IIpRoyaltyVault.RevenueTokenClaimed(address(2), address(USDC), expectedAmount);
        emit IIpRoyaltyVault.RevenueTokenClaimed(address(2), address(LINK), expectedAmount);

        ipRoyaltyVault.claimRevenueOnBehalfByTokenBatch(1, tokens, address(2));

        assertEq(USDC.balanceOf(address(2)) - userUsdcBalanceBefore, expectedAmount);
        assertEq(LINK.balanceOf(address(2)) - userLinkBalanceBefore, expectedAmount);
        assertEq(contractUsdcBalanceBefore - USDC.balanceOf(address(ipRoyaltyVault)), expectedAmount);
        assertEq(contractLinkBalanceBefore - LINK.balanceOf(address(ipRoyaltyVault)), expectedAmount);
        assertEq(usdcClaimVaultBefore - ipRoyaltyVault.claimVaultAmount(address(USDC)), expectedAmount);
        assertEq(linkClaimVaultBefore - ipRoyaltyVault.claimVaultAmount(address(LINK)), expectedAmount);
        assertEq(ipRoyaltyVault.isClaimedAtSnapshot(1, address(2), address(USDC)), true);
        assertEq(ipRoyaltyVault.isClaimedAtSnapshot(1, address(2), address(LINK)), true);
    }

    function test_IpRoyaltyVault_claimRevenueOnBehalfBySnapshotBatch_revert_VaultsMustClaimAsSelf() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.expectRevert(Errors.IpRoyaltyVault__VaultsMustClaimAsSelf.selector);
        ipRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch(new uint256[](0), address(USDC), address(ipRoyaltyVault));
    }

    function test_IpRoyaltyVault_claimRevenueOnBehalfBySnapshotBatch_revert_NoClaimableTokens() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.expectRevert(Errors.IpRoyaltyVault__NoClaimableTokens.selector);
        ipRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch(new uint256[](0), address(USDC), u.admin);
    }

    function test_IpRoyaltyVault_claimRevenueOnBehalfBySnapshotBatch() public {
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(2), royaltyAmount); // 100k USDC

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();

        // 1st payment is made to vault
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount / 2);

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        // 2nt payment is made to vault
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount / 2);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        uint256[] memory snapshots = new uint256[](2);
        snapshots[0] = 1;
        snapshots[1] = 2;

        uint256 userUsdcBalanceBefore = USDC.balanceOf(address(2));
        uint256 contractUsdcBalanceBefore = USDC.balanceOf(address(ipRoyaltyVault));
        uint256 usdcClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(USDC));

        uint256 expectedAmount = royaltyAmount;

        vm.expectEmit(true, true, true, true, address(ipRoyaltyVault));
        emit IIpRoyaltyVault.RevenueTokenClaimed(address(2), address(USDC), expectedAmount);

        vm.startPrank(address(2));
        ipRoyaltyVault.claimRevenueOnBehalfBySnapshotBatch(snapshots, address(USDC), address(2));

        assertEq(USDC.balanceOf(address(2)) - userUsdcBalanceBefore, expectedAmount);
        assertEq(contractUsdcBalanceBefore - USDC.balanceOf(address(ipRoyaltyVault)), expectedAmount);
        assertEq(usdcClaimVaultBefore - ipRoyaltyVault.claimVaultAmount(address(USDC)), expectedAmount);
        assertEq(ipRoyaltyVault.isClaimedAtSnapshot(1, address(2), address(USDC)), true);
        assertEq(ipRoyaltyVault.isClaimedAtSnapshot(2, address(2), address(USDC)), true);
    }

    function test_IpRoyaltyVault_claimByTokenBatchAsSelf_revert_InvalidTargetIpId() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.expectRevert(Errors.IpRoyaltyVault__InvalidTargetIpId.selector);
        ipRoyaltyVault.claimByTokenBatchAsSelf(1, new address[](0), address(0));
    }

    function test_IpRoyaltyVault_claimByTokenBatchAsSelf_revert_VaultDoesNotBelongToAnAncestor() public {
        // deploy two vaults and send 30% of rts to another address
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(2), royaltyAmount); // 100k USDC
        LINK.mint(address(2), royaltyAmount); // 100k LINK
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(3), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault3 = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(3)));
        vm.stopPrank();

        vm.prank(address(2));
        IERC20(address(ipRoyaltyVault)).transfer(address(ipRoyaltyVault3), 30e6);
        vm.stopPrank();

        // payment is made to vault
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);
        LINK.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(LINK), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        address[] memory tokens = new address[](2);
        tokens[0] = address(USDC);
        tokens[1] = address(LINK);

        vm.startPrank(address(100));

        uint256 expectedAmount = (royaltyAmount * 30e6) / 100e6;

        vm.expectRevert(Errors.IpRoyaltyVault__VaultDoesNotBelongToAnAncestor.selector);
        ipRoyaltyVault3.claimByTokenBatchAsSelf(1, tokens, address(2));
    }

    function test_IpRoyaltyVault_claimByTokenBatchAsSelf() public {
        // deploy two vaults and send 30% of rts to another address
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(1), royaltyAmount); // 100k USDC
        LINK.mint(address(1), royaltyAmount); // 100k LINK
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(3), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault3 = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(3)));
        vm.stopPrank();

        vm.prank(address(2));
        IERC20(address(ipRoyaltyVault)).transfer(address(ipRoyaltyVault3), 30e6);
        vm.stopPrank();

        // mock parent-child relationship
        address[] memory parents = new address[](1);
        parents[0] = address(3);
        ipGraph.addParentIp(address(2), parents);

        // payment is made to vault
        vm.startPrank(address(1));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(1), address(USDC), royaltyAmount);
        LINK.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(1), address(LINK), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        address[] memory tokens = new address[](2);
        tokens[0] = address(USDC);
        tokens[1] = address(LINK);

        uint256 claimerUsdcBalanceBefore = USDC.balanceOf(address(ipRoyaltyVault3));
        uint256 claimerLinkBalanceBefore = LINK.balanceOf(address(ipRoyaltyVault3));
        //uint256 claimedUsdcBalanceBefore = USDC.balanceOf(address(ipRoyaltyVault));
        uint256 claimedLinkBalanceBefore = LINK.balanceOf(address(ipRoyaltyVault));
        //uint256 usdcClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(USDC));
        uint256 linkClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(LINK));
        //uint256 usdcPendingVaultBefore = ipRoyaltyVault3.pendingVaultAmount(address(USDC));
        uint256 linkPendingVaultBefore = ipRoyaltyVault3.pendingVaultAmount(address(LINK));

        vm.startPrank(address(100));

        uint256 expectedAmount = (royaltyAmount * 30e6) / 100e6;

        vm.expectEmit(true, true, true, true, address(ipRoyaltyVault));
        emit IIpRoyaltyVault.RevenueTokenClaimed(address(ipRoyaltyVault3), address(USDC), expectedAmount);

        vm.expectEmit(true, true, true, true, address(ipRoyaltyVault));
        emit IIpRoyaltyVault.RevenueTokenClaimed(address(ipRoyaltyVault3), address(LINK), expectedAmount);

        ipRoyaltyVault3.claimByTokenBatchAsSelf(1, tokens, address(2));

        assertEq(USDC.balanceOf(address(ipRoyaltyVault3)) - claimerUsdcBalanceBefore, expectedAmount);
        assertEq(LINK.balanceOf(address(ipRoyaltyVault3)) - claimerLinkBalanceBefore, expectedAmount);
        //assertEq(claimedUsdcBalanceBefore - USDC.balanceOf(address(ipRoyaltyVault)), expectedAmount);
        assertEq(claimedLinkBalanceBefore - LINK.balanceOf(address(ipRoyaltyVault)), expectedAmount);
        //assertEq(usdcClaimVaultBefore - ipRoyaltyVault.claimVaultAmount(address(USDC)), expectedAmount);
        assertEq(linkClaimVaultBefore - ipRoyaltyVault.claimVaultAmount(address(LINK)), expectedAmount);
        //assertEq(ipRoyaltyVault.isClaimedAtSnapshot(1, address(ipRoyaltyVault3), address(USDC)), true);
        assertEq(ipRoyaltyVault.isClaimedAtSnapshot(1, address(ipRoyaltyVault3), address(LINK)), true);
        //assertEq(ipRoyaltyVault3.pendingVaultAmount(address(USDC)) - usdcPendingVaultBefore, expectedAmount);
        assertEq(ipRoyaltyVault3.pendingVaultAmount(address(LINK)) - linkPendingVaultBefore, expectedAmount);
    }

    function test_IpRoyaltyVault_claimBySnapshotBatchAsSelf_revert_InvalidTargetIpId() public {
        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(1), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(1)));
        vm.stopPrank();

        vm.expectRevert(Errors.IpRoyaltyVault__InvalidTargetIpId.selector);
        ipRoyaltyVault.claimBySnapshotBatchAsSelf(new uint256[](0), address(USDC), address(0));
    }

    function test_IpRoyaltyVault_claimBySnapshotBatchAsSelf_revert_VaultDoesNotBelongToAnAncestor() public {
        // deploy two vaults and send 30% of rts to another address
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(1), royaltyAmount); // 100k USDC
        LINK.mint(address(1), royaltyAmount); // 100k LINK
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(3), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault3 = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(3)));
        vm.stopPrank();

        vm.prank(address(2));
        IERC20(address(ipRoyaltyVault)).transfer(address(ipRoyaltyVault3), 30e6);
        vm.stopPrank();

        // payment is made to vault
        vm.startPrank(address(1));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(1), address(USDC), royaltyAmount);
        LINK.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(1), address(LINK), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        uint256[] memory snapshots = new uint256[](2);
        snapshots[0] = 1;
        snapshots[1] = 2;

        vm.startPrank(address(100));

        vm.expectRevert(Errors.IpRoyaltyVault__VaultDoesNotBelongToAnAncestor.selector);
        ipRoyaltyVault3.claimBySnapshotBatchAsSelf(snapshots, address(USDC), address(2));
    }

    function test_IpRoyaltyVault_claimBySnapshotBatchAsSelf() public {
        // deploy two vaults and send 30% of rts to another address
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(1), royaltyAmount * 2); // 100k USDC
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(2)));
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(3), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        IpRoyaltyVault ipRoyaltyVault3 = IpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(3)));
        vm.stopPrank();

        vm.prank(address(2));
        IERC20(address(ipRoyaltyVault)).transfer(address(ipRoyaltyVault3), 30e6);
        vm.stopPrank();

        // mock parent-child relationship
        address[] memory parents = new address[](1);
        parents[0] = address(3);
        ipGraph.addParentIp(address(2), parents);

        // payment is made to vault
        vm.startPrank(address(1));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(1), address(USDC), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipRoyaltyVault.snapshot();

        // payment is made to vault
        vm.startPrank(address(1));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(1), address(USDC), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 15 days + 1);
        ipRoyaltyVault.snapshot();

        uint256[] memory snapshots = new uint256[](2);
        snapshots[0] = 1;
        snapshots[1] = 2;

        uint256 expectedAmount = (royaltyAmount * 2 * 30e6) / 100e6;

        vm.expectEmit(true, true, true, true, address(ipRoyaltyVault));
        emit IIpRoyaltyVault.RevenueTokenClaimed(address(ipRoyaltyVault3), address(USDC), expectedAmount);

        uint256 claimerUsdcBalanceBefore = USDC.balanceOf(address(ipRoyaltyVault3));
        uint256 claimedUsdcBalanceBefore = USDC.balanceOf(address(ipRoyaltyVault));
        uint256 usdcClaimVaultBefore = ipRoyaltyVault.claimVaultAmount(address(USDC));
        uint256 usdcPendingVaultBefore = ipRoyaltyVault3.pendingVaultAmount(address(USDC));

        ipRoyaltyVault3.claimBySnapshotBatchAsSelf(snapshots, address(USDC), address(2));

        assertEq(USDC.balanceOf(address(ipRoyaltyVault3)) - claimerUsdcBalanceBefore, expectedAmount);
        assertEq(claimedUsdcBalanceBefore - USDC.balanceOf(address(ipRoyaltyVault)), expectedAmount);
        assertEq(usdcClaimVaultBefore - ipRoyaltyVault.claimVaultAmount(address(USDC)), expectedAmount);
        assertEq(ipRoyaltyVault3.pendingVaultAmount(address(USDC)) - usdcPendingVaultBefore, expectedAmount);
    }
}
