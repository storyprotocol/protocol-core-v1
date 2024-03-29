// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IpPool } from "../../../../contracts/modules/royalty/policies/IpPool.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TestIpPool is BaseTest {
    event Claimed(address claimerIpId);
    event SnapshotCompleted(uint256 snapshotId, uint256 timestamp, uint32 unclaimedTokens);

    IpPool ipPool;

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({ disputeModule: false, royaltyModule: true, licensingModule: false })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ arbitrationPolicySP: false, royaltyPolicyLAP: true }));
        deployConditionally();
        postDeploymentSetup();

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.whitelistRoyaltyToken(address(LINK), true);
        royaltyPolicyLAP.setSnapshotInterval(7 days);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        _setupMaxUniqueTree();

        (, address ipPool2, , , ) = royaltyPolicyLAP.getRoyaltyData(address(2));
        ipPool = IpPool(ipPool2);
    }

    function _setupMaxUniqueTree() internal {
        // init royalty policy for roots
        royaltyPolicyLAP.onLicenseMinting(address(7), abi.encode(uint32(7)), "");
        royaltyPolicyLAP.onLicenseMinting(address(8), abi.encode(uint32(8)), "");
        royaltyPolicyLAP.onLicenseMinting(address(9), abi.encode(uint32(9)), "");
        royaltyPolicyLAP.onLicenseMinting(address(10), abi.encode(uint32(10)), "");
        royaltyPolicyLAP.onLicenseMinting(address(11), abi.encode(uint32(11)), "");
        royaltyPolicyLAP.onLicenseMinting(address(12), abi.encode(uint32(12)), "");
        royaltyPolicyLAP.onLicenseMinting(address(13), abi.encode(uint32(13)), "");
        royaltyPolicyLAP.onLicenseMinting(address(14), abi.encode(uint32(14)), "");

        // init 2nd level with children
        address[] memory parents = new address[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);

        // 3 is child of 7 and 8
        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7 * 10 ** 5;
        parentRoyalties1[1] = 8 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(3), parents, encodedLicenseData, "");

        // 4 is child of 9 and 10
        parents[0] = address(9);
        parents[1] = address(10);
        parentRoyalties1[0] = 9 * 10 ** 5;
        parentRoyalties1[1] = 10 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(4), parents, encodedLicenseData, "");

        // 5 is child of 11 and 12
        parents[0] = address(11);
        parents[1] = address(12);
        parentRoyalties1[0] = 11 * 10 ** 5;
        parentRoyalties1[1] = 12 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(5), parents, encodedLicenseData, "");

        // 6 is child of 13 and 14
        parents[0] = address(13);
        parents[1] = address(14);
        parentRoyalties1[0] = 13 * 10 ** 5;
        parentRoyalties1[1] = 14 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(6), parents, encodedLicenseData, "");

        // init 3rd level with children
        // 1 is child of 3 and 4
        parents[0] = address(3);
        parents[1] = address(4);
        parentRoyalties1[0] = 3 * 10 ** 5;
        parentRoyalties1[1] = 4 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(1), parents, encodedLicenseData, "");

        // 2 is child of 5 and 6
        parents[0] = address(5);
        parents[1] = address(6);
        parentRoyalties1[0] = 5 * 10 ** 5;
        parentRoyalties1[1] = 6 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(2), parents, encodedLicenseData, "");

        address[] memory parentsIpIds100 = new address[](2);
        parentsIpIds100 = new address[](2);
        parentsIpIds100[0] = address(1);
        parentsIpIds100[1] = address(2);

        parents[0] = address(1);
        parents[1] = address(2);
        parentRoyalties1[0] = 1 * 10 ** 5;
        parentRoyalties1[1] = 2 * 10 ** 5;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(100), address(royaltyPolicyLAP), parents, encodedLicenseData, "");
        //royaltyPolicyLAP.onLinkToParents(address(100), parents, encodedLicenseData, "");
    }

    function test_IpPool_UpdateIpPoolTokens_NotRoyaltyPolicyLAP() public {
        vm.expectRevert(Errors.IpPool__NotRoyaltyPolicyLAP.selector);
        ipPool.updateIpPoolTokens(address(0));
    }

    function test_IpPool_UpdateIpPoolTokens() public {
        vm.startPrank(address(royaltyPolicyLAP));
        ipPool.updateIpPoolTokens(address(1));

        address[] memory tokens = ipPool.getPoolTokens();

        assertEq(tokens.length, 1);
        assertEq(tokens[0], address(1));
    }

    function test_IpPool_ClaimableRevenue() public {
        // payment is made to pool
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(100), 100000 * 10 ** 6); // 100k USDC
        vm.startPrank(address(100));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(USDC), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipPool.snapshot();

        (, , uint32 royaltyStack2, , ) = royaltyPolicyLAP.getRoyaltyData(address(2));

        uint256 claimableRevenue = ipPool.claimableRevenue(address(2), 1, address(USDC));
        assertEq(
            claimableRevenue,
            royaltyAmount - (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY()
        );
    }

    function test_IpPool_ClaimRevenueByTokenBatch() public {
        // payment is made to pool
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(100), royaltyAmount); // 100k USDC
        LINK.mint(address(100), royaltyAmount); // 100k LINK
        vm.startPrank(address(100));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(USDC), royaltyAmount);
        LINK.approve(address(royaltyPolicyLAP), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(LINK), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipPool.snapshot();

        (, , uint32 royaltyStack2, , ) = royaltyPolicyLAP.getRoyaltyData(address(2));

        address[] memory tokens = new address[](2);
        tokens[0] = address(USDC);
        tokens[1] = address(LINK);

        uint256 userUsdcBalanceBefore = USDC.balanceOf(address(2));
        uint256 userLinkBalanceBefore = LINK.balanceOf(address(2));
        uint256 contractUsdcBalanceBefore = USDC.balanceOf(address(ipPool));
        uint256 contractLinkBalanceBefore = LINK.balanceOf(address(ipPool));
        uint256 usdcClaimPoolBefore = ipPool.claimPoolAmount(address(USDC));
        uint256 linkClaimPoolBefore = ipPool.claimPoolAmount(address(LINK));

        vm.startPrank(address(2));
        ipPool.claimRevenueByTokenBatch(1, tokens);

        uint256 expectedAmount = royaltyAmount - (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY();

        assertEq(USDC.balanceOf(address(2)) - userUsdcBalanceBefore, expectedAmount);
        assertEq(LINK.balanceOf(address(2)) - userLinkBalanceBefore, expectedAmount);
        assertEq(contractUsdcBalanceBefore - USDC.balanceOf(address(ipPool)), expectedAmount);
        assertEq(contractLinkBalanceBefore - LINK.balanceOf(address(ipPool)), expectedAmount);
        assertEq(usdcClaimPoolBefore - ipPool.claimPoolAmount(address(USDC)), expectedAmount);
        assertEq(linkClaimPoolBefore - ipPool.claimPoolAmount(address(LINK)), expectedAmount);
        assertEq(ipPool.isClaimedAtSnapshot(1, address(2), address(USDC)), true);
        assertEq(ipPool.isClaimedAtSnapshot(1, address(2), address(LINK)), true);
    }

    function test_IpPool_ClaimRevenueBySnapshotBatch() public {
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(100), royaltyAmount); // 100k USDC

        // 1st payment is made to pool
        vm.startPrank(address(100));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(USDC), royaltyAmount / 2);

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipPool.snapshot();

        // 2nt payment is made to pool
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(USDC), royaltyAmount / 2);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipPool.snapshot();

        (, , uint32 royaltyStack2, , ) = royaltyPolicyLAP.getRoyaltyData(address(2));

        uint256[] memory snapshots = new uint256[](2);
        snapshots[0] = 1;
        snapshots[1] = 2;

        uint256 userUsdcBalanceBefore = USDC.balanceOf(address(2));
        uint256 contractUsdcBalanceBefore = USDC.balanceOf(address(ipPool));
        uint256 usdcClaimPoolBefore = ipPool.claimPoolAmount(address(USDC));

        vm.startPrank(address(2));
        ipPool.claimRevenueBySnapshotBatch(snapshots, address(USDC));

        uint256 expectedAmount = royaltyAmount - (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY();

        assertEq(USDC.balanceOf(address(2)) - userUsdcBalanceBefore, expectedAmount);
        assertEq(contractUsdcBalanceBefore - USDC.balanceOf(address(ipPool)), expectedAmount);
        assertEq(usdcClaimPoolBefore - ipPool.claimPoolAmount(address(USDC)), expectedAmount);
        assertEq(ipPool.isClaimedAtSnapshot(1, address(2), address(USDC)), true);
        assertEq(ipPool.isClaimedAtSnapshot(2, address(2), address(USDC)), true);
    }

    function test_IpPool_Snapshot_SnapshotIntervalTooShort() public {
        vm.expectRevert(Errors.IpPool__SnapshotIntervalTooShort.selector);
        ipPool.snapshot();
    }

    function test_IpPool_Snapshot() public {
        // payment is made to pool
        uint256 royaltyAmount = 100000 * 10 ** 6;
        USDC.mint(address(100), royaltyAmount); // 100k USDC
        LINK.mint(address(100), royaltyAmount); // 100k LINK
        vm.startPrank(address(100));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(USDC), royaltyAmount);
        LINK.approve(address(royaltyPolicyLAP), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(LINK), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);

        uint256 usdcClaimPoolBefore = ipPool.claimPoolAmount(address(USDC));
        uint256 linkClaimPoolBefore = ipPool.claimPoolAmount(address(LINK));
        uint256 usdcAncestorsPoolBefore = ipPool.ancestorsPoolAmount(address(USDC));
        uint256 linkAncestorsPoolBefore = ipPool.ancestorsPoolAmount(address(LINK));

        (, , uint32 royaltyStack2, , ) = royaltyPolicyLAP.getRoyaltyData(address(2));

        vm.expectEmit(true, true, true, true, address(ipPool));
        emit SnapshotCompleted(1, block.timestamp, royaltyStack2);

        ipPool.snapshot();

        assertEq(ipPool.claimPoolAmount(address(USDC)) + ipPool.ancestorsPoolAmount(address(USDC)), royaltyAmount);
        assertEq(ipPool.claimPoolAmount(address(LINK)) + ipPool.ancestorsPoolAmount(address(LINK)), royaltyAmount);
        assertEq(
            ipPool.claimPoolAmount(address(USDC)) - usdcClaimPoolBefore,
            royaltyAmount - (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY()
        );
        assertEq(
            ipPool.claimPoolAmount(address(LINK)) - linkClaimPoolBefore,
            royaltyAmount - (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY()
        );
        assertEq(
            ipPool.ancestorsPoolAmount(address(USDC)) - usdcAncestorsPoolBefore,
            (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY()
        );
        assertEq(
            ipPool.ancestorsPoolAmount(address(LINK)) - linkAncestorsPoolBefore,
            (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY()
        );
        assertEq(ipPool.lastSnapshotTimestamp(), block.timestamp);
        assertEq(ipPool.unclaimedRoyaltyTokens(), royaltyStack2);
        assertEq(ipPool.unclaimedAtSnapshot(1), royaltyStack2);
        assertEq(
            ipPool.claimableAtSnapshot(1, address(USDC)),
            royaltyAmount - (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY()
        );
        assertEq(
            ipPool.claimableAtSnapshot(1, address(LINK)),
            royaltyAmount - (royaltyAmount * royaltyStack2) / royaltyPolicyLAP.TOTAL_RT_SUPPLY()
        );

        // users claim all USDC
        address[] memory tokens = new address[](1);
        tokens[0] = address(USDC);
        vm.prank(address(2));
        ipPool.claimRevenueByTokenBatch(1, tokens);

        ipPool.collectRoyaltyTokens(address(5));
        ipPool.collectRoyaltyTokens(address(11));
        ipPool.collectRoyaltyTokens(address(12));
        ipPool.collectRoyaltyTokens(address(6));
        ipPool.collectRoyaltyTokens(address(13));
        ipPool.collectRoyaltyTokens(address(14));

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipPool.snapshot();

        // all USDC was claimed but LINK was not
        assertEq(ipPool.getPoolTokens().length, 1);
    }

    function test_IpPool_CollectRoyaltyTokens_AlreadyClaimed() public {
        ipPool.collectRoyaltyTokens(address(5));

        vm.expectRevert(Errors.IpPool__AlreadyClaimed.selector);
        ipPool.collectRoyaltyTokens(address(5));
    }

    function test_IpPool_CollectRoyaltyTokens_ClaimerNotAnAncestor() public {
        vm.expectRevert(Errors.IpPool__ClaimerNotAnAncestor.selector);
        ipPool.collectRoyaltyTokens(address(0));
    }

    function test_IpPool_CollectRoyaltyTokens() public {
        uint256 parentRoyalty = 5 * 10 ** 5;
        uint256 royaltyAmount = 100000 * 10 ** 6;
        uint256 accruedCollectableRevenue = (royaltyAmount * 5 * 10 ** 5) / royaltyPolicyLAP.TOTAL_RT_SUPPLY();

        // payment is made to pool
        USDC.mint(address(100), royaltyAmount); // 100k USDC
        vm.startPrank(address(100));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(100), address(USDC), royaltyAmount);
        vm.stopPrank();

        // take snapshot
        vm.warp(block.timestamp + 7 days + 1);
        ipPool.snapshot();

        uint256 userUsdcBalanceBefore = USDC.balanceOf(address(5));
        uint256 contractUsdcBalanceBefore = USDC.balanceOf(address(ipPool));
        uint256 usdcClaimPoolBefore = ipPool.claimPoolAmount(address(USDC));
        uint256 contractRTBalBefore = IERC20(address(ipPool)).balanceOf(address(ipPool));
        uint256 userRTBalBefore = IERC20(address(ipPool)).balanceOf(address(5));
        uint256 unclaimedRoyaltyTokensBefore = ipPool.unclaimedRoyaltyTokens();
        uint256 ancestorsPoolAmountBefore = ipPool.ancestorsPoolAmount(address(USDC));

        vm.expectEmit(true, true, true, true, address(ipPool));
        emit Claimed(address(5));

        ipPool.collectRoyaltyTokens(address(5));

        assertEq(USDC.balanceOf(address(5)) - userUsdcBalanceBefore, accruedCollectableRevenue);
        assertEq(contractUsdcBalanceBefore - USDC.balanceOf(address(ipPool)), accruedCollectableRevenue);
        assertEq(ipPool.isClaimedByAncestor(address(5)), true);
        assertEq(contractRTBalBefore - IERC20(address(ipPool)).balanceOf(address(ipPool)), parentRoyalty);
        assertEq(IERC20(address(ipPool)).balanceOf(address(5)) - userRTBalBefore, parentRoyalty);
        assertEq(unclaimedRoyaltyTokensBefore - ipPool.unclaimedRoyaltyTokens(), parentRoyalty);
        assertEq(ancestorsPoolAmountBefore - ipPool.ancestorsPoolAmount(address(USDC)), accruedCollectableRevenue);
    }
}
