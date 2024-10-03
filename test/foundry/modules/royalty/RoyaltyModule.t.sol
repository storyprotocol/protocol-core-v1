// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

// contracts
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { RoyaltyModule } from "../../../../contracts/modules/royalty/RoyaltyModule.sol";
import { IIpRoyaltyVault } from "../../../../contracts/interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";

// tests
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../../utils/TestProxyHelper.sol";
import { MockExternalRoyaltyPolicy1 } from "../../mocks/policy/MockExternalRoyaltyPolicy1.sol";
import { MockExternalRoyaltyPolicy2 } from "../../mocks/policy/MockExternalRoyaltyPolicy2.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { MockEvenSplitGroupPool } from "../../mocks/grouping/MockEvenSplitGroupPool.sol";

contract TestRoyaltyModule is BaseTest {
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);
    event RoyaltyPolicySet(address ipId, address royaltyPolicy, bytes data);
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);
    event LicenseMintingFeePaid(address receiverIpId, address payerAddress, address token, uint256 amount);
    event RoyaltyVaultAddedToIp(address ipId, address ipRoyaltyVault);
    event ExternalRoyaltyPolicyRegistered(address externalRoyaltyPolicy);
    event LicensedWithRoyalty(address ipId, address royaltyPolicy, uint32 licensePercent, bytes externalData);
    event LinkedToParents(
        address ipId,
        address[] parentIpIds,
        address[] licenseRoyaltyPolicies,
        uint32[] licensesPercent,
        bytes externalData
    );
    event RoyaltyFeePercentSet(uint32 royaltyFeePercent);
    event TreasurySet(address treasury);

    bytes32 internal disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;

    address internal ipAccount1 = address(0x111000aaa);
    address internal ipAccount2 = address(0x111000bbb);
    address internal ipAddr;
    address internal arbitrationRelayer;
    address internal mockExternalRoyaltyPolicy1;
    address internal mockExternalRoyaltyPolicy2;

    // grouping
    MockERC721 internal mockNft = new MockERC721("MockERC721");
    address public ipId1;
    address public ipOwner1 = address(0x111);
    uint256 public tokenId1 = 1;
    MockEvenSplitGroupPool public rewardPool;

    function setUp() public override {
        super.setUp();

        USDC.mint(ipAccount1, 1000 * 10 ** 6); // 1000 USDC
        USDC.mint(ipAccount2, 1000 * 10 ** 6); // 1000 USDC

        arbitrationRelayer = u.relayer;

        // register external royalty policies
        mockExternalRoyaltyPolicy1 = address(new MockExternalRoyaltyPolicy1());
        mockExternalRoyaltyPolicy2 = address(new MockExternalRoyaltyPolicy2());
        royaltyModule.registerExternalRoyaltyPolicy(mockExternalRoyaltyPolicy1);
        royaltyModule.registerExternalRoyaltyPolicy(mockExternalRoyaltyPolicy2);

        vm.startPrank(address(licensingModule));
        _setupTree();
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
        disputeModule.setArbitrationPolicy(ipAddr, address(mockArbitrationPolicy));
        vm.stopPrank();

        // grouping
        mockNft.mintId(ipOwner1, tokenId1);
        ipId1 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId1);
        rewardPool = new MockEvenSplitGroupPool(address(royaltyModule));
        vm.prank(admin);
        groupingModule.whitelistGroupRewardPool(address(rewardPool));
    }

    function _setupTree() internal {
        // mint license for roots
        royaltyModule.onLicenseMinting(address(10), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(20), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(30), address(royaltyPolicyLRP), uint32(7 * 10 ** 6), "");

        // link 40 to parents
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(20);
        parents[2] = address(30);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[2] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(10 * 10 ** 6);
        parentRoyalties[1] = uint32(10 * 10 ** 6);
        parentRoyalties[2] = uint32(7 * 10 ** 6);
        ipGraph.addParentIp(address(40), parents);
        royaltyModule.onLinkToParents(address(40), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 40
        royaltyModule.onLicenseMinting(address(40), address(royaltyPolicyLRP), uint32(5 * 10 ** 6), "");

        // link 50 to 40
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(40);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        ipGraph.addParentIp(address(50), parents);
        royaltyModule.onLinkToParents(address(50), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 50
        royaltyModule.onLicenseMinting(address(50), address(royaltyPolicyLRP), uint32(15 * 10 ** 6), "");

        // link 60 to 50
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(50);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLRP);
        parentRoyalties[0] = uint32(15 * 10 ** 6);
        ipGraph.addParentIp(address(60), parents);
        royaltyModule.onLinkToParents(address(60), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 60
        royaltyModule.onLicenseMinting(address(60), address(mockExternalRoyaltyPolicy1), uint32(12 * 10 ** 6), "");

        // link 70 to 60
        parents = new address[](1);
        licenseRoyaltyPolicies = new address[](1);
        parentRoyalties = new uint32[](1);
        parents[0] = address(60);
        licenseRoyaltyPolicies[0] = address(mockExternalRoyaltyPolicy1);
        parentRoyalties[0] = uint32(12 * 10 ** 6);
        ipGraph.addParentIp(address(70), parents);
        royaltyModule.onLinkToParents(address(70), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        // mint license for 10 + 60 + 70
        royaltyModule.onLicenseMinting(address(10), address(royaltyPolicyLAP), uint32(5 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(60), address(royaltyPolicyLRP), uint32(20 * 10 ** 6), "");
        royaltyModule.onLicenseMinting(address(70), address(mockExternalRoyaltyPolicy2), uint32(24 * 10 ** 6), "");
    }

    function test_RoyaltyModule_initialize_revert_ZeroAccessManager() public {
        address impl = address(
            new RoyaltyModule(
                address(licensingModule),
                address(disputeModule),
                address(licenseRegistry),
                address(ipAssetRegistry)
            )
        );
        vm.expectRevert(Errors.RoyaltyModule__ZeroAccessManager.selector);
        RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyModule.initialize, (address(0), uint256(8), uint256(1024), uint256(15)))
            )
        );
    }

    function test_RoyaltyModule_initialize_revert_ZeroMaxParents() public {
        address impl = address(
            new RoyaltyModule(
                address(licensingModule),
                address(disputeModule),
                address(licenseRegistry),
                address(ipAssetRegistry)
            )
        );
        vm.expectRevert(Errors.RoyaltyModule__ZeroMaxParents.selector);
        RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyModule.initialize, (address(1), uint256(0), uint256(1024), uint256(15)))
            )
        );
    }

    function test_RoyaltyModule_initialize_revert_ZeroMaxAncestors() public {
        address impl = address(
            new RoyaltyModule(
                address(licensingModule),
                address(disputeModule),
                address(licenseRegistry),
                address(ipAssetRegistry)
            )
        );
        vm.expectRevert(Errors.RoyaltyModule__ZeroMaxAncestors.selector);
        RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyModule.initialize, (address(1), uint256(8), uint256(0), uint256(15)))
            )
        );
    }

    function test_RoyaltyModule_initialize_revert_ZeroAccumulatedRoyaltyPoliciesLimit() public {
        address impl = address(
            new RoyaltyModule(
                address(licensingModule),
                address(disputeModule),
                address(licenseRegistry),
                address(ipAssetRegistry)
            )
        );
        vm.expectRevert(Errors.RoyaltyModule__ZeroAccumulatedRoyaltyPoliciesLimit.selector);
        RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(RoyaltyModule.initialize, (address(1), uint256(8), uint256(1024), uint256(0)))
            )
        );
    }

    function test_RoyaltyModule_setTreasury_revert_ZeroTreasury() public {
        vm.startPrank(u.admin);

        vm.expectRevert(Errors.RoyaltyModule__ZeroTreasury.selector);
        royaltyModule.setTreasury(address(0));
    }

    function test_RoyaltyModule_setTreasury() public {
        vm.startPrank(u.admin);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit TreasurySet(address(1));

        royaltyModule.setTreasury(address(1));

        assertEq(royaltyModule.treasury(), address(1));
    }

    function test_RoyaltyModule_setRoyaltyFeePercent_revert_AboveMaxPercent() public {
        vm.startPrank(u.admin);

        vm.expectRevert(Errors.RoyaltyModule__AboveMaxPercent.selector);
        royaltyModule.setRoyaltyFeePercent(500 * 10 ** 6);
    }

    function test_RoyaltyModule_setRoyaltyFeePercent_revert_ZeroTreasury() public {
        vm.startPrank(u.admin);

        vm.expectRevert(Errors.RoyaltyModule__ZeroTreasury.selector);
        royaltyModule.setRoyaltyFeePercent(10);
    }

    function test_RoyaltyModule_setRoyaltyFeePercent() public {
        vm.startPrank(u.admin);

        royaltyModule.setTreasury(address(1));

        royaltyModule.setRoyaltyFeePercent(100);

        assertEq(royaltyModule.royaltyFeePercent(), 100);
    }

    function test_RoyaltyModule_setIpGraphLimits_revert_ZeroMaxParents() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyModule__ZeroMaxParents.selector);

        royaltyModule.setIpGraphLimits(0, 1, 10);
    }

    function test_RoyaltyModule_setIpGraphLimits_revert_ZeroMaxAncestors() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyModule__ZeroMaxAncestors.selector);

        royaltyModule.setIpGraphLimits(1, 0, 10);
    }

    function test_RoyaltyModule_setIpGraphLimits_revert_ZeroAccumulatedRoyaltyPoliciesLimit() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyModule__ZeroAccumulatedRoyaltyPoliciesLimit.selector);

        royaltyModule.setIpGraphLimits(1, 1, 0);
    }

    function test_RoyaltyModule_setIpGraphLimits() public {
        assertEq(royaltyModule.maxParents(), 8);
        assertEq(royaltyModule.maxAncestors(), 1024);
        assertEq(royaltyModule.maxAccumulatedRoyaltyPolicies(), 15);

        vm.startPrank(u.admin);
        royaltyModule.setIpGraphLimits(1, 1, 1);
        vm.stopPrank();

        assertEq(royaltyModule.maxParents(), 1);
        assertEq(royaltyModule.maxAncestors(), 1);
        assertEq(royaltyModule.maxAccumulatedRoyaltyPolicies(), 1);
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

    function test_RoyaltyModule_registerExternalRoyaltyPolicy_revert_ZeroExternalRoyaltyPolicy() public {
        vm.expectRevert(Errors.RoyaltyModule__PolicyAlreadyWhitelistedOrRegistered.selector);
        royaltyModule.registerExternalRoyaltyPolicy(address(royaltyPolicyLAP));
    }

    function test_RoyaltyModule_registerExternalRoyaltyPolicy() public {
        address externalRoyaltyPolicy = address(new MockExternalRoyaltyPolicy1());
        assertEq(royaltyModule.isRegisteredExternalRoyaltyPolicy(externalRoyaltyPolicy), false);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit ExternalRoyaltyPolicyRegistered(externalRoyaltyPolicy);
        royaltyModule.registerExternalRoyaltyPolicy(externalRoyaltyPolicy);

        assertEq(royaltyModule.isRegisteredExternalRoyaltyPolicy(externalRoyaltyPolicy), true);
    }

    function test_RoyaltyModule_onLicenseMinting_revert_RoyaltyModule__NotAllowedCaller() public {
        vm.expectRevert(Errors.RoyaltyModule__NotAllowedCaller.selector);
        royaltyModule.onLicenseMinting(address(1), address(2), uint32(1), "");
    }

    function test_RoyaltyModule_onLicenseMinting_revert_NotWhitelistedOrRegisteredRoyaltyPolicy() public {
        address licensor = address(1);
        uint32 licensePercent = uint32(15);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedOrRegisteredRoyaltyPolicy.selector);
        royaltyModule.onLicenseMinting(licensor, address(1), licensePercent, "");
    }

    function test_RoyaltyModule_onLicenseMinting_revert_ZeroRoyaltyPolicy() public {
        address licensor = address(1);
        uint32 licensePercent = uint32(15);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyPolicy.selector);
        royaltyModule.onLicenseMinting(licensor, address(0), licensePercent, "");
    }

    function test_RoyaltyModule_onLicenseMinting_revert_LastPositionNotAbleToMintLicense() public {
        vm.startPrank(u.admin);
        royaltyModule.setIpGraphLimits(1, 1, 15);
        vm.stopPrank();

        address licensor = address(50);
        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__LastPositionNotAbleToMintLicense.selector);
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), uint32(15), "");
    }

    function test_RoyaltyModule_onLicenseMinting_revert_AboveMaxPercent() public {
        address licensor = address(1);
        uint32 licensePercent = uint32(500 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__AboveMaxPercent.selector);
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licensePercent, "");
    }

    function test_RoyaltyModule_onLicenseMinting_NewVault() public {
        address licensor = address(2);
        uint32 licensePercent = uint32(15);

        vm.startPrank(address(licensingModule));

        assertEq(royaltyModule.ipRoyaltyVaults(licensor), address(0));

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LicensedWithRoyalty(licensor, address(royaltyPolicyLAP), licensePercent, "");

        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licensePercent, "");

        address newVault = royaltyModule.ipRoyaltyVaults(licensor);
        uint256 ipIdRtBalAfter = IERC20(newVault).balanceOf(licensor);

        assertEq(ipIdRtBalAfter, royaltyModule.maxPercent());
        assertFalse(royaltyModule.ipRoyaltyVaults(licensor) == address(0));
        assertEq(royaltyModule.isIpRoyaltyVault(newVault), true);
    }

    function test_RoyaltyModule_onLicenseMinting_NewVaultGroup() public {
        address groupId = groupingModule.registerGroup(address(rewardPool));
        uint32 licensePercent = uint32(15);

        vm.startPrank(address(licensingModule));

        assertEq(royaltyModule.ipRoyaltyVaults(groupId), address(0));

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LicensedWithRoyalty(groupId, address(royaltyPolicyLAP), licensePercent, "");

        royaltyModule.onLicenseMinting(groupId, address(royaltyPolicyLAP), licensePercent, "");

        address newVault = royaltyModule.ipRoyaltyVaults(groupId);
        uint256 groupPoolRtBalAfter = IERC20(newVault).balanceOf(address(rewardPool));

        assertEq(groupPoolRtBalAfter, royaltyModule.maxPercent());
        assertFalse(royaltyModule.ipRoyaltyVaults(groupId) == address(0));
        assertEq(royaltyModule.isIpRoyaltyVault(newVault), true);
    }

    function test_RoyaltyModule_onLicenseMinting_ExistingVault() public {
        address licensor = address(2);
        uint32 licensePercent = uint32(15);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licensePercent, "");

        address ipRoyaltyVaultBefore = royaltyModule.ipRoyaltyVaults(licensor);
        uint256 ipIdRtBalBefore = IERC20(ipRoyaltyVaultBefore).balanceOf(licensor);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LicensedWithRoyalty(licensor, address(royaltyPolicyLAP), licensePercent, "");

        royaltyModule.onLicenseMinting(licensor, address(royaltyPolicyLAP), licensePercent, "");

        address ipRoyaltyVaultAfter = royaltyModule.ipRoyaltyVaults(licensor);
        address newVault = royaltyModule.ipRoyaltyVaults(licensor);
        uint256 ipIdRtBalAfter = IERC20(newVault).balanceOf(licensor);

        assertEq(ipIdRtBalBefore - ipIdRtBalAfter, 0);
        assertEq(ipRoyaltyVaultBefore, ipRoyaltyVaultAfter);
    }

    function test_RoyaltyModule_onLinkToParents_revert_NotAllowedCaller() public {
        vm.expectRevert(Errors.RoyaltyModule__NotAllowedCaller.selector);
        royaltyModule.onLinkToParents(address(1), new address[](0), new address[](0), new uint32[](0), "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_ZeroRoyaltyPolicy() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(0);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyPolicy.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_UnlinkableToParents() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(address(80), address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        vm.expectRevert(Errors.RoyaltyModule__UnlinkableToParents.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_NoParentsOnLinking() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NoParentsOnLinking.selector);
        royaltyModule.onLinkToParents(address(80), new address[](0), licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_RoyaltyModule_AboveParentLimit() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link 80 to 10 + 60 + 70
        parents = new address[](10);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__AboveParentLimit.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_AboveAncestorsLimit() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        vm.startPrank(u.admin);
        royaltyModule.setIpGraphLimits(3, 2, 15);
        vm.stopPrank();

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        ipGraph.addParentIp(address(80), parents);
        vm.expectRevert(Errors.RoyaltyModule__AboveAncestorsLimit.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_AboveMaxPercent() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy1);
        parentRoyalties[0] = uint32(500 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        ipGraph.addParentIp(address(80), parents);

        // tests royalty stack above 100%
        vm.expectRevert(Errors.RoyaltyModule__AboveMaxPercent.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        parentRoyalties[0] = uint32(50 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(240 * 10 ** 6);

        // tests royalty token supply above 100%
        vm.expectRevert(Errors.RoyaltyModule__AboveMaxPercent.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_RoyaltyModule_NotWhitelistedOrRegisteredRoyaltyPolicy() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        address nonRegisteredRoyaltyPolicy = address(new MockExternalRoyaltyPolicy1());

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(nonRegisteredRoyaltyPolicy);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(1 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        ipGraph.addParentIp(address(80), parents);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedOrRegisteredRoyaltyPolicy.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents_revert_AboveAccumulatedRoyaltyPoliciesLimit() public {
        vm.startPrank(u.admin);
        royaltyModule.setIpGraphLimits(8, 1024, 3);
        vm.stopPrank();

        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        ipGraph.addParentIp(address(80), parents);

        vm.expectRevert(Errors.RoyaltyModule__AboveAccumulatedRoyaltyPoliciesLimit.selector);
        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");
    }

    function test_RoyaltyModule_onLinkToParents() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link 80 to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        ipGraph.addParentIp(address(80), parents);

        assertEq(royaltyModule.ipRoyaltyVaults(address(80)), address(0));

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LinkedToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        royaltyModule.onLinkToParents(address(80), parents, licenseRoyaltyPolicies, parentRoyalties, "");

        address ipRoyaltyVault80 = royaltyModule.ipRoyaltyVaults(address(80));
        uint256 ipId80RtLAPBalAfter = IERC20(ipRoyaltyVault80).balanceOf(address(royaltyPolicyLAP));
        uint256 ipId80RtLRPBalAfter = IERC20(ipRoyaltyVault80).balanceOf(address(royaltyPolicyLRP));
        uint256 ipId80RtLRPParentVaultBalAfter = IERC20(ipRoyaltyVault80).balanceOf(
            royaltyModule.ipRoyaltyVaults(address(60))
        );
        uint256 ipId80RtExternal1BalAfter = IERC20(ipRoyaltyVault80).balanceOf(mockExternalRoyaltyPolicy1);
        uint256 ipId80RtExternal2BalAfter = IERC20(ipRoyaltyVault80).balanceOf(mockExternalRoyaltyPolicy2);
        uint256 ipId80IpIdRtBalAfter = IERC20(ipRoyaltyVault80).balanceOf(address(80));

        assertFalse(royaltyModule.ipRoyaltyVaults(address(80)) == address(0));
        assertEq(royaltyModule.isIpRoyaltyVault(royaltyModule.ipRoyaltyVaults(address(80))), true);
        assertEq(ipId80RtLAPBalAfter, 0);
        assertEq(ipId80RtLRPBalAfter, 0);
        assertEq(ipId80RtLRPParentVaultBalAfter, 0);
        assertEq(ipId80RtExternal1BalAfter, 0);
        assertEq(ipId80RtExternal2BalAfter, 10 * 10 ** 6);
        assertEq(ipId80IpIdRtBalAfter, 90 * 10 ** 6);

        address[] memory accRoyaltyPolicies80After = royaltyModule.accumulatedRoyaltyPolicies(address(80));
        assertEq(accRoyaltyPolicies80After[0], address(royaltyPolicyLAP));
        assertEq(accRoyaltyPolicies80After[1], address(royaltyPolicyLRP));
        assertEq(accRoyaltyPolicies80After[2], address(mockExternalRoyaltyPolicy1));
        assertEq(accRoyaltyPolicies80After[3], address(mockExternalRoyaltyPolicy2));

        address[] memory accRoyaltyPolicies10After = royaltyModule.accumulatedRoyaltyPolicies(address(10));
        assertEq(accRoyaltyPolicies10After[0], address(royaltyPolicyLAP));

        address[] memory accRoyaltyPolicies60After = royaltyModule.accumulatedRoyaltyPolicies(address(60));
        assertEq(accRoyaltyPolicies60After[0], address(royaltyPolicyLAP));
        assertEq(accRoyaltyPolicies60After[1], address(royaltyPolicyLRP));
        assertEq(accRoyaltyPolicies60After[2], address(mockExternalRoyaltyPolicy1));

        address[] memory accRoyaltyPolicies70After = royaltyModule.accumulatedRoyaltyPolicies(address(70));
        assertEq(accRoyaltyPolicies70After[0], address(royaltyPolicyLAP));
        assertEq(accRoyaltyPolicies70After[1], address(royaltyPolicyLRP));
        assertEq(accRoyaltyPolicies70After[2], address(mockExternalRoyaltyPolicy1));
        assertEq(accRoyaltyPolicies70After[3], address(mockExternalRoyaltyPolicy2));
    }

    function test_RoyaltyModule_onLinkToParents_group() public {
        address[] memory parents = new address[](3);
        address[] memory licenseRoyaltyPolicies = new address[](3);
        uint32[] memory parentRoyalties = new uint32[](3);

        // link group ip to 10 + 60 + 70
        parents = new address[](3);
        licenseRoyaltyPolicies = new address[](3);
        parentRoyalties = new uint32[](3);
        parents[0] = address(10);
        parents[1] = address(60);
        parents[2] = address(70);
        licenseRoyaltyPolicies[0] = address(royaltyPolicyLAP);
        licenseRoyaltyPolicies[1] = address(royaltyPolicyLRP);
        licenseRoyaltyPolicies[2] = address(mockExternalRoyaltyPolicy2);
        parentRoyalties[0] = uint32(5 * 10 ** 6);
        parentRoyalties[1] = uint32(17 * 10 ** 6);
        parentRoyalties[2] = uint32(24 * 10 ** 6);

        vm.startPrank(address(licensingModule));
        address groupId = groupingModule.registerGroup(address(rewardPool));
        ipGraph.addParentIp(groupId, parents);

        assertEq(royaltyModule.ipRoyaltyVaults(groupId), address(0));

        royaltyModule.onLinkToParents(groupId, parents, licenseRoyaltyPolicies, parentRoyalties, "");

        address ipRoyaltyVault80 = royaltyModule.ipRoyaltyVaults(groupId);
        uint256 ipId80RtLAPBalAfter = IERC20(ipRoyaltyVault80).balanceOf(address(royaltyPolicyLAP));
        uint256 ipId80RtLRPBalAfter = IERC20(ipRoyaltyVault80).balanceOf(address(royaltyPolicyLRP));
        uint256 ipId80RtLRPParentVaultBalAfter = IERC20(ipRoyaltyVault80).balanceOf(
            royaltyModule.ipRoyaltyVaults(address(60))
        );
        uint256 ipId80RtExternal1BalAfter = IERC20(ipRoyaltyVault80).balanceOf(mockExternalRoyaltyPolicy1);
        uint256 ipId80RtExternal2BalAfter = IERC20(ipRoyaltyVault80).balanceOf(mockExternalRoyaltyPolicy2);
        uint256 ipId80GroupPoolRtBalAfter = IERC20(ipRoyaltyVault80).balanceOf(address(rewardPool));

        assertEq(ipId80RtLAPBalAfter, 0);
        assertEq(ipId80RtLRPBalAfter, 0);
        assertEq(ipId80RtLRPParentVaultBalAfter, 0);
        assertEq(ipId80RtExternal1BalAfter, 0);
        assertEq(ipId80RtExternal2BalAfter, 10 * 10 ** 6);
        assertEq(ipId80GroupPoolRtBalAfter, 90 * 10 ** 6);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_IpIsTagged() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        USDC.approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        vm.expectRevert(Errors.RoyaltyModule__IpIsTagged.selector);
        royaltyModule.payRoyaltyOnBehalf(ipAddr, ipAccount1, address(USDC), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_ZeroAmount() public {
        vm.expectRevert(Errors.RoyaltyModule__ZeroAmount.selector);
        royaltyModule.payRoyaltyOnBehalf(address(1), address(2), address(USDC), 0);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyToken() public {
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyToken.selector);
        royaltyModule.payRoyaltyOnBehalf(address(1), address(2), address(1), 100);
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

    function test_RoyaltyModule_payRoyaltyOnBehalf() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerIpId = address(3);

        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(receiverIpId, address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(receiverIpId);
        vm.stopPrank();

        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);

        uint256 payerIpIdUSDCBalBefore = USDC.balanceOf(payerIpId);
        uint256 ipRoyaltyVaultUSDCBalBefore = USDC.balanceOf(ipRoyaltyVault);
        uint256 totalRevenueTokensReceivedBefore = royaltyModule.totalRevenueTokensReceived(
            receiverIpId,
            address(USDC)
        );
        uint256 pendingVaultAmountBefore = IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC));

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPaid(receiverIpId, payerIpId, payerIpId, address(USDC), royaltyAmount);

        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);

        uint256 payerIpIdUSDCBalAfter = USDC.balanceOf(payerIpId);
        uint256 ipRoyaltyVaultUSDCBalAfter = USDC.balanceOf(ipRoyaltyVault);
        uint256 totalRevenueTokensReceivedAfter = royaltyModule.totalRevenueTokensReceived(receiverIpId, address(USDC));
        uint256 pendingVaultAmountAfter = IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC));

        assertEq(payerIpIdUSDCBalBefore - payerIpIdUSDCBalAfter, royaltyAmount);
        assertEq(ipRoyaltyVaultUSDCBalAfter - ipRoyaltyVaultUSDCBalBefore, royaltyAmount);
        assertEq(totalRevenueTokensReceivedAfter - totalRevenueTokensReceivedBefore, royaltyAmount);
        assertEq(pendingVaultAmountAfter - pendingVaultAmountBefore, royaltyAmount);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_WithFee() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerIpId = address(3);

        // set fee and treasury
        vm.startPrank(u.admin);
        royaltyModule.setTreasury(address(100));
        royaltyModule.setRoyaltyFeePercent(uint32(10 * 10 ** 6)); // 10%
        vm.stopPrank();

        // deploy vault
        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(receiverIpId, address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(receiverIpId);
        vm.stopPrank();

        vm.startPrank(payerIpId);
        USDC.mint(payerIpId, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);

        uint256 payerIpIdUSDCBalBefore = USDC.balanceOf(payerIpId);
        uint256 ipRoyaltyVaultUSDCBalBefore = USDC.balanceOf(ipRoyaltyVault);
        uint256 totalRevenueTokensReceivedBefore = royaltyModule.totalRevenueTokensReceived(
            receiverIpId,
            address(USDC)
        );
        uint256 pendingVaultAmountBefore = IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC));
        uint256 usdcTreasuryAmountBefore = USDC.balanceOf(address(100));

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPaid(receiverIpId, payerIpId, payerIpId, address(USDC), royaltyAmount);

        royaltyModule.payRoyaltyOnBehalf(receiverIpId, payerIpId, address(USDC), royaltyAmount);

        assertEq(payerIpIdUSDCBalBefore - USDC.balanceOf(payerIpId), royaltyAmount);
        assertEq(
            USDC.balanceOf(ipRoyaltyVault) - ipRoyaltyVaultUSDCBalBefore,
            (royaltyAmount * 90e6) / royaltyModule.maxPercent()
        );
        assertEq(
            royaltyModule.totalRevenueTokensReceived(receiverIpId, address(USDC)) - totalRevenueTokensReceivedBefore,
            (royaltyAmount * 90e6) / royaltyModule.maxPercent()
        );
        assertEq(
            IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC)) - pendingVaultAmountBefore,
            (royaltyAmount * 90e6) / royaltyModule.maxPercent()
        );
        assertEq(
            USDC.balanceOf(address(100)) - usdcTreasuryAmountBefore,
            (royaltyAmount * 10e6) / royaltyModule.maxPercent()
        );
    }

    function test_RoyaltyModule_payLicenseMintingFee_revert_ZeroAmount() public {
        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__ZeroAmount.selector);
        royaltyModule.payLicenseMintingFee(address(1), address(2), address(USDC), 0);
    }

    function test_RoyaltyModule_payLicenseMintingFee_revert_NotWhitelistedRoyaltyToken() public {
        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyToken.selector);
        royaltyModule.payLicenseMintingFee(address(1), address(2), address(1), 100);
    }

    function test_RoyaltyModule_payLicenseMintingFee_revert_IpIsTagged() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        USDC.approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        vm.startPrank(address(licensingModule));

        vm.expectRevert(Errors.RoyaltyModule__IpIsTagged.selector);
        royaltyModule.payLicenseMintingFee(ipAddr, ipAccount1, address(USDC), 100);
    }

    function test_RoyaltyModule_payLicenseMintingFee() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerAddress = address(3);
        address token = address(USDC);

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(receiverIpId, address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(receiverIpId);
        vm.stopPrank();

        vm.startPrank(payerAddress);
        USDC.mint(payerAddress, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);
        vm.stopPrank();

        uint256 payerAddressUSDCBalBefore = USDC.balanceOf(payerAddress);
        uint256 ipRoyaltyVaultUSDCBalBefore = USDC.balanceOf(ipRoyaltyVault);
        uint256 totalRevenueTokensReceivedBefore = royaltyModule.totalRevenueTokensReceived(
            receiverIpId,
            address(USDC)
        );
        uint256 pendingVaultAmountBefore = IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC));

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LicenseMintingFeePaid(receiverIpId, payerAddress, address(USDC), royaltyAmount);

        vm.startPrank(address(licensingModule));
        royaltyModule.payLicenseMintingFee(receiverIpId, payerAddress, token, royaltyAmount);

        assertEq(payerAddressUSDCBalBefore - USDC.balanceOf(payerAddress), royaltyAmount);
        assertEq(USDC.balanceOf(ipRoyaltyVault) - ipRoyaltyVaultUSDCBalBefore, royaltyAmount);
        assertEq(
            royaltyModule.totalRevenueTokensReceived(receiverIpId, address(USDC)) - totalRevenueTokensReceivedBefore,
            royaltyAmount
        );
        assertEq(
            IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC)) - pendingVaultAmountBefore,
            royaltyAmount
        );
    }

    function test_RoyaltyModule_payLicenseMintingFee_WithFee() public {
        uint256 royaltyAmount = 100 * 10 ** 6;
        address receiverIpId = address(2);
        address payerAddress = address(3);
        address token = address(USDC);

        // set fee and treasury
        vm.startPrank(u.admin);
        royaltyModule.setTreasury(address(100));
        royaltyModule.setRoyaltyFeePercent(uint32(10 * 10 ** 6)); // 10%
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        royaltyModule.onLicenseMinting(receiverIpId, address(royaltyPolicyLAP), uint32(10 * 10 ** 6), "");
        address ipRoyaltyVault = royaltyModule.ipRoyaltyVaults(receiverIpId);
        vm.stopPrank();

        vm.startPrank(payerAddress);
        USDC.mint(payerAddress, royaltyAmount);
        USDC.approve(address(royaltyModule), royaltyAmount);
        vm.stopPrank();

        uint256 payerAddressUSDCBalBefore = USDC.balanceOf(payerAddress);
        uint256 ipRoyaltyVaultUSDCBalBefore = USDC.balanceOf(ipRoyaltyVault);
        uint256 totalRevenueTokensReceivedBefore = royaltyModule.totalRevenueTokensReceived(
            receiverIpId,
            address(USDC)
        );
        uint256 pendingVaultAmountBefore = IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC));
        uint256 usdcTreasuryAmountBefore = USDC.balanceOf(address(100));

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit LicenseMintingFeePaid(receiverIpId, payerAddress, address(USDC), royaltyAmount);

        vm.startPrank(address(licensingModule));
        royaltyModule.payLicenseMintingFee(receiverIpId, payerAddress, token, royaltyAmount);

        assertEq(payerAddressUSDCBalBefore - USDC.balanceOf(payerAddress), royaltyAmount);
        assertEq(
            USDC.balanceOf(ipRoyaltyVault) - ipRoyaltyVaultUSDCBalBefore,
            (royaltyAmount * 90e6) / royaltyModule.maxPercent()
        );
        assertEq(
            royaltyModule.totalRevenueTokensReceived(receiverIpId, address(USDC)) - totalRevenueTokensReceivedBefore,
            (royaltyAmount * 90e6) / royaltyModule.maxPercent()
        );
        assertEq(
            IIpRoyaltyVault(ipRoyaltyVault).pendingVaultAmount(address(USDC)) - pendingVaultAmountBefore,
            (royaltyAmount * 90e6) / royaltyModule.maxPercent()
        );
        assertEq(
            USDC.balanceOf(address(100)) - usdcTreasuryAmountBefore,
            (royaltyAmount * 10e6) / royaltyModule.maxPercent()
        );
    }
}
