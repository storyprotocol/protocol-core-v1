// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { IGroupingModule } from "../../../../contracts/interfaces/modules/grouping/IGroupingModule.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
// test
import { EvenSplitGroupPool } from "../../../../contracts/modules/grouping/EvenSplitGroupPool.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { IIpRoyaltyVault } from "../../../../contracts/interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";

contract GroupingModuleTest is BaseTest {
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

    function test_GroupingModule_whitelistRewardPool() public {
        vm.prank(admin);
        groupingModule.whitelistGroupRewardPool(address(rewardPool));
        assertEq(ipAssetRegistry.isWhitelistedGroupRewardPool(address(rewardPool)), true);

        assertEq(ipAssetRegistry.isWhitelistedGroupRewardPool(address(0x123)), false);
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

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
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

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
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

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        licensingModule.mintLicenseTokens(ipId1, address(pilTemplate), termsId, 1, address(this), "");
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);
        licensingModule.mintLicenseTokens(ipId2, address(pilTemplate), termsId, 1, address(this), "");

        vm.startPrank(alice);
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
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
        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "");

        erc20.mint(ipOwner3, 1000);
        vm.startPrank(ipOwner3);
        erc20.approve(address(royaltyModule), 1000);
        royaltyModule.payRoyaltyOnBehalf(ipId3, ipOwner3, address(erc20), 1000);
        vm.stopPrank();
        royaltyPolicyLAP.transferToVault(ipId3, groupId, address(erc20), 100);
        vm.warp(vm.getBlockTimestamp() + 7 days);

        uint256 snapshotId = IIpRoyaltyVault(royaltyModule.ipRoyaltyVaults(groupId)).snapshot();
        uint256[] memory snapshotIds = new uint256[](1);
        snapshotIds[0] = snapshotId;

        vm.expectEmit();
        emit IGroupingModule.CollectedRoyaltiesToGroupPool(
            groupId,
            address(erc20),
            address(rewardPool),
            100,
            snapshotIds
        );
        groupingModule.collectRoyalties(groupId, address(erc20), snapshotIds);

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

    function test_GroupingModule_addIp_revert_after_registerDerivative() public {
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

        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "");
        vm.stopPrank();

        address[] memory ipIds = new address[](2);
        ipIds[0] = ipId1;
        ipIds[1] = ipId2;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.GroupingModule__GroupFrozenDueToHasDerivativeIps.selector, groupId)
        );
        vm.prank(alice);
        groupingModule.addIp(groupId, ipIds);

        assertEq(ipAssetRegistry.totalMembers(groupId), 0);
        assertEq(rewardPool.getTotalIps(groupId), 0);
        assertEq(rewardPool.getIpAddedTime(groupId, ipId1), 0);
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

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), termsId);
        vm.prank(ipOwner2);
        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), termsId);

        vm.startPrank(alice);
        address groupId = groupingModule.registerGroup(address(rewardPool));
        licensingModule.attachLicenseTerms(groupId, address(pilTemplate), termsId);
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

        licensingModule.registerDerivative(ipId3, parentIpIds, licenseTermsIds, address(pilTemplate), "");
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
