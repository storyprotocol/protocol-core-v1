// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contracts
import { RoyaltyPolicyLRP } from "../../../../../contracts/modules/royalty/policies/LRP/RoyaltyPolicyLRP.sol";
import { Errors } from "../../../../../contracts/lib/Errors.sol";

// tests
import { BaseTest } from "../../../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../../../utils/TestProxyHelper.sol";
import { MockExternalRoyaltyPolicy1 } from "../../../mocks/policy/MockExternalRoyaltyPolicy1.sol";
import { MockExternalRoyaltyPolicy2 } from "../../../mocks/policy/MockExternalRoyaltyPolicy2.sol";

contract TestRoyaltyPolicyLRP is BaseTest {
    RoyaltyPolicyLRP internal testRoyaltyPolicyLRP;

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
    }

    function test_RoyaltyPolicyLRP_constructor_revert_ZeroRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLRP__ZeroRoyaltyModule.selector);
        new RoyaltyPolicyLRP(address(0));
    }

    function test_RoyaltyPolicyLRP_initialize_revert_ZeroAccessManager() public {
        address impl = address(new RoyaltyPolicyLRP(address(royaltyModule)));
        vm.expectRevert(Errors.RoyaltyPolicyLRP__ZeroAccessManager.selector);
        RoyaltyPolicyLRP(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(RoyaltyPolicyLRP.initialize, (address(0))))
        );
    }

    function test_RoyaltyPolicyLRP_constructor() public {
        testRoyaltyPolicyLRP = new RoyaltyPolicyLRP(address(royaltyModule));
        assertEq(address(testRoyaltyPolicyLRP.ROYALTY_MODULE()), address(royaltyModule));
    }

    function test_RoyaltyPolicyLRP_onLicenseMinting_revert_NotRoyaltyModule() public {
        vm.startPrank(address(1));
        vm.expectRevert(Errors.RoyaltyPolicyLRP__NotRoyaltyModule.selector);
        royaltyPolicyLRP.onLicenseMinting(address(80), uint32(10 * 10 ** 6), "");
    }

    function test_RoyaltyPolicyLRP_onLinkToParents() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(10 * 10 ** 6);
        parentRoyalties[1] = uint32(15 * 10 ** 6);
        parentRoyalties[2] = uint32(20 * 10 ** 6);
        ipGraph.addParentIp(address(80), parents);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(address(80));

        uint256 ipId10Balance = IERC20(ipRoyaltyVault).balanceOf(royaltyModule.ipRoyaltyVaults(address(10)));
        uint256 ipId20Balance = IERC20(ipRoyaltyVault).balanceOf(royaltyModule.ipRoyaltyVaults(address(20)));
        uint256 ipId30Balance = IERC20(ipRoyaltyVault).balanceOf(royaltyModule.ipRoyaltyVaults(address(30)));
        uint256 ipId80Balance = IERC20(ipRoyaltyVault).balanceOf(address(80));

        assertEq(ipId10Balance, 10 * 10 ** 6);
        assertEq(ipId20Balance, 15 * 10 ** 6);
        assertEq(ipId30Balance, 20 * 10 ** 6);
        assertEq(ipId80Balance, 55 * 10 ** 6);
    }
}
