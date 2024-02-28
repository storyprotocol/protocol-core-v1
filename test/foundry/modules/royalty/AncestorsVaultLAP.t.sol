// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { AncestorsVaultLAP } from "../../../../contracts/modules/royalty/policies/AncestorsVaultLAP.sol";
import { ILiquidSplitClone } from "../../../../contracts/interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { ILiquidSplitMain } from "../../../../contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TestAncestorsVaultLAP is BaseTest {
    event Claimed(address ipId, address claimerIpId, ERC20[] tokens);

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

    AncestorsVaultLAP internal ancestorsVault100;
    AncestorsVaultLAP internal ancestorsVault1;
    address internal splitClone100;
    address internal ancestorsVaultAddr100;
    address internal ancestorsVaultAddr1;
    uint32 internal royaltyStack100;
    uint256 internal ethAccrued;
    uint256 internal usdcAccrued;
    uint256 internal linkAccrued;
    address internal ipIdToClaim;
    ERC20[] internal tokens = new ERC20[](2);
    uint32 internal expectedRnft7;
    address internal claimerIpId7;
    address internal claimerIpId10;
    address internal splitClone7;

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
        buildDeployMiscCondition(
            DeployMiscCondition({ ipAssetRenderer: false, ipMetadataProvider: false, ipResolver: true })
        );
        deployConditionally();
        postDeploymentSetup();

        vm.startPrank(address(royaltyModule));
        _setupMaxUniqueTree();

        // setup ancestors vault 100 data
        parentsIpIds100 = new address[](2);
        parentsIpIds100[0] = address(1);
        parentsIpIds100[1] = address(2);

        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, MAX_ANCESTORS);
        vm.stopPrank();

        (, splitClone100, ancestorsVaultAddr100, royaltyStack100, ) = royaltyPolicyLAP.royaltyData(address(100));
        ancestorsVault100 = AncestorsVaultLAP(ancestorsVaultAddr100);

        (, , ancestorsVaultAddr1, , ) = royaltyPolicyLAP.royaltyData(address(1));
        ancestorsVault1 = AncestorsVaultLAP(ancestorsVaultAddr1);

        ipIdToClaim = address(100);
        tokens[0] = USDC;
        tokens[1] = LINK;

        expectedRnft7 = 7;
        claimerIpId7 = address(7);
        claimerIpId10 = address(10);

        (, splitClone7, , , ) = royaltyPolicyLAP.royaltyData(claimerIpId7);

        // send tokens to ancestors vault
        ethAccrued = 1 ether;
        usdcAccrued = 1000 * 10 ** 6;
        linkAccrued = 100 * 10 ** 18;
        vm.deal(address(ancestorsVault100), ethAccrued);
        USDC.mint(address(ancestorsVault100), usdcAccrued);

        LINK.mint(address(ancestorsVault100), linkAccrued);
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
    }

    function test_AncestorsVaultLAP_claim_AlreadyClaimed() public {
        ancestorsVault100.claim(ipIdToClaim, claimerIpId7, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);

        vm.expectRevert(Errors.AncestorsVaultLAP__AlreadyClaimed.selector);
        ancestorsVault100.claim(ipIdToClaim, claimerIpId7, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);
    }

    function test_AncestorsVaultLAP_claim_InvalidClaimer() public {
        vm.expectRevert(Errors.AncestorsVaultLAP__InvalidClaimer.selector);
        ancestorsVault1.claim(ipIdToClaim, claimerIpId7, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);
    }

    function test_AncestorsVaultLAP_claim_InvalidAncestorsHash() public {
        address[] memory invalidAncestors = new address[](14);
        vm.expectRevert(Errors.AncestorsVaultLAP__InvalidAncestorsHash.selector);
        ancestorsVault100.claim(ipIdToClaim, claimerIpId7, invalidAncestors, MAX_ANCESTORS_ROYALTY_, tokens);

        uint32[] memory invalidAncestorsRoyalty = new uint32[](14);
        vm.expectRevert(Errors.AncestorsVaultLAP__InvalidAncestorsHash.selector);
        ancestorsVault100.claim(ipIdToClaim, claimerIpId7, MAX_ANCESTORS_, invalidAncestorsRoyalty, tokens);
    }

    function test_AncestorsVaultLAP_claim_ClaimerNotAnAncestor() public {
        address notAnAncestor = address(50);
        vm.expectRevert(Errors.AncestorsVaultLAP__ClaimerNotAnAncestor.selector);
        ancestorsVault100.claim(ipIdToClaim, notAnAncestor, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);
    }

    function test_AncestorsVaultLAP_claim_ERC20BalanceNotZero() public {
        USDC.mint(address(splitClone100), 1000 * 10 ** 6);

        address[] memory ancestors = new address[](2);
        ancestors[0] = address(100);
        ancestors[1] = address(ancestorsVault100);

        ILiquidSplitClone(splitClone100).distributeFunds(address(USDC), ancestors, address(0));

        ERC20 token_ = USDC;
        // value of 0 is stored as 1 in 0xSplits (for cheaper, warm storage)
        assertGt(
            ILiquidSplitMain(royaltyPolicyLAP.LIQUID_SPLIT_MAIN()).getERC20Balance(address(ancestorsVault100), token_),
            1
        );

        vm.expectRevert(Errors.AncestorsVaultLAP__ERC20BalanceNotZero.selector);
        ancestorsVault100.claim(ipIdToClaim, claimerIpId7, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);
    }

    function test_AncestorsVaultLAP_claim() public {
        // address 7 as the root will claim from address 100
        uint256 rnftBalBefore = ILiquidSplitClone(splitClone100).balanceOf(address(7), 0);
        uint256 ancestorsVaultUSDCBalBefore = USDC.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultUSDCBalBefore = USDC.balanceOf(address(7));
        uint256 ancestorsVaultLinkBalBefore = LINK.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultLinkBalBefore = LINK.balanceOf(address(7));

        vm.expectEmit(true, true, true, true, address(ancestorsVault100));
        emit Claimed(ipIdToClaim, claimerIpId7, tokens);

        ancestorsVault100.claim(ipIdToClaim, claimerIpId7, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);

        uint256 rnftBalAfter = ILiquidSplitClone(splitClone100).balanceOf(address(7), 0);
        uint256 ancestorsVaultUSDCBalAfter = USDC.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultUSDCBalAfter = USDC.balanceOf(address(7));
        uint256 ancestorsVaultLinkBalAfter = LINK.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultLinkBalAfter = LINK.balanceOf(address(7));

        assertEq(ancestorsVault100.isClaimed(ipIdToClaim, claimerIpId7), true);
        assertEq(rnftBalAfter - rnftBalBefore, expectedRnft7);
        assertEq(
            ancestorsVaultUSDCBalBefore - ancestorsVaultUSDCBalAfter,
            (usdcAccrued * expectedRnft7) / (royaltyStack100)
        );
        assertEq(
            claimerVaultUSDCBalAfter - claimerVaultUSDCBalBefore,
            (usdcAccrued * expectedRnft7) / (royaltyStack100)
        );
        assertEq(
            ancestorsVaultLinkBalBefore - ancestorsVaultLinkBalAfter,
            (linkAccrued * expectedRnft7) / (royaltyStack100)
        );
        assertEq(
            claimerVaultLinkBalAfter - claimerVaultLinkBalBefore,
            (linkAccrued * expectedRnft7) / (royaltyStack100)
        );
    }

    function test_AncestorsVaultLAP_claim_MultipleClaims() public {
        ancestorsVault100.claim(ipIdToClaim, claimerIpId10, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);

        // address 7 as the root will claim from address 100
        uint256 rnftBalBefore = ILiquidSplitClone(splitClone100).balanceOf(address(7), 0);
        uint256 ancestorsVaultUSDCBalBefore = USDC.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultUSDCBalBefore = USDC.balanceOf(address(7));
        uint256 ancestorsVaultLinkBalBefore = LINK.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultLinkBalBefore = LINK.balanceOf(address(7));

        vm.expectEmit(true, true, true, true, address(ancestorsVault100));
        emit Claimed(ipIdToClaim, claimerIpId7, tokens);

        ancestorsVault100.claim(ipIdToClaim, claimerIpId7, MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_, tokens);

        uint256 rnftBalAfter = ILiquidSplitClone(splitClone100).balanceOf(address(7), 0);
        uint256 ancestorsVaultUSDCBalAfter = USDC.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultUSDCBalAfter = USDC.balanceOf(address(7));
        uint256 ancestorsVaultLinkBalAfter = LINK.balanceOf(address(ancestorsVault100));
        uint256 claimerVaultLinkBalAfter = LINK.balanceOf(address(7));

        assertEq(ancestorsVault100.isClaimed(ipIdToClaim, claimerIpId7), true);
        assertEq(rnftBalAfter - rnftBalBefore, expectedRnft7);
        assertEq(
            ancestorsVaultUSDCBalBefore - ancestorsVaultUSDCBalAfter,
            (usdcAccrued * expectedRnft7) / (royaltyStack100)
        );
        assertEq(
            claimerVaultUSDCBalAfter - claimerVaultUSDCBalBefore,
            (usdcAccrued * expectedRnft7) / (royaltyStack100)
        );
        assertEq(
            ancestorsVaultLinkBalBefore - ancestorsVaultLinkBalAfter,
            (linkAccrued * expectedRnft7) / (royaltyStack100)
        );
        assertEq(
            claimerVaultLinkBalAfter - claimerVaultLinkBalBefore,
            (linkAccrued * expectedRnft7) / (royaltyStack100)
        );
    }
}
