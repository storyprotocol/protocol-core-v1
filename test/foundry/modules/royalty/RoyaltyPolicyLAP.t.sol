// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

import { BaseTest } from "../../utils/BaseTest.t.sol";
import { IAccessManaged } from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

contract TestRoyaltyPolicyLAP is BaseTest {
    RoyaltyPolicyLAP internal testRoyaltyPolicyLAP;

    address[] internal MAX_ANCESTORS_ = new address[](14);
    uint32[] internal MAX_ANCESTORS_ROYALTY_ = new uint32[](14);
    address[] internal parentsIpIds100;

    function setUp() public override {
        super.setUp();

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        _setupMaxUniqueTree();
        vm.stopPrank();
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
        uint32[] memory parentRoyalties = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);

        // 3 is child of 7 and 8
        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties[0] = 7;
        parentRoyalties[1] = 8;

        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(3), parents, encodedLicenseData, "");

        // 4 is child of 9 and 10
        parents[0] = address(9);
        parents[1] = address(10);
        parentRoyalties[0] = 9;
        parentRoyalties[1] = 10;

        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(4), parents, encodedLicenseData, "");

        // 5 is child of 11 and 12
        parents[0] = address(11);
        parents[1] = address(12);
        parentRoyalties[0] = 11;
        parentRoyalties[1] = 12;

        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(5), parents, encodedLicenseData, "");

        // 6 is child of 13 and 14
        parents[0] = address(13);
        parents[1] = address(14);
        parentRoyalties[0] = 13;
        parentRoyalties[1] = 14;

        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(6), parents, encodedLicenseData, "");

        // init 3rd level with children
        // 1 is child of 3 and 4
        parents[0] = address(3);
        parents[1] = address(4);
        parentRoyalties[0] = 3;
        parentRoyalties[1] = 4;

        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(1), parents, encodedLicenseData, "");

        // 2 is child of 5 and 6
        parents[0] = address(5);
        parents[1] = address(6);
        parentRoyalties[0] = 5;
        parentRoyalties[1] = 6;

        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(2), parents, encodedLicenseData, "");

        // ancestors of parent 1
        MAX_ANCESTORS_[0] = address(1);
        MAX_ANCESTORS_[1] = address(3);
        MAX_ANCESTORS_[2] = address(7);
        MAX_ANCESTORS_[3] = address(8);
        MAX_ANCESTORS_[4] = address(4);
        MAX_ANCESTORS_[5] = address(9);
        MAX_ANCESTORS_[6] = address(10);
        // ancestors of parent 2
        MAX_ANCESTORS_[7] = address(2);
        MAX_ANCESTORS_[8] = address(5);
        MAX_ANCESTORS_[9] = address(11);
        MAX_ANCESTORS_[10] = address(12);
        MAX_ANCESTORS_[11] = address(6);
        MAX_ANCESTORS_[12] = address(13);
        MAX_ANCESTORS_[13] = address(14);

        MAX_ANCESTORS_ROYALTY_[0] = 1;
        MAX_ANCESTORS_ROYALTY_[1] = 3;
        MAX_ANCESTORS_ROYALTY_[2] = 7;
        MAX_ANCESTORS_ROYALTY_[3] = 8;
        MAX_ANCESTORS_ROYALTY_[4] = 4;
        MAX_ANCESTORS_ROYALTY_[5] = 9;
        MAX_ANCESTORS_ROYALTY_[6] = 10;
        MAX_ANCESTORS_ROYALTY_[7] = 2;
        MAX_ANCESTORS_ROYALTY_[8] = 5;
        MAX_ANCESTORS_ROYALTY_[9] = 11;
        MAX_ANCESTORS_ROYALTY_[10] = 12;
        MAX_ANCESTORS_ROYALTY_[11] = 6;
        MAX_ANCESTORS_ROYALTY_[12] = 13;
        MAX_ANCESTORS_ROYALTY_[13] = 14;

        parentsIpIds100 = new address[](2);
        parentsIpIds100[0] = address(1);
        parentsIpIds100[1] = address(2);
    }

    function test_RoyaltyPolicyLAP_setSnapshotInterval_revert_NotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        royaltyPolicyLAP.setSnapshotInterval(100);
    }

    function test_RoyaltyPolicyLAP_setSnapshotInterval() public {
        vm.startPrank(u.admin);
        royaltyPolicyLAP.setSnapshotInterval(100);
        assertEq(royaltyPolicyLAP.getSnapshotInterval(), 100);
    }

    function test_RoyaltyPolicyLAP_setIpRoyaltyVaultBeacon_revert_NotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        royaltyPolicyLAP.setIpRoyaltyVaultBeacon(address(1));
    }

    function testRoyaltyPolicyLAP_setIpRoyaltyVaultBeacon_revert_ZeroIpRoyaltyVaultBeacon() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroIpRoyaltyVaultBeacon.selector);
        royaltyPolicyLAP.setIpRoyaltyVaultBeacon(address(0));
    }

    function test_RoyaltyPolicyLAP_setIpRoyaltyVaultBeacon() public {
        vm.startPrank(u.admin);
        royaltyPolicyLAP.setIpRoyaltyVaultBeacon(address(1));
        assertEq(royaltyPolicyLAP.getIpRoyaltyVaultBeacon(), address(1));
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_NotRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLicenseMinting(address(1), abi.encode(uint32(0)), abi.encode(uint32(0)));
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_AboveRoyaltyStackLimit() public {
        uint256 excessPercent = royaltyPolicyLAP.TOTAL_RT_SUPPLY() + 1;
        vm.prank(address(royaltyModule));
        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(excessPercent), "");
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_LastPositionNotAbleToMintLicense() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }
        vm.startPrank(address(royaltyModule));
        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, "");

        vm.expectRevert(Errors.RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), "");
        vm.stopPrank();
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting() public {
        vm.prank(address(royaltyModule));
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), "");

        (
            ,
            address ipRoyaltyVault,
            uint32 royaltyStack,
            address[] memory ancestors,
            uint32[] memory ancestorsRoyalties
        ) = royaltyPolicyLAP.getRoyaltyData(address(100));

        assertEq(royaltyStack, 0);
        assertEq(ancestors.length, 0);
        assertEq(ancestorsRoyalties.length, 0);
        assertFalse(ipRoyaltyVault == address(0));
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_NotRoyaltyModule() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_AboveParentLimit() public {
        bytes[] memory encodedLicenseData = new bytes[](3);
        for (uint32 i = 0; i < 3; i++) {
            encodedLicenseData[i] = abi.encode(1);
        }

        address[] memory excessParents = new address[](3);
        excessParents[0] = address(1);
        excessParents[1] = address(2);
        excessParents[2] = address(3);

        vm.prank(address(royaltyModule));
        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveParentLimit.selector);
        royaltyPolicyLAP.onLinkToParents(address(100), excessParents, encodedLicenseData, "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }
        vm.prank(address(royaltyModule));
        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, "");

        (
            ,
            address ipRoyaltyVault,
            uint32 royaltyStack,
            address[] memory ancestors,
            uint32[] memory ancestorsRoyalties
        ) = royaltyPolicyLAP.getRoyaltyData(address(100));

        assertEq(royaltyStack, 105);
        for (uint32 i = 0; i < ancestorsRoyalties.length; i++) {
            assertEq(ancestorsRoyalties[i], MAX_ANCESTORS_ROYALTY_[i]);
        }
        assertEq(ancestors, MAX_ANCESTORS_);
        assertFalse(ipRoyaltyVault == address(0));
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment_NotRoyaltyModule() public {
        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onRoyaltyPayment(address(1), address(1), address(1), 0);
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment() public {
        (, address ipRoyaltyVault2, , , ) = royaltyPolicyLAP.getRoyaltyData(address(2));
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(address(1), royaltyAmount);
        vm.stopPrank();

        vm.startPrank(address(1));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));

        uint256 ipRoyaltyVault2USDCBalBefore = USDC.balanceOf(ipRoyaltyVault2);
        uint256 splitMainUSDCBalBefore = USDC.balanceOf(address(1));

        royaltyPolicyLAP.onRoyaltyPayment(address(1), address(2), address(USDC), royaltyAmount);

        uint256 ipRoyaltyVault2USDCBalAfter = USDC.balanceOf(ipRoyaltyVault2);
        uint256 splitMainUSDCBalAfter = USDC.balanceOf(address(1));

        assertEq(ipRoyaltyVault2USDCBalAfter - ipRoyaltyVault2USDCBalBefore, royaltyAmount);
        assertEq(splitMainUSDCBalBefore - splitMainUSDCBalAfter, royaltyAmount);
    }
}
