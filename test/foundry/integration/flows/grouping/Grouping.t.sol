// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contracts
import { IRoyaltyModule } from "../../../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IpRoyaltyVault } from "../../../../../contracts/modules/royalty/policies/IpRoyaltyVault.sol";
// solhint-disable-next-line max-line-length
import { IRoyaltyPolicyLAP } from "../../../../../contracts/interfaces/modules/royalty/policies/LAP/IRoyaltyPolicyLAP.sol";
import { Errors } from "../../../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../../../contracts/lib/PILFlavors.sol";
import { IGroupRewardPool } from "../../../../../contracts/interfaces/modules/grouping/IGroupRewardPool.sol";
import { MockEvenSplitGroupPool } from "test/foundry/mocks/grouping/MockEvenSplitGroupPool.sol";

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
    address internal rewardPool = address(new MockEvenSplitGroupPool(address(royaltyModule)));

    address internal groupOwner;

    function setUp() public override {
        super.setUp();

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
        // create a group
        {
            vm.startPrank(groupOwner);
            address groupId = groupingModule.registerGroup(rewardPool);
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

            mockToken.mint(newUser, 1 ether);

            mockToken.approve(address(royaltyModule), 1 ether);
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

            address ipRoyaltyVault3 = royaltyModule.ipRoyaltyVaults(ipAcct[3]);
            address groupRoyaltyVault = royaltyModule.ipRoyaltyVaults(groupId);

            vm.warp(block.timestamp + 7 days + 1);
            IpRoyaltyVault(ipRoyaltyVault3).snapshot();

            // Expect 10% (10_000_000) because ipAcct[2] has only one parent (IPAccount1), with 10% absolute royalty.

            uint256[] memory snapshotsToClaim = new uint256[](1);
            snapshotsToClaim[0] = 1;
            royaltyPolicyLAP.claimBySnapshotBatchAsSelf(snapshotsToClaim, address(mockToken), ipAcct[3]);

            vm.expectEmit(ipRoyaltyVault3);
            emit IERC20.Transfer({ from: address(royaltyPolicyLAP), to: groupRoyaltyVault, value: 10_000_000 });

            vm.expectEmit(address(royaltyPolicyLAP));
            emit IRoyaltyPolicyLAP.RoyaltyTokensCollected(ipAcct[3], groupId, 10_000_000);

            royaltyPolicyLAP.collectRoyaltyTokens(ipAcct[3], groupId);

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
            assertEq(mockToken.balanceOf(royaltyModule.ipRoyaltyVaults(ipAcct[1])), 5_000_000);
            assertEq(mockToken.balanceOf(royaltyModule.ipRoyaltyVaults(ipAcct[2])), 5_000_000);
        }

        //        // Owner of IPAccount2, Bob, claims his RTs from IPAccount3 vault
        //        {
        //            vm.startPrank(u.bob);
        //
        //            ERC20[] memory tokens = new ERC20[](1);
        //            tokens[0] = mockToken;
        //
        //            address ipRoyaltyVault3 = royaltyModule.ipRoyaltyVaults(ipAcct[3]);
        //            address ipRoyaltyVault2 = royaltyModule.ipRoyaltyVaults(ipAcct[2]);
        //
        //            vm.warp(block.timestamp + 7 days + 1);
        //            IpRoyaltyVault(ipRoyaltyVault3).snapshot();
        //
        //            // Expect 10% (10_000_000) because ipAcct[2] has only one parent (IPAccount1), with 10% absolute royalty.
        //
        //            uint256[] memory snapshotsToClaim = new uint256[](1);
        //            snapshotsToClaim[0] = 1;
        //            royaltyPolicyLAP.claimBySnapshotBatchAsSelf(snapshotsToClaim, address(mockToken), ipAcct[3]);
        //
        //            vm.expectEmit(ipRoyaltyVault3);
        //            emit IERC20.Transfer({ from: address(royaltyPolicyLAP), to: ipRoyaltyVault2, value: 10_000_000 });
        //
        //            vm.expectEmit(address(royaltyPolicyLAP));
        //            emit IRoyaltyPolicyLAP.RoyaltyTokensCollected(ipAcct[3], ipAcct[2], 10_000_000);
        //
        //            royaltyPolicyLAP.collectRoyaltyTokens(ipAcct[3], ipAcct[2]);
        //        }

        // Owner of IPAccount1, Alice, claims her RTs from IPAccount2 and IPAccount3 vaults
//        {
//            vm.startPrank(address(100));
//
//            ERC20[] memory tokens = new ERC20[](1);
//            tokens[0] = mockToken;
//
//            address ipRoyaltyVault1 = royaltyModule.ipRoyaltyVaults(ipAcct[1]);
//            address ipRoyaltyVault2 = royaltyModule.ipRoyaltyVaults(ipAcct[2]);
//            address ipRoyaltyVault3 = royaltyModule.ipRoyaltyVaults(ipAcct[3]);
//
//            vm.warp(block.timestamp + 7 days + 1);
//            IpRoyaltyVault(ipRoyaltyVault2).snapshot();
//
//            // IPAccount1 should expect 10% absolute royalty from its children (IPAccount2)
//            // and 20% from its grandchild (IPAccount3) and so on.
//
//            uint256[] memory snapshotsToClaim = new uint256[](1);
//            snapshotsToClaim[0] = 1;
//            royaltyPolicyLAP.claimBySnapshotBatchAsSelf(snapshotsToClaim, address(mockToken), ipAcct[2]);
//
//            vm.expectEmit(ipRoyaltyVault2);
//            emit IERC20.Transfer({ from: address(royaltyPolicyLAP), to: ipRoyaltyVault1, value: 10_000_000 });
//            vm.expectEmit(address(royaltyPolicyLAP));
//            emit IRoyaltyPolicyLAP.RoyaltyTokensCollected(ipAcct[2], ipAcct[1], 10_000_000);
//            royaltyPolicyLAP.collectRoyaltyTokens(ipAcct[2], ipAcct[1]);
//
//            vm.expectEmit(ipRoyaltyVault3);
//            emit IERC20.Transfer({ from: address(royaltyPolicyLAP), to: ipRoyaltyVault1, value: 20_000_000 });
//            vm.expectEmit(address(royaltyPolicyLAP));
//            emit IRoyaltyPolicyLAP.RoyaltyTokensCollected(ipAcct[3], ipAcct[1], 20_000_000);
//            royaltyPolicyLAP.collectRoyaltyTokens(ipAcct[3], ipAcct[1]);
//        }
//
//        // Alice using IPAccount1 takes snapshot on IPAccount2 vault and claims her revenue from both
//        // IPAccount2 and IPAccount3
//        {
//            vm.startPrank(ipAcct[1]);
//
//            address ipRoyaltyVault1 = royaltyModule.ipRoyaltyVaults(ipAcct[1]);
//
//            address[] memory tokens = new address[](1);
//            tokens[0] = address(mockToken);
//
//            IpRoyaltyVault(ipRoyaltyVault1).snapshot();
//
//            IpRoyaltyVault(ipRoyaltyVault1).claimRevenueByTokenBatch(1, tokens);
//        }
    }
}
