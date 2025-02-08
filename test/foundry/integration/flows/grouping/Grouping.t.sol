// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contracts
// solhint-disable-next-line max-line-length
import { PILFlavors } from "../../../../../contracts/lib/PILFlavors.sol";
import { Licensing } from "../../../../../contracts/lib/Licensing.sol";
import { IGroupingModule } from "../../../../../contracts/interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "../../../../../contracts/interfaces/registries/IGroupIPAssetRegistry.sol";
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

// test
import { BaseIntegration } from "../../BaseIntegration.t.sol";

contract Flows_Integration_Grouping is BaseIntegration, ERC721Holder {
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

    address internal groupOwner;
    address internal groupId;

    function setUp() public override {
        super.setUp();
        commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: defaultCommRevShare,
                royaltyPolicy: address(royaltyPolicyLRP),
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

        licensingConfig.expectGroupRewardPool = address(0);

        {
            vm.startPrank(groupOwner);
            groupId = groupingModule.registerGroup(address(evenSplitGroupPool));
            vm.label(groupId, "Group1");
            licensingModule.attachLicenseTerms(groupId, address(pilTemplate), commRemixTermsId);
            licensingModule.setLicensingConfig(groupId, address(pilTemplate), commRemixTermsId, licensingConfig);
            vm.stopPrank();
        }

        licensingConfig.expectGroupRewardPool = address(evenSplitGroupPool);
        {
            vm.startPrank(u.alice);
            ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
            vm.label(ipAcct[1], "IPAccount1");
            licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commRemixTermsId);
            licensingModule.setLicensingConfig(ipAcct[1], address(pilTemplate), commRemixTermsId, licensingConfig);
            vm.stopPrank();
        }

        {
            vm.startPrank(u.bob);
            ipAcct[2] = registerIpAccount(mockNFT, 2, u.bob);
            vm.label(ipAcct[2], "IPAccount2");
            licensingModule.attachLicenseTerms(ipAcct[2], address(pilTemplate), commRemixTermsId);
            licensingModule.setLicensingConfig(ipAcct[2], address(pilTemplate), commRemixTermsId, licensingConfig);
            vm.stopPrank();
        }

        licensingModule.mintLicenseTokens(
            ipAcct[1],
            address(pilTemplate),
            commRemixTermsId,
            1,
            address(this),
            "",
            0,
            0
        );
        licensingModule.mintLicenseTokens(
            ipAcct[2],
            address(pilTemplate),
            commRemixTermsId,
            1,
            address(this),
            "",
            0,
            0
        );
        {
            address[] memory ipIds = new address[](2);
            ipIds[0] = ipAcct[1];
            ipIds[1] = ipAcct[2];
            vm.startPrank(groupOwner);
            groupingModule.addIp(groupId, ipIds, 100e6);
            vm.stopPrank();
        }

        {
            vm.startPrank(u.carl);
            ipAcct[3] = registerIpAccount(mockNFT, 3, u.carl);
            address[] memory parentIpIds = new address[](1);
            parentIpIds[0] = groupId;
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = commRemixTermsId;
            licensingModule.registerDerivative(
                ipAcct[3],
                parentIpIds,
                licenseIds,
                address(pilTemplate),
                "",
                0,
                100e6,
                0
            );
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

            royaltyPolicyLRP.transferToVault(ipAcct[3], groupId, address(mockToken));

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
            emit IGroupingModule.CollectedRoyaltiesToGroupPool(
                groupId,
                address(mockToken),
                IGroupIPAssetRegistry(ipAssetRegistry).getGroupRewardPool(groupId),
                1 ether
            );
            uint256 royalties = groupingModule.collectRoyalties(groupId, address(mockToken));
            assertEq(royalties, 1 ether);
            vm.expectEmit(address(groupingModule));
            emit IGroupingModule.ClaimedReward(groupId, address(erc20), ipIds, rewards);
            groupingModule.claimReward(groupId, address(erc20), ipIds);
            assertEq(mockToken.balanceOf(royaltyModule.ipRoyaltyVaults(ipAcct[1])), 1 ether / 2);
            assertEq(mockToken.balanceOf(royaltyModule.ipRoyaltyVaults(ipAcct[2])), 1 ether / 2);
        }
    }
}
