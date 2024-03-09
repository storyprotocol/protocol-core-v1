// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
// contracts
import { Errors } from "contracts/lib/Errors.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute/policies/ArbitrationPolicySP.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { PILPolicy } from "contracts/modules/licensing/PILPolicyFrameworkManager.sol";
import { IP } from "contracts/lib/IP.sol";
// test
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract DisputeModuleTest is BaseTest {
    event TagWhitelistUpdated(bytes32 tag, bool allowed);
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);
    event ArbitrationRelayerWhitelistUpdated(address arbitrationPolicy, address arbitrationRelayer, bool allowed);
    event DisputeRaised(
        uint256 disputeId,
        address targetIpId,
        address disputeInitiator,
        address arbitrationPolicy,
        bytes32 linkToDisputeEvidence,
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
    address internal arbitrationRelayer;
    ArbitrationPolicySP internal arbitrationPolicySP2;

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({ disputeModule: true, royaltyModule: false, licensingModule: false })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ arbitrationPolicySP: true, royaltyPolicyLAP: true }));
        buildDeployMiscCondition(
            DeployMiscCondition({ ipAssetRenderer: false, ipMetadataProvider: false, ipResolver: true })
        );
        deployConditionally();
        postDeploymentSetup();

        arbitrationRelayer = u.admin;

        USDC.mint(ipAccount1, 1000 * 10 ** 6);

        // second arbitration policy
        arbitrationPolicySP2 = new ArbitrationPolicySP(
            getDisputeModule(),
            address(USDC),
            ARBITRATION_PRICE,
            getGovernance()
        );

        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP2), true);
        disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP2));
        vm.stopPrank();

        _setPILPolicyFrameworkManager();
        _addPILPolicy(
            "cheap_flexible",
            true,
            address(royaltyPolicyLAP),
            PILPolicy({
                attribution: false,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            })
        );

        mockNFT.mintId(u.alice, 0);

        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            address(mockNFT),
            0
        );
        vm.label(expectedAddr, "IPAccount0");

        vm.startPrank(u.alice);
        ipAddr = ipAssetRegistry.register(
            block.chainid,
            address(mockNFT),
            0,
            address(ipResolver),
            true,
            abi.encode(
                IP.MetadataV1({
                    name: "IPAccount0",
                    hash: bytes32("content hash"),
                    registrationDate: uint64(block.timestamp),
                    registrant: u.alice,
                    uri: "https://example.com/test-ip"
                })
            )
        );
        licensingModule.addPolicyToIp(ipAddr, policyIds["pil_cheap_flexible"]);

        // set arbitration policy
        vm.startPrank(ipAddr);
        disputeModule.setArbitrationPolicy(ipAddr, address(arbitrationPolicySP));
        vm.stopPrank();
    }

    function test_DisputeModule_whitelistDisputeTag_revert_ZeroDisputeTag() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__ZeroDisputeTag.selector);
        disputeModule.whitelistDisputeTag(bytes32(0), true);
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
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), address(0), true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer() public {
        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationRelayerWhitelistUpdated(address(arbitrationPolicySP), address(1), true);

        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), address(1), true);

        assertEq(disputeModule.isWhitelistedArbitrationRelayer(address(arbitrationPolicySP), address(1)), true);
    }

    function test_DisputeModule_setBaseArbitrationPolicy_revert_NotWhitelistedArbitrationPolicy() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationPolicy.selector);
        disputeModule.setBaseArbitrationPolicy(address(0));
    }

    function test_DisputeModule_setBaseArbitrationPolicy() public {
        vm.startPrank(u.admin);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DefaultArbitrationPolicyUpdated(address(arbitrationPolicySP2));

        disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP2));

        assertEq(disputeModule.baseArbitrationPolicy(), address(arbitrationPolicySP2));
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
        disputeModule.setArbitrationPolicy(ipAddr, address(arbitrationPolicySP2));
    }

    function test_DisputeModule_setArbitrationPolicy_revert_NotWhitelistedArbitrationPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP2), false);
        vm.stopPrank();

        vm.startPrank(ipAddr);
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationPolicy.selector);
        disputeModule.setArbitrationPolicy(ipAddr, address(arbitrationPolicySP2));
    }

    function test_setArbitrationPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP2), true);
        vm.stopPrank();

        vm.startPrank(ipAddr);

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationPolicySet(ipAddr, address(arbitrationPolicySP2));

        disputeModule.setArbitrationPolicy(ipAddr, address(arbitrationPolicySP2));
        assertEq(disputeModule.arbitrationPolicies(ipAddr), address(arbitrationPolicySP2));
    }

    function test_DisputeModule_PolicySP_raiseDispute_revert_NotRegisteredIpId() public {
        vm.expectRevert(Errors.DisputeModule__NotRegisteredIpId.selector);
        disputeModule.raiseDispute(address(1), string("urlExample"), "PLAGIARISM", "");
    }

    function test_DisputeModule_PolicySP_raiseDispute_revert_NotWhitelistedDisputeTag() public {
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedDisputeTag.selector);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "NOT_WHITELISTED", "");
    }

    function test_DisputeModule_PolicySP_raiseDispute_revert_ZeroLinkToDisputeEvidence() public {
        vm.expectRevert(Errors.DisputeModule__ZeroLinkToDisputeEvidence.selector);
        disputeModule.raiseDispute(ipAddr, string(""), "PLAGIARISM", "");
    }

    function test_DisputeModule_PolicySP_raiseDispute_BlacklistedPolicy() public {
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), false);
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP2), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(USDC).balanceOf(address(arbitrationPolicySP2));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            address(arbitrationPolicySP2),
            ShortStringOps.stringToBytes32("urlExample"),
            bytes32("PLAGIARISM"),
            ""
        );

        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(USDC).balanceOf(address(arbitrationPolicySP2));

        (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 linkToDisputeEvidence,
            bytes32 targetTag,
            bytes32 currentTag
        ) = disputeModule.disputes(disputeIdAfter);

        assertEq(disputeIdAfter - disputeIdBefore, 1);
        assertEq(ipAccount1USDCBalanceBefore - ipAccount1USDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceAfter - arbitrationPolicySPUSDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(targetIpId, ipAddr);
        assertEq(disputeInitiator, ipAccount1);
        assertEq(arbitrationPolicy, address(arbitrationPolicySP2));
        assertEq(linkToDisputeEvidence, ShortStringOps.stringToBytes32("urlExample"));
        assertEq(targetTag, bytes32("PLAGIARISM"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
    }

    function test_DisputeModule_PolicySP_raiseDispute() public {
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeRaised(
            disputeIdBefore + 1,
            ipAddr,
            ipAccount1,
            address(arbitrationPolicySP),
            ShortStringOps.stringToBytes32("urlExample"),
            bytes32("PLAGIARISM"),
            ""
        );

        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");

        uint256 disputeIdAfter = disputeModule.disputeCounter();
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

        (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 linkToDisputeEvidence,
            bytes32 targetTag,
            bytes32 currentTag
        ) = disputeModule.disputes(disputeIdAfter);

        assertEq(disputeIdAfter - disputeIdBefore, 1);
        assertEq(ipAccount1USDCBalanceBefore - ipAccount1USDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceAfter - arbitrationPolicySPUSDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(targetIpId, ipAddr);
        assertEq(disputeInitiator, ipAccount1);
        assertEq(arbitrationPolicy, address(arbitrationPolicySP));
        assertEq(linkToDisputeEvidence, ShortStringOps.stringToBytes32("urlExample"));
        assertEq(targetTag, bytes32("PLAGIARISM"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_revert_NotInDisputeState() public {
        vm.expectRevert(Errors.DisputeModule__NotInDisputeState.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_revert_NotWhitelistedArbitrationRelayer() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationRelayer.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_True() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        (, , , , , bytes32 currentTagBefore) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, true, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        (, , , , , bytes32 currentTagAfter) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("PLAGIARISM"));
        assertTrue(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_False() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        (, , , , , bytes32 currentTagBefore) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, false, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, false, "");

        (, , , , , bytes32 currentTagAfter) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, 0);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, 0);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_PolicySP_cancelDispute_revert_NotDisputeInitiator() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.cancelDispute(1, "");
    }

    function test_DisputeModule_PolicySP_cancelDispute_revert_NotInDisputeState() public {
        vm.expectRevert(Errors.DisputeModule__NotInDisputeState.selector);
        disputeModule.cancelDispute(1, "");
    }

    function test_DisputeModule_PolicySP_cancelDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        (, , , , , bytes32 currentTagBeforeCancel) = disputeModule.disputes(1);

        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeCancelled(1, "");

        disputeModule.cancelDispute(1, "");
        vm.stopPrank();

        (, , , , , bytes32 currentTagAfterCancel) = disputeModule.disputes(1);

        assertEq(currentTagBeforeCancel, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfterCancel, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));
    }

    function test_DisputeModule_resolveDispute_revert_NotDisputeInitiator() public {
        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.resolveDispute(1);
    }

    function test_DisputeModule_resolveDispute_revert_NotAbleToResolve() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        vm.expectRevert(Errors.DisputeModule__NotAbleToResolve.selector);
        disputeModule.resolveDispute(1);
    }

    function test_DisputeModule_resolveDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        (, , , , , bytes32 currentTagBeforeResolve) = disputeModule.disputes(1);

        // resolve dispute
        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeResolved(1);

        disputeModule.resolveDispute(1);

        (, , , , , bytes32 currentTagAfterResolve) = disputeModule.disputes(1);

        assertEq(currentTagBeforeResolve, bytes32("PLAGIARISM"));
        assertEq(currentTagAfterResolve, bytes32(0));
        assertFalse(disputeModule.isIpTagged(ipAddr));

        // Cant resolve again
        vm.expectRevert(Errors.DisputeModule__NotAbleToResolve.selector);
        disputeModule.resolveDispute(1);
        vm.stopPrank();
    }

    function test_DisputeModule_name() public {
        assertEq(IModule(address(disputeModule)).name(), "DISPUTE_MODULE");
    }
}
