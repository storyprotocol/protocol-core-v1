// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// contracts
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { RoyaltyModule } from "../../../../contracts/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";

// tests
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TestRoyaltyModule is BaseTest {
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);
    event RoyaltyPolicySet(address ipId, address royaltyPolicy, bytes data);
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);
    event LicenseMintingFeePaid(address receiverIpId, address payerAddress, address token, uint256 amount);

    address internal ipAccount1 = address(0x111000aaa);
    address internal ipAccount2 = address(0x111000bbb);
    struct InitParams {
        address[] targetAncestors;
        uint32[] targetRoyaltyAmount;
        address[] parentAncestors1;
        address[] parentAncestors2;
        uint32[] parentAncestorsRoyalties1;
        uint32[] parentAncestorsRoyalties2;
    }

    InitParams internal initParamsMax;
    bytes internal MAX_ANCESTORS;
    address[] internal MAX_ANCESTORS_ = new address[](14);
    uint32[] internal MAX_ANCESTORS_ROYALTY_ = new uint32[](14);
    address[] internal parentsIpIds100;

    RoyaltyPolicyLAP internal royaltyPolicyLAP2;

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({ disputeModule: false, royaltyModule: true, licensingModule: false })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ arbitrationPolicySP: false, royaltyPolicyLAP: true }));
        deployConditionally();
        postDeploymentSetup();

        USDC.mint(ipAccount2, 1000 * 10 ** 6); // 1000 USDC

        royaltyPolicyLAP2 = new RoyaltyPolicyLAP(
            getRoyaltyModule(),
            getLicensingModule(),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN,
            getGovernance()
        );

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);

        // whitelist royalty token
        royaltyModule.whitelistRoyaltyToken(address(USDC), true);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        // split made to avoid stack too deep error
        _setupTree();
        vm.stopPrank();
    }

    function _setupTree() internal {
        // init royalty policy for roots
        address[] memory nullTargetAncestors = new address[](0);
        uint32[] memory nullTargetRoyaltyAmount = new uint32[](0);
        uint32[] memory parentRoyalties = new uint32[](0);
        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory nullInitParams = InitParams({
            targetAncestors: nullTargetAncestors,
            targetRoyaltyAmount: nullTargetRoyaltyAmount,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        bytes memory nullBytes = abi.encode(nullInitParams);

        royaltyModule.onLicenseMinting(address(7), address(royaltyPolicyLAP), abi.encode(uint32(7)), nullBytes);
        royaltyModule.onLicenseMinting(address(8), address(royaltyPolicyLAP), abi.encode(uint32(8)), nullBytes);

        // init 2nd level with children
        address[] memory parents = new address[](2);
        address[] memory targetAncestors1 = new address[](2);
        uint32[] memory targetRoyaltyAmount1 = new uint32[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);

        // 3 is child of 7 and 8
        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7;
        parentRoyalties1[1] = 8;
        targetAncestors1[0] = address(7);
        targetAncestors1[1] = address(8);
        targetRoyaltyAmount1[0] = 7;
        targetRoyaltyAmount1[1] = 8;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        bytes memory encodedBytes = abi.encode(initParams);
        royaltyModule.onLinkToParents(address(3), address(royaltyPolicyLAP), parents, encodedLicenseData, encodedBytes);
    }

    function test_RoyaltyModule_setLicensingModule_revert_ZeroLicensingModule() public {
        RoyaltyModule testRoyaltyModule = new RoyaltyModule(address(governance));
        vm.expectRevert(Errors.RoyaltyModule__ZeroLicensingModule.selector);
        vm.prank(u.admin);
        testRoyaltyModule.setLicensingModule(address(0));
    }

    function test_RoyaltyModule_setLicensingModule() public {
        vm.startPrank(u.admin);
        RoyaltyModule testRoyaltyModule = new RoyaltyModule(address(governance));
        testRoyaltyModule.setLicensingModule(address(licensingModule));

        assertEq(testRoyaltyModule.LICENSING_MODULE(), address(licensingModule));
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy_revert_ZeroRoyaltyToken() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyToken.selector);

        royaltyModule.whitelistRoyaltyToken(address(0), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy() public {
        vm.startPrank(u.admin);
        assertEq(royaltyModule.isWhitelistedRoyaltyPolicy(address(1)), false);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPolicyWhitelistUpdated(address(1), true);

        royaltyModule.whitelistRoyaltyPolicy(address(1), true);

        assertEq(royaltyModule.isWhitelistedRoyaltyPolicy(address(1)), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyToken_revert_ZeroRoyaltyPolicy() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyPolicy.selector);

        royaltyModule.whitelistRoyaltyPolicy(address(0), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyToken() public {
        vm.startPrank(u.admin);
        assertEq(royaltyModule.isWhitelistedRoyaltyToken(address(1)), false);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyTokenWhitelistUpdated(address(1), true);

        royaltyModule.whitelistRoyaltyToken(address(1), true);

        assertEq(royaltyModule.isWhitelistedRoyaltyToken(address(1)), true);
    }

    function test_RoyaltyModule_onLicenseMinting_revert_NotWhitelistedRoyaltyPolicy() public {
        address licensor = address(1);
        bytes memory licenseData = abi.encode(uint32(15));

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.onLicenseMinting(licensor, address(1), licenseData, "");
    }

    function test_RoyaltyModule_onLicenseMinting_revert_CanOnlyMintSelectedPolicy() public {
        address licensor = address(3);
        bytes memory licenseData = abi.encode(uint32(15));

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(1), true);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__CanOnlyMintSelectedPolicy.selector);
        royaltyModule.onLicenseMinting(licensor, address(1), licenseData, "");
    }

    function test_RoyaltyModule_onLicenseMinting_Derivative() public {
        address licensor = address(3);
        bytes memory licenseData = abi.encode(uint32(15));

        address[] memory parents = new address[](2);
        address[] memory targetAncestors1 = new address[](2);
        uint32[] memory targetRoyaltyAmount1 = new uint32[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);

        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);

        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7;
        parentRoyalties1[1] = 8;
        targetAncestors1[0] = address(7);
        targetAncestors1[1] = address(8);
        targetRoyaltyAmount1[0] = 7;
        targetRoyaltyAmount1[1] = 8;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        bytes memory encodedBytes = abi.encode(initParams);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licenseData, encodedBytes);
    }

    function test_RoyaltyModule_onLicenseMinting_Root() public {
        address licensor = address(7);
        bytes memory licenseData = abi.encode(uint32(15));

        // mint a license of another policy
        address[] memory nullTargetAncestors = new address[](0);
        uint32[] memory nullTargetRoyaltyAmount = new uint32[](0);
        uint32[] memory parentRoyalties = new uint32[](0);
        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory nullInitParams = InitParams({
            targetAncestors: nullTargetAncestors,
            targetRoyaltyAmount: nullTargetRoyaltyAmount,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        bytes memory nullBytes = abi.encode(nullInitParams);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licenseData, nullBytes);
        vm.stopPrank();

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP2), true);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP2), licenseData, nullBytes);
    }

    function test_RoyaltyModule_onLinkToParents_revert_NotWhitelistedRoyaltyPolicy() public {
        address newChild = address(9);
        address[] memory parents = new address[](2);
        address[] memory targetAncestors1 = new address[](2);
        uint32[] memory targetRoyaltyAmount1 = new uint32[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);
        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);

        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7;
        parentRoyalties1[1] = 8;
        targetAncestors1[0] = address(7);
        targetAncestors1[1] = address(8);
        targetRoyaltyAmount1[0] = 7;
        targetRoyaltyAmount1[1] = 8;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        bytes memory encodedBytes = abi.encode(initParams);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.onLinkToParents(newChild, address(1), parents, encodedLicenseData, encodedBytes);
    }

    function test_RoyaltyModule_onLinkToParents_revert_NoParentsOnLinking() public {
        address newChild = address(9);
        address[] memory parents = new address[](0);
        address[] memory targetAncestors1 = new address[](2);
        uint32[] memory targetRoyaltyAmount1 = new uint32[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);
        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);

        parentRoyalties1[0] = 7;
        parentRoyalties1[1] = 8;
        targetAncestors1[0] = address(7);
        targetAncestors1[1] = address(8);
        targetRoyaltyAmount1[0] = 7;
        targetRoyaltyAmount1[1] = 8;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        bytes memory encodedBytes = abi.encode(initParams);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NoParentsOnLinking.selector);
        royaltyModule.onLinkToParents(newChild, address(royaltyPolicyLAP), parents, encodedLicenseData, encodedBytes);
    }

    function test_RoyaltyModule_onLinkToParents_revert_IncompatibleRoyaltyPolicy() public {
        address newChild = address(9);
        address[] memory parents = new address[](2);
        address[] memory targetAncestors1 = new address[](3);
        uint32[] memory targetRoyaltyAmount1 = new uint32[](3);
        uint32[] memory parentRoyalties1 = new uint32[](1);
        bytes[] memory encodedLicenseData = new bytes[](2);
        address[] memory ParentAncestors1 = new address[](2);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory ParentAncestorsRoyalties1 = new uint32[](2);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);

        parents[0] = address(3);
        parentRoyalties1[0] = 3;
        targetAncestors1[0] = address(3);
        targetAncestors1[1] = address(7);
        targetAncestors1[2] = address(8);
        targetRoyaltyAmount1[0] = 3;
        targetRoyaltyAmount1[1] = 7;
        targetRoyaltyAmount1[2] = 8;
        ParentAncestors1[0] = address(7);
        ParentAncestors1[1] = address(8);
        ParentAncestorsRoyalties1[0] = 7;
        ParentAncestorsRoyalties1[1] = 8;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentAncestors1: ParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: ParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        bytes memory encodedBytes = abi.encode(initParams);

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP2), true);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__IncompatibleRoyaltyPolicy.selector);
        royaltyModule.onLinkToParents(newChild, address(royaltyPolicyLAP2), parents, encodedLicenseData, encodedBytes);
    }

    function test_RoyaltyModule_onLinkToParents() public {
        address newChild = address(9);

        // new child is linked to 7 and 8
        address[] memory parents = new address[](2);
        address[] memory targetAncestors1 = new address[](2);
        uint32[] memory targetRoyaltyAmount1 = new uint32[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);
        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);

        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7;
        parentRoyalties1[1] = 8;
        targetAncestors1[0] = address(7);
        targetAncestors1[1] = address(8);
        targetRoyaltyAmount1[0] = 7;
        targetRoyaltyAmount1[1] = 8;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        bytes memory encodedBytes = abi.encode(initParams);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(newChild, address(royaltyPolicyLAP), parents, encodedLicenseData, encodedBytes);

        assertEq(royaltyModule.royaltyPolicies(newChild), address(royaltyPolicyLAP));
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NoRoyaltyPolicySet() public {
        vm.expectRevert(Errors.RoyaltyModule__NoRoyaltyPolicySet.selector);

        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, address(USDC), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyToken() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(7);
        address payerIpId = address(3);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyToken.selector);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(1), royaltyAmount);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyPolicy() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(7);
        address payerIpId = address(3);

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), false);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(7);
        address payerIpId = address(3);

        (, address splitClone, , , ) = royaltyPolicyLAP.royaltyData(receiverIpId);

        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);

        uint256 payerIpIdUSDCBalBefore = USDC.balanceOf(payerIpId);
        uint256 splitCloneUSDCBalBefore = USDC.balanceOf(splitClone);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPaid(receiverIpId, payerIpId, payerIpId, address(USDC), royaltyAmount);

        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);

        uint256 payerIpIdUSDCBalAfter = USDC.balanceOf(payerIpId);
        uint256 splitCloneUSDCBalAfter = USDC.balanceOf(splitClone);

        assertEq(payerIpIdUSDCBalBefore - payerIpIdUSDCBalAfter, royaltyAmount);
        assertEq(splitCloneUSDCBalAfter - splitCloneUSDCBalBefore, royaltyAmount);
    }

    function test_RoyaltyModule_payLicenseMintingFee() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(7);
        address payerAddress = address(3);
        address licenseRoyaltyPolicy = address(royaltyPolicyLAP);
        address token = address(USDC);

        (, address splitClone, , , ) = royaltyPolicyLAP.royaltyData(receiverIpId);

        vm.startPrank(payerAddress);
        USDC.mint(payerAddress, royaltyAmount);
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        vm.stopPrank;

        uint256 payerAddressUSDCBalBefore = USDC.balanceOf(payerAddress);
        uint256 splitCloneUSDCBalBefore = USDC.balanceOf(splitClone);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LicenseMintingFeePaid(receiverIpId, payerAddress, address(USDC), royaltyAmount);

        vm.startPrank(address(licensingModule));
        royaltyModule.payLicenseMintingFee(receiverIpId, payerAddress, licenseRoyaltyPolicy, token, royaltyAmount);

        uint256 payerAddressUSDCBalAfter = USDC.balanceOf(payerAddress);
        uint256 splitCloneUSDCBalAfter = USDC.balanceOf(splitClone);

        assertEq(payerAddressUSDCBalBefore - payerAddressUSDCBalAfter, royaltyAmount);
        assertEq(splitCloneUSDCBalAfter - splitCloneUSDCBalBefore, royaltyAmount);
    }
}
