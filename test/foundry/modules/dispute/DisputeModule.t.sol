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
import { IGroupingModule } from "contracts/interfaces/modules/grouping/IGroupingModule.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { PILFlavors } from "contracts/lib/PILFlavors.sol";
// test
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
import { MockArbitrationPolicy } from "test/foundry/mocks/dispute/MockArbitrationPolicy.sol";
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";

contract DisputeModuleTest is BaseTest {
    event TagWhitelistUpdated(bytes32 tag, bool allowed);
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);
    event ArbitrationRelayerUpdated(address arbitrationPolicy, address arbitrationRelayer);
    event DisputeJudgementSet(uint256 disputeId, bool decision, bytes data);
    event DisputeCancelled(uint256 disputeId, bytes data);
    event DisputeResolved(uint256 disputeId, bytes data);
    event DefaultArbitrationPolicyUpdated(address arbitrationPolicy);

    address internal ipAccount1 = address(0x111000aaa);
    address internal ipAccount2 = address(0x111000bbb);

    address internal ipAddr;
    address internal ipAddr2;
    address internal arbitrationRelayer;
    MockArbitrationPolicy internal mockArbitrationPolicy2;

    bytes32 internal disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;

    // grouping
    MockERC721 internal mockNft = new MockERC721("MockERC721");
    address public ipIdGroupMember;
    address public ipOwnerGroupMember = address(0x222);

    function setUp() public override {
        super.setUp();

        arbitrationRelayer = u.relayer;

        USDC.mint(ipAccount1, 1000 * 10 ** 6);

        // second arbitration policy
        mockArbitrationPolicy2 = new MockArbitrationPolicy(address(disputeModule), address(USDC), ARBITRATION_PRICE);

        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy2), true);
        disputeModule.setBaseArbitrationPolicy(address(mockArbitrationPolicy));
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
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        }); // first license minted

        ipAddr2 = ipAssetRegistry.register(block.chainid, address(mockNFT), 1);

        licensingModule.registerDerivativeWithLicenseTokens(ipAddr2, licenseIds, "", 100e6);

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

    function test_DisputeModule_whitelistArbitrationPolicy_revert_CannotBlacklistBaseArbitrationPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(10), true);
        disputeModule.setBaseArbitrationPolicy(address(10));
        assertEq(disputeModule.isWhitelistedArbitrationPolicy(address(10)), true);
        assertEq(disputeModule.baseArbitrationPolicy(), address(10));

        vm.expectRevert(Errors.DisputeModule__CannotBlacklistBaseArbitrationPolicy.selector);
        disputeModule.whitelistArbitrationPolicy(address(10), false);
    }

    function test_DisputeModule_whitelistArbitrationPolicy() public {
        vm.startPrank(u.admin);

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationPolicyWhitelistUpdated(address(1), true);

        disputeModule.whitelistArbitrationPolicy(address(1), true);

        assertEq(disputeModule.isWhitelistedArbitrationPolicy(address(1)), true);
    }

    function test_DisputeModule_setArbitrationRelayer_revert_ZeroArbitrationPolicy() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationPolicy.selector);
        disputeModule.setArbitrationRelayer(address(0), arbitrationRelayer);
    }

    function test_DisputeModule_setArbitrationRelayer() public {
        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationRelayerUpdated(address(mockArbitrationPolicy), address(1));

        disputeModule.setArbitrationRelayer(address(mockArbitrationPolicy), address(1));

        assertEq(disputeModule.arbitrationRelayer(address(mockArbitrationPolicy)), address(1));
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

    function test_DisputeModule_setArbitrationPolicyCooldown_revert_ZeroCooldown() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationPolicyCooldown.selector);
        disputeModule.setArbitrationPolicyCooldown(0);
    }

    function test_DisputeModule_setArbitrationPolicyCooldown() public {
        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.ArbitrationPolicyCooldownUpdated(100);

        disputeModule.setArbitrationPolicyCooldown(100);
        assertEq(disputeModule.arbitrationPolicyCooldown(), 100);
    }

    function test_DisputeModule_setArbitrationPolicy_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));
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
        emit IDisputeModule.ArbitrationPolicySet(ipAddr, address(mockArbitrationPolicy2), block.timestamp + 7 days);

        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));

        assertEq(disputeModule.arbitrationPolicies(ipAddr), address(0));
        assertEq(disputeModule.nextArbitrationPolicies(ipAddr), address(mockArbitrationPolicy2));
        assertEq(disputeModule.nextArbitrationUpdateTimestamps(ipAddr), block.timestamp + 7 days);
    }

    function test_DisputeModule_setArbitrationPolicy_WithQueuedPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy2), true);
        vm.stopPrank();

        vm.startPrank(ipAddr);

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.ArbitrationPolicySet(ipAddr, address(mockArbitrationPolicy2), block.timestamp + 7 days);

        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));

        vm.warp(block.timestamp + disputeModule.arbitrationPolicyCooldown() + 1);

        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy));

        assertEq(disputeModule.arbitrationPolicies(ipAddr), address(mockArbitrationPolicy2));
        assertEq(disputeModule.nextArbitrationPolicies(ipAddr), address(mockArbitrationPolicy));
        assertEq(disputeModule.nextArbitrationUpdateTimestamps(ipAddr), block.timestamp + 7 days);
    }

    function test_DisputeModule_raiseDispute_revert_NotRegisteredIpId() public {
        vm.expectRevert(Errors.DisputeModule__NotRegisteredIpId.selector);
        disputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
    }

    function test_DisputeModule_raiseDispute_revert_NotWhitelistedDisputeTag() public {
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedDisputeTag.selector);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "NOT_WHITELISTED", "");
    }

    function test_DisputeModule_raiseDispute_revert_ZeroDisputeEvidenceHash() public {
        vm.expectRevert(Errors.DisputeModule__ZeroDisputeEvidenceHash.selector);
        disputeModule.raiseDispute(ipAddr, bytes32(""), "IMPROPER_REGISTRATION", "");
    }

    function test_DisputeModule_raiseDispute_revert_EvidenceHashAlreadyUsed() public {
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);

        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");

        vm.expectRevert(Errors.DisputeModule__EvidenceHashAlreadyUsed.selector);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
    }

    function test_DisputeModule_raiseDispute_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.startPrank(u.bob);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();
    }

    function test_DisputeModule_raiseDispute_BlacklistedPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.setBaseArbitrationPolicy(address(mockArbitrationPolicy2));
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy), false);
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy2), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = IERC20(USDC).balanceOf(address(mockArbitrationPolicy2));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            ipAccount1,
            block.timestamp,
            address(mockArbitrationPolicy2),
            disputeEvidenceHashExample,
            bytes32("IMPROPER_REGISTRATION"),
            ""
        );

        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = IERC20(USDC).balanceOf(address(mockArbitrationPolicy2));

        (
            address targetIpId,
            address disputeInitiator,
            uint256 disputeTimestamp,
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
        assertEq(disputeTimestamp, block.timestamp);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy2));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("IMPROPER_REGISTRATION"));
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
        emit IDisputeModule.DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            ipAccount1,
            block.timestamp,
            address(mockArbitrationPolicy),
            disputeEvidenceHashExample,
            bytes32("IMPROPER_REGISTRATION"),
            ""
        );

        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = USDC.balanceOf(address(mockArbitrationPolicy));

        (
            address targetIpId,
            address disputeInitiator,
            uint256 disputeTimestamp,
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
        assertEq(disputeTimestamp, block.timestamp);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("IMPROPER_REGISTRATION"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
        assertEq(parentDisputeId, 0);
    }

    function test_DisputeModule_raiseDisputeOnBehalf_revert_NotRegisteredIpId() public {
        vm.expectRevert(Errors.DisputeModule__NotRegisteredIpId.selector);
        disputeModule.raiseDisputeOnBehalf(
            address(1),
            address(2),
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            ""
        );
    }

    function test_DisputeModule_raiseDisputeOnBehalf_revert_NotWhitelistedDisputeTag() public {
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedDisputeTag.selector);
        disputeModule.raiseDisputeOnBehalf(ipAddr, address(2), disputeEvidenceHashExample, "NOT_WHITELISTED", "");
    }

    function test_DisputeModule_raiseDisputeOnBehalf_revert_ZeroDisputeEvidenceHash() public {
        vm.expectRevert(Errors.DisputeModule__ZeroDisputeEvidenceHash.selector);
        disputeModule.raiseDisputeOnBehalf(ipAddr, address(2), bytes32(""), "IMPROPER_REGISTRATION", "");
    }

    function test_DisputeModule_raiseDisputeOnBehalf_revert_EvidenceHashAlreadyUsed() public {
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);

        disputeModule.raiseDisputeOnBehalf(ipAddr, address(2), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");

        vm.expectRevert(Errors.DisputeModule__EvidenceHashAlreadyUsed.selector);
        disputeModule.raiseDisputeOnBehalf(ipAddr, address(2), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
    }

    function test_DisputeModule_raiseDisputeOnBehalf_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.startPrank(u.bob);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.raiseDisputeOnBehalf(ipAddr, address(2), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();
    }

    function test_DisputeModule_raiseDisputeOnBehalf_BlacklistedPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.setBaseArbitrationPolicy(address(mockArbitrationPolicy2));
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy), false);
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy2), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = IERC20(USDC).balanceOf(address(mockArbitrationPolicy2));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            address(2),
            block.timestamp,
            address(mockArbitrationPolicy2),
            disputeEvidenceHashExample,
            bytes32("IMPROPER_REGISTRATION"),
            ""
        );

        disputeModule.raiseDisputeOnBehalf(ipAddr, address(2), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = IERC20(USDC).balanceOf(address(mockArbitrationPolicy2));

        (
            address targetIpId,
            address disputeInitiator,
            uint256 disputeTimestamp,
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
        assertEq(disputeInitiator, address(2));
        assertEq(disputeTimestamp, block.timestamp);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy2));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("IMPROPER_REGISTRATION"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
        assertEq(parentDisputeId, 0);
    }

    function test_DisputeModule_raiseDisputeOnBehalf() public {
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = USDC.balanceOf(address(mockArbitrationPolicy));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            address(2),
            block.timestamp,
            address(mockArbitrationPolicy),
            disputeEvidenceHashExample,
            bytes32("IMPROPER_REGISTRATION"),
            ""
        );

        disputeModule.raiseDisputeOnBehalf(ipAddr, address(2), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = USDC.balanceOf(address(mockArbitrationPolicy));

        (
            address targetIpId,
            address disputeInitiator,
            uint256 disputeTimestamp,
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
        assertEq(disputeInitiator, address(2));
        assertEq(disputeTimestamp, block.timestamp);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("IMPROPER_REGISTRATION"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
        assertEq(parentDisputeId, 0);
    }

    function test_DisputeModule_setDisputeJudgement_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        // set dispute judgement
        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_setDisputeJudgement_revert_NotInDisputeState() public {
        vm.expectRevert(Errors.DisputeModule__NotInDisputeState.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_setDisputeJudgement_revert_NotWhitelistedArbitrationRelayer() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotArbitrationRelayer.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_setDisputeJudgement_True() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = USDC.balanceOf(address(mockArbitrationPolicy));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, true, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = USDC.balanceOf(address(mockArbitrationPolicy));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(mockArbitrationPolicyUSDCBalanceBefore - mockArbitrationPolicyUSDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
        assertTrue(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_setDisputeJudgement_False() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceBefore = USDC.balanceOf(address(mockArbitrationPolicy));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, false, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, false, "");

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 mockArbitrationPolicyUSDCBalanceAfter = USDC.balanceOf(address(mockArbitrationPolicy));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, 0);
        assertEq(mockArbitrationPolicyUSDCBalanceBefore - mockArbitrationPolicyUSDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_cancelDispute_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.cancelDispute(1, "");
    }

    function test_DisputeModule_cancelDispute_revert_NotDisputeInitiator() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
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
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        (, , , , , , bytes32 currentTagBeforeCancel, ) = disputeModule.disputes(1);

        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeCancelled(1, "");

        disputeModule.cancelDispute(1, "");
        vm.stopPrank();

        (, , , , , , bytes32 currentTagAfterCancel, ) = disputeModule.disputes(1);

        assertEq(currentTagBeforeCancel, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfterCancel, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_tagIfRelatedIpInfringed_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.tagIfRelatedIpInfringed(address(2), 1);
    }

    function test_DisputeModule_tagIfRelatedIpInfringed_revert_DisputeWithoutInfringementTag() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__DisputeWithoutInfringementTag.selector);
        disputeModule.tagIfRelatedIpInfringed(ipAddr2, 1);
    }

    function test_DisputeModule_tagIfRelatedIpInfringed_revert_DisputeAlreadyPropagated() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        assertEq(licenseRegistry.isParentIp(ipAddr, ipAddr2), true);

        disputeModule.tagIfRelatedIpInfringed(ipAddr2, 1);
        vm.expectRevert(Errors.DisputeModule__DisputeAlreadyPropagated.selector);
        disputeModule.tagIfRelatedIpInfringed(ipAddr2, 1);
    }

    function test_DisputeModule_tagIfRelatedIpInfringed_revert_NotDerivative() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotDerivativeOrGroupIp.selector);
        disputeModule.tagIfRelatedIpInfringed(address(0), 1);
    }

    function test_DisputeModule_tagIfRelatedIpInfringed_Derivative() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        assertEq(licenseRegistry.isParentIp(ipAddr, ipAddr2), true);

        // child ip changes arbitration policy
        vm.startPrank(address(ipAddr2));
        disputeModule.setArbitrationPolicy(ipAddr2, address(mockArbitrationPolicy2));
        vm.warp(block.timestamp + disputeModule.arbitrationPolicyCooldown() + 1);
        disputeModule.updateActiveArbitrationPolicy(ipAddr2);
        assertEq(disputeModule.arbitrationPolicies(ipAddr2), address(mockArbitrationPolicy2));
        vm.stopPrank();

        // tag child ip
        vm.startPrank(address(1));
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.IpTaggedOnRelatedIpInfringement(
            2,
            ipAddr,
            ipAddr2,
            1,
            "IMPROPER_REGISTRATION",
            block.timestamp
        );

        uint256 disputeIdBefore = disputeModule.disputeCounter();

        disputeModule.tagIfRelatedIpInfringed(ipAddr2, 1);

        uint256 disputeIdAfter = disputeModule.disputeCounter();

        (
            address targetIpId,
            address disputeInitiator,
            uint256 disputeTimestamp,
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
        assertEq(disputeTimestamp, block.timestamp);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("IMPROPER_REGISTRATION"));
        assertEq(currentTag, bytes32("IMPROPER_REGISTRATION"));
        assertEq(parentDisputeId, 1);
    }

    function test_DisputeModule_tagIfRelatedIpInfringed_Group() public {
        // set group member
        mockNft.mintId(ipOwnerGroupMember, 11);
        ipIdGroupMember = ipAssetRegistry.register(block.chainid, address(mockNft), 11);

        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(evenSplitGroupPool));

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLRP)
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(evenSplitGroupPool)
        });

        vm.startPrank(ipIdGroupMember);
        licensingModule.attachLicenseTerms(ipIdGroupMember, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipIdGroupMember, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingConfig.expectGroupRewardPool = address(0);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        address[] memory ipIds = new address[](1);
        ipIds[0] = ipIdGroupMember;
        vm.expectEmit();
        emit IGroupingModule.AddedIpToGroup(groupId, ipIds);
        groupingModule.addIp(groupId, ipIds, 100e6);

        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipIdGroupMember, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        // tag group ip
        vm.startPrank(address(1));
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.IpTaggedOnRelatedIpInfringement(
            2,
            ipIdGroupMember,
            groupId,
            1,
            "IMPROPER_REGISTRATION",
            block.timestamp
        );

        disputeModule.tagIfRelatedIpInfringed(groupId, 1);

        (
            address targetIpId,
            address disputeInitiator,
            uint256 disputeTimestamp,
            address arbitrationPolicy,
            bytes32 disputeEvidenceHash,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 infringerDisputeId
        ) = disputeModule.disputes(disputeModule.disputeCounter());

        assertEq(disputeModule.disputeCounter(), 2);
        assertTrue(disputeModule.isIpTagged(groupId));
        assertEq(targetIpId, groupId);
        assertEq(disputeInitiator, address(1));
        assertEq(disputeTimestamp, block.timestamp);
        assertEq(arbitrationPolicy, address(mockArbitrationPolicy));
        assertEq(disputeEvidenceHash, disputeEvidenceHashExample);
        assertEq(targetTag, bytes32("IMPROPER_REGISTRATION"));
        assertEq(currentTag, bytes32("IMPROPER_REGISTRATION"));
        assertEq(infringerDisputeId, 1);
    }

    function test_DisputeModule_resolveDispute_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.resolveDispute(1, "");
    }

    function test_DisputeModule_resolveDispute_revert_NotDisputeInitiator() public {
        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.resolveDispute(1, "");
    }

    function test_DisputeModule_resolveDispute_revert_NotAbleToResolve() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        vm.expectRevert(Errors.DisputeModule__NotAbleToResolve.selector);
        disputeModule.resolveDispute(1, "");
    }

    function test_DisputeModule_resolveDispute_revert_RelatedDisputeNotResolved() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        // tag derivative
        disputeModule.tagIfRelatedIpInfringed(ipAddr2, 1);

        vm.expectRevert(Errors.DisputeModule__RelatedDisputeNotResolved.selector);
        disputeModule.resolveDispute(2, "");
    }

    function test_DisputeModule_resolveDispute_Derivative() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        (, , , , , , bytes32 currentTagBeforeResolve, ) = disputeModule.disputes(1);

        // resolve dispute
        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeResolved(1, "");

        disputeModule.resolveDispute(1, "");

        (, , , , , , bytes32 currentTagAfterResolve, ) = disputeModule.disputes(1);

        assertEq(currentTagBeforeResolve, bytes32("IMPROPER_REGISTRATION"));
        assertEq(currentTagAfterResolve, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));

        // Can't resolve again
        vm.expectRevert(Errors.DisputeModule__NotAbleToResolve.selector);
        disputeModule.resolveDispute(1, "");
        vm.stopPrank();
    }

    function test_DisputeModule_resolveDispute_Group() public {
        // set group member
        mockNft.mintId(ipOwnerGroupMember, 11);
        ipIdGroupMember = ipAssetRegistry.register(block.chainid, address(mockNft), 11);

        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(evenSplitGroupPool));

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLRP)
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(evenSplitGroupPool)
        });

        vm.startPrank(ipIdGroupMember);
        licensingModule.attachLicenseTerms(ipIdGroupMember, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipIdGroupMember, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingConfig.expectGroupRewardPool = address(0);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        address[] memory ipIds = new address[](1);
        ipIds[0] = ipIdGroupMember;
        vm.expectEmit();
        emit IGroupingModule.AddedIpToGroup(groupId, ipIds);
        groupingModule.addIp(groupId, ipIds, 100e6);

        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipIdGroupMember, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        // tag group ip
        vm.startPrank(address(1));
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit IDisputeModule.IpTaggedOnRelatedIpInfringement(
            2,
            ipIdGroupMember,
            groupId,
            1,
            "IMPROPER_REGISTRATION",
            block.timestamp
        );
        disputeModule.tagIfRelatedIpInfringed(groupId, 1);
        assertEq(disputeModule.disputeCounter(), 2);

        // resolve dispute of group member
        vm.startPrank(ipAccount1);
        disputeModule.resolveDispute(1, "");
        vm.stopPrank();

        // resolve dispute of group ip
        disputeModule.resolveDispute(2, "");

        assertFalse(disputeModule.isIpTagged(ipIdGroupMember));
        assertFalse(disputeModule.isIpTagged(groupId));
    }

    function test_DisputeModule_updateActiveArbitrationPolicy_revert_paused() public {
        vm.prank(u.admin);
        disputeModule.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.updateActiveArbitrationPolicy(address(1));
    }

    function test_DisputeModule_updateActiveArbitrationPolicy_BaseArbitrationPolicyToStart() public {
        address currentArbPolicy = disputeModule.updateActiveArbitrationPolicy(address(1));

        assertEq(currentArbPolicy, address(mockArbitrationPolicy));
        assertEq(disputeModule.arbitrationPolicies(address(1)), address(0));
        assertEq(disputeModule.nextArbitrationPolicies(address(1)), address(0));
        assertEq(disputeModule.nextArbitrationUpdateTimestamps(address(1)), 0);
    }

    function test_DisputeModule_updateActiveArbitrationPolicy_UpdateToNextArbitrationPolicy() public {
        vm.startPrank(ipAddr);
        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));

        vm.warp(block.timestamp + disputeModule.arbitrationPolicyCooldown() + 1);

        disputeModule.updateActiveArbitrationPolicy(ipAddr);

        assertEq(disputeModule.arbitrationPolicies(ipAddr), address(mockArbitrationPolicy2));
        assertEq(disputeModule.nextArbitrationPolicies(ipAddr), address(0));
        assertEq(disputeModule.nextArbitrationUpdateTimestamps(ipAddr), 0);

        disputeModule.updateActiveArbitrationPolicy(ipAddr);

        assertEq(disputeModule.arbitrationPolicies(ipAddr), address(mockArbitrationPolicy2));
        assertEq(disputeModule.nextArbitrationPolicies(ipAddr), address(0));
        assertEq(disputeModule.nextArbitrationUpdateTimestamps(ipAddr), 0);
    }

    function test_DisputeModule_updateActiveArbitrationPolicy_UpdateToBlacklistedPolicy() public {
        vm.startPrank(ipAddr);
        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy2));
        vm.stopPrank();

        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy2), false);
        vm.stopPrank();

        vm.warp(block.timestamp + disputeModule.arbitrationPolicyCooldown() + 1);

        address currentArbPolicy = disputeModule.updateActiveArbitrationPolicy(ipAddr);

        assertEq(currentArbPolicy, disputeModule.baseArbitrationPolicy());
        assertEq(disputeModule.arbitrationPolicies(ipAddr), address(mockArbitrationPolicy2));
        assertEq(disputeModule.nextArbitrationPolicies(ipAddr), address(0));
        assertEq(disputeModule.nextArbitrationUpdateTimestamps(ipAddr), 0);
    }

    function test_DisputeModule_name() public {
        assertEq(IModule(address(disputeModule)).name(), "DISPUTE_MODULE");
    }
}
