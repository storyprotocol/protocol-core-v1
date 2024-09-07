// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract
import { PILFlavors } from "../../../../../contracts/lib/PILFlavors.sol";
import { Errors } from "../../../../../contracts/lib/Errors.sol";

// test
import { BaseIntegration } from "../../BaseIntegration.t.sol";

contract Licensing_Scenarios is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    function setUp() public override {
        super.setUp();

        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);

        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        ipAcct[2] = registerIpAccount(mockNFT, 2, u.bob);
    }

    function test_Integration_LicensingScenarios_PILFlavors_getId() public {
        uint256 ncSocialRemixTermsId = registerSelectedPILicenseTerms_NonCommercialSocialRemixing();
        assertEq(ncSocialRemixTermsId, PILFlavors.getNonCommercialSocialRemixingId(pilTemplate));

        uint32 commercialRevShare = 10;
        uint256 mintingFee = 100;

        uint256 commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                commercialRevShare: commercialRevShare,
                mintingFee: mintingFee,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(USDC)
            })
        );
        assertEq(
            commRemixTermsId,
            PILFlavors.getCommercialRemixId({
                pilTemplate: pilTemplate,
                commercialRevShare: commercialRevShare,
                mintingFee: mintingFee,
                currencyToken: address(USDC),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        uint256 commTermsId = registerSelectedPILicenseTerms(
            "commercial_use",
            PILFlavors.commercialUse({
                mintingFee: mintingFee,
                currencyToken: address(USDC),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        assertEq(
            commTermsId,
            PILFlavors.getCommercialUseId({
                pilTemplate: pilTemplate,
                mintingFee: mintingFee,
                currencyToken: address(USDC),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
    }

    // solhint-disable-next-line max-line-length
    function test_Integration_LicensingScenarios_ipaHasNonCommercialAndCommercialPolicy_mintingLicenseFromCommercial()
        public
    {
        uint32 commercialRevShare = 10;
        uint256 mintingFee = 100;

        // Register non-commercial social remixing policy
        uint256 ncSocialRemixTermsId = registerSelectedPILicenseTerms_NonCommercialSocialRemixing();

        // Register commercial remixing policy
        uint256 commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                commercialRevShare: commercialRevShare,
                mintingFee: mintingFee,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(USDC)
            })
        );

        // Register commercial use policy
        uint256 commTermsId = registerSelectedPILicenseTerms(
            "commercial_use",
            PILFlavors.commercialUse({
                mintingFee: mintingFee,
                currencyToken: address(USDC),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        uint256[] memory licenseIds = new uint256[](1);

        // Add policies to IP account
        vm.startPrank(u.alice);
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commRemixTermsId);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                ncSocialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), ncSocialRemixTermsId);
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commTermsId);
        vm.stopPrank();

        // Register new IPAs
        mockNFT.mintId(u.bob, 3);
        ipAcct[3] = registerIpAccount(mockNFT, 3, u.bob);
        mockNFT.mintId(u.bob, 4);
        ipAcct[4] = registerIpAccount(mockNFT, 4, u.bob);

        // Mint license for Non-commercial remixing, then link to new IPA to make it a derivative
        vm.startPrank(u.bob);
        licenseIds[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: ncSocialRemixTermsId,
            amount: 1,
            receiver: u.bob,
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[2], licenseIds, "");

        // Mint license for commercial use, then link to new IPA to make it a derivative
        IERC20(USDC).approve(address(royaltyModule), mintingFee);
        licenseIds[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commTermsId,
            amount: 1,
            receiver: u.bob,
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[3], licenseIds, "");

        // Mint license for commercial remixing, then link to new IPA to make it a derivative
        IERC20(USDC).approve(address(royaltyModule), mintingFee);
        licenseIds[0] = licensingModule.mintLicenseTokens({
            licensorIpId: ipAcct[1],
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            amount: 1,
            receiver: u.bob,
            royaltyContext: ""
        });
        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[4], licenseIds, "");

        vm.stopPrank();
    }
}
