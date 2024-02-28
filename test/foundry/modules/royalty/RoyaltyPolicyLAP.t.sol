// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { ILiquidSplitMain } from "../../../../contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TestRoyaltyPolicyLAP is BaseTest {
    event PolicyInitialized(
        address ipId,
        address splitClone,
        address claimer,
        uint32 royaltyStack,
        address[] targetAncestors,
        uint32[] targetRoyaltyAmount
    );

    struct InitParams {
        address[] targetAncestors;
        uint32[] targetRoyaltyAmount;
        address[] parentAncestors1;
        address[] parentAncestors2;
        uint32[] parentAncestorsRoyalties1;
        uint32[] parentAncestorsRoyalties2;
    }

    RoyaltyPolicyLAP internal testRoyaltyPolicyLAP;

    InitParams internal initParamsMax;
    bytes internal MAX_ANCESTORS;
    address[] internal MAX_ANCESTORS_ = new address[](14);
    uint32[] internal MAX_ANCESTORS_ROYALTY_ = new uint32[](14);
    address[] internal parentsIpIds100;

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({
                registrationModule: false,
                disputeModule: false,
                royaltyModule: true,
                licensingModule: false
            })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ arbitrationPolicySP: false, royaltyPolicyLAP: true }));
        deployConditionally();
        postDeploymentSetup();

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        _setupMaxUniqueTree();
        //_setupDuplicatesTree();
    }

    function _setupMaxUniqueTree() internal {
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
        royaltyPolicyLAP.onLicenseMinting(address(7), abi.encode(uint32(7)), nullBytes);
        royaltyPolicyLAP.onLicenseMinting(address(8), abi.encode(uint32(8)), nullBytes);
        royaltyPolicyLAP.onLicenseMinting(address(9), abi.encode(uint32(9)), nullBytes);
        royaltyPolicyLAP.onLicenseMinting(address(10), abi.encode(uint32(10)), nullBytes);
        royaltyPolicyLAP.onLicenseMinting(address(11), abi.encode(uint32(11)), nullBytes);
        royaltyPolicyLAP.onLicenseMinting(address(12), abi.encode(uint32(12)), nullBytes);
        royaltyPolicyLAP.onLicenseMinting(address(13), abi.encode(uint32(13)), nullBytes);
        royaltyPolicyLAP.onLicenseMinting(address(14), abi.encode(uint32(14)), nullBytes);

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
        royaltyPolicyLAP.onLinkToParents(address(3), parents, encodedLicenseData, encodedBytes);

        // 4 is child of 9 and 10
        parents[0] = address(9);
        parents[1] = address(10);
        parentRoyalties1[0] = 9;
        parentRoyalties1[1] = 10;
        targetAncestors1[0] = address(9);
        targetAncestors1[1] = address(10);
        targetRoyaltyAmount1[0] = 9;
        targetRoyaltyAmount1[1] = 10;
        initParams = InitParams({
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
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.onLinkToParents(address(4), parents, encodedLicenseData, encodedBytes);

        // 5 is child of 11 and 12
        parents[0] = address(11);
        parents[1] = address(12);
        parentRoyalties1[0] = 11;
        parentRoyalties1[1] = 12;
        targetAncestors1[0] = address(11);
        targetAncestors1[1] = address(12);
        targetRoyaltyAmount1[0] = 11;
        targetRoyaltyAmount1[1] = 12;
        initParams = InitParams({
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
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.onLinkToParents(address(5), parents, encodedLicenseData, encodedBytes);

        // 6 is child of 13 and 14
        parents[0] = address(13);
        parents[1] = address(14);
        parentRoyalties1[0] = 13;
        parentRoyalties1[1] = 14;
        targetAncestors1[0] = address(13);
        targetAncestors1[1] = address(14);
        targetRoyaltyAmount1[0] = 13;
        targetRoyaltyAmount1[1] = 14;
        initParams = InitParams({
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
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.onLinkToParents(address(6), parents, encodedLicenseData, encodedBytes);

        // init 3rd level with children
        address[] memory targetAncestors2 = new address[](6);
        uint32[] memory targetRoyaltyAmount2 = new uint32[](6);
        address[] memory parentAncestors1 = new address[](2);
        address[] memory parentAncestors2 = new address[](2);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](2);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](2);

        // 1 is child of 3 and 4
        parents[0] = address(3);
        parents[1] = address(4);
        parentRoyalties1[0] = 3;
        parentRoyalties1[1] = 4;
        parentAncestors1[0] = address(7);
        parentAncestors1[1] = address(8);
        parentAncestors2[0] = address(9);
        parentAncestors2[1] = address(10);
        parentAncestorsRoyalties1[0] = 7;
        parentAncestorsRoyalties1[1] = 8;
        parentAncestorsRoyalties2[0] = 9;
        parentAncestorsRoyalties2[1] = 10;
        targetAncestors2[0] = address(3);
        targetAncestors2[1] = address(7);
        targetAncestors2[2] = address(8);
        targetAncestors2[3] = address(4);
        targetAncestors2[4] = address(9);
        targetAncestors2[5] = address(10);
        targetRoyaltyAmount2[0] = 3;
        targetRoyaltyAmount2[1] = 7;
        targetRoyaltyAmount2[2] = 8;
        targetRoyaltyAmount2[3] = 4;
        targetRoyaltyAmount2[4] = 9;
        targetRoyaltyAmount2[5] = 10;
        initParams = InitParams({
            targetAncestors: targetAncestors2,
            targetRoyaltyAmount: targetRoyaltyAmount2,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.onLinkToParents(address(1), parents, encodedLicenseData, encodedBytes);

        // 2 is child of 5 and 6
        parents[0] = address(5);
        parents[1] = address(6);
        parentRoyalties1[0] = 5;
        parentRoyalties1[1] = 6;
        parentAncestors1[0] = address(11);
        parentAncestors1[1] = address(12);
        parentAncestors2[0] = address(13);
        parentAncestors2[1] = address(14);
        parentAncestorsRoyalties1[0] = 11;
        parentAncestorsRoyalties1[1] = 12;
        parentAncestorsRoyalties2[0] = 13;
        parentAncestorsRoyalties2[1] = 14;
        targetAncestors2[0] = address(5);
        targetAncestors2[1] = address(11);
        targetAncestors2[2] = address(12);
        targetAncestors2[3] = address(6);
        targetAncestors2[4] = address(13);
        targetAncestors2[5] = address(14);
        targetRoyaltyAmount2[0] = 5;
        targetRoyaltyAmount2[1] = 11;
        targetRoyaltyAmount2[2] = 12;
        targetRoyaltyAmount2[3] = 6;
        targetRoyaltyAmount2[4] = 13;
        targetRoyaltyAmount2[5] = 14;
        initParams = InitParams({
            targetAncestors: targetAncestors2,
            targetRoyaltyAmount: targetRoyaltyAmount2,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.onLinkToParents(address(2), parents, encodedLicenseData, encodedBytes);

        address[] memory parentAncestors3 = new address[](6);
        address[] memory parentAncestors4 = new address[](6);
        uint32[] memory parentAncestorsRoyalties3 = new uint32[](6);
        uint32[] memory parentAncestorsRoyalties4 = new uint32[](6);
        uint32[] memory parentRoyalties3 = new uint32[](2);

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

        parentAncestors3[0] = address(3);
        parentAncestors3[1] = address(7);
        parentAncestors3[2] = address(8);
        parentAncestors3[3] = address(4);
        parentAncestors3[4] = address(9);
        parentAncestors3[5] = address(10);
        parentAncestorsRoyalties3[0] = 3;
        parentAncestorsRoyalties3[1] = 7;
        parentAncestorsRoyalties3[2] = 8;
        parentAncestorsRoyalties3[3] = 4;
        parentAncestorsRoyalties3[4] = 9;
        parentAncestorsRoyalties3[5] = 10;

        parentAncestors4[0] = address(5);
        parentAncestors4[1] = address(11);
        parentAncestors4[2] = address(12);
        parentAncestors4[3] = address(6);
        parentAncestors4[4] = address(13);
        parentAncestors4[5] = address(14);
        parentAncestorsRoyalties4[0] = 5;
        parentAncestorsRoyalties4[1] = 11;
        parentAncestorsRoyalties4[2] = 12;
        parentAncestorsRoyalties4[3] = 6;
        parentAncestorsRoyalties4[4] = 13;
        parentAncestorsRoyalties4[5] = 14;

        parentRoyalties3[0] = 1;
        parentRoyalties3[1] = 2;

        initParamsMax = InitParams({
            targetAncestors: MAX_ANCESTORS_,
            targetRoyaltyAmount: MAX_ANCESTORS_ROYALTY_,
            parentAncestors1: parentAncestors3,
            parentAncestors2: parentAncestors4,
            parentAncestorsRoyalties1: parentAncestorsRoyalties3,
            parentAncestorsRoyalties2: parentAncestorsRoyalties4
        });

        MAX_ANCESTORS = abi.encode(initParamsMax);

        parentsIpIds100 = new address[](2);
        parentsIpIds100[0] = address(1);
        parentsIpIds100[1] = address(2);
    }

    function test_RoyaltyPolicyLAP_setAncestorsVaultImplementation_ZeroAncestorsVaultImpl() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroAncestorsVaultImpl.selector);
        royaltyPolicyLAP.setAncestorsVaultImplementation(address(0));
    }

    function test_RoyaltyPolicyLAP_setAncestorsVaultImplementation_ImplementationAlreadySet() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ImplementationAlreadySet.selector);
        royaltyPolicyLAP.setAncestorsVaultImplementation(address(2));
    }

    function test_RoyaltyPolicyLAP_setAncestorsVaultImplementation() public {
        RoyaltyPolicyLAP royaltyPolicyLAP2 = new RoyaltyPolicyLAP(
            address(1),
            address(2),
            address(3),
            address(4),
            address(governance)
        );

        vm.startPrank(u.admin);
        royaltyPolicyLAP2.setAncestorsVaultImplementation(address(2));

        assertEq(royaltyPolicyLAP2.ANCESTORS_VAULT_IMPL(), address(2));
    }

    function test_RoyaltyPolicyLAP_initPolicy_AboveAncestorsLimit() public {
        address[] memory targetAncestors = new address[](15);
        uint32[] memory targetRoyaltyAmount = new uint32[](0);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveAncestorsLimit.selector);
        royaltyPolicyLAP.onLicenseMinting(address(30), abi.encode(uint32(0)), inputBytes);
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_NotRoyaltyModule() public {
        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLicenseMinting(address(1), abi.encode(uint32(0)), abi.encode(uint32(0)));
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_AboveRoyaltyStackLimit() public {
        address[] memory targetAncestors = new address[](0);
        uint32[] memory targetRoyaltyAmount = new uint32[](0);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(1001)), inputBytes);
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_InvalidAncestors() public {
        address[] memory targetAncestors = new address[](0);
        uint32[] memory targetRoyaltyAmount = new uint32[](0);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), inputBytes);

        address[] memory targetAncestors2 = new address[](2);
        initParams = InitParams({
            targetAncestors: targetAncestors2,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        inputBytes = abi.encode(initParams);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__InvalidAncestorsHash.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), inputBytes);
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_LastPositionNotAbleToMintLicense() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, MAX_ANCESTORS);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), MAX_ANCESTORS);
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting() public {
        address[] memory targetAncestors = new address[](0);
        uint32[] memory targetRoyaltyAmount = new uint32[](0);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), inputBytes);

        (, address splitClone, address ancestorsVault, uint32 royaltyStack, bytes32 ancestorsHash) = royaltyPolicyLAP
            .royaltyData(address(100));

        assertEq(royaltyStack, 0);
        assertEq(ancestorsHash, keccak256(abi.encodePacked(targetAncestors, targetRoyaltyAmount)));
        assertFalse(splitClone == address(0));
        assertEq(ancestorsVault, address(0));
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_NotRoyaltyModule() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, MAX_ANCESTORS);
    }

    function test_RoyaltyPolicyLAP_onLinkToParents() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, MAX_ANCESTORS);

        (, address splitClone, address ancestorsVault, uint32 royaltyStack, bytes32 ancestorsHash) = royaltyPolicyLAP
            .royaltyData(address(100));

        assertEq(royaltyStack, 105);
        assertEq(ancestorsHash, keccak256(abi.encodePacked(MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_)));
        assertFalse(splitClone == address(0));
        assertFalse(ancestorsVault == address(0));
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment_NotRoyaltyModule() public {
        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onRoyaltyPayment(address(1), address(1), address(1), 0);
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment() public {
        (, address splitClone2, , , ) = royaltyPolicyLAP.royaltyData(address(2));
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(address(1), royaltyAmount);
        vm.stopPrank();

        vm.startPrank(address(1));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));

        uint256 splitClone2USDCBalBefore = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalBefore = USDC.balanceOf(address(1));

        royaltyPolicyLAP.onRoyaltyPayment(address(1), address(2), address(USDC), royaltyAmount);

        uint256 splitClone2USDCBalAfter = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalAfter = USDC.balanceOf(address(1));

        assertEq(splitClone2USDCBalAfter - splitClone2USDCBalBefore, royaltyAmount);
        assertEq(splitMainUSDCBalBefore - splitMainUSDCBalAfter, royaltyAmount);
    }

    function test_RoyaltyPolicyLAP_distributeIpPoolFunds() public {
        (, address splitClone2, address ancestorsVault2, , ) = royaltyPolicyLAP.royaltyData(address(2));

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        accounts[0] = address(2);
        accounts[1] = ancestorsVault2;

        uint256 splitClone2USDCBalBefore = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalBefore = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());

        royaltyPolicyLAP.distributeIpPoolFunds(address(2), address(USDC), accounts, address(0));

        uint256 splitClone2USDCBalAfter = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalAfter = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());

        assertApproxEqRel(splitClone2USDCBalBefore - splitClone2USDCBalAfter, royaltyAmount, 0.0001e18);
        assertApproxEqRel(splitMainUSDCBalAfter - splitMainUSDCBalBefore, royaltyAmount, 0.0001e18);
    }

    function test_RoyaltyPolicyLAP_claimFromIpPool() public {
        (, address splitClone2, address ancestorsVault2, , ) = royaltyPolicyLAP.royaltyData(address(2));

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        accounts[0] = address(2);
        accounts[1] = ancestorsVault2;

        royaltyPolicyLAP.distributeIpPoolFunds(address(2), address(USDC), accounts, address(0));

        uint256 expectedAmountToBeClaimed = ILiquidSplitMain(royaltyPolicyLAP.LIQUID_SPLIT_MAIN()).getERC20Balance(
            address(2),
            USDC
        );

        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = USDC;

        uint256 splitMainUSDCBalBefore = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());
        uint256 address2USDCBalBefore = USDC.balanceOf(address(2));

        royaltyPolicyLAP.claimFromIpPool(address(2), tokens);

        uint256 splitMainUSDCBalAfter = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());
        uint256 address2USDCBalAfter = USDC.balanceOf(address(2));

        assertApproxEqRel(splitMainUSDCBalBefore - splitMainUSDCBalAfter, expectedAmountToBeClaimed, 0.0001e18);
        assertApproxEqRel(address2USDCBalAfter - address2USDCBalBefore, expectedAmountToBeClaimed, 0.0001e18);
    }

    function test_RoyaltyPolicyLAP_claimAsFullRnftOwner() public {
        (, address splitClone7, , , ) = royaltyPolicyLAP.royaltyData(address(7));

        uint256 royaltyAmountUSDC = 100 * 10 ** 6;
        USDC.mint(address(splitClone7), royaltyAmountUSDC);

        vm.startPrank(address(7));
        ERC1155(address(splitClone7)).setApprovalForAll(address(royaltyPolicyLAP), true);

        uint256 usdcClaimerBalBefore = USDC.balanceOf(address(7));
        uint256 rnftClaimerBalBefore = ERC1155(address(splitClone7)).balanceOf(address(7), 0);

        royaltyPolicyLAP.claimFromIpPoolAsTotalRnftOwner(address(7), address(USDC));

        uint256 usdcClaimerBalAfter = USDC.balanceOf(address(7));
        uint256 rnftClaimerBalAfter = ERC1155(address(splitClone7)).balanceOf(address(7), 0);

        assertApproxEqRel(usdcClaimerBalAfter - usdcClaimerBalBefore, royaltyAmountUSDC, 0.0001e18);
        assertEq(rnftClaimerBalAfter, 1000);
        assertEq(rnftClaimerBalBefore, 1000);
    }
}
