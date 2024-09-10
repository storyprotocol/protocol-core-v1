// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// contracts
import { PILFlavors } from "../../../../../contracts/lib/PILFlavors.sol";
import { Errors } from "../../../../../contracts/lib/Errors.sol";
import { PILicenseTemplate } from "../../../../../contracts/modules/licensing/PILicenseTemplate.sol";

// test
import { BaseIntegration } from "../../BaseIntegration.t.sol";
import { TestProxyHelper } from "../../../utils/TestProxyHelper.sol";
import { MockERC20 } from "../../../mocks/token/MockERC20.sol";

contract LicensingIntegrationTest is BaseIntegration {
    error ERC721NonexistentToken(uint256 tokenId);

    mapping(uint256 => uint256 tokenId) private tokenIds;
    mapping(uint256 tokenId => address ipId) private ipAcct;

    PILicenseTemplate private anotherPILTemplate;

    function setUp() public override {
        super.setUp();

        // new token to make this test work (asserts) temporarily
        erc20 = new MockERC20();
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);

        tokenIds[1] = mockNFT.mint(u.alice);
        tokenIds[2] = mockNFT.mint(u.bob);
        tokenIds[3] = mockNFT.mint(u.carl);
        tokenIds[6] = mockNFT.mint(u.dan);
        tokenIds[7] = mockNFT.mint(u.eve);

        ipAcct[1] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[1]);
        ipAcct[2] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[2]);
        ipAcct[3] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[3]);
        ipAcct[6] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[6]);
        ipAcct[7] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[7]);

        address anotherPILTemplateImpl = address(
            new PILicenseTemplate(
                address(accessController),
                address(ipAccountRegistry),
                address(licenseRegistry),
                address(royaltyModule)
            )
        );

        anotherPILTemplate = PILicenseTemplate(
            TestProxyHelper.deployUUPSProxy(
                anotherPILTemplateImpl,
                abi.encodeCall(
                    PILicenseTemplate.initialize,
                    (
                        address(protocolAccessManager),
                        "another-pil",
                        "https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf"
                    )
                )
            )
        );
    }

    function test_LicensingIntegration_Simple() public {
        // register license terms
        uint256 lcId1 = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        assertEq(lcId1, 1);

        uint256 lcId2 = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
        );
        assertEq(lcId2, 2);
        assertEq(
            pilTemplate.getLicenseTermsId(
                PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
            ),
            2
        );
        assertTrue(pilTemplate.exists(2));

        assertTrue(pilTemplate.exists(lcId2));

        // attach licenses
        vm.startPrank(u.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                1
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), 1);

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipAcct[1], address(pilTemplate), 1), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipAcct[1]), 1);

        (address attachedTemplate, uint256 attachedId) = licenseRegistry.getAttachedLicenseTerms(ipAcct[1], 0);
        assertEq(attachedTemplate, address(pilTemplate));
        assertEq(attachedId, 1);

        (address defaultLicenseTemplate, uint256 defaultLicenseTermsId) = licenseRegistry.getDefaultLicenseTerms();
        assertEq(defaultLicenseTemplate, address(pilTemplate));
        assertEq(defaultLicenseTermsId, 1);

        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), 2);

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipAcct[1], address(pilTemplate), 2), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipAcct[1]), 2);

        (attachedTemplate, attachedId) = licenseRegistry.getAttachedLicenseTerms(ipAcct[1], 0);
        assertEq(attachedTemplate, address(pilTemplate));
        assertEq(attachedId, 2);
        vm.stopPrank();

        // register derivative directly
        vm.startPrank(u.bob);
        address[] memory parentIpIds = new address[](1);
        uint256[] memory licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipAcct[1];
        licenseTermsIds[0] = 1;

        licensingModule.registerDerivative(ipAcct[2], parentIpIds, licenseTermsIds, address(pilTemplate), "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipAcct[2], address(pilTemplate), 1), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipAcct[2]), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[2]), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[2]), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[1]), true);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[1]), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[1]), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[2]), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipAcct[1], 0), ipAcct[2]);
        assertEq(licenseRegistry.getParentIp(ipAcct[2], 0), ipAcct[1]);
        assertEq(licenseRegistry.getParentIpCount(ipAcct[2]), 1);
        vm.stopPrank();

        // mint license token
        vm.startPrank(u.carl);
        uint256 lcTokenId = licensingModule.mintLicenseTokens(
            ipAcct[1],
            address(pilTemplate),
            1,
            1,
            address(u.carl),
            ""
        );
        assertEq(licenseToken.ownerOf(lcTokenId), u.carl);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), 1);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipAcct[1]);
        assertEq(licenseToken.totalMintedTokens(), 1);

        // register derivative with license tokens
        uint256[] memory licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[3], licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipAcct[3], address(pilTemplate), 1), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipAcct[3]), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[3]), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[3]), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[1]), true);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[1]), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[1]), 2);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[2]), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipAcct[1], 0), ipAcct[2]);
        assertEq(licenseRegistry.getDerivativeIp(ipAcct[1], 1), ipAcct[3]);
        assertEq(licenseRegistry.getParentIp(ipAcct[3], 0), ipAcct[1]);
        assertEq(licenseRegistry.getParentIpCount(ipAcct[3]), 1);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        assertEq(licenseToken.ownerOf(lcTokenId), address(0));
        assertEq(licenseToken.totalMintedTokens(), 1);
        vm.stopPrank();

        // mint license token with payments
        vm.startPrank(u.dan);
        erc20.mint(u.dan, 1000);
        erc20.approve(address(royaltyModule), 100);

        lcTokenId = licensingModule.mintLicenseTokens(ipAcct[1], address(pilTemplate), 2, 1, address(u.dan), "");

        assertEq(licenseToken.ownerOf(lcTokenId), u.dan);
        assertEq(licenseToken.getLicenseTermsId(lcTokenId), 2);
        assertEq(licenseToken.getLicenseTemplate(lcTokenId), address(pilTemplate));
        assertEq(licenseToken.getLicensorIpId(lcTokenId), ipAcct[1]);
        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(erc20.balanceOf(u.dan), 900);

        // register derivative with license tokens
        licenseTokens = new uint256[](1);
        licenseTokens[0] = lcTokenId;

        licensingModule.registerDerivativeWithLicenseTokens(ipAcct[6], licenseTokens, "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipAcct[6], address(pilTemplate), 2), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipAcct[6]), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[6]), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[6]), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[1]), true);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[1]), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[1]), 3);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[6]), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipAcct[1], 0), ipAcct[2]);
        assertEq(licenseRegistry.getDerivativeIp(ipAcct[1], 1), ipAcct[3]);
        assertEq(licenseRegistry.getDerivativeIp(ipAcct[1], 2), ipAcct[6]);
        assertEq(licenseRegistry.getParentIp(ipAcct[6], 0), ipAcct[1]);
        assertEq(licenseRegistry.getParentIpCount(ipAcct[6]), 1);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, lcTokenId));
        assertEq(licenseToken.ownerOf(lcTokenId), address(0));
        assertEq(licenseToken.totalMintedTokens(), 2);
        vm.stopPrank();

        // register derivative directly with payments
        vm.startPrank(u.eve);
        erc20.mint(u.eve, 1000);
        erc20.approve(address(royaltyModule), 100);
        parentIpIds = new address[](1);
        licenseTermsIds = new uint256[](1);
        parentIpIds[0] = ipAcct[1];
        licenseTermsIds[0] = 2;

        licensingModule.registerDerivative(ipAcct[7], parentIpIds, licenseTermsIds, address(pilTemplate), "");

        assertEq(licenseRegistry.hasIpAttachedLicenseTerms(ipAcct[7], address(pilTemplate), 2), true);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipAcct[7]), 2);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[7]), true);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[7]), false);
        assertEq(licenseRegistry.hasDerivativeIps(ipAcct[1]), true);
        assertEq(licenseRegistry.isDerivativeIp(ipAcct[1]), false);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[1]), 4);
        assertEq(licenseRegistry.getDerivativeIpCount(ipAcct[7]), 0);
        assertEq(licenseRegistry.getDerivativeIp(ipAcct[1], 3), ipAcct[7]);
        assertEq(licenseRegistry.getParentIp(ipAcct[7], 0), ipAcct[1]);
        assertEq(licenseRegistry.getParentIpCount(ipAcct[7]), 1);
        assertEq(licenseToken.totalMintedTokens(), 2);
        assertEq(erc20.balanceOf(u.eve), 900);
        vm.stopPrank();
    }

    function test_LicensingIntegration_revert_registerDerivative_parentIpUnmatchedLicenseTemplate() public {
        uint256 commRemixTermsId = anotherPILTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                commercialRevShare: 100,
                mintingFee: 1 ether,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(USDC)
            })
        );

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commRemixTermsId;

        vm.prank(u.carl);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__ParentIpUnmatchedLicenseTemplate.selector,
                ipAcct[1],
                address(anotherPILTemplate)
            )
        );
        licensingModule.registerDerivative({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(anotherPILTemplate),
            royaltyContext: ""
        });
    }

    function test_LicensingIntegration_revert_registerDerivative_parentIpNoLicenseTerms() public {
        uint256 ncSocialRemixTermsId = registerSelectedPILicenseTerms_NonCommercialSocialRemixing();
        uint256 commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                commercialRevShare: 100,
                mintingFee: 1 ether,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(USDC)
            })
        );

        vm.prank(u.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__LicenseTermsAlreadyAttached.selector,
                ipAcct[1],
                address(pilTemplate),
                ncSocialRemixTermsId
            )
        );
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), ncSocialRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];

        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commRemixTermsId;

        vm.prank(u.carl);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__ParentIpHasNoLicenseTerms.selector,
                ipAcct[1],
                commRemixTermsId
            )
        );
        licensingModule.registerDerivative({
            childIpId: ipAcct[3],
            parentIpIds: parentIpIds,
            licenseTermsIds: licenseTermsIds,
            licenseTemplate: address(pilTemplate),
            royaltyContext: ""
        });
    }
}
