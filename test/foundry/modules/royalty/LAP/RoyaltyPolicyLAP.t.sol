// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contracts
import { RoyaltyPolicyLAP } from "../../../../../contracts/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { IIpRoyaltyVault } from "../../../../../contracts/interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { Errors } from "../../../../../contracts/lib/Errors.sol";

// tests
import { BaseTest } from "../../../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../../../utils/TestProxyHelper.sol";
import { MockExternalRoyaltyPolicy1 } from "../../../mocks/policy/MockExternalRoyaltyPolicy1.sol";
import { MockExternalRoyaltyPolicy2 } from "../../../mocks/policy/MockExternalRoyaltyPolicy2.sol";

contract TestRoyaltyPolicyLAP is BaseTest {
    event RevenueTransferredToVault(address ipId, address ancestorIpId, address token, uint256 amount);

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
        new RoyaltyPolicyLAP(address(0), address(1));
    }

    function test_RoyaltyPolicyLAP_constructor_revert_ZeroIPGraphACL() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroIPGraphACL.selector);
        new RoyaltyPolicyLAP(address(1), address(0));
    }

    function test_RoyaltyPolicyLAP_constructor() public {
        testRoyaltyPolicyLAP = new RoyaltyPolicyLAP(address(royaltyModule), address(ipGraphACL));
        assertEq(address(testRoyaltyPolicyLAP.ROYALTY_MODULE()), address(royaltyModule));
        assertEq(address(testRoyaltyPolicyLAP.IP_GRAPH_ACL()), address(ipGraphACL));
    }

    function test_RoyaltyPolicyLAP_initialize_revert_ZeroAccessManager() public {
        address impl = address(new RoyaltyPolicyLAP(address(royaltyModule), address(ipGraphACL)));
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroAccessManager.selector);
        RoyaltyPolicyLAP(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(RoyaltyPolicyLAP.initialize, (address(0))))
        );
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_NotRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLicenseMinting(address(1), uint32(0), "");
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_AboveMaxPercent() public {
        vm.startPrank(address(royaltyModule));
        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveMaxPercent.selector);
        royaltyPolicyLAP.onLicenseMinting(address(1), uint32(1000 * 10 ** 6), "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_NotRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLinkToParents(address(100), new address[](0), new address[](0), new uint32[](0), "");
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

        assertEq(ipId80LapBalance, 0);
        assertEq(ipId80Balance, 100 * 10 ** 6);
        assertEq(royaltyPolicyLAP.getPolicyRoyaltyStack(address(80)), 45 * 10 ** 6);
        assertEq(royaltyPolicyLAP.getPolicyRoyalty(address(80), address(10)), 10 * 10 ** 6);
        assertEq(royaltyPolicyLAP.getPolicyRoyalty(address(80), address(20)), 15 * 10 ** 6);
        assertEq(royaltyPolicyLAP.getPolicyRoyalty(address(80), address(30)), 20 * 10 ** 6);
    }

    function test_RoyaltyPolicyLAP_transferToVault_revert_ZeroAmount() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroAmount.selector);
        royaltyPolicyLAP.transferToVault(address(80), address(10), address(USDC), 0);
    }

    function test_RoyaltyPolicyLAP_transferToVault_revert_ZeroClaimableRoyalty() public {
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

        // make payment to ip 80
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(80);
        address payerIpId = address(3);
        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);
        vm.stopPrank();

        // first transfer to vault
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroClaimableRoyalty.selector);
        royaltyPolicyLAP.transferToVault(address(80), address(2000), address(USDC), 100 * 10 ** 6);
    }

    function test_RoyaltyPolicyLAP_transferToVault_revert_ExceedsClaimableRoyalty() public {
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

        // make payment to ip 80
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(80);
        address payerIpId = address(3);
        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);
        vm.stopPrank();

        royaltyPolicyLAP.transferToVault(address(80), address(10), address(USDC), 5 * 10 ** 6);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__ExceedsClaimableRoyalty.selector);
        royaltyPolicyLAP.transferToVault(address(80), address(10), address(USDC), 6 * 10 ** 6);
    }
    function test_RoyaltyPolicyLAP_transferToVault() public {
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

        // make payment to ip 80
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(80);
        address payerIpId = address(3);
        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);
        vm.stopPrank();

        assertEq(royaltyModule.totalRevenueTokensReceived(address(80), address(USDC)), 100 * 10 ** 6);
        address ancestorIpRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(10));

        uint256 transferredAmountBefore = royaltyPolicyLAP.getTransferredTokens(
            address(80),
            address(10),
            address(USDC)
        );
        uint256 usdcAncestorVaultBalanceBefore = USDC.balanceOf(ancestorIpRoyaltyVault);
        uint256 usdcLAPContractBalanceBefore = USDC.balanceOf(address(royaltyPolicyLAP));
        uint256 ancestorPendingVaultAmountBefore = IIpRoyaltyVault(ancestorIpRoyaltyVault).pendingVaultAmount(
            address(USDC)
        );

        vm.expectEmit(true, true, true, true, address(royaltyPolicyLAP));
        emit RevenueTransferredToVault(address(80), address(10), address(USDC), 10 * 10 ** 6);

        royaltyPolicyLAP.transferToVault(address(80), address(10), address(USDC), 10 * 10 ** 6);

        uint256 transferredAmountAfter = royaltyPolicyLAP.getTransferredTokens(address(80), address(10), address(USDC));
        uint256 usdcAncestorVaultBalanceAfter = USDC.balanceOf(ancestorIpRoyaltyVault);
        uint256 usdcLAPContractBalanceAfter = USDC.balanceOf(address(royaltyPolicyLAP));
        uint256 ancestorPendingVaultAmountAfter = IIpRoyaltyVault(ancestorIpRoyaltyVault).pendingVaultAmount(
            address(USDC)
        );

        assertEq(transferredAmountAfter - transferredAmountBefore, 10 * 10 ** 6);
        assertEq(usdcAncestorVaultBalanceAfter - usdcAncestorVaultBalanceBefore, 10 * 10 ** 6);
        assertEq(usdcLAPContractBalanceBefore - usdcLAPContractBalanceAfter, 10 * 10 ** 6);
        assertEq(ancestorPendingVaultAmountAfter - ancestorPendingVaultAmountBefore, 10 * 10 ** 6);
    }

    function test_RoyaltyPolicyLAP_getPolicyRtsRequiredToLink() public {
        uint256 rtsRequiredToLink = royaltyPolicyLAP.getPolicyRtsRequiredToLink(address(80), uint32(10 * 10 ** 6));
        assertEq(rtsRequiredToLink, 0);
    }
}
