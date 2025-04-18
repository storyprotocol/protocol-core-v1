// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { DisputeModule } from "contracts/modules/dispute/DisputeModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty/RoyaltyModule.sol";
import { ArbitrationPolicyUMA } from "contracts/modules/dispute/policies/UMA/ArbitrationPolicyUMA.sol";
import { IArbitrationPolicyUMA } from "contracts/interfaces/modules/dispute/policies/UMA/IArbitrationPolicyUMA.sol";
import { IOOV3 } from "contracts/interfaces/modules/dispute/policies/UMA/IOOV3.sol";
import { Errors } from "contracts/lib/Errors.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
import { MockERC20 } from "test/foundry/mocks/token/MockERC20.sol";

contract ArbitrationPolicyUMATest is BaseTest {
    event OOV3Set(address oov3);
    event LivenessSet(uint64 minLiveness, uint64 maxLiveness, uint32 ipOwnerTimePercent);
    event MaxBondSet(address token, uint256 maxBond);
    event DisputeRaisedUMA(uint256 disputeId, address caller, uint64 liveness, address currency, uint256 bond);

    address internal protocolAdmin;
    address internal protocolPauseAdmin;
    address internal newOOV3;
    address internal oracleSpoke;
    address internal wip;
    bytes32 internal disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;
    address internal randomIpId;
    address internal disputeInitiator;
    address internal counterDisputer;
    uint256 internal disputeBond;
    address internal umaRegisteredContract;
    address internal childMessenger;

    function setUp() public virtual override {
        // Fork the desired network where UMA contracts are deployed
        uint256 forkId = vm.createFork("https://mainnet.storyrpc.io/");
        vm.selectFork(forkId);

        // Mainnet
        // UMA related addresses
        newOOV3 = 0x8EF424F90C6BC1b98153A09c0Cac5072545793e8;
        oracleSpoke = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
        umaRegisteredContract = 0x8EF424F90C6BC1b98153A09c0Cac5072545793e8;
        childMessenger = 0x3baD7AD0728f9917d1Bf08af5782dCbD516cDd96;

        // PoC related addresses
        wip = 0x1514000000000000000000000000000000000000; // WIP address
        disputeModule = DisputeModule(0x9b7A9c70AFF961C799110954fc06F3093aeb94C5);
        royaltyModule = RoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);
        arbitrationPolicyUMA = ArbitrationPolicyUMA(0xfFD98c3877B8789124f02C7E8239A4b0Ef11E936);
        protocolAdmin = 0x623Cb5A594dAD5cc1Ea1bDb0b084bf8F1fE4B2e4;
        protocolPauseAdmin = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;
        address upgrader = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
        address accessController = 0xcCF37d0a503Ee1D4C11208672e622ed3DFB2275a;
        address ipAssetRegistry = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
        address licenseRegistry = 0x529a750E02d8E2f15649c13D69a465286a780e24;
        address ipGraphACL = 0x1640A22a8A086747cD377b73954545e2Dfcc9Cad;
        address accessManager = 0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53; // protocol access manager
        randomIpId = 0x452E6787A18a15e1A645DEd3dF519017D7E60b62;

        vm.startPrank(protocolAdmin);
        arbitrationPolicyUMA.setOOV3(newOOV3);
        arbitrationPolicyUMA.setMaxBond(wip, 350e18);
        vm.stopPrank();

        // fund addresses
        disputeInitiator = address(2);
        counterDisputer = address(3);

        disputeBond = IOOV3(newOOV3).getMinimumBond(wip);

        vm.startPrank(disputeInitiator);
        vm.deal(disputeInitiator, disputeBond);
        IWIP(wip).deposit{ value: disputeBond }();
        IERC20(wip).approve(address(arbitrationPolicyUMA), disputeBond);
        vm.stopPrank();

        vm.startPrank(counterDisputer); // random counter disputer address that is not the IP owner
        vm.deal(counterDisputer, disputeBond * 2);
        IWIP(wip).deposit{ value: disputeBond * 2 }();
        IERC20(wip).approve(address(arbitrationPolicyUMA), disputeBond * 2);
        vm.stopPrank();

        vm.startPrank(randomIpId);
        vm.deal(randomIpId, disputeBond * 2);
        IWIP(wip).deposit{ value: disputeBond * 2 }();
        IERC20(wip).approve(address(arbitrationPolicyUMA), disputeBond * 2);
        vm.stopPrank();

        // upgrade dispute module
        address newDisputeModuleImpl = address(
            new DisputeModule(accessController, ipAssetRegistry, licenseRegistry, ipGraphACL)
        );
        vm.startPrank(upgrader);
        AccessManager(accessManager).schedule(
            address(disputeModule),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (newDisputeModuleImpl, "")),
            0 // earliest time possible
        );
        vm.warp(block.timestamp + 1 days);
        UUPSUpgradeable(disputeModule).upgradeToAndCall(newDisputeModuleImpl, "");

        // upgrade arbitration policy UMA
        address newArbitrationPolicyUMAImpl = address(
            new ArbitrationPolicyUMA(address(disputeModule), address(royaltyModule))
        );
        AccessManager(accessManager).schedule(
            address(arbitrationPolicyUMA),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (newArbitrationPolicyUMAImpl, "")),
            0 // earliest time possible
        );
        vm.warp(block.timestamp + 1 days);
        UUPSUpgradeable(arbitrationPolicyUMA).upgradeToAndCall(newArbitrationPolicyUMAImpl, "");
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
        vm.startPrank(protocolAdmin);
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroOOV3.selector);
        arbitrationPolicyUMA.setOOV3(address(0));
    }

    function test_ArbitrationPolicyUMA_setOOV3() public {
        address testOOV3 = address(1000);
        vm.expectEmit(true, true, true, true);
        emit OOV3Set(testOOV3);

        vm.startPrank(protocolAdmin);
        arbitrationPolicyUMA.setOOV3(testOOV3);

        assertEq(arbitrationPolicyUMA.oov3(), testOOV3);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_ZeroMinLiveness() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroMinLiveness.selector);
        arbitrationPolicyUMA.setLiveness(0, 10, 10);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_ZeroMaxLiveness() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroMaxLiveness.selector);
        arbitrationPolicyUMA.setLiveness(10, 0, 10);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_MinLivenessAboveMax() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(Errors.ArbitrationPolicyUMA__MinLivenessAboveMax.selector);
        arbitrationPolicyUMA.setLiveness(100, 10, 10);
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_IpOwnerTimePercentAboveMax() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(Errors.ArbitrationPolicyUMA__IpOwnerTimePercentAboveMax.selector);
        arbitrationPolicyUMA.setLiveness(10, 100, 100_000_001);
    }

    function test_ArbitrationPolicyUMA_setLiveness() public {
        vm.expectEmit(true, true, true, true);
        emit LivenessSet(10, 100, 10);

        vm.startPrank(protocolAdmin);
        arbitrationPolicyUMA.setLiveness(10, 100, 10);

        assertEq(arbitrationPolicyUMA.minLiveness(), 10);
        assertEq(arbitrationPolicyUMA.maxLiveness(), 100);
        assertEq(arbitrationPolicyUMA.ipOwnerTimePercent(), 10);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_paused() public {
        vm.startPrank(protocolPauseAdmin);
        arbitrationPolicyUMA.pause();
        vm.stopPrank();

        uint64 liveness = 1;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_LivenessBelowMin() public {
        uint64 liveness = 1;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__LivenessBelowMin.selector);
        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_LivenessAboveMax() public {
        uint64 liveness = 365 days + 1;
        IERC20 currency = IERC20(wip);
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__LivenessAboveMax.selector);
        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_setMaxBond_revert_MaxBondBelowMinimumBond() public {
        vm.startPrank(protocolAdmin);
        vm.expectRevert(Errors.ArbitrationPolicyUMA__MaxBondBelowMinimumBond.selector);
        arbitrationPolicyUMA.setMaxBond(wip, 0);
    }

    function test_ArbitrationPolicyUMA_setMaxBond() public {
        vm.startPrank(protocolAdmin);

        vm.expectEmit(true, true, true, true);
        emit MaxBondSet(wip, 1000e18);

        arbitrationPolicyUMA.setMaxBond(wip, 1000e18);

        assertEq(arbitrationPolicyUMA.maxBonds(wip), 1000e18);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__NotDisputeModule.selector);
        arbitrationPolicyUMA.onRaiseDispute(address(1), address(1), address(1), bytes32(0), bytes32(0), 1, bytes(""));
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_BondAboveMax() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = 25000e18;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__BondAboveMax.selector);
        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_CurrencyNotWhitelisted() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(address(new MockERC20()));
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(protocolAdmin);
        royaltyModule.whitelistRoyaltyToken(address(currency), false);
        vm.stopPrank();

        vm.expectRevert(Errors.ArbitrationPolicyUMA__CurrencyNotWhitelisted.selector);
        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_UnsupportedCurrency() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(address(new MockERC20()));
        uint256 bond = 0;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(protocolAdmin);
        royaltyModule.whitelistRoyaltyToken(address(currency), true);
        vm.stopPrank();

        vm.expectRevert("Unsupported currency");
        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);

        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);

        uint256 disputeId = disputeModule.disputeCounter();
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        assertFalse(arbitrationPolicyUMA.disputeIdToAssertionId(disputeId) == bytes32(0));
        assertEq(arbitrationPolicyUMA.assertionIdToDisputeId(assertionId), disputeId);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_WithBond() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;

        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);

        uint256 raiserBalBefore = currency.balanceOf(address(2));
        uint256 oov3BalBefore = currency.balanceOf(address(newOOV3));

        disputeModule.raiseDispute(randomIpId, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", data);

        uint256 raiserBalAfter = currency.balanceOf(address(2));
        uint256 oov3BalAfter = currency.balanceOf(address(newOOV3));

        assertEq(raiserBalBefore - raiserBalAfter, bond);
        assertEq(oov3BalAfter - oov3BalBefore, bond);

        uint256 disputeId = disputeModule.disputeCounter();
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        assertFalse(arbitrationPolicyUMA.disputeIdToAssertionId(disputeId) == bytes32(0));
        assertEq(arbitrationPolicyUMA.assertionIdToDisputeId(assertionId), disputeId);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_WithBondAndCallerDifferentFromDisputeInitiator() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;

        bytes memory data = abi.encode(liveness, currency, bond);

        address caller = address(10);
        vm.startPrank(caller);
        vm.deal(caller, disputeBond);
        IWIP(wip).deposit{ value: disputeBond }();
        IERC20(wip).approve(address(arbitrationPolicyUMA), disputeBond);

        uint256 raiserBalBefore = currency.balanceOf(caller);
        uint256 oov3BalBefore = currency.balanceOf(address(newOOV3));

        disputeModule.raiseDisputeOnBehalf(
            randomIpId,
            disputeInitiator,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        uint256 raiserBalAfter = currency.balanceOf(caller);
        uint256 oov3BalAfter = currency.balanceOf(address(newOOV3));

        assertEq(raiserBalBefore - raiserBalAfter, bond);
        assertEq(oov3BalAfter - oov3BalBefore, bond);

        uint256 disputeId = disputeModule.disputeCounter();
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        assertFalse(arbitrationPolicyUMA.disputeIdToAssertionId(disputeId) == bytes32(0));
        assertEq(arbitrationPolicyUMA.assertionIdToDisputeId(assertionId), disputeId);
    }

    function test_ArbitrationPolicyUMA_onDisputeCancel_revert_CannotCancel() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        vm.expectRevert(Errors.ArbitrationPolicyUMA__CannotCancel.selector);
        disputeModule.cancelDispute(disputeId, "");
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_revert_AssertionNotExpired() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // settle the assertion
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectRevert("Assertion not expired");
        IOOV3(newOOV3).settleAssertion(assertionId);
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithoutDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // wait for assertion to expire
        vm.warp(block.timestamp + liveness + 1);

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        // settle the assertion
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        IOOV3(newOOV3).settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithoutDisputeWithBond() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // wait for assertion to expire
        vm.warp(block.timestamp + liveness + 1);

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        uint256 disputerBalBefore = currency.balanceOf(disputeInitiator);

        // settle the assertion
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        IOOV3(newOOV3).settleAssertion(assertionId);

        uint256 disputerBalAfter = currency.balanceOf(disputeInitiator);

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
        assertEq(disputerBalAfter - disputerBalBefore, bond);
    }

    // solhint-disable-next-line max-line-length
    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithoutDisputeWithBondAndCallerDifferentFromDisputeInitiator()
        public
    {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        address caller = address(10);
        vm.startPrank(caller);
        vm.deal(caller, disputeBond);
        IWIP(wip).deposit{ value: disputeBond }();
        IERC20(wip).approve(address(arbitrationPolicyUMA), disputeBond);

        uint256 disputeId = disputeModule.raiseDisputeOnBehalf(
            randomIpId,
            disputeInitiator,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // wait for assertion to expire
        vm.warp(block.timestamp + liveness + 1);

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        uint256 disputerBalBefore = currency.balanceOf(disputeInitiator);
        uint256 callerBalBefore = currency.balanceOf(caller);

        // settle the assertion
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        IOOV3(newOOV3).settleAssertion(assertionId);

        uint256 disputerBalAfter = currency.balanceOf(disputeInitiator);
        uint256 callerBalAfter = currency.balanceOf(caller);
        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
        assertEq(disputerBalAfter - disputerBalBefore, bond);
        assertEq(callerBalAfter - callerBalBefore, 0);
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(randomIpId);
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");
        arbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        vm.startPrank(umaRegisteredContract);
        IOracleSpoke(oracleSpoke).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        vm.stopPrank();
        vm.startPrank(childMessenger);
        bytes memory message = abi.encode(
            bytes32("ASSERT_TRUTH"),
            assertionTimestamp,
            IOracleSpoke(oracleSpoke).stampAncillaryData(ancillaryData),
            1e18
        );
        IOracleSpoke(oracleSpoke).processMessageFromParent(message);
        vm.stopPrank();
        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("IMPROPER_REGISTRATION"));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_CannotDisputeAssertionTwice() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(randomIpId);
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");
        arbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        vm.expectRevert("Assertion already disputed");
        arbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_NoCounterEvidence() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(randomIpId);
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__NoCounterEvidence.selector);
        arbitrationPolicyUMA.disputeAssertion(assertionId, bytes32(0));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_DisputeNotFound() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        vm.expectRevert(Errors.ArbitrationPolicyUMA__DisputeNotFound.selector);
        arbitrationPolicyUMA.disputeAssertion(bytes32(0), bytes32("COUNTER_EVIDENCE_HASH"));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_revert_OnlyTargetIpIdCanDispute() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.startPrank(counterDisputer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ArbitrationPolicyUMA__OnlyTargetIpIdCanDisputeWithinTimeWindow.selector,
                0,
                liveness,
                counterDisputer
            )
        );
        arbitrationPolicyUMA.disputeAssertion(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_IPA() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // dispute the assertion
        vm.startPrank(randomIpId);
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");

        vm.expectEmit(true, true, true, true);
        emit IArbitrationPolicyUMA.AssertionDisputed(disputeId, assertionId, counterEvidenceHash);

        arbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        vm.startPrank(umaRegisteredContract);
        IOracleSpoke(oracleSpoke).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        vm.stopPrank();
        vm.startPrank(childMessenger);
        bytes memory message = abi.encode(
            bytes32("ASSERT_TRUTH"),
            assertionTimestamp,
            IOracleSpoke(oracleSpoke).stampAncillaryData(ancillaryData),
            0
        );
        IOracleSpoke(oracleSpoke).processMessageFromParent(message);
        vm.stopPrank();
        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_NotIPA() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        vm.warp(block.timestamp + ((liveness * 66_666_666) / 100_000_000) + 1);

        // dispute the assertion
        vm.startPrank(counterDisputer);
        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");

        vm.expectEmit(true, true, true, true);
        emit IArbitrationPolicyUMA.AssertionDisputed(disputeId, assertionId, counterEvidenceHash);

        arbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        vm.startPrank(umaRegisteredContract);
        IOracleSpoke(oracleSpoke).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        vm.stopPrank();
        vm.startPrank(childMessenger);
        bytes memory message = abi.encode(
            bytes32("ASSERT_TRUTH"),
            assertionTimestamp,
            IOracleSpoke(oracleSpoke).stampAncillaryData(ancillaryData),
            0
        );
        IOracleSpoke(oracleSpoke).processMessageFromParent(message);
        vm.stopPrank();
        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
    }

    function test_ArbitrationPolicyUMA_disputeAssertion_WithBondAndIpTagged() public {
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(wip);
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        // raise dispute
        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );
        vm.stopPrank();

        // dispute the assertion
        vm.startPrank(randomIpId);

        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectEmit(true, true, true, true);
        emit IArbitrationPolicyUMA.AssertionDisputed(disputeId, assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        arbitrationPolicyUMA.disputeAssertion(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        vm.startPrank(umaRegisteredContract);
        IOracleSpoke(oracleSpoke).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        vm.stopPrank();
        vm.startPrank(childMessenger);
        bytes memory message = abi.encode(
            bytes32("ASSERT_TRUTH"),
            assertionTimestamp,
            IOracleSpoke(oracleSpoke).stampAncillaryData(ancillaryData),
            1e18
        );
        IOracleSpoke(oracleSpoke).processMessageFromParent(message);
        vm.stopPrank();

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalBefore = currency.balanceOf(disputeInitiator);
        uint256 defenderIpIdOwnerBalBefore = currency.balanceOf(randomIpId);

        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalAfter = currency.balanceOf(disputeInitiator);
        uint256 defenderIpIdOwnerBalAfter = currency.balanceOf(randomIpId);

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
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        // raise dispute
        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );
        vm.stopPrank();

        // dispute the assertion
        vm.startPrank(randomIpId);

        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectEmit(true, true, true, true);
        emit IArbitrationPolicyUMA.AssertionDisputed(disputeId, assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        arbitrationPolicyUMA.disputeAssertion(assertionId, bytes32("COUNTER_EVIDENCE_HASH"));

        // settle the assertion
        IOOV3 oov3 = IOOV3(newOOV3);
        IOOV3.Assertion memory assertion = oov3.getAssertion(assertionId);
        uint64 assertionTimestamp = assertion.assertionTime;
        bytes memory ancillaryData = AuxiliaryOOV3Interface(newOOV3).stampAssertion(assertionId);
        vm.startPrank(umaRegisteredContract);
        IOracleSpoke(oracleSpoke).requestPrice(bytes32("ASSERT_TRUTH"), assertionTimestamp, ancillaryData);
        vm.stopPrank();
        vm.startPrank(childMessenger);
        bytes memory message = abi.encode(
            bytes32("ASSERT_TRUTH"),
            assertionTimestamp,
            IOracleSpoke(oracleSpoke).stampAncillaryData(ancillaryData),
            0
        );
        IOracleSpoke(oracleSpoke).processMessageFromParent(message);
        vm.stopPrank();

        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalBefore = currency.balanceOf(disputeInitiator);
        uint256 defenderIpIdOwnerBalBefore = currency.balanceOf(randomIpId);

        oov3.settleAssertion(assertionId);

        (, , , , , , bytes32 currentTagAfter, ) = disputeModule.disputes(disputeId);

        uint256 disputeInitiatorBalAfter = currency.balanceOf(disputeInitiator);
        uint256 defenderIpIdOwnerBalAfter = currency.balanceOf(randomIpId);

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
        uint256 bond = disputeBond;
        bytes memory data = abi.encode(liveness, currency, bond);

        vm.startPrank(disputeInitiator);
        uint256 disputeId = disputeModule.raiseDispute(
            randomIpId,
            disputeEvidenceHashExample,
            "IMPROPER_REGISTRATION",
            data
        );

        // warp
        vm.warp(block.timestamp + 4 days);

        // set the IpOwnerTimePercent to 0%
        vm.startPrank(protocolAdmin);
        arbitrationPolicyUMA.setLiveness(10, 100, 0);
        vm.stopPrank();

        bytes32 assertionId = arbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        bytes32 counterEvidenceHash = bytes32("COUNTER_EVIDENCE_HASH");

        vm.startPrank(counterDisputer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ArbitrationPolicyUMA__OnlyTargetIpIdCanDisputeWithinTimeWindow.selector,
                4 days,
                liveness,
                counterDisputer
            )
        );
        arbitrationPolicyUMA.disputeAssertion(assertionId, counterEvidenceHash);
    }

    function test_ArbitrationPolicyUMA_assertionDisputedCallback_revert_NotOOV3() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__NotOOV3.selector);
        arbitrationPolicyUMA.assertionDisputedCallback(bytes32(0));
    }

    function test_ArbitrationPolicyUMA_assertionDisputedCallback_revert_NoCounterEvidence() public {
        vm.startPrank(newOOV3);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__NoCounterEvidence.selector);
        arbitrationPolicyUMA.assertionDisputedCallback(bytes32(0));
    }
}

interface AuxiliaryOOV3Interface {
    function stampAssertion(bytes32 assertionId) external view returns (bytes memory);
}

interface IWIP is IERC20 {
    function deposit() external payable;
}

interface IOracleSpoke {
    function requestPrice(bytes32 identifier, uint256 time, bytes memory ancillaryData) external;

    function processMessageFromParent(bytes memory data) external;

    function stampAncillaryData(bytes memory ancillaryData) external returns (bytes memory);
}
