// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contracts
// solhint-disable-next-line max-line-length
import { PILFlavors } from "../../../../../contracts/lib/PILFlavors.sol";
import { EvenSplitGroupPool } from "../../../../../contracts/modules/grouping/EvenSplitGroupPool.sol";
import { IGroupingModule } from "../../../../../contracts/interfaces/modules/grouping/IGroupingModule.sol";

// test
import { BaseIntegration } from "../../BaseIntegration.t.sol";

contract Flows_Integration_Grouping is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    // steps:
    // 1. create a group
    // 2. add IP to the group
    // 3. register derivative of the group
    // 4. pay royalty to the group
    // 5. claim royalty to the pool
    // 6. distribute rewards to each IP in the group

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    uint32 internal defaultCommRevShare = 10 * 10 ** 6; // 10%
    uint256 internal commRemixTermsId;
    address internal rewardPool;

    address internal groupOwner;
    address internal groupId;

    function setUp() public override {
        super.setUp();
        rewardPool = address(
            new EvenSplitGroupPool(address(groupingModule), address(royaltyModule), address(ipAssetRegistry))
        );
        commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: defaultCommRevShare,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );

        groupOwner = address(0x123456);
        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);
        mockNFT.mintId(u.carl, 3);
    }

    function test_Integration_Grouping() public {
        vm.prank(admin);
        groupingModule.whitelistGroupRewardPool(rewardPool);
        // create a group
        {
            vm.startPrank(groupOwner);
            groupId = groupingModule.registerGroup(rewardPool);
            vm.label(groupId, "Group1");
            licensingModule.attachLicenseTerms(groupId, address(pilTemplate), commRemixTermsId);
            vm.stopPrank();
        }
        {
            vm.startPrank(u.alice);
            ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
            vm.label(ipAcct[1], "IPAccount1");
            licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commRemixTermsId);
            vm.stopPrank();
        }

        {
            vm.startPrank(u.bob);
            ipAcct[2] = registerIpAccount(mockNFT, 2, u.bob);
            vm.label(ipAcct[1], "IPAccount2");
            licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), commRemixTermsId);
            vm.stopPrank();
        }

        licensingModule.mintLicenseTokens(ipAcct[1], address(pilTemplate), commRemixTermsId, 1, address(this), "");
        licensingModule.mintLicenseTokens(ipAcct[2], address(pilTemplate), commRemixTermsId, 1, address(this), "");
        {
            address[] memory ipIds = new address[](2);
            ipIds[0] = ipAcct[1];
            ipIds[1] = ipAcct[2];
            vm.startPrank(groupOwner);
            groupingModule.addIp(groupId, ipIds);
            vm.stopPrank();
        }

        {
            vm.startPrank(u.carl);
            ipAcct[3] = registerIpAccount(mockNFT, 3, u.carl);
            address[] memory parentIpIds = new address[](1);
            parentIpIds[0] = groupId;
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = commRemixTermsId;
            licensingModule.registerDerivative(ipAcct[3], parentIpIds, licenseIds, address(pilTemplate), "");
            vm.stopPrank();
        }

        // IPAccount1 and IPAccount2 have commercial policy, of which IPAccount3 has used to mint licenses and link.
        // Thus, any payment to IPAccount3 will get split to IPAccount1 and IPAccount2 accordingly to policy.

        uint256 totalPaymentToIpAcct3;

        // A new user, who likes IPAccount3, decides to pay IPAccount3 some royalty (1 token).
        {
            address newUser = address(0xbeef);
            vm.startPrank(newUser);

            mockToken.mint(newUser, 10 ether);
            vm.label(address(royaltyModule), "RoyaltyModule");
            mockToken.approve(address(royaltyModule), 10 ether);
            // ipAcct[3] is the receiver, the actual token is paid by the caller (newUser).
            royaltyModule.payRoyaltyOnBehalf(ipAcct[3], ipAcct[3], address(mockToken), 10 ether);
            totalPaymentToIpAcct3 += 10 ether;

            vm.stopPrank();
        }

        // Owner of GroupIP, groupOwner, claims his RTs from IPAccount3 vault
        {
            vm.startPrank(groupOwner);

            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = mockToken;

            royaltyPolicyLAP.transferToVault(
                ipAcct[3],
                groupId,
                address(mockToken),
                (10 ether * 10_000_000) / royaltyModule.maxPercent()
            );

            vm.warp(block.timestamp + 7 days + 1);

            vm.stopPrank();
        }
        {
            address[] memory ipIds = new address[](2);
            ipIds[0] = ipAcct[1];
            ipIds[1] = ipAcct[2];
            uint256[] memory rewards = new uint256[](2);
            rewards[0] = 1 ether / 2;
            rewards[1] = 1 ether / 2;

            vm.expectEmit(address(groupingModule));
            emit IGroupingModule.ClaimedReward(groupId, address(erc20), ipIds, rewards);
            groupingModule.claimReward(groupId, address(erc20), ipIds);
            assertEq(mockToken.balanceOf(royaltyModule.ipRoyaltyVaults(ipAcct[1])), 1 ether / 2);
            assertEq(mockToken.balanceOf(royaltyModule.ipRoyaltyVaults(ipAcct[2])), 1 ether / 2);
        }
    }
}
