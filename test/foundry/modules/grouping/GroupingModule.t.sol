// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

// contracts
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { Licensing } from "../../../../contracts/lib/Licensing.sol";
import { IGroupingModule } from "../../../../contracts/interfaces/modules/grouping/IGroupingModule.sol";
import { IIPAssetRegistry } from "../../../../contracts/interfaces/registries/IIPAssetRegistry.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
// test
import { EvenSplitGroupPool } from "../../../../contracts/modules/grouping/EvenSplitGroupPool.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract GroupingModuleTest is BaseTest, ERC721Holder {
    // test register group
    // test add ip to group
    // test remove ip from group
    // test claim reward
    // test get claimable reward
    // test make derivative of group ipa
    // test recursive group ipa
    // test remove ipa from group ipa which has derivative
    using Strings for *;

    error ERC721NonexistentToken(uint256 tokenId);

    MockERC721 internal mockNft = new MockERC721("MockERC721");
    MockERC721 internal gatedNftFoo = new MockERC721{ salt: bytes32(uint256(1)) }("GatedNftFoo");
    MockERC721 internal gatedNftBar = new MockERC721{ salt: bytes32(uint256(2)) }("GatedNftBar");

    address public ipId1;
    address public ipId2;
    address public ipId3;
    address public ipId5;
    address public ipOwner1 = address(0x111);
    address public ipOwner2 = address(0x222);
    address public ipOwner3 = address(0x333);
    address public ipOwner5 = address(0x444);
    uint256 public tokenId1 = 1;
    uint256 public tokenId2 = 2;
    uint256 public tokenId3 = 3;
    uint256 public tokenId5 = 5;

    EvenSplitGroupPool public rewardPool;

    function setUp() public override {
        super.setUp();
        // Create IPAccounts
        mockNft.mintId(ipOwner1, tokenId1);
        mockNft.mintId(ipOwner2, tokenId2);
        mockNft.mintId(ipOwner3, tokenId3);
        mockNft.mintId(ipOwner5, tokenId5);

        ipId1 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId1);
        ipId2 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId2);
        ipId3 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId3);
        ipId5 = ipAssetRegistry.register(block.chainid, address(mockNft), tokenId5);

        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
        vm.label(ipId3, "IPAccount3");
        vm.label(ipId5, "IPAccount5");

        rewardPool = evenSplitGroupPool;
    }

    function test_GroupingModule_registerGroup() public {
        address expectedGroupId = ipAssetRegistry.ipId(block.chainid, address(groupNft), 0);
        vm.expectEmit();
        emit IGroupingModule.IPGroupRegistered(expectedGroupId, address(rewardPool));
        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));
        assertEq(groupId, expectedGroupId);
        assertEq(ipAssetRegistry.getGroupRewardPool(groupId), address(rewardPool));
        assertEq(ipAssetRegistry.isRegisteredGroup(groupId), true);
        assertEq(ipAssetRegistry.totalMembers(groupId), 0);
    }

    function test_GroupingModule_registerGroup_withRegisterFee() public {
        address treasury = address(0x123);
        vm.prank(u.admin);
        ipAssetRegistry.setRegistrationFee(treasury, address(erc20), 1000);

        erc20.mint(alice, 1000);
        vm.prank(alice);
        erc20.approve(address(ipAssetRegistry), 1000);

        address expectedGroupId = ipAssetRegistry.ipId(block.chainid, address(groupNft), 0);
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistrationFeePaid(alice, treasury, address(erc20), 1000);
        vm.expectEmit();
        emit IGroupingModule.IPGroupRegistered(expectedGroupId, address(rewardPool));
        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));

        assertEq(groupId, expectedGroupId);
        assertEq(ipAssetRegistry.getGroupRewardPool(groupId), address(rewardPool));
        assertEq(ipAssetRegistry.isRegisteredGroup(groupId), true);
        assertEq(ipAssetRegistry.totalMembers(groupId), 0);
    }

    function test_GroupingModule_registerGroup_revert_nonexitsTokenId() public {
        address expectedGroupId = ipAssetRegistry.ipId(block.chainid, address(groupNft), 0);
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 0));
        ipAssetRegistry.register(block.chainid, address(groupNft), 0);
    }

    function test_GroupingModule_whitelistRewardPool() public {
        vm.prank(admin);
        groupingModule.whitelistGroupRewardPool(address(rewardPool), true);
        assertEq(ipAssetRegistry.isWhitelistedGroupRewardPool(address(rewardPool)), true);

        assertEq(ipAssetRegistry.isWhitelistedGroupRewardPool(address(0x123)), false);

        vm.prank(admin);
        groupingModule.whitelistGroupRewardPool(address(rewardPool), false);
        assertEq(ipAssetRegistry.isWhitelistedGroupRewardPool(address(rewardPool)), false);
    }

    function test_GroupingModule_addIp() public {
        vm.warp(100);
        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
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

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();
        vm.startPrank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingConfig.expectGroupRewardPool = address(0);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        address[] memory ipIds = new address[](2);
        ipIds[0] = ipId1;
        ipIds[1] = ipId2;
        vm.expectEmit();
        emit IGroupingModule.AddedIpToGroup(groupId, ipIds);
        groupingModule.addIp(groupId, ipIds);
        assertEq(ipAssetRegistry.totalMembers(groupId), 2);
        assertEq(rewardPool.getTotalIps(groupId), 2);
        assertEq(rewardPool.getIpAddedTime(groupId, ipId1), 100);
    }

    function test_GroupingModule_removeIp() public {
        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
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

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();
        vm.startPrank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        licensingConfig.expectGroupRewardPool = address(0);
        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        address[] memory ipIds = new address[](2);
        ipIds[0] = ipId1;
        ipIds[1] = ipId2;
        groupingModule.addIp(groupId, ipIds);
        assertEq(ipAssetRegistry.totalMembers(groupId), 2);
        address[] memory removeIpIds = new address[](1);
        removeIpIds[0] = ipId1;
        vm.expectEmit();
        emit IGroupingModule.RemovedIpFromGroup(groupId, removeIpIds);
        groupingModule.removeIp(groupId, removeIpIds);
    }

    function test_GroupingModule_claimReward() public {
        vm.warp(100);
        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10_000_000,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: false,
            expectMinimumGroupRewardShare: 10 * 10 ** 6,
            expectGroupRewardPool: address(evenSplitGroupPool)
        });

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();
        licensingModule.mintLicenseTokens(ipId1, address(pilTemplate), termsId, 1, address(this), "", 0);
        vm.startPrank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        licensingModule.mintLicenseTokens(ipId2, address(pilTemplate), termsId, 1, address(this), "", 0);
        vm.stopPrank();

        licensingConfig.expectGroupRewardPool = address(0);
        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        address[] memory ipIds = new address[](2);
        ipIds[0] = ipId1;
        ipIds[1] = ipId2;
        groupingModule.addIp(groupId, ipIds);
        assertEq(ipAssetRegistry.totalMembers(groupId), 2);
        assertEq(rewardPool.getTotalIps(groupId), 2);
        vm.stopPrank();

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = groupId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = termsId;
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6);

        erc20.mint(ipOwner3, 1000);
        vm.startPrank(ipOwner3);
        erc20.approve(address(royaltyModule), 1000);
        royaltyModule.payRoyaltyOnBehalf(ipId3, ipOwner3, address(erc20), 1000);
        vm.stopPrank();
        royaltyPolicyLAP.transferToVault(ipId3, groupId, address(erc20));
        vm.warp(vm.getBlockTimestamp() + 7 days);

        vm.expectEmit();
        emit IGroupingModule.CollectedRoyaltiesToGroupPool(groupId, address(erc20), address(rewardPool), 100);
        groupingModule.collectRoyalties(groupId, address(erc20));

        address[] memory claimIpIds = new address[](1);
        claimIpIds[0] = ipId1;

        uint256[] memory claimAmounts = new uint256[](1);
        claimAmounts[0] = 50;

        vm.expectEmit();
        emit IGroupingModule.ClaimedReward(groupId, address(erc20), claimIpIds, claimAmounts);
        groupingModule.claimReward(groupId, address(erc20), claimIpIds);
        assertEq(erc20.balanceOf(address(rewardPool)), 50);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 50);
    }

    function test_GroupingModule_claimReward_revert_notWhitelistedPool() public {
        vm.warp(100);
        vm.prank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10_000_000,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: false,
            expectMinimumGroupRewardShare: 10 * 10 ** 6,
            expectGroupRewardPool: address(evenSplitGroupPool)
        });

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();
        licensingModule.mintLicenseTokens(ipId1, address(pilTemplate), termsId, 1, address(this), "", 0);
        vm.startPrank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        licensingModule.mintLicenseTokens(ipId2, address(pilTemplate), termsId, 1, address(this), "", 0);
        vm.stopPrank();

        licensingConfig.expectGroupRewardPool = address(0);
        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        address[] memory ipIds = new address[](2);
        ipIds[0] = ipId1;
        ipIds[1] = ipId2;
        groupingModule.addIp(groupId, ipIds);
        assertEq(ipAssetRegistry.totalMembers(groupId), 2);
        assertEq(rewardPool.getTotalIps(groupId), 2);
        vm.stopPrank();

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = groupId;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = termsId;
        vm.prank(ipOwner3);
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6);

        erc20.mint(ipOwner3, 1000);
        vm.startPrank(ipOwner3);
        erc20.approve(address(royaltyModule), 1000);
        royaltyModule.payRoyaltyOnBehalf(ipId3, ipOwner3, address(erc20), 1000);
        vm.stopPrank();
        royaltyPolicyLAP.transferToVault(ipId3, groupId, address(erc20));
        vm.warp(vm.getBlockTimestamp() + 7 days);

        vm.prank(address(groupingModule));
        ipAssetRegistry.whitelistGroupRewardPool(address(rewardPool), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GroupingModule__GroupRewardPoolNotWhitelisted.selector,
                groupId,
                address(rewardPool)
            )
        );
        groupingModule.collectRoyalties(groupId, address(erc20));

        vm.prank(address(groupingModule));
        ipAssetRegistry.whitelistGroupRewardPool(address(rewardPool), true);

        vm.expectEmit();
        emit IGroupingModule.CollectedRoyaltiesToGroupPool(groupId, address(erc20), address(rewardPool), 100);
        groupingModule.collectRoyalties(groupId, address(erc20));

        address[] memory claimIpIds = new address[](1);
        claimIpIds[0] = ipId1;

        uint256[] memory claimAmounts = new uint256[](1);
        claimAmounts[0] = 50;

        vm.prank(address(groupingModule));
        ipAssetRegistry.whitelistGroupRewardPool(address(rewardPool), false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GroupingModule__GroupRewardPoolNotWhitelisted.selector,
                groupId,
                address(rewardPool)
            )
        );
        groupingModule.claimReward(groupId, address(erc20), claimIpIds);

        vm.prank(address(groupingModule));
        ipAssetRegistry.whitelistGroupRewardPool(address(rewardPool), true);

        vm.expectEmit();
        emit IGroupingModule.ClaimedReward(groupId, address(erc20), claimIpIds, claimAmounts);
        groupingModule.claimReward(groupId, address(erc20), claimIpIds);
        assertEq(erc20.balanceOf(address(rewardPool)), 50);
        assertEq(erc20.balanceOf(royaltyModule.ipRoyaltyVaults(ipId1)), 50);
    }

    function test_GroupingModule_addIp_revert_addGroupToGroup() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId1, address(pilTemplate), termsId);
        address groupId2 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId2, address(pilTemplate), termsId);
        vm.stopPrank();

        address[] memory ipIds = new address[](1);
        ipIds[0] = groupId2;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GroupingModule__CannotAddGroupToGroup.selector, groupId1, groupId2)
        );
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 0);
        assertEq(rewardPool.getTotalIps(groupId1), 0);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId1), 0);
    }

    function test_GroupingModule_addIp_revert_GroupOnlyAttachedDefaultLicense() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        vm.stopPrank();

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GroupingModule__GroupIPShouldHasNonDefaultLicenseTerms.selector, groupId1)
        );
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 0);
        assertEq(rewardPool.getTotalIps(groupId1), 0);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId1), 0);
    }

    function test_GroupingModule_addIp_revert_DisputedIp() public {
        bytes32 disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId1, address(pilTemplate), termsId);
        vm.stopPrank();

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        // raise dispute
        vm.startPrank(ipId2);
        USDC.mint(ipId2, 1000 * 10 ** 6);
        IERC20(USDC).approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipId1, disputeEvidenceHashExample, "IMPROPER_REGISTRATION", "");
        vm.stopPrank();

        // set dispute judgement
        (, , , , , , bytes32 currentTagBefore, ) = disputeModule.disputes(1);

        vm.prank(u.relayer);
        disputeModule.setDisputeJudgement(1, true, "");

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;
        vm.expectRevert(abi.encodeWithSelector(Errors.GroupingModule__CannotAddDisputedIpToGroup.selector, ipId1));
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 0);
        assertEq(rewardPool.getTotalIps(groupId1), 0);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId1), 0);
    }

    function test_GroupingModule_addIp_revert_licenseDisabled() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId1, address(pilTemplate), termsId);
        vm.stopPrank();

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: true,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(evenSplitGroupPool)
        });

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__IpLicenseDisabled.selector,
                ipId1,
                address(pilTemplate),
                termsId
            )
        );
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 0);
        assertEq(rewardPool.getTotalIps(groupId1), 0);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId1), 0);
    }

    function test_GroupingModule_addIp_revert_IpExpectedGroupRewardPoolNotMatchGroupPool() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId1, address(pilTemplate), termsId);
        vm.stopPrank();

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0x123)
        });

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__IpExpectGroupRewardPoolNotMatch.selector,
                ipId1,
                address(0x123),
                groupId1,
                address(rewardPool)
            )
        );
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 0);
        assertEq(rewardPool.getTotalIps(groupId1), 0);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId1), 0);
    }

    function test_GroupingModule_addIp_revert_IpNotSetExpectedGroupRewardPool() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId1, address(pilTemplate), termsId);
        vm.stopPrank();

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IpExpectGroupRewardPoolNotSet.selector, ipId1));
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 0);
        assertEq(rewardPool.getTotalIps(groupId1), 0);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId1), 0);
    }

    function test_GroupingModule_addIp_revert_TotalGroupRewardShareExceed100Percent() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(0),
            hookData: "",
            commercialRevShare: 10 * 10 ** 6,
            disabled: false,
            expectMinimumGroupRewardShare: 60 * 10 ** 6,
            expectGroupRewardPool: address(rewardPool)
        });

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        vm.startPrank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        licensingConfig.expectGroupRewardPool = address(0);
        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(groupId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        ipIds[0] = ipId2;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.GroupingModule__TotalGroupRewardShareExceeds100Percent.selector,
                groupId1,
                120 * 10 ** 6,
                ipId2,
                60 * 10 ** 6
            )
        );
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 1);
        assertEq(rewardPool.getTotalIps(groupId1), 1);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId1), block.timestamp);
    }

    function test_GroupingModule_addIp_revert_ipWithExpiration() public {
        PILTerms memory expiredTerms = PILFlavors.commercialRemix({
            mintingFee: 0,
            commercialRevShare: 10,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        expiredTerms.expiration = 10 days;
        uint256 termsId = pilTemplate.registerLicenseTerms(expiredTerms);

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

        vm.startPrank(alice);
        address groupId1 = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId1, address(pilTemplate), termsId);
        vm.stopPrank();

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = termsId;
        vm.startPrank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId2;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseRegistry__CannotAddIpWithExpirationToGroup.selector, ipId2)
        );
        vm.prank(alice);
        groupingModule.addIp(groupId1, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId1), 0);
        assertEq(rewardPool.getTotalIps(groupId1), 0);
        assertEq(rewardPool.getIpAddedTime(groupId1, ipId2), 0);
    }

    function test_GroupingModule_addIp_revert_after_registerDerivative() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

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
        vm.prank(ipOwner1);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);

        licensingConfig.expectGroupRewardPool = address(0);
        vm.startPrank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;
        vm.prank(alice);
        groupingModule.addIp(groupId, ipIds);

        vm.startPrank(ipOwner3);
        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = groupId;
        licenseTermsIds[0] = termsId;

        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6);
        vm.stopPrank();

        ipIds = new address[](1);
        ipIds[0] = ipId2;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GroupingModule__GroupFrozenDueToHasDerivativeIps.selector, groupId)
        );
        vm.prank(alice);
        groupingModule.addIp(groupId, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId), 1);
        assertEq(rewardPool.getTotalIps(groupId), 1);
        assertEq(rewardPool.getIpAddedTime(groupId, ipId1), block.timestamp);
    }

    function test_GroupingModule_registerDerivative_revert_emptyGroup() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.startPrank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        vm.stopPrank();

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

        vm.startPrank(ipOwner3);
        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = groupId;
        licenseTermsIds[0] = termsId;

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__ParentIpIsEmptyGroup.selector, groupId));
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6);
        vm.stopPrank();
    }

    function test_GroupingModule_mintLicenseToken_revert_emptyGroup() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.startPrank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        vm.stopPrank();

        vm.startPrank(ipOwner3);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.LicenseRegistry__EmptyGroupCannotMintLicenseToken.selector, groupId)
        );
        licensingModule.mintLicenseTokens(groupId, address(pilTemplate), termsId, 1, ipOwner3, "", 0);
        vm.stopPrank();
    }

    function test_GroupingModule_registerDerivative_revert_registerGroupAsChild() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        vm.startPrank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));
        vm.stopPrank();

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);

        vm.startPrank(alice);
        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipId1;
        licenseTermsIds[0] = termsId;

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__GroupCannotHasParentIp.selector, groupId));
        licensingModule.registerDerivative(groupId, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6);
        vm.stopPrank();
    }

    function test_GroupingModule_removeIp_revert_after_registerDerivative() public {
        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
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

        vm.startPrank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId1, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();
        vm.startPrank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(ipId2, address(pilTemplate), termsId, licensingConfig);
        vm.stopPrank();

        licensingConfig.expectGroupRewardPool = address(0);
        vm.startPrank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
        licensingModule.setLicensingConfig(groupId, address(pilTemplate), termsId, licensingConfig);
        address[] memory ipIds = new address[](2);
        ipIds[0] = ipId1;
        ipIds[1] = ipId2;
        vm.expectEmit();
        emit IGroupingModule.AddedIpToGroup(groupId, ipIds);
        groupingModule.addIp(groupId, ipIds);
        vm.stopPrank();

        assertEq(ipAssetRegistry.totalMembers(groupId), 2);
        assertEq(rewardPool.getTotalIps(groupId), 2);
        assertEq(rewardPool.getIpAddedTime(groupId, ipId1), block.timestamp);

        vm.startPrank(ipOwner3);
        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = groupId;
        licenseTermsIds[0] = termsId;

        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "", 0, 100e6);
        vm.stopPrank();

        address[] memory removeIpIds = new address[](1);
        removeIpIds[0] = ipId1;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GroupingModule__GroupFrozenDueToHasDerivativeIps.selector, groupId)
        );
        vm.prank(alice);
        groupingModule.removeIp(groupId, removeIpIds);
    }
}
