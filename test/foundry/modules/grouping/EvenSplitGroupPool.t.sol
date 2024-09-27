// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
// test
import { EvenSplitGroupPool } from "../../../../contracts/modules/grouping/EvenSplitGroupPool.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract EvenSplitGroupPoolTest is BaseTest {
    using Strings for *;

    MockERC721 internal mockNft = new MockERC721("MockERC721");

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
    address public group1;
    address public group2;
    address public group3;

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

        rewardPool = new EvenSplitGroupPool(address(groupingModule), address(royaltyModule), address(ipAssetRegistry));
        vm.prank(admin);
        groupingModule.whitelistGroupRewardPool(address(rewardPool));
        group1 = groupingModule.registerGroup(address(rewardPool));
        group2 = groupingModule.registerGroup(address(rewardPool));
        group3 = groupingModule.registerGroup(address(rewardPool));
    }

    function test_EvenSplitGroupPool_AddIp() public {
        vm.startPrank(address(groupingModule));

        rewardPool.addIp(group1, ipId1);
        rewardPool.addIp(group1, ipId2);
        rewardPool.addIp(group1, ipId3);
        assertNotEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertNotEq(rewardPool.getIpAddedTime(group1, ipId2), 0);
        assertNotEq(rewardPool.getIpAddedTime(group1, ipId3), 0);
        assertTrue(rewardPool.isIPAdded(group1, ipId1));
        assertTrue(rewardPool.isIPAdded(group1, ipId2));
        assertTrue(rewardPool.isIPAdded(group1, ipId3));

        // remove ip
        rewardPool.removeIp(group1, ipId1);
        assertEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertFalse(rewardPool.isIPAdded(group1, ipId1));

        // add ip again
        rewardPool.addIp(group1, ipId1);
        assertNotEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertTrue(rewardPool.isIPAdded(group1, ipId1));

        vm.stopPrank();
    }

    function test_EvenSplitGroupPool_RemoveIp() public {
        vm.startPrank(address(groupingModule));

        rewardPool.addIp(group1, ipId1);
        rewardPool.removeIp(group1, ipId1);
        assertEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertFalse(rewardPool.isIPAdded(group1, ipId1));
        // remove again
        rewardPool.removeIp(group1, ipId1);
        assertEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertFalse(rewardPool.isIPAdded(group1, ipId1));
    }

    // test add and remove ip from pool
    // test add an IP twice
    // test add an IP to multiple pools
    // test remove an IP from multiple pools
    // test remove an IP that is not in the pool
    // test add ip to pool and distribute reward
    // test deposit reward and distribute reward
    // test deposit unregistered token
    // test deposit with registered group

    function test_EvenSplitGroupPool_AddIpTwice() public {
        vm.startPrank(address(groupingModule));

        rewardPool.addIp(group1, ipId1);
        rewardPool.addIp(group1, ipId1);
        assertNotEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertTrue(rewardPool.isIPAdded(group1, ipId1));

        vm.stopPrank();
    }

    function test_EvenSplitGroupPool_AddIpToMultiplePools() public {
        vm.startPrank(address(groupingModule));

        rewardPool.addIp(group1, ipId1);
        rewardPool.addIp(group2, ipId1);
        assertNotEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertNotEq(rewardPool.getIpAddedTime(group2, ipId1), 0);
        assertTrue(rewardPool.isIPAdded(group1, ipId1));
        assertTrue(rewardPool.isIPAdded(group2, ipId1));

        vm.stopPrank();
    }

    function test_EvenSplitGroupPool_RemoveIpFromMultiplePools() public {
        vm.startPrank(address(groupingModule));

        rewardPool.addIp(group1, ipId1);
        rewardPool.addIp(group2, ipId1);
        rewardPool.removeIp(group1, ipId1);
        assertEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertNotEq(rewardPool.getIpAddedTime(group2, ipId1), 0);
        assertFalse(rewardPool.isIPAdded(group1, ipId1));
        assertTrue(rewardPool.isIPAdded(group2, ipId1));

        vm.stopPrank();
    }

    function test_EvenSplitGroupPool_RemoveIpNotInPool() public {
        vm.startPrank(address(groupingModule));

        rewardPool.removeIp(group1, ipId1);
        assertEq(rewardPool.getIpAddedTime(group1, ipId1), 0);
        assertFalse(rewardPool.isIPAdded(group1, ipId1));

        vm.stopPrank();
    }

    function test_EvenSplitGroupPool_AddIpAndDistributeReward() public {
        uint256 commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10_000_000, // 10%
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );

        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        licensingModule.mintLicenseTokens(ipId1, address(pilTemplate), commRemixTermsId, 1, address(this), "");

        vm.prank(address(groupingModule));
        rewardPool.addIp(group1, ipId1);

        erc20.mint(address(this), 100);
        erc20.approve(address(rewardPool), 100);

        rewardPool.depositReward(group1, address(erc20), 100);
        assertEq(erc20.balanceOf(address(rewardPool)), 100);

        uint256 rewardDebt = rewardPool.getIpRewardDebt(group1, address(erc20), ipId1);
        assertEq(rewardDebt, 0);

        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId1;

        uint256[] memory rewards = rewardPool.getAvailableReward(group1, address(erc20), ipIds);
        assertEq(rewards[0], 100);

        rewards = rewardPool.distributeRewards(group1, address(erc20), ipIds);
        assertEq(rewards[0], 100);

        assertEq(erc20.balanceOf(address(rewardPool)), 0);

        rewardDebt = rewardPool.getIpRewardDebt(group1, address(erc20), ipId1);
        assertEq(rewardDebt, 100);

        vm.stopPrank();
    }
}
