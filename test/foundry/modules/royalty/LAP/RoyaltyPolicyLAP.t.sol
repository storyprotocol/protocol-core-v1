// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";

// contracts
import { RoyaltyPolicyLAP } from "../../../../../contracts/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
// solhint-disable-next-line max-line-length
import { IRoyaltyPolicyLAP } from "../../../../../contracts/interfaces/modules/royalty/policies/LAP/IRoyaltyPolicyLAP.sol";
import { Errors } from "../../../../../contracts/lib/Errors.sol";

// tests
import { BaseTest } from "../../../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../../../utils/TestProxyHelper.sol";
import { IIpRoyaltyVault } from "../../../../../contracts/interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { MockExternalRoyaltyPolicy1 } from "../../../mocks/policy/MockExternalRoyaltyPolicy1.sol";
import { MockExternalRoyaltyPolicy2 } from "../../../mocks/policy/MockExternalRoyaltyPolicy2.sol";

contract TestRoyaltyPolicyLAP is BaseTest {
    RoyaltyPolicyLAP internal testRoyaltyPolicyLAP;

    address internal mockExternalRoyaltyPolicy1;
    address internal mockExternalRoyaltyPolicy2;

    function setUp() public override {
        super.setUp();

        // register external royalty policies
        mockExternalRoyaltyPolicy1 = address(new MockExternalRoyaltyPolicy1());
        mockExternalRoyaltyPolicy2 = address(new MockExternalRoyaltyPolicy2());
        royaltyModule.registerExternalRoyaltyPolicy(mockExternalRoyaltyPolicy1);
        royaltyModule.registerExternalRoyaltyPolicy(mockExternalRoyaltyPolicy2);

        vm.startPrank(address(licensingModule));
        _setupTree();
        vm.stopPrank();
    }

    function _setupTree() internal {
        // mint license for roots
        royaltyModule.onLicenseMinting(address(10), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(20), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(30), address(royaltyPolicyLRP), uint32(7 * 10 ** 6), "");

        // link 40 to parents
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(10 * 10 ** 6);
        parentRoyalties[1] = uint32(10 * 10 ** 6);
        parentRoyalties[2] = uint32(7 * 10 ** 6);
        ipGraph.addParentIp(address(40), parents);
        royaltyModule.onLinkToParents(address(40), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 40
        royaltyModule.onLicenseMinting(address(40), address(royaltyPolicyLRP), uint32(5 * 10 ** 6), "");

        // link 50 to 40
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(40);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        ipGraph.addParentIp(address(50), parents);
        royaltyModule.onLinkToParents(address(50), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 50
        royaltyModule.onLicenseMinting(address(50), address(royaltyPolicyLRP), uint32(15 * 10 ** 6), "");

        // link 60 to 50
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(50);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(15 * 10 ** 6);
        ipGraph.addParentIp(address(60), parents);
        royaltyModule.onLinkToParents(address(60), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 60
        royaltyModule.onLicenseMinting(address(60), address(mockExternalRoyaltyPolicy1), uint32(12 * 10 ** 6), "");

        // link 70 to 60
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(60);
        licenseRoyaltyPolicies[0] = address(mockExternalRoyaltyPolicy1);
        parentRoyalties[0] = uint32(12 * 10 ** 6);
        ipGraph.addParentIp(address(70), parents);
        royaltyModule.onLinkToParents(address(70), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 10 + 60 + 70
        royaltyModule.onLicenseMinting(address(10), address(royaltyPolicyLAP), uint32(5 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(60), address(royaltyPolicyLRP), uint32(20 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(70), address(mockExternalRoyaltyPolicy2), uint32(24 * 10 ** 6), "");
    }

    function test_RoyaltyPolicyLAP_constructor_revert_ZeroRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroRoyaltyModule.selector);
        new RoyaltyPolicyLAP(address(0), address(1), address(1));
    }

    function test_RoyaltyPolicyLAP_constructor_revert_ZeroDisputeModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroDisputeModule.selector);
        new RoyaltyPolicyLAP(address(1), address(0), address(1));
    }

    function test_RoyaltyPolicyLAP_constructor_revert_ZeroIPGraphACL() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroIPGraphACL.selector);
        new RoyaltyPolicyLAP(address(1), address(1), address(0));
    }

    function test_RoyaltyPolicyLAP_constructor() public {
        testRoyaltyPolicyLAP = new RoyaltyPolicyLAP(
            address(royaltyModule),
            address(disputeModule),
            address(ipGraphACL)
        );
        assertEq(address(testRoyaltyPolicyLAP.ROYALTY_MODULE()), address(royaltyModule));
        assertEq(address(testRoyaltyPolicyLAP.DISPUTE_MODULE()), address(disputeModule));
    }

    function test_RoyaltyPolicyLAP_initialize_revert_ZeroAccessManager() public {
        address impl = address(
            new RoyaltyPolicyLAP(address(royaltyModule), address(disputeModule), address(ipGraphACL))
        );
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroAccessManager.selector);
        RoyaltyPolicyLAP(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(RoyaltyPolicyLAP.initialize, (address(0))))
        );
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_NotRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLicenseMinting(address(1), uint32(0), "");
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_AboveRoyaltyStackLimit() public {
        uint32 excessPercent = royaltyModule.TOTAL_RT_SUPPLY() + 1;
        vm.prank(address(royaltyModule));
        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), excessPercent, "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_NotRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLinkToParents(address(100), new address[](0), new address[](0), new uint32[](0), "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_AboveRoyaltyStackLimit() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLAP);
        parentRoyalties[0] = uint32(10 * 10 ** 6);
        parentRoyalties[1] = uint32(15 * 10 ** 6);
        parentRoyalties[2] = uint32(200 * 10 ** 6);
        ipGraph.addParentIp(address(80), parents);

        vm.startPrank(address(royaltyModule));
        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit.selector);
        royaltyPolicyLAP.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLAP);
        parentRoyalties[0] = uint32(10 * 10 ** 6);
        parentRoyalties[1] = uint32(15 * 10 ** 6);
        parentRoyalties[2] = uint32(20 * 10 ** 6);
        ipGraph.addParentIp(address(80), parents);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(80));

        uint256 ipId80Balance = IERC20(ipRoyaltyVault).balanceOf(address(80));
        uint256 ipId80LapBalance = IERC20(ipRoyaltyVault).balanceOf(address(royaltyPolicyLAP));

        assertEq(ipId80LapBalance, 45 * 10 ** 6);
        assertEq(ipId80Balance, 55 * 10 ** 6);
        assertEq(royaltyPolicyLAP.royaltyStack(address(80)), 45 * 10 ** 6);
        assertEq(royaltyPolicyLAP.unclaimedRoyaltyTokens(address(80)), 45 * 10 ** 6);
    }

    function test_RoyaltyPolicyLAP_collectRoyaltyTokens_IpTagged() public {
        registerSelectedPILicenseTerms_Commercial({
            selectionName: "cheap_flexible",
            transferable: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 10,
            mintingFee: 0
        });
        mockNFT.mintId(u.alice, 0);
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            address(mockNFT),
            0
        );
        vm.label(expectedAddr, "IPAccount0");
        vm.startPrank(u.alice);
        address ipAddr = ipAssetRegistry.register(block.chainid, address(mockNFT), 0);
        licensingModule.attachLicenseTerms(ipAddr, address(pilTemplate), getSelectedPILicenseTermsId("cheap_flexible"));
        vm.stopPrank();

        // raise dispute
        vm.startPrank(ipAddr);
        USDC.mint(ipAddr, ARBITRATION_PRICE);
        USDC.approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(u.relayer);
        disputeModule.setDisputeJudgement(1, true, "");

        vm.expectRevert(Errors.RoyaltyPolicyLAP__IpTagged.selector);
        royaltyPolicyLAP.collectRoyaltyTokens(ipAddr, address(20));
    }

    function test_RoyaltyPolicyLAP_collectRoyaltyTokens_revert_AlreadyClaimed() public {
        // link ip 80
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLAP);
        parentRoyalties[0] = uint32(12345678);
        parentRoyalties[1] = uint32(3);
        parentRoyalties[2] = uint32(77654321);
        ipGraph.addParentIp(address(2), parents);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(2), parents, licenseRoyaltyPolicies, parentRoyalties, "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(2));
        assertFalse(ipRoyaltyVault == address(0));

        // make payment
        uint256 royaltyAmount = 1234;
        USDC.mint(address(2), royaltyAmount); // 1000 USDC
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);

        // call snapshot
        vm.warp(7 days + 1);
        IIpRoyaltyVault(ipRoyaltyVault).snapshot();

        // call collectRoyaltyTokens
        address[] memory tokenList = IIpRoyaltyVault(ipRoyaltyVault).tokens();
        assertEq(tokenList.length, 1);
        assertEq(tokenList[0], address(USDC));

        // LAP claims revenue tokens
        uint256[] memory snapshotIds = new uint256[](1);
        snapshotIds[0] = 1;
        royaltyPolicyLAP.claimBySnapshotBatchAsSelf(snapshotIds, address(USDC), address(2));

        // one parent collects royalty tokens
        royaltyPolicyLAP.collectRoyaltyTokens(address(2), address(20));

        vm.expectRevert(Errors.RoyaltyPolicyLAP__AlreadyClaimed.selector);
        royaltyPolicyLAP.collectRoyaltyTokens(address(2), address(20));
    }

    function test_RoyaltyPolicyLAP_collectRoyaltyTokens_revert_ClaimerNotAnAncestor() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ClaimerNotAnAncestor.selector);
        royaltyPolicyLAP.collectRoyaltyTokens(address(2), address(1111));
    }

    function test_RoyaltyPolicyLAP_collectRoyaltyTokens_revert_NotAllRevenueTokensHaveBeenClaimed() public {
        // link ip 80
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLAP);
        parentRoyalties[0] = uint32(12345678);
        parentRoyalties[1] = uint32(3);
        parentRoyalties[2] = uint32(77654321);
        ipGraph.addParentIp(address(2), parents);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(2), parents, licenseRoyaltyPolicies, parentRoyalties, "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(2));
        assertFalse(ipRoyaltyVault == address(0));

        // make payment
        uint256 royaltyAmount = 1234;
        USDC.mint(address(2), royaltyAmount); // 1000 USDC
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);

        // call snapshot
        vm.warp(7 days + 1);
        IIpRoyaltyVault(ipRoyaltyVault).snapshot();

        // call collectRoyaltyTokens
        address[] memory tokenList = IIpRoyaltyVault(ipRoyaltyVault).tokens();
        assertEq(tokenList.length, 1);
        assertEq(tokenList[0], address(USDC));

        // one parent collects royalty tokens
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotAllRevenueTokensHaveBeenClaimed.selector);
        royaltyPolicyLAP.collectRoyaltyTokens(address(2), address(20));
    }

    function test_RoyaltyPolicyLAP_collectRoyaltyTokens() public {
        // link ip 80
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLAP);
        parentRoyalties[0] = uint32(12345678);
        parentRoyalties[1] = uint32(3);
        parentRoyalties[2] = uint32(77654321);
        ipGraph.addParentIp(address(2), parents);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(2), parents, licenseRoyaltyPolicies, parentRoyalties, "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(2));
        assertFalse(ipRoyaltyVault == address(0));

        // make payment
        uint256 royaltyAmount = 1234;
        USDC.mint(address(2), royaltyAmount); // 1000 USDC
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);

        // call snapshot
        vm.warp(7 days + 1);
        IIpRoyaltyVault(ipRoyaltyVault).snapshot();

        // call collectRoyaltyTokens
        address[] memory tokenList = IIpRoyaltyVault(ipRoyaltyVault).tokens();
        assertEq(tokenList.length, 1);
        assertEq(tokenList[0], address(USDC));

        // LAP claims revenue tokens
        uint256[] memory snapshotIds = new uint256[](1);
        snapshotIds[0] = 1;
        royaltyPolicyLAP.claimBySnapshotBatchAsSelf(snapshotIds, address(USDC), address(2));

        // one parent collects royalty tokens
        royaltyPolicyLAP.collectRoyaltyTokens(address(2), address(20));

        // new payment and new snapshot
        USDC.mint(address(2), royaltyAmount); // 1000 USDC
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);
        vm.warp(14 days + 1);
        IIpRoyaltyVault(ipRoyaltyVault).snapshot();

        // LAP claims revenue tokens
        uint256[] memory snapshotIds2 = new uint256[](2);
        snapshotIds2[0] = 1;
        snapshotIds2[1] = 2;
        royaltyPolicyLAP.claimBySnapshotBatchAsSelf(snapshotIds2, address(USDC), address(2));

        // another parent collects royalty tokens
        uint32 parent10Royalty = parentRoyalties[0];
        address ancestor10Vault = royaltyModule.ipRoyaltyVaults(address(10));
        uint256 expectedUSDCForAncestor10 = (royaltyAmount * 2 * parent10Royalty) / royaltyModule.TOTAL_RT_SUPPLY();

        uint256 ipId2RTAncestorVaultBalBefore = IERC20(ipRoyaltyVault).balanceOf(address(ancestor10Vault));
        uint256 USDCAncestorVaultBalBefore = IERC20(USDC).balanceOf(address(ancestor10Vault));
        uint256 revenueTokenBalancesBefore = royaltyPolicyLAP.revenueTokenBalances(address(2), address(USDC));
        bool isCollectedByAncestorBefore = royaltyPolicyLAP.isCollectedByAncestor(address(2), address(10));
        uint256 unclaimedRoyaltyTokensBefore = royaltyPolicyLAP.unclaimedRoyaltyTokens(address(2));

        vm.expectEmit(true, true, true, true, address(royaltyPolicyLAP));
        emit IRoyaltyPolicyLAP.RoyaltyTokensCollected(address(2), address(10), parent10Royalty);
        royaltyPolicyLAP.collectRoyaltyTokens(address(2), address(10));

        uint256 ipId2RTAncestorVaultBalAfter = IERC20(ipRoyaltyVault).balanceOf(address(ancestor10Vault));
        uint256 USDCAncestorVaultBalAfter = IERC20(USDC).balanceOf(address(ancestor10Vault));
        uint256 revenueTokenBalancesAfter = royaltyPolicyLAP.revenueTokenBalances(address(2), address(USDC));
        bool isCollectedByAncestorAfter = royaltyPolicyLAP.isCollectedByAncestor(address(2), address(10));
        uint256 unclaimedRoyaltyTokensAfter = royaltyPolicyLAP.unclaimedRoyaltyTokens(address(2));

        assertEq(ipId2RTAncestorVaultBalAfter - ipId2RTAncestorVaultBalBefore, parent10Royalty);
        assertEq(USDCAncestorVaultBalAfter - USDCAncestorVaultBalBefore, expectedUSDCForAncestor10);
        assertEq(revenueTokenBalancesBefore - revenueTokenBalancesAfter, expectedUSDCForAncestor10);
        assertEq(isCollectedByAncestorBefore, false);
        assertEq(isCollectedByAncestorAfter, true);
        assertEq(unclaimedRoyaltyTokensBefore - unclaimedRoyaltyTokensAfter, parent10Royalty);
    }

    function test_RoyaltyPolicyLAP_claimBySnapshotBatchAsSelf() public {
        // link ip 80
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLAP);
        parentRoyalties[0] = uint32(12345678);
        parentRoyalties[1] = uint32(3);
        parentRoyalties[2] = uint32(77654321);
        ipGraph.addParentIp(address(2), parents);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(2), parents, licenseRoyaltyPolicies, parentRoyalties, "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(2));
        assertFalse(ipRoyaltyVault == address(0));

        // make payment
        uint256 royaltyAmount = 1234;
        USDC.mint(address(2), royaltyAmount); // 1000 USDC
        vm.startPrank(address(2));
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(address(2), address(2), address(USDC), royaltyAmount);

        // call snapshot
        vm.warp(7 days + 1);
        IIpRoyaltyVault(ipRoyaltyVault).snapshot();

        // call collectRoyaltyTokens
        address[] memory tokenList = IIpRoyaltyVault(ipRoyaltyVault).tokens();
        assertEq(tokenList.length, 1);
        assertEq(tokenList[0], address(USDC));

        // LAP claims revenue tokens
        uint256[] memory snapshotIds = new uint256[](1);
        snapshotIds[0] = 1;

        uint256 expectedUSDCForLap = (royaltyAmount * royaltyPolicyLAP.unclaimedRoyaltyTokens(address(2))) /
            royaltyModule.TOTAL_RT_SUPPLY();

        uint256 lapContractUSDCBalBefore = IERC20(USDC).balanceOf(address(royaltyPolicyLAP));
        bool snapshotsClaimedBefore = royaltyPolicyLAP.snapshotsClaimed(address(2), address(USDC), 1);
        uint256 snapshotsClaimedCounterBefore = royaltyPolicyLAP.snapshotsClaimedCounter(address(2), address(USDC));

        royaltyPolicyLAP.claimBySnapshotBatchAsSelf(snapshotIds, address(USDC), address(2));

        uint256 lapContractUSDCBalAfter = IERC20(USDC).balanceOf(address(royaltyPolicyLAP));
        bool snapshotsClaimedAfter = royaltyPolicyLAP.snapshotsClaimed(address(2), address(USDC), 1);
        uint256 snapshotsClaimedCounterAfter = royaltyPolicyLAP.snapshotsClaimedCounter(address(2), address(USDC));

        assertEq(lapContractUSDCBalAfter - lapContractUSDCBalBefore, expectedUSDCForLap);
        assertEq(snapshotsClaimedBefore, false);
        assertEq(snapshotsClaimedAfter, true);
        assertEq(snapshotsClaimedCounterBefore, 0);
        assertEq(snapshotsClaimedCounterAfter, 1);
    }
}
