// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DisputeModule } from "contracts/modules/dispute/DisputeModule.sol";
import { ArbitrationPolicyUMA } from "contracts/modules/dispute/policies/UMA/ArbitrationPolicyUMA.sol";
import { IOptimisticOracleV3 } from "contracts/interfaces/modules/dispute/policies/UMA/IOptimisticOracleV3.sol";
import { Errors } from "contracts/lib/Errors.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
import { MockIpAssetRegistry } from "test/foundry/mocks/dispute/MockIpAssetRegistry.sol";
import { TestProxyHelper } from "test/foundry/utils/TestProxyHelper.sol";

contract ArbitrationPolicyUMATest is BaseTest {
    MockIpAssetRegistry mockIpAssetRegistry;
    ArbitrationPolicyUMA newArbitrationPolicyUMA;
    DisputeModule newDisputeModule;
    address internal newOptimisticOracleV3;
    AccessManager newAccessManager;
    address internal newAdmin;
    address internal susd;

    bytes32 internal disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;

    function setUp() public virtual override {
        // Fork the desired network where UMA contracts are deployed
        uint256 forkId = vm.createFork("https://testnet.storyrpc.io");
        vm.selectFork(forkId);

        // Illiad chain 1513
        newOptimisticOracleV3 = 0x3CA11702f7c0F28e0b4e03C31F7492969862C569;
        susd = 0x91f6F05B08c16769d3c85867548615d270C42fC7;

        // deploy mock ip asset registry
        mockIpAssetRegistry = new MockIpAssetRegistry();

        // deploy access manager
        newAdmin = address(100);
        newAccessManager = new AccessManager(newAdmin);

        vm.startPrank(newAdmin);

        // deploy dispute module
        address newDisputeModuleImpl = address(
            new DisputeModule(address(newAccessManager), address(mockIpAssetRegistry), address(2))
        );
        newDisputeModule = DisputeModule(
            TestProxyHelper.deployUUPSProxy(
                newDisputeModuleImpl,
                abi.encodeCall(DisputeModule.initialize, address(newAccessManager))
            )
        );

        // deploy arbitration policy UMA
        address newArbitrationPolicyUMAImpl = address(
            new ArbitrationPolicyUMA(address(newDisputeModule), newOptimisticOracleV3)
        );
        newArbitrationPolicyUMA = ArbitrationPolicyUMA(
            TestProxyHelper.deployUUPSProxy(
                newArbitrationPolicyUMAImpl,
                abi.encodeCall(ArbitrationPolicyUMA.initialize, address(newAccessManager))
            )
        );

        // setup UMA parameters
        newArbitrationPolicyUMA.setLiveness(30 days, 365 days);
        newArbitrationPolicyUMA.setMaxBond(susd, 25000e18); // 25k USD max bond

        // whitelist dispute tag, arbitration policy and arbitration relayer
        newDisputeModule.whitelistDisputeTag("PLAGIARISM", true);
        newDisputeModule.whitelistArbitrationPolicy(address(newArbitrationPolicyUMA), true);
        newDisputeModule.whitelistArbitrationRelayer(
            address(newArbitrationPolicyUMA),
            address(newArbitrationPolicyUMA),
            true
        );
        newDisputeModule.setBaseArbitrationPolicy(address(newArbitrationPolicyUMA));
    }

    function test_ArbitrationPolicyUMA_constructor_revert_ZeroDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroDisputeModule.selector);
        new ArbitrationPolicyUMA(address(0), address(1));
    }

    function test_ArbitrationPolicyUMA_constructor_revert_ZeroOptimisticOracleV3() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroOptimisticOracleV3.selector);
        new ArbitrationPolicyUMA(address(1), address(0));
    }

    function test_ArbitrationPolicyUMA_setLiveness_revert_ZeroMinLiveness() public {
        vm.expectRevert(Errors.ArbitrationPolicyUMA__ZeroMinLiveness.selector);
        newArbitrationPolicyUMA.setLiveness(0, 10);
    }

    function test_ArbitrationPolicyUMA_setLiveness() public {
        newArbitrationPolicyUMA.setLiveness(10, 100);
        assertEq(newArbitrationPolicyUMA.minLiveness(), 10);
        assertEq(newArbitrationPolicyUMA.maxLiveness(), 100);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_LivenessBelowMin() public {
        bytes memory claim = "test claim";
        uint64 liveness = 1;
        IERC20 currency = IERC20(susd);
        uint256 bond = 0;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__LivenessBelowMin.selector);
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_LivenessAboveMax() public {
        bytes memory claim = "test claim";
        uint64 liveness = 365 days + 1;
        IERC20 currency = IERC20(susd);
        uint256 bond = 0;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__LivenessAboveMax.selector);
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_BondAboveMax() public {
        bytes memory claim = "test claim";
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(susd);
        uint256 bond = 25000e18 + 1;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__BondAboveMax.selector);
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_UnsupportedCurrency() public {
        bytes memory claim = "test claim";
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(address(1));
        uint256 bond = 0;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        vm.expectRevert("Unsupported currency");
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute_revert_UnsupportedIdentifier() public {
        bytes memory claim = "test claim";
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(susd);
        uint256 bond = 0;
        bytes32 identifier = bytes32("RANDOM_IDENTIFIER");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        vm.expectRevert("Unsupported identifier");
        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);
    }

    function test_ArbitrationPolicyUMA_onRaiseDispute() public {
        bytes memory claim = "test claim";
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(susd);
        uint256 bond = 0;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);

        uint256 disputeId = newDisputeModule.disputeCounter();
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        assertFalse(newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId) == bytes32(0));
        assertEq(newArbitrationPolicyUMA.assertionIdToDisputeId(assertionId), disputeId);
    }

    function test_ArbitrationPolicyUMA_onDisputeCancel_revert_CannotCancel() public {
        bytes memory claim = "test claim";
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(susd);
        uint256 bond = 0;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);

        vm.expectRevert(Errors.ArbitrationPolicyUMA__CannotCancel.selector);
        newDisputeModule.cancelDispute(1, "");
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_revert_AssertionNotExpired() public {
        bytes memory claim = "test claim";
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(susd);
        uint256 bond = 0;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        uint256 disputeId = newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);

        // settle the assertion
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);

        vm.expectRevert("Assertion not expired");
        IOptimisticOracleV3(newOptimisticOracleV3).settleAssertion(assertionId);
    }

    function test_ArbitrationPolicyUMA_onDisputeJudgement_AssertionWithoutDispute() public {
        bytes memory claim = "test claim";
        uint64 liveness = 3600 * 24 * 30;
        IERC20 currency = IERC20(susd);
        uint256 bond = 0;
        bytes32 identifier = bytes32("ASSERT_TRUTH");

        bytes memory data = abi.encode(claim, liveness, currency, bond, identifier);

        uint256 disputeId = newDisputeModule.raiseDispute(address(1), disputeEvidenceHashExample, "PLAGIARISM", data);

        // wait for assertion to expire
        vm.warp(block.timestamp + liveness + 1);

        (, , , , , bytes32 currentTagBefore, ) = newDisputeModule.disputes(disputeId);

        // settle the assertion
        bytes32 assertionId = newArbitrationPolicyUMA.disputeIdToAssertionId(disputeId);
        IOptimisticOracleV3(newOptimisticOracleV3).settleAssertion(assertionId);

        (, , , , , bytes32 currentTagAfter, ) = newDisputeModule.disputes(disputeId);

        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("PLAGIARISM"));
    }
}
