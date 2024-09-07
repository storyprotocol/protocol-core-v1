// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";
import { MockTokenGatedHook } from "../../mocks/MockTokenGatedHook.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";

contract BigBang_Integration_SingleNftCollection is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;

    MockTokenGatedHook internal mockTokenGatedHook = new MockTokenGatedHook();

    MockERC721 internal mockGatedNft = new MockERC721("MockGatedNft");

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    mapping(string name => uint256 licenseId) internal licenseIds;

    uint32 internal constant derivCheapFlexibleRevShare = 10;

    uint256 internal constant mintingFee = 100 ether;

    uint256 internal ncSocialRemixTermsId;

    uint256 internal commDerivTermsId;

    function setUp() public override {
        super.setUp();

        ncSocialRemixTermsId = registerSelectedPILicenseTerms_NonCommercialSocialRemixing();

        commDerivTermsId = registerSelectedPILicenseTerms(
            "commercial_flexible",
            PILTerms({
                transferable: true,
                royaltyPolicy: address(royaltyPolicyLAP),
                defaultMintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(mockTokenGatedHook),
                // Gated via balance > 1 of mockGatedNft
                commercializerCheckerData: abi.encode(address(mockGatedNft)),
                commercialRevShare: derivCheapFlexibleRevShare,
                commercialRevCeiling: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCeiling: 0,
                currency: address(erc20),
                uri: ""
            })
        );
    }

    function test_Integration_SingleNftCollection_DirectCallsByIPAccountOwners() public {
        /*//////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        // ipAcct[tokenId] => ipAccount address
        // owner is the vm.pranker

        vm.startPrank(u.alice);
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.alice, 100);
        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        ipAcct[100] = registerIpAccount(mockNFT, 100, u.alice);

        vm.startPrank(u.bob);
        mockNFT.mintId(u.bob, 3);
        mockNFT.mintId(u.bob, 300);
        ipAcct[3] = registerIpAccount(mockNFT, 3, u.bob);
        ipAcct[300] = registerIpAccount(mockNFT, 300, u.bob);

        vm.startPrank(u.carl);
        mockNFT.mintId(u.carl, 5);
        ipAcct[5] = registerIpAccount(mockNFT, 5, u.carl);

        /*//////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        vm.startPrank(u.alice);
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commDerivTermsId);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[100],
                address(pilTemplate),
                ncSocialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[100], address(pilTemplate), ncSocialRemixTermsId);

        vm.startPrank(u.bob);
        licensingModule.attachLicenseTerms(ipAcct[3], address(pilTemplate), commDerivTermsId);
        licensingModule.attachLicenseTerms(ipAcct[300], address(pilTemplate), commDerivTermsId);

        vm.startPrank(u.bob);
        // NOTE: the two calls below achieve the same functionality
        // licensingModule.attachLicenseTerms(ipAcct[3], address(pilTemplate), ncSocialRemixTermsId);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[3],
                address(pilTemplate),
                ncSocialRemixTermsId
            )
        );
        IIPAccount(payable(ipAcct[3])).execute(
            address(licensingModule),
            0,
            abi.encodeWithSignature(
                "attachLicenseTerms(address,address,uint256)",
                ipAcct[3],
                address(pilTemplate),
                ncSocialRemixTermsId
            )
        );

        /*///////////////////////////////////////////////////////////////
                                MINT & USE LICENSES
        ///////////////////////////////////////////////////////////////*/

        // Carl mints 1 license for policy "com_deriv_all_true" on Alice's NFT 1 IPAccount
        // Carl creates NFT 6 IPAccount
        // Carl activates the license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount
        {
            vm.startPrank(u.carl);
            mockNFT.mintId(u.carl, 6);

            // Carl needs to hold an NFT from mockGatedNFT collection to mint license pil_com_deriv_cheap_flexible
            // (verified by the mockTokenGatedHook commercializer checker)
            mockGatedNft.mint(u.carl);

            mockToken.approve(address(royaltyModule), mintingFee);

            uint256[] memory carl_license_from_root_alice = new uint256[](1);
            carl_license_from_root_alice[0] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[1],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commDerivTermsId,
                amount: 1,
                receiver: u.carl,
                royaltyContext: ""
            });

            ipAcct[6] = registerIpAccount(mockNFT, 6, u.carl);
            registerDerivativeWithLicenseTokens(ipAcct[6], carl_license_from_root_alice, "", u.carl);
        }

        // Carl mints 2 license for policy "pil_noncom_deriv_reciprocal_derivative" on Bob's NFT 3 IPAccount
        // Carl creates NFT 7 IPAccount
        // Carl activates one of the two licenses on his NFT 7 IPAccount, linking as child to Bob's NFT 3 IPAccount
        {
            vm.startPrank(u.carl);
            uint256 tokenId = 7;
            mockNFT.mintId(u.carl, tokenId); // NFT for Carl's IPAccount7

            // Carl is minting license on non-commercial policy, so no commercializer checker is involved.
            // Thus, no need to mint anything (although Carl already has mockGatedNft from above)

            uint256[] memory carl_license_from_root_bob = new uint256[](1);
            carl_license_from_root_bob[0] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[3],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: ncSocialRemixTermsId,
                amount: 1,
                receiver: u.carl,
                royaltyContext: ""
            });

            ipAcct[tokenId] = registerIpAccount(address(mockNFT), tokenId, u.carl);
            registerDerivativeWithLicenseTokens(ipAcct[tokenId], carl_license_from_root_bob, "", u.carl);
        }

        // Alice mints 2 license for policy "pil_com_deriv_cheap_flexible" on Bob's NFT 3 IPAccount
        // Alice creates NFT 2 IPAccount
        // Alice activates one of the two licenses on her NFT 2 IPAccount, linking as child to Bob's NFT 3 IPAccount
        // Alice creates derivative NFT 3 directly using the other license
        {
            vm.startPrank(u.alice);
            mockNFT.mintId(u.alice, 2);
            uint256 mintAmount = 2;

            mockToken.approve(address(royaltyModule), mintAmount * mintingFee);

            // Alice needs to hold an NFT from mockGatedNFT collection to mint license on pil_com_deriv_cheap_flexible
            // (verified by the mockTokenGatedHook commercializer checker)
            mockGatedNft.mint(u.alice);

            uint256[] memory alice_license_from_root_bob = new uint256[](1);
            alice_license_from_root_bob[0] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[3],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commDerivTermsId,
                amount: 2,
                receiver: u.alice,
                royaltyContext: ""
            }); // ID 0 (first license)

            ipAcct[2] = registerIpAccount(mockNFT, 2, u.alice);
            registerDerivativeWithLicenseTokens(ipAcct[2], alice_license_from_root_bob, "", u.alice);

            uint256 tokenId = 99999999;
            mockNFT.mintId(u.alice, tokenId);

            alice_license_from_root_bob[0] = alice_license_from_root_bob[0] + 1; // ID 1 (second license)

            ipAcct[tokenId] = registerIpAccount(address(mockNFT), tokenId, u.alice);
            registerDerivativeWithLicenseTokens(ipAcct[tokenId], alice_license_from_root_bob, "", u.alice);
        }

        // Carl mints licenses and linkts to multiple parents
        // Carl creates NFT 6 IPAccount
        // Carl activates the license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount
        {
            vm.startPrank(u.carl);

            uint256 license0_mintAmount = 1000;
            uint256 tokenId = 70000; // dummy number that shouldn't conflict with any other token IDs used in this test
            mockNFT.mintId(u.carl, tokenId);

            mockToken.mint(u.carl, mintingFee * license0_mintAmount);
            mockToken.approve(address(royaltyModule), mintingFee * license0_mintAmount);

            uint256[] memory carl_licenses = new uint256[](2);
            // Commercial license (Carl already has mockGatedNft from above, so he passes commercializer checker check)
            carl_licenses[0] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[1],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commDerivTermsId,
                amount: license0_mintAmount,
                receiver: u.carl,
                royaltyContext: ""
            });

            // NC Social Remix license
            carl_licenses[1] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[3],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: ncSocialRemixTermsId, // ipAcct[3] has this policy attached
                amount: 1,
                receiver: u.carl,
                royaltyContext: ""
            });

            ipAcct[tokenId] = registerIpAccount(address(mockNFT), tokenId, u.carl);
            // This should revert since license[0] is commercial but license[1] is non-commercial
            vm.expectRevert(
                abi.encodeWithSelector(
                    Errors.LicensingModule__LicenseTokenNotCompatibleForDerivative.selector,
                    ipAcct[tokenId],
                    carl_licenses
                )
            );
            licensingModule.registerDerivativeWithLicenseTokens(ipAcct[tokenId], carl_licenses, "");

            uint256 license1_mintAmount = 500;
            mockToken.mint(u.carl, mintingFee * license1_mintAmount);
            mockToken.approve(address(royaltyModule), mintingFee * license1_mintAmount);

            // Modify license[1] to a Commercial license
            carl_licenses[1] = licensingModule.mintLicenseTokens({
                licensorIpId: ipAcct[300],
                licenseTemplate: address(pilTemplate),
                licenseTermsId: commDerivTermsId,
                amount: license1_mintAmount,
                receiver: u.carl,
                royaltyContext: ""
            });
            carl_licenses[1] = carl_licenses[1] + license1_mintAmount - 1; // use last license ID minted from above

            // Linking 2 licenses, ID 1 and ID 4.
            // These licenses are from 2 different parents, ipAcct[1] and ipAcct[300], respectively.

            // This should succeed since both license[0] and license[1] are commercial
            tokenId = 70001;
            mockNFT.mintId(u.carl, tokenId);

            ipAcct[tokenId] = registerIpAccount(address(mockNFT), tokenId, u.carl);
            registerDerivativeWithLicenseTokens(ipAcct[tokenId], carl_licenses, "", u.carl);
        }
    }
}
