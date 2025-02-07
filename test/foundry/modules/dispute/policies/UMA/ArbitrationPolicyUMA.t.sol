// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { DisputeModule } from "contracts/modules/dispute/DisputeModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty/RoyaltyModule.sol";
import { ArbitrationPolicyUMA } from "contracts/modules/dispute/policies/UMA/ArbitrationPolicyUMA.sol";
import { IOOV3 } from "contracts/interfaces/modules/dispute/policies/UMA/IOOV3.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IPGraphACL } from "contracts/access/IPGraphACL.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
import { MockIpAssetRegistry } from "test/foundry/mocks/dispute/MockIpAssetRegistry.sol";
import { IMockAncillary } from "test/foundry/mocks/IMockAncillary.sol";
import { MockERC20 } from "test/foundry/mocks/token/MockERC20.sol";
import { TestProxyHelper } from "test/foundry/utils/TestProxyHelper.sol";

contract ArbitrationPolicyUMATest is BaseTest {
    event OOV3Set(address oov3);
    event LivenessSet(uint64 minLiveness, uint64 maxLiveness, uint32 ipOwnerTimePercent);
    event MaxBondSet(address token, uint256 maxBond);
    event DisputeRaisedUMA(uint256 disputeId, address caller, uint64 liveness, address currency, uint256 bond);
    event AssertionDisputed(bytes32 assertionId, bytes32 counterEvidenceHash);

    MockIpAssetRegistry mockIpAssetRegistry;
    ArbitrationPolicyUMA newArbitrationPolicyUMA;
    DisputeModule newDisputeModule;
    RoyaltyModule newRoyaltyModule;
    address internal newOOV3;
    AccessManager newAccessManager;
    IPGraphACL newIPGraphACL;
    address internal newAdmin;
    address internal wip;
    address internal mockAncillary;
    bytes32 internal disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;

    function setUp() public virtual override {
        // Fork the desired network where UMA contracts are deployed
        uint256 forkId = vm.createFork("https://aeneid.storyrpc.io/");
        vm.selectFork(forkId);

        // Aeneid
        newOOV3 = 0xABac6a158431edED06EE6cba37eDE8779F599eE4;
        mockAncillary = 0xE71bf0858B0D1deC83a5068F5332ba5B7e8239Dd;
        wip = 0x1514000000000000000000000000000000000000; // WIP address

        // deploy mock ip asset registry
        mockIpAssetRegistry = new MockIpAssetRegistry();

        // deploy access manager
        newAdmin = address(100);
        newAccessManager = new AccessManager(newAdmin);

        newIPGraphACL = new IPGraphACL(address(newAccessManager));

        vm.startPrank(newAdmin);

        // deploy dispute module
        address newDisputeModuleImpl = address(
            new DisputeModule(
                address(newAccessManager),
                address(mockIpAssetRegistry),
                address(2),
                address(newIPGraphACL)
            )
        );
        newDisputeModule = DisputeModule(
            TestProxyHelper.deployUUPSProxy(
                newDisputeModuleImpl,
                abi.encodeCall(DisputeModule.initialize, address(newAccessManager))
            )
        );

        // deploy royalty module
        address newRoyaltyModuleImpl = address(
            new RoyaltyModule(address(1), address(1), address(1), address(1), address(1))
        );
        newRoyaltyModule = RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                newRoyaltyModuleImpl,
                abi.encodeCall(RoyaltyModule.initialize, (address(newAccessManager), uint256(15)))
            )
        );
        newRoyaltyModule.whitelistRoyaltyToken(wip, true);

        // deploy arbitration policy UMA
        address newArbitrationPolicyUMAImpl = address(
            new ArbitrationPolicyUMA(address(newDisputeModule), address(newRoyaltyModule))
        );
        newArbitrationPolicyUMA = ArbitrationPolicyUMA(
            TestProxyHelper.deployUUPSProxy(
                newArbitrationPolicyUMAImpl,
                abi.encodeCall(ArbitrationPolicyUMA.initialize, address(newAccessManager))
            )
        );

        // setup UMA parameters
        newArbitrationPolicyUMA.setOOV3(newOOV3);
        newArbitrationPolicyUMA.setLiveness(30 days, 365 days, 66_666_666);
        newArbitrationPolicyUMA.setMaxBond(wip, 100e18);

        // whitelist dispute tag, arbitration policy and arbitration relayer
        newDisputeModule.whitelistDisputeTag("IMPROPER_REGISTRATION", true);
        newDisputeModule.whitelistArbitrationPolicy(address(newArbitrationPolicyUMA), true);
        newDisputeModule.setArbitrationRelayer(address(newArbitrationPolicyUMA), address(newArbitrationPolicyUMA));
        newDisputeModule.setBaseArbitrationPolicy(address(newArbitrationPolicyUMA));

        vm.label(newOOV3, "newOOV3");
        vm.label(mockAncillary, "mockAncillary");
        vm.label(wip, "wip");
        vm.label(address(newArbitrationPolicyUMA), "newArbitrationPolicyUMA");
        vm.label(address(newDisputeModule), "newDisputeModule");
    }

    function test_ArbitrationPolicyUMA_constructor_revert_ZeroDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroDisputeModule.selector);
        new ArbitrationPolicyUMA(address(0), address(1));
    }

    function test_ArbitrationPolicyUMA_constructor_revert_ZeroRoyaltyModule() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroRoyaltyModule.selector);
        new ArbitrationPolicyUMA(address(1), address(0));
    }

    function test_ArbitrationPolicyUMA_setOOV3_revert_ZeroOOV3() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroOOV3.selector);
        newArbitrationPolicyUMA.setOOV3(address(0));
    }

    function test_ArbitrationPolicyUMA_setOOV3() public {
        address testOOV3 = address(1000);
        vm.expectEmit(true, true, true, true);
        emit OOV3Set(testOOV3);

        newArbitrationPolicyUMA.setOOV3(testOOV3);

        assertEq(newArbitrationPolicyUMA.oov3(), testOOV3);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_ZeroMinLiveness() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroMinLiveness.selector);
        newArbitrationPolicyUMA.setLiveness(0, 10, 10);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_ZeroMaxLiveness() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroMaxLiveness.selector);
        newArbitrationPolicyUMA.setLiveness(10, 0, 10);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_MinLivenessAboveMax() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__MinLivenessAboveMax.selector);
        newArbitrationPolicyUMA.setLiveness(100, 10, 10);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_IpOwnerTimePercentAboveMax() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__IpOwnerTimePercentAboveMax.selector);
        newArbitrationPolicyUMA.setLiveness(10, 100, 100_000_001);
    }

    function test_ArbitrationPolicyUMA_setLiveness() public {
        vm.expectEmit(true, true, true, true);
        emit LivenessSet(10, 100, 10);

        newArbitrationPolicyUMA.setLiveness(10, 100, 10);

        assertEq(newArbitrationPolicyUMA.minLiveness(), 10);
        assertEq(newArbitrationPolicyUMA.maxLiveness(), 100);
        assertEq(newArbitrationPolicyUMA.ipOwnerTimePercent(), 10);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_paused() public {
        newArbitrationPolicyUMA.pause();

        uint64 liveness = 1;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_LivenessBelowMin() public {
        uint64 liveness = 1;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__LivenessBelowMin.selector);
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_LivenessAboveMax() public {
        uint64 liveness = 365 days + 1;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__LivenessAboveMax.selector);
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_setMaxBond() public {
        vm.expectEmit(true, true, true, true);
        emit MaxBondSet(wip, 1);

        newArbitrationPolicyUMA.setMaxBond(wip, 1);

        assertEq(newArbitrationPolicyUMA.maxBonds(wip), 1);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__NotDisputeModule.selector);
        newArbitrationPolicyUMA.onRaiseDispute(address(1), address(1), bytes32(0), bytes32(0), 1, bytes(""));
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_BondAboveMax() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 25000e18 + 1;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__BondAboveMax.selector);
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_CurrencyNotWhitelisted() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(address(new MockERC20()));
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        newRoyaltyModule.whitelistRoyaltyToken(address(currency), false);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__CurrencyNotWhitelisted.selector);
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_UnsupportedCurrency() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(address(new MockERC20()));
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        newRoyaltyModule.whitelistRoyaltyToken(address(currency), true);

        vm.expectRevert("Unsupported currency");
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectEmit(true, true, true, true);
        emit DisputeRaisedUMA(1, address(2), liveness, address(currency), bond);

        vm.startPrank(address(2));
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);

        uint256 disputeId = newDisputeModule.disputeCounter();
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        assertFalse(newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId) == bytes32(0));
        assertEq(newArbitrationPolicyUMA.assertionIdToDisputeId(assertionId), disputeId);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_WithBond() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 1000;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(address(2));
        vm.deal(address(2), bond);
        IWIP(wip).deposit{ value: bond }();
        currency.approve(address(newArbitrationPolicyUMA), bond);

        uint256 raiserBalBefore = currency.balanceOf(address(2));
        uint256 oov3BalBefore = currency.balanceOf(address(newOOV3));

        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);

        uint256 raiserBalAfter = currency.balanceOf(address(2));
        uint256 oov3BalAfter = currency.balanceOf(address(newOOV3));

        assertEq(raiserBalBefore - raiserBalAfter, bond);
        assertEq(oov3BalAfter - oov3BalBefore, bond);

        uint256 disputeId = newDisputeModule.disputeCounter();
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        assertFalse(newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId) == bytes32(0));
        assertEq(newArbitrationPolicyUMA.assertionIdToDisputeId(assertionId), disputeId);
    }

    function test_ArbitrationPolicyUMA_onDisputeCancel_revert_CannotCancel() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__CannotCancel.selector);
        newDisputeModule.cancelDispute(1, "");
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_revert_AssertionNotExpired() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        uint256 disputeId = newDisputeModule.raiseDispute(
            address(1),
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // settle the assertion
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectRevert("Assertion not expired");
        IOOV3(newOOV3).settleAssertion(assertionId);
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithoutDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        uint256 disputeId = newDisputeModule.raiseDispute(
            address(1),
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // wait for assertion to expire
        vm.warp(block.timestamp + liveness + 1);

        (, , , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        // settle the assertion
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        IOOV3(newOOV3).settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithoutDisputeWithBond() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 1000;

        bytes memory data = abi.encode(liveness, currency, bond);

        address disputer = address(2);

        vm.startPrank(disputer);
        vm.deal(disputer, bond);
        IWIP(wip).deposit{ value: bond }();
        currency.approve(address(newArbitrationPolicyUMA), bond);
        uint256 disputeId = newDisputeModule.raiseDispute(
            address(1),
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // wait for assertion to expire
        vm.warp(block.timestamp + liveness + 1);

        (, , , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        uint256 disputerBalBefore = currency.balanceOf(disputer);

        // settle the assertion
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        IOOV3(newOOV3).settleAssertion(assertionId);

        uint256 disputerBalAfter = currency.balanceOf(disputer);

        (, , , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
        assertEq(disputerBalAfter - disputerBalBefore, bond);
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);

        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(targetIpId);
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");
        newArbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        (, , , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        IMockAncillary(mockAncillary).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        IMockAncillary(mockAncillary).pushPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData, 1e18);
        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_CannotDisputeAssertionTwice() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);
        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(targetIpId);
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");
        newArbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        vm.expectRevert("Assertion already disputed");
        newArbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_NoCounterEvidence() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);
        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(targetIpId);
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__NoCounterEvidence.selector);
        newArbitrationPolicyUMA.disputeAssertion(assertionId, bytes32(0));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_DisputeNotFound() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);
        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        vm.expectRevert(Errors.ArbitrationPolicyUMA__DisputeNotFound.selector);
        newArbitrationPolicyUMA.disputeAssertion(bytes32(0), bytes32("COUNTER_EVIDENCE_HASH"));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_OnlyTargetIpIdCanDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);
        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.startPrank(address(2));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ArbitrationPolicyUMA__OnlyTargetIpIdCanDisputeWithinTimeWindow.selector,
                0,
                liveness,
                address(2)
            )
        );
        newArbitrationPolicyUMA.disputeAssertion(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_IPA() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);
        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(targetIpId);
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");

        vm.expectEmit(true, true, true, true);
        emit AssertionDisputed(assertionId, counterEvidenceHash);

        newArbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        (, , , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        IMockAncillary(mockAncillary).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        IMockAncillary(mockAncillary).pushPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData, 0);
        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_NotIPA() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);
        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        vm.warp(block.timestamp + (liveness * 66_666_666) / 100_000_000 + 1);

        // dispute the assertion
        vm.startPrank(address(2));
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");

        vm.expectEmit(true, true, true, true);
        emit AssertionDisputed(assertionId, counterEvidenceHash);

        newArbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        (, , , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        IMockAncillary(mockAncillary).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        IMockAncillary(mockAncillary).pushPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData, 0);
        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_WithBondAndIpTagged() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 1000;
        bytes memory data = abi.encode(liveness, currency, bond);

        //address defenderIpIdOwner = address(1);
        //address disputeInitiator = address(2);

        // raise dispute
        vm.startPrank(address(2));
        vm.deal(address(2), bond);
        IWIP(wip).deposit{ value: bond }();
        currency.approve(address(newArbitrationPolicyUMA), bond);
        uint256 disputeId = newDisputeModule.raiseDispute(
            address(1),
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );
        vm.stopPrank();

        // dispute the assertion
        vm.startPrank(address(1));
        vm.deal(address(1), bond);
        IWIP(wip).deposit{ value: bond }();
        currency.approve(address(newArbitrationPolicyUMA), bond);

        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectEmit(true, true, true, true);
        emit AssertionDisputed(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        newArbitrationPolicyUMA.disputeAssertion(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        IMockAncillary(mockAncillary).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        IMockAncillary(mockAncillary).pushPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData, 1e18);

        (, , , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalBefore = currency.balanceOf(address(2));
        uint256 defenderIpIdOwnerBalBefore = currency.balanceOf(address(1));

        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalAfter = currency.balanceOf(address(2));
        uint256 defenderIpIdOwnerBalAfter = currency.balanceOf(address(1));

        uint256 oracleFee = (oov3.burnedBondPercentage() * assertion.bond) / 1e18;
        uint256 bondRecipientAmount = assertion.bond * 2 - oracleFee;

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
        assertEq(disputeInitiatorBalAfter - disputeInitiatorBalBefore, bondRecipientAmount);
        assertEq(defenderIpIdOwnerBalAfter - defenderIpIdOwnerBalBefore, 0);
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_WithBondAndIpNotTagged() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 1000;
        bytes memory data = abi.encode(liveness, currency, bond);

        //address defenderIpIdOwner = address(1);
        //address disputeInitiator = address(2);

        // raise dispute
        vm.startPrank(address(2));
        vm.deal(address(2), bond);
        IWIP(wip).deposit{ value: bond }();
        currency.approve(address(newArbitrationPolicyUMA), bond);
        uint256 disputeId = newDisputeModule.raiseDispute(
            address(1),
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );
        vm.stopPrank();

        // dispute the assertion
        vm.startPrank(address(1));
        vm.deal(address(1), bond);
        IWIP(wip).deposit{ value: bond }();
        currency.approve(address(newArbitrationPolicyUMA), bond);

        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectEmit(true, true, true, true);
        emit AssertionDisputed(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        newArbitrationPolicyUMA.disputeAssertion(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        IMockAncillary(mockAncillary).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        IMockAncillary(mockAncillary).pushPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData, 0);

        (, , , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalBefore = currency.balanceOf(address(2));
        uint256 defenderIpIdOwnerBalBefore = currency.balanceOf(address(1));

        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalAfter = currency.balanceOf(address(2));
        uint256 defenderIpIdOwnerBalAfter = currency.balanceOf(address(1));

        uint256 oracleFee = (oov3.burnedBondPercentage() * assertion.bond) / 1e18;
        uint256 bondRecipientAmount = assertion.bond * 2 - oracleFee;

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
        assertEq(disputeInitiatorBalAfter - disputeInitiatorBalBefore, 0);
        assertEq(defenderIpIdOwnerBalAfter - defenderIpIdOwnerBalBefore, bondRecipientAmount);
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_WithIpOwnerTimePercentChange() public {
        // liveness set to 30 days
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        address targetIpId = address(1);

        uint256 disputeId = newDisputeModule.raiseDispute(
            targetIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );
        // warp
        vm.warp(block.timestamp + 4 days);
        // set the IpOwnerTimePercent to 0%
        newArbitrationPolicyUMA.setLiveness(10, 100, 0);

        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");
        vm.startPrank(address(2));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ArbitrationPolicyUMA__OnlyTargetIpIdCanDisputeWithinTimeWindow.selector,
                4 days,
                liveness,
                address(2)
            )
        );
        newArbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);
    }

    function test_ArbitrationPolicyUMA_assertionDisputedCallback_revert_NotOOV3() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__NotOOV3.selector);
        newArbitrationPolicyUMA.assertionDisputedCallback(bytes32(0));
    }

    function test_ArbitrationPolicyUMA_assertionDisputedCallback_revert_NoCounterEvidence() public {
        vm.startPrank(newOOV3);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__NoCounterEvidence.selector);
        newArbitrationPolicyUMA.assertionDisputedCallback(bytes32(0));
    }
}

interface AuxiliaryOOV3Interface {
    function stampAssertion(bytes32 assertionId) external view returns (bytes memory);
}

interface IWIP is IERC20 {
    function deposit() external payable;
}
