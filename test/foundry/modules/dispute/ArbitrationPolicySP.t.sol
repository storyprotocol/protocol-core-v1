// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
// contracts
import { Errors } from "contracts/lib/Errors.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute/policies/ArbitrationPolicySP.sol";
import { PILPolicy } from "contracts/modules/licensing/PILPolicyFrameworkManager.sol";
import { IP } from "contracts/lib/IP.sol";
// test
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract TestArbitrationPolicySP is BaseTest {
    event GovernanceWithdrew(uint256 amount);

    address internal ipAccount1 = address(0x111000aaa);

    address public ipAddr;
    address internal arbitrationRelayer;

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

        USDC.mint(ipAccount1, 10000 * 10 ** 6);

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

        mockNFT.mintId(u.admin, 0);

        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            address(mockNFT),
            0
        );
        vm.label(expectedAddr, "IPAccount0");

        vm.startPrank(u.admin);
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
                    registrant: u.admin,
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

    function test_ArbitrationPolicySP_constructor_ZeroDisputeModule() public {
        address disputeModule = address(0);
        address paymentToken = address(1);
        uint256 arbitrationPrice = 1000;
        address governance = address(3);

        vm.expectRevert(Errors.ArbitrationPolicySP__ZeroDisputeModule.selector);
        new ArbitrationPolicySP(disputeModule, paymentToken, arbitrationPrice, governance);
    }

    function test_ArbitrationPolicySP_constructor_ZeroPaymentToken() public {
        address disputeModule = address(1);
        address paymentToken = address(0);
        uint256 arbitrationPrice = 1000;
        address governance = address(3);

        vm.expectRevert(Errors.ArbitrationPolicySP__ZeroPaymentToken.selector);
        new ArbitrationPolicySP(disputeModule, paymentToken, arbitrationPrice, governance);
    }

    function test_ArbitrationPolicySP_constructor() public {
        address disputeModule = address(1);
        address paymentToken = address(2);
        uint256 arbitrationPrice = 1000;
        address governance = address(3);

        ArbitrationPolicySP arbitrationPolicySP = new ArbitrationPolicySP(
            disputeModule,
            paymentToken,
            arbitrationPrice,
            address(3)
        );

        assertEq(address(arbitrationPolicySP.DISPUTE_MODULE()), disputeModule);
        assertEq(address(arbitrationPolicySP.PAYMENT_TOKEN()), paymentToken);
        assertEq(arbitrationPolicySP.ARBITRATION_PRICE(), arbitrationPrice);
        assertEq(arbitrationPolicySP.governance(), governance);
    }

    function test_ArbitrationPolicySP_onRaiseDispute_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicySP__NotDisputeModule.selector);
        arbitrationPolicySP.onRaiseDispute(address(1), new bytes(0));
    }

    function test_ArbitrationPolicySP_onRaiseDispute() public {
        address caller = ipAccount1;
        vm.startPrank(caller);
        USDC.approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        vm.stopPrank();

        USDC.mint(caller, 10000 * 10 ** 6);

        vm.startPrank(address(disputeModule));

        uint256 userUSDCBalBefore = USDC.balanceOf(caller);
        uint256 arbitrationContractBalBefore = USDC.balanceOf(address(arbitrationPolicySP));

        arbitrationPolicySP.onRaiseDispute(caller, new bytes(0));

        uint256 userUSDCBalAfter = USDC.balanceOf(caller);
        uint256 arbitrationContractBalAfter = USDC.balanceOf(address(arbitrationPolicySP));

        assertEq(userUSDCBalBefore - userUSDCBalAfter, ARBITRATION_PRICE);
        assertEq(arbitrationContractBalAfter - arbitrationContractBalBefore, ARBITRATION_PRICE);
    }

    function test_ArbitrationPolicySP_onDisputeJudgement_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicySP__NotDisputeModule.selector);
        arbitrationPolicySP.onDisputeJudgement(1, true, new bytes(0));
    }

    function test_ArbitrationPolicySP_onDisputeJudgement_True() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, ARBITRATION_PRICE);
    }

    function test_ArbitrationPolicySP_onDisputeJudgement_False() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, false, "");

        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, 0);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, 0);
    }

    function test_ArbitrationPolicySP_onDisputeCancel_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicySP__NotDisputeModule.selector);
        arbitrationPolicySP.onDisputeCancel(address(1), 1, new bytes(0));
    }

    function test_ArbitrationPolicySP_governanceWithdraw() public {
        // send USDC to arbitration policy
        uint256 mintAmount = 10000 * 10 ** 6;
        USDC.mint(address(arbitrationPolicySP), mintAmount);

        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));
        uint256 governanceUSDCBalanceBefore = USDC.balanceOf(address(governance));

        vm.expectEmit(true, true, true, true, address(arbitrationPolicySP));
        emit GovernanceWithdrew(mintAmount);

        vm.startPrank(u.admin);
        arbitrationPolicySP.governanceWithdraw();
        vm.stopPrank();

        uint256 governanceUSDCBalanceAfter = USDC.balanceOf(address(governance));
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

        assertEq(governanceUSDCBalanceAfter - governanceUSDCBalanceBefore, mintAmount);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, mintAmount);
    }
}
