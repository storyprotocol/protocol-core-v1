// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
// contracts
import { Errors } from "contracts/lib/Errors.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IDisputeModule } from "contracts/interfaces/modules/dispute/IDisputeModule.sol";
// test
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
import { MockArbitrationPolicy } from "test/foundry/mocks/dispute/MockArbitrationPolicy.sol";

contract DisputeModuleTest is BaseTest {
    event TagWhitelistUpdated(bytes32 tag, bool allowed);
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);
    event ArbitrationRelayerWhitelistUpdated(address arbitrationPolicy, address arbitrationRelayer, bool allowed);
    event DisputeRaised(
        uint256 disputeId,
        address targetIpId,
        address disputeInitiator,
        address arbitrationPolicy,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        bytes data
    );
    event DisputeJudgementSet(uint256 disputeId, bool decision, bytes data);
    event DisputeCancelled(uint256 disputeId, bytes data);
    event DisputeResolved(uint256 disputeId);
    event DefaultArbitrationPolicyUpdated(address arbitrationPolicy);
    event ArbitrationPolicySet(address ipId, address arbitrationPolicy);

    address internal ipAccount1 = address(0x111000aaa);
    address internal ipAccount2 = address(0x111000bbb);

    address internal ipAddr;
    address internal ipAddr2;
    address internal arbitrationRelayer;
    MockArbitrationPolicy internal mockArbitrationPolicy2;

    bytes32 internal disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;

    function setUp() public override {
        super.setUp();

        arbitrationRelayer = u.relayer;

        USDC.mint(ipAccount1, 1000 * 10 ** 6);

        // second arbitration policy
        mockArbitrationPolicy2 = new MockArbitrationPolicy(address(disputeModule), address(USDC), ARBITRATION_PRICE);

        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy2), true);
        disputeModule.setBaseArbitrationPolicy(address(mockArbitrationPolicy2));
        vm.stopPrank();

        registerSelectedPILicenseTerms_Commercial({
            selectionName: "cheap_flexible",
            transferable: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 10,
            mintingFee: 0
        });

        mockNFT.mintId(u.alice, 0);
        mockNFT.mintId(u.bob, 1);

        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            address(mockNFT),
            0
        );

        vm.startPrank(u.alice);
        ipAddr = ipAssetRegistry.register(block.chainid, address(mockNFT), 0);
        licensingModule.attachLicenseTerms(ipAddr, address(pilTemplate), getSelectedPILicenseTermsId("cheap_flexible"));

        // Bob mints 1 license of policy "pil-commercial-remix" from IPAccount1 and registers the derivative IP for
        // NFT tokenId 2.
        vm.startPrank(u.bob);

        uint256 mintAmount = 3;
        erc20.approve(address(royaltyModule), type(uint256).max);

        uint256[] memory licenseIds = new uint256[](1);

        licenseIds[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAddr,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: getSelectedPILicenseTermsId("cheap_flexible"),
            amount: mintAmount,
            receiver: u.bob,
            royaltyContext: ""
        }); // first license minted

        ipAddr2 = ipAssetRegistry.register(block.chainid, address(mockNFT), 1);

        licensingModule.registerDerivativeWithLicenseTokens(ipAddr2, licenseIds, "");

        vm.stopPrank();

        // set arbitration policy
        vm.startPrank(ipAddr);
        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy));
        vm.stopPrank();

        // set arbitration policy
        vm.startPrank(ipAddr2);
        disputeModule.setArbitrationPolicy(ipAddr2, address(mockArbitrationPolicy));
        vm.stopPrank();
    }

    function test_DisputeModule_whitelistDisputeTag_revert_ZeroDisputeTag() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__ZeroDisputeTag.selector);
        disputeModule.whitelistDisputeTag(bytes32(0), true);
    }

    function test_DisputeModule_whitelistDisputeTag_revert_NotAllowedToWhitelist() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__NotAllowedToWhitelist.selector);
        disputeModule.whitelistDisputeTag("IN_DISPUTE", true);
    }

    function test_DisputeModule_whitelistDisputeTag() public {
        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit TagWhitelistUpdated(bytes32("INAPPROPRIATE_CONTENT"), true);

        disputeModule.whitelistDisputeTag("INAPPROPRIATE_CONTENT", true);
        assertEq(disputeModule.isWhitelistedDisputeTag("INAPPROPRIATE_CONTENT"), true);
    }

    function test_DisputeModule_whitelistArbitrationPolicy_revert_ZeroArbitrationPolicy() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationPolicy.selector);
        disputeModule.whitelistArbitrationPolicy(address(0), true);
    }

    function test_DisputeModule_whitelistArbitrationPolicy() public {
        vm.startPrank(u.admin);

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationPolicyWhitelistUpdated(address(1), true);

        disputeModule.whitelistArbitrationPolicy(address(1), true);

        assertEq(disputeModule.isWhitelistedArbitrationPolicy(address(1)), true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer_revert_ZeroArbitrationPolicy() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationPolicy.selector);
        disputeModule.whitelistArbitrationRelayer(address(0), arbitrationRelayer, true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer_revert_ZeroArbitrationRelayer() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationRelayer.selector);
        disputeModule.whitelistArbitrationRelayer(address(mockArbitrationPolicy), address(0), true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer() public {
        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationRelayerWhitelistUpdated(address(mockArbitrationPolicy), address(1), true);

        disputeModule.whitelistArbitrationRelayer(address(mockArbitrationPolicy), address(1), true);

        assertEq(disputeModule.isWhitelistedArbitrationRelayer(address(mockArbitrationPolicy), address(1)), true);
    }

    function test_DisputeModule_setBaseArbitrationPolicy_revert_NotWhitelistedArbitrationPolicy() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationPolicy.selector);
        disputeModule.setBaseArbitrationPolicy(address(0));
    }

    function test_DisputeModule_setBaseArbitrationPolicy() public {
        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DefaultArbitrationPolicyUpdated(address(mockArbitrationPolicy2));

        disputeModule.setBaseArbitrationPolicy(address(mockArbitrationPolicy2));

        assertEq(disputeModule.baseArbitrationPolicy(), address(mockArbitrationPolicy2));
    }

    function test_DisputeModule_setArbitrationPolicy_revert_UnauthorizedAccess() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                ipAddr,
                address(this),
                address(disputeModule),
                disputeModule.setArbitrationPolicy.selector
            )
        );
        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));
    }

    function test_DisputeModule_setArbitrationPolicy_revert_NotWhitelistedArbitrationPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy2), false);
        vm.stopPrank();

        vm.startPrank(ipAddr);
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationPolicy.selector);
        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));
    }

    function test_DisputeModule_setArbitrationPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy2), true);
        vm.stopPrank();

        vm.startPrank(ipAddr);

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationPolicySet(ipAddr, address(mockArbitrationPolicy2));

        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));
        assertEq(disputeModule.arbitrationPolicies(ipAddr), address(mockArbitrationPolicy2));
    }

    function test_DisputeModule_raiseDispute_revert_NotRegisteredIpId() public {
        vm.expectRevert(Errors.DisputeModule__NotRegisteredIpId.selector);
        disputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", "");
    }

    function test_DisputeModule_raiseDispute_revert_NotWhitelistedDisputeTag() public {
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedDisputeTag.selector);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "NOT_WHITELISTED", "");
    }

    function test_DisputeModule_raiseDispute_revert_ZeroDisputeEvidenceHash() public {
        vm.expectRevert(Errors.DisputeModule__ZeroDisputeEvidenceHash.selector);
        disputeModule.raiseDispute(ipAddr, bytes32(""), "PLAGIARISM", "");
    }

    function test_DisputeModule_raiseDispute_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.startPrank(u.bob);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();
    }

    function test_DisputeModule_PolicySP_raiseDispute_BlacklistedPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy), false);
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy2), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = IERC20(USDC).balanceOf(address(mockArbitrationPolicy2));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            address(mockArbitrationPolicy2),
            disputeEvidenceHashExample,
            bytes32("PLAGIARISM"),
            ""
        );

        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = IERC20(USDC).balanceOf(address(mockArbitrationPolicy2));

        (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 disputeEvidenceHash,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 parentDisputeId
        ) = disputeModule.disputes(disputeIdAfter);

        assertEq(disputeIdAfter, 1);
        assertEq(disputeIdAfter - disputeIdBefore, 1);
        assertEq(ipAccount1USDCBalanceBefore - ipAccount1USDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(mockArbitrationPolicyUSDCBalanceAfter - mockArbitrationPolicyUSDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(targetIpId, ipAddr);
        assertEq(disputeInitiator, ipAccount1);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy2));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("PLAGIARISM"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
        assertEq(parentDisputeId, 0);
    }

    function test_DisputeModule_raiseDispute() public {
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = USDC.balanceOf(address(mockArbitrationPolicy));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            address(mockArbitrationPolicy),
            disputeEvidenceHashExample,
            bytes32("PLAGIARISM"),
            ""
        );

        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = USDC.balanceOf(address(mockArbitrationPolicy));

        (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 disputeEvidenceHash,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 parentDisputeId
        ) = disputeModule.disputes(disputeIdAfter);

        assertEq(disputeIdAfter - disputeIdBefore, 1);
        assertEq(ipAccount1USDCBalanceBefore - ipAccount1USDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(mockArbitrationPolicyUSDCBalanceAfter - mockArbitrationPolicyUSDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(targetIpId, ipAddr);
        assertEq(disputeInitiator, ipAccount1);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("PLAGIARISM"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
        assertEq(parentDisputeId, 0);
    }

    function test_DisputeModule_setDisputeJudgement_revert_NotInDisputeState() public {
        vm.expectRevert(Errors.DisputeModule__NotInDisputeState.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_setDisputeJudgement_revert_NotWhitelistedArbitrationRelayer() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationRelayer.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_setDisputeJudgement_True() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        (, , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = USDC.balanceOf(address(mockArbitrationPolicy));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, true, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        (, , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = USDC.balanceOf(address(mockArbitrationPolicy));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(mockArbitrationPolicyUSDCBalanceBefore - mockArbitrationPolicyUSDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("PLAGIARISM"));
        assertTrue(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_setDisputeJudgement_False() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        (, , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = USDC.balanceOf(address(mockArbitrationPolicy));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, false, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, false, "");

        (, , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = USDC.balanceOf(address(mockArbitrationPolicy));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, 0);
        assertEq(mockArbitrationPolicyUSDCBalanceBefore - mockArbitrationPolicyUSDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_PolicySP_revert_paused() public {
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        vm.prank(u.admin);
        disputeModule.pause();

        // set dispute judgement
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();
    }

    function test_DisputeModule_PolicySP_cancelDispute_revert_NotDisputeInitiator() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.cancelDispute(1, "");
    }

    function test_DisputeModule_cancelDispute_revert_NotInDisputeState() public {
        vm.expectRevert(Errors.DisputeModule__NotInDisputeState.selector);
        disputeModule.cancelDispute(1, "");
    }

    function test_DisputeModule_cancelDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        (, , , , , bytes32 currentTagBeforeCancel, ) = disputeModule.disputes(1);

        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeCancelled(1, "");

        disputeModule.cancelDispute(1, "");
        vm.stopPrank();

        (, , , , , bytes32 currentTagAfterCancel, ) = disputeModule.disputes(1);

        assertEq(currentTagBeforeCancel, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfterCancel, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_tagDerivativeIfParentInfringed_revert_ParentIpIdMismatch() public {
        vm.expectRevert(Errors.DisputeModule__ParentIpIdMismatch.selector);
        disputeModule.tagDerivativeIfParentInfringed(address(1), address(2), 1);
    }

    function test_DisputeModule_tagDerivativeIfParentInfringed_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.tagDerivativeIfParentInfringed(address(1), address(2), 1);
    }

    function test_DisputeModule_tagDerivativeIfParentInfringed_revert_ParentNotTagged() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__ParentNotTagged.selector);
        disputeModule.tagDerivativeIfParentInfringed(ipAddr, ipAddr2, 1);
    }

    function test_DisputeModule_tagDerivativeIfParentInfringed_revert_NotDerivative() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotDerivative.selector);
        disputeModule.tagDerivativeIfParentInfringed(ipAddr, address(0), 1);
    }

    function test_DisputeModule_tagDerivativeIfParentInfringed() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        assertEq(licenseRegistry.isParentIp(ipAddr, ipAddr2), true);

        // tag child ip
        vm.startPrank(address(1));
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.DerivativeTaggedOnParentInfringement(ipAddr, ipAddr2, 1, "PLAGIARISM");

        uint256 disputeIdBefore = disputeModule.disputeCounter();

        disputeModule.tagDerivativeIfParentInfringed(ipAddr, ipAddr2, 1);

        uint256 disputeIdAfter = disputeModule.disputeCounter();

        (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 disputeEvidenceHash,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 parentDisputeId
        ) = disputeModule.disputes(disputeIdAfter);

        assertEq(disputeIdAfter - disputeIdBefore, 1);
        assertEq(disputeIdAfter, 2);
        assertTrue(disputeModule.isIpTagged(ipAddr2));
        assertEq(targetIpId, ipAddr2);
        assertEq(disputeInitiator, address(1));
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy));
        assertEq(disputeEvidenceHash, bytes32(0));
        assertEq(targetTag, bytes32("PLAGIARISM"));
        assertEq(currentTag, bytes32("PLAGIARISM"));
        assertEq(parentDisputeId, 1);
    }

    function test_DisputeModule_resolveDispute_revert_NotDisputeInitiator() public {
        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.resolveDispute(1, "");
    }

    function test_DisputeModule_resolveDispute_revert_NotAbleToResolve() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        vm.expectRevert(Errors.DisputeModule__NotAbleToResolve.selector);
        disputeModule.resolveDispute(1, "");
    }

    function test_DisputeModule_resolveDispute_revert_ParentDisputeNotResolved() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        // tag derivative
        disputeModule.tagDerivativeIfParentInfringed(ipAddr, ipAddr2, 1);

        vm.expectRevert(Errors.DisputeModule__ParentDisputeNotResolved.selector);
        disputeModule.resolveDispute(2, "");
    }

    function test_DisputeModule_resolveDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        (, , , , , bytes32 currentTagBeforeResolve, ) = disputeModule.disputes(1);

        // resolve dispute
        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeResolved(1);

        disputeModule.resolveDispute(1, "");

        (, , , , , bytes32 currentTagAfterResolve, ) = disputeModule.disputes(1);

        assertEq(currentTagBeforeResolve, bytes32("PLAGIARISM"));
        assertEq(currentTagAfterResolve, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));

        // Can't resolve again
        vm.expectRevert(Errors.DisputeModule__NotAbleToResolve.selector);
        disputeModule.resolveDispute(1, "");
        vm.stopPrank();
    }

    function test_DisputeModule_name() public {
        assertEq(IModule(address(disputeModule)).name(), "DISPUTE_MODULE");
    }
}
