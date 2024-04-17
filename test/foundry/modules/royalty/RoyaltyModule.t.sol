// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// contracts
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { RoyaltyModule } from "../../../../contracts/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";

// tests
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../../utils/TestProxyHelper.sol";

contract TestRoyaltyModule is BaseTest {
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);
    event RoyaltyPolicySet(address ipId, address royaltyPolicy, bytes data);
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);
    event LicenseMintingFeePaid(address receiverIpId, address payerAddress, address token, uint256 amount);

    address internal ipAccount1 = address(0x111000aaa);
    address internal ipAccount2 = address(0x111000bbb);
    address internal ipAddr;
    address internal arbitrationRelayer;
    RoyaltyPolicyLAP internal royaltyPolicyLAP2;

    function setUp() public override {
        super.setUp();

        USDC.mint(ipAccount2, 1000 * 10 ** 6); // 1000 USDC

        address impl = address(new RoyaltyPolicyLAP(address(royaltyModule), address(licensingModule)));
        royaltyPolicyLAP2 = RoyaltyPolicyLAP(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyPolicyLAP.initialize, address(protocolAccessManager))
            )
        );

        arbitrationRelayer = u.relayer;

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

        USDC.mint(ipAccount1, 1000 * 10 ** 6);

        registerSelectedPILicenseTerms_Commercial({
            selectionName: "cheap_flexible",
            transferable: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 10,
            mintingFee: 0
        });

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
        ipAddr = ipAssetRegistry.register(block.chainid, address(mockNFT), 0);

        licensingModule.attachLicenseTerms(ipAddr, address(pilTemplate), getSelectedPILicenseTermsId("cheap_flexible"));

        // set arbitration policy
        vm.startPrank(ipAddr);
        disputeModule.setArbitrationPolicy(ipAddr, address(arbitrationPolicySP));
        vm.stopPrank();
    }

    function _setupTree() internal {
        // init royalty policy for roots
        royaltyModule.onLicenseMinting(address(2), address(royaltyPolicyLAP), abi.encode(uint32(7)), "");
        royaltyModule.onLicenseMinting(address(8), address(royaltyPolicyLAP), abi.encode(uint32(8)), "");

        // init 2nd level with children
        address[] memory parents = new address[](2);
        uint32[] memory parentRoyalties = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);

        // 3 is child of 2 and 8
        parents[0] = address(2);
        parents[1] = address(8);
        parentRoyalties[0] = 7;
        parentRoyalties[1] = 8;
        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        royaltyModule.onLinkToParents(address(3), address(royaltyPolicyLAP), parents, encodedLicenseData, "");
    }
    function test_RoyaltyModule_initialize_revert_ZeroAccessManager() public {
        address impl = address(
            new RoyaltyModule(address(licensingModule), address(disputeModule), address(licenseRegistry))
        );
        vm.expectRevert(Errors.RoyaltyModule__ZeroAccessManager.selector);
        RoyaltyModule(TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(RoyaltyModule.initialize, address(0))));
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
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licenseData, "");
    }

    function test_RoyaltyModule_onLicenseMinting_Root() public {
        address licensor = address(2);
        bytes memory licenseData = abi.encode(uint32(15));

        // mint a license of another policy
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licenseData, "");
        vm.stopPrank();

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licenseData, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_NotWhitelistedRoyaltyPolicy() public {
        address newChild = address(9);
        address[] memory parents = new address[](2);
        uint32[] memory parentRoyalties = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);
        parents[0] = address(2);
        parents[1] = address(8);
        parentRoyalties[0] = 7;
        parentRoyalties[1] = 8;
        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.onLinkToParents(newChild, address(1), parents, encodedLicenseData, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_NoParentsOnLinking() public {
        address newChild = address(9);
        address[] memory parents = new address[](0);
        uint32[] memory parentRoyalties = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);
        parentRoyalties[0] = 7;
        parentRoyalties[1] = 8;
        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NoParentsOnLinking.selector);
        royaltyModule.onLinkToParents(newChild, address(royaltyPolicyLAP), parents, encodedLicenseData, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_IncompatibleRoyaltyPolicy() public {
        address newChild = address(9);
        address[] memory parents = new address[](2);
        uint32[] memory parentRoyalties = new uint32[](1);
        bytes[] memory encodedLicenseData = new bytes[](2);
        parents[0] = address(3);
        parentRoyalties[0] = 3;
        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP2), true);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__IncompatibleRoyaltyPolicy.selector);
        royaltyModule.onLinkToParents(newChild, address(royaltyPolicyLAP2), parents, encodedLicenseData, "");
    }

    function test_RoyaltyModule_onLinkToParents() public {
        address newChild = address(9);

        // new child is linked to 7 and 8
        address[] memory parents = new address[](2);
        uint32[] memory parentRoyalties = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);
        parents[0] = address(2);
        parents[1] = address(8);
        parentRoyalties[0] = 7;
        parentRoyalties[1] = 8;
        for (uint32 i = 0; i < parentRoyalties.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties[i]);
        }
        vm.startPrank(address(licensingModule));
        royaltyModule.onLinkToParents(newChild, address(royaltyPolicyLAP), parents, encodedLicenseData, "");

        assertEq(royaltyModule.royaltyPolicies(newChild), address(royaltyPolicyLAP));
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NoRoyaltyPolicySet() public {
        vm.expectRevert(Errors.RoyaltyModule__NoRoyaltyPolicySet.selector);

        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, address(USDC), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyToken() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerIpId = address(3);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyToken.selector);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(1), royaltyAmount);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_IpIsTagged() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        USDC.approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        vm.expectRevert(Errors.RoyaltyModule__IpIsTagged.selector);
        royaltyModule.payRoyaltyOnBehalf(ipAddr, ipAccount1, address(USDC), 100);

        vm.expectRevert(Errors.RoyaltyModule__IpIsTagged.selector);
        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAddr, address(USDC), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyPolicy() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerIpId = address(3);

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), false);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_paused() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(7);
        address payerIpId = address(3);
        vm.prank(u.admin);
        royaltyModule.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_IpIsExpired() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerIpId = address(3);

        (, address ipRoyaltyVault, , , ) = royaltyPolicyLAP.getRoyaltyData(receiverIpId);

        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);

        vm.warp(block.timestamp + licenseRegistry.getExpireTime(receiverIpId) + 1);

        vm.expectRevert(Errors.RoyaltyModule__IpIsExpired.selector);
        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerIpId = address(3);

        (, address ipRoyaltyVault, , , ) = royaltyPolicyLAP.getRoyaltyData(receiverIpId);

        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);

        uint256 payerIpIdUSDCBalBefore = USDC.balanceOf(payerIpId);
        uint256 ipRoyaltyVaultUSDCBalBefore = USDC.balanceOf(ipRoyaltyVault);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPaid(receiverIpId, payerIpId, payerIpId, address(USDC), royaltyAmount);

        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);

        uint256 payerIpIdUSDCBalAfter = USDC.balanceOf(payerIpId);
        uint256 ipRoyaltyVaultUSDCBalAfter = USDC.balanceOf(ipRoyaltyVault);

        assertEq(payerIpIdUSDCBalBefore - payerIpIdUSDCBalAfter, royaltyAmount);
        assertEq(ipRoyaltyVaultUSDCBalAfter - ipRoyaltyVaultUSDCBalBefore, royaltyAmount);
    }

    function test_RoyaltyModule_payLicenseMintingFee_revert_IpIsTagged() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        USDC.approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        vm.startPrank(address(licensingModule));

        vm.expectRevert(Errors.RoyaltyModule__IpIsTagged.selector);
        royaltyModule.payLicenseMintingFee(ipAddr, ipAccount1, address(royaltyPolicyLAP), address(USDC), 100);
    }

    function test_RoyaltyModule_payLicenseMintingFee_revert_NotWhitelistedRoyaltyToken() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerAddress = address(3);
        address licenseRoyaltyPolicy = address(royaltyPolicyLAP);
        address token = address(1);
        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyToken.selector);
        royaltyModule.payLicenseMintingFee(receiverIpId, payerAddress, licenseRoyaltyPolicy, token, royaltyAmount);
    }

    function test_RoyaltyModule_payLicenseMintingFee_revert_NotWhitelistedRoyaltyPolicy() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerAddress = address(3);
        address licenseRoyaltyPolicy = address(1);
        address token = address(USDC);
        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), false);
        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.payLicenseMintingFee(receiverIpId, payerAddress, licenseRoyaltyPolicy, token, royaltyAmount);
    }

    function test_RoyaltyModule_payLicenseMintingFee_revert_IpIsExpired() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerAddress = address(3);
        address licenseRoyaltyPolicy = address(royaltyPolicyLAP);
        address token = address(USDC);

        (, address ipRoyaltyVault, , , ) = royaltyPolicyLAP.getRoyaltyData(receiverIpId);

        vm.startPrank(payerAddress);
        USDC.mint(payerAddress, royaltyAmount);
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        vm.stopPrank;

        vm.warp(block.timestamp + licenseRegistry.getExpireTime(receiverIpId) + 1);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__IpIsExpired.selector);
        royaltyModule.payLicenseMintingFee(receiverIpId, payerAddress, licenseRoyaltyPolicy, token, royaltyAmount);
    }

    function test_RoyaltyModule_payLicenseMintingFee() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerAddress = address(3);
        address licenseRoyaltyPolicy = address(royaltyPolicyLAP);
        address token = address(USDC);

        (, address ipRoyaltyVault, , , ) = royaltyPolicyLAP.getRoyaltyData(receiverIpId);

        vm.startPrank(payerAddress);
        USDC.mint(payerAddress, royaltyAmount);
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        vm.stopPrank;

        uint256 payerAddressUSDCBalBefore = USDC.balanceOf(payerAddress);
        uint256 ipRoyaltyVaultUSDCBalBefore = USDC.balanceOf(ipRoyaltyVault);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LicenseMintingFeePaid(receiverIpId, payerAddress, address(USDC), royaltyAmount);

        vm.startPrank(address(licensingModule));
        royaltyModule.payLicenseMintingFee(receiverIpId, payerAddress, licenseRoyaltyPolicy, token, royaltyAmount);

        uint256 payerAddressUSDCBalAfter = USDC.balanceOf(payerAddress);
        uint256 ipRoyaltyVaultUSDCBalAfter = USDC.balanceOf(ipRoyaltyVault);

        assertEq(payerAddressUSDCBalBefore - payerAddressUSDCBalAfter, royaltyAmount);
        assertEq(ipRoyaltyVaultUSDCBalAfter - ipRoyaltyVaultUSDCBalBefore, royaltyAmount);
    }
}
