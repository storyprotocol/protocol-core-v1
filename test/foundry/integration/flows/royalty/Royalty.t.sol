// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IRoyaltyModule } from "../../../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IpRoyaltyVault } from "../../../../../contracts/modules/royalty/policies/IpRoyaltyVault.sol";
import { Errors } from "../../../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../../../contracts/lib/PILFlavors.sol";
import { MockExternalRoyaltyPolicy1 } from "../../../mocks/policy/MockExternalRoyaltyPolicy1.sol";

// test
import { BaseIntegration } from "../../BaseIntegration.t.sol";

contract Flows_Integration_Disputes is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    uint32 internal defaultCommRevShare = 10 * 10 ** 6; // 10%
    uint256 internal mintingFee = 7 ether;
    uint256 internal commRemixTermsId;

    function setUp() public override {
        super.setUp();

        commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                mintingFee: mintingFee,
                commercialRevShare: defaultCommRevShare,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );

        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);
        mockNFT.mintId(u.carl, 3);
    }

    function test_Integration_Royalty() public {
        {
            vm.startPrank(u.alice);

            ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
            vm.label(ipAcct[1], "IPAccount1");

            licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commRemixTermsId);
            vm.stopPrank();
        }

        // Bob mints 1 license of policy "pil-commercial-remix" from IPAccount1 and registers the derivative IP for
        // NFT tokenId 2.
        {
            vm.startPrank(u.bob);

            uint256 mintAmount = 3;
            erc20.approve(address(royaltyModule), mintAmount * mintingFee);

            uint256[] memory licenseIds = new uint256[](3);

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.LicenseMintingFeePaid(ipAcct[1], u.bob, address(erc20), mintAmount * mintingFee);

            licenseIds[0] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[1],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commRemixTermsId,
                amount: mintAmount,
                receiver: u.bob,
                royaltyContext: ""
            }); // first license minted
            licenseIds[1] = licenseIds[0] + 1; // second license minted
            licenseIds[2] = licenseIds[0] + 2; // third license minted

            ipAcct[2] = registerIpAccount(address(mockNFT), 2, u.bob);

            vm.expectRevert(
                abi.encodeWithSelector(
                    Errors.LicenseRegistry__DuplicateLicense.selector,
                    ipAcct[1],
                    address(pilTemplate),
                    commRemixTermsId
                )
            );
            licensingModule.registerDerivativeWithLicenseTokens(ipAcct[2], licenseIds, "");

            // can link max two
            uint256[] memory licenseIdsMax = new uint256[](1);
            licenseIdsMax[0] = licenseIds[0];

            registerDerivativeWithLicenseTokens(ipAcct[2], licenseIdsMax, "", u.bob);

            vm.stopPrank();
        }

        // Carl mints 1 license of policy "pil-commercial-remix" from IPAccount1 and IPAccount2 and registers the
        // derivative IP for NFT tokenId 3. Thus, IPAccount3 is a derivative of both IPAccount1 and IPAccount2.
        // More precisely, IPAccount1 is a grandparent and IPAccount2 is a parent of IPAccount3.
        {
            vm.startPrank(u.carl);

            uint256 mintAmount = 1;
            uint256[] memory licenseIds = new uint256[](2);

            erc20.approve(address(royaltyModule), 2 * mintAmount * mintingFee);

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.LicenseMintingFeePaid(ipAcct[1], u.carl, address(erc20), mintAmount * mintingFee);
            licenseIds[0] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[1],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commRemixTermsId,
                amount: mintAmount,
                receiver: u.carl,
                royaltyContext: ""
            });

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.LicenseMintingFeePaid(ipAcct[2], u.carl, address(erc20), mintAmount * mintingFee);
            licenseIds[1] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[2], // parent, is child IP of ipAcct[1]
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commRemixTermsId,
                amount: mintAmount,
                receiver: u.carl,
                royaltyContext: ""
            });

            ipAcct[3] = registerIpAccount(address(mockNFT), 3, u.carl);
            registerDerivativeWithLicenseTokens(ipAcct[3], licenseIds, "", u.carl);
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
            royaltyModule.payRoyaltyOnBehalf(ipAcct[3], ipAcct[3], address(mockToken), 1 ether);
            totalPaymentToIpAcct3 += 1 ether;

            vm.stopPrank();
        }

        // Alice claims her revenue from both IPAccount2 and IPAccount3
        {
            vm.startPrank(ipAcct[1]);

            address vault = royaltyModule.ipRoyaltyVaults(ipAcct[1]);
            uint256 earningsFromMintingFees = 4 * mintingFee;
            assertEq(mockToken.balanceOf(vault), earningsFromMintingFees);

            royaltyPolicyLAP.transferToVault(
                ipAcct[2],
                ipAcct[1],
                address(mockToken),
                (1 ether * 10_000_000) / royaltyModule.maxPercent()
            );
            royaltyPolicyLAP.transferToVault(
                ipAcct[3],
                ipAcct[1],
                address(mockToken),
                (1 ether * 20_000_000) / royaltyModule.maxPercent()
            );

            vm.warp(block.timestamp + 7 days + 1);
            IpRoyaltyVault(vault).snapshot();

            uint256[] memory snapshotIds = new uint256[](1);
            snapshotIds[0] = 1;

            uint256 aliceBalanceBefore = mockToken.balanceOf(ipAcct[1]);

            IpRoyaltyVault(vault).claimRevenueOnBehalfBySnapshotBatch(snapshotIds, address(mockToken), ipAcct[1]);

            uint256 aliceBalanceAfter = mockToken.balanceOf(ipAcct[1]);

            assertEq(
                aliceBalanceAfter - aliceBalanceBefore,
                earningsFromMintingFees + (1 ether * (10_000_000 + 20_000_000)) / royaltyModule.maxPercent()
            );
        }

        // A derivation occurs using an external royalty policy
        {
            // Register an external royalty policy
            MockExternalRoyaltyPolicy1 mockExternalRoyaltyPolicy1 = new MockExternalRoyaltyPolicy1();
            royaltyModule.registerExternalRoyaltyPolicy(address(mockExternalRoyaltyPolicy1));

            vm.startPrank(u.alice);
            erc20.approve(address(royaltyModule), type(uint256).max);

            mockNFT.mintId(u.alice, 4);
            ipAcct[4] = registerIpAccount(mockNFT, 4, u.alice);
            vm.label(ipAcct[4], "IPAccount4");

            uint256 commRemixExternalTermsId = registerSelectedPILicenseTerms(
                "commercial_remix_external",
                PILFlavors.commercialRemix({
                    mintingFee: mintingFee,
                    commercialRevShare: defaultCommRevShare,
                    royaltyPolicy: address(mockExternalRoyaltyPolicy1),
                    currencyToken: address(erc20)
                })
            );

            licensingModule.attachLicenseTerms(ipAcct[4], address(pilTemplate), commRemixExternalTermsId);

            uint256[] memory licenseId = new uint256[](1);
            licenseId[0] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[4],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commRemixExternalTermsId,
                amount: 1,
                receiver: u.alice,
                royaltyContext: ""
            });

            mockNFT.mintId(u.alice, 5);
            ipAcct[5] = registerIpAccount(mockNFT, 5, u.alice);
            vm.label(ipAcct[5], "IPAccount5");

            licensingModule.registerDerivativeWithLicenseTokens(ipAcct[5], licenseId, "");

            vm.stopPrank();
        }
    }
}
