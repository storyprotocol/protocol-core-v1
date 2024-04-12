// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { PILicenseTemplateErrors } from "../../../../contracts/lib/PILicenseTemplateErrors.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";

// test
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract PILicenseTemplateTest is BaseTest {
    using Strings for *;

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

    address public licenseHolder = address(0x101);

    function setUp() public override {
        super.setUp();
        // Create IPAccounts
        mockNft.mintId(ipOwner1, tokenId1);
        mockNft.mintId(ipOwner2, tokenId2);
        mockNft.mintId(ipOwner3, tokenId3);
        mockNft.mintId(ipOwner5, tokenId5);

        ipId1 = ipAssetRegistry.register(address(mockNft), tokenId1);
        ipId2 = ipAssetRegistry.register(address(mockNft), tokenId2);
        ipId3 = ipAssetRegistry.register(address(mockNft), tokenId3);
        ipId5 = ipAssetRegistry.register(address(mockNft), tokenId5);

        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
        vm.label(ipId3, "IPAccount3");
        vm.label(ipId5, "IPAccount5");
    }
    // this contract is for testing for each PILicenseTemplate's functions
    // register license terms with PILTerms struct
    function test_PILicenseTemplate_registerLicenseTerms() public {
        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        assertEq(defaultTermsId, 1);
        (address royaltyPolicy, bytes memory royaltyData, uint256 mintingFee, address currency) = pilTemplate
            .getRoyaltyPolicy(defaultTermsId);
        assertEq(royaltyPolicy, address(0), "royaltyPolicy should be address(0)");
        assertEq(royaltyData, abi.encode(0), "royaltyData should be empty");
        assertEq(mintingFee, 0, "mintingFee should be 0");
        assertEq(currency, address(0), "currency should be address(0)");
        assertTrue(pilTemplate.isLicenseTransferable(defaultTermsId), "license should be transferable");
        assertEq(pilTemplate.getLicenseTermsId(PILFlavors.defaultValuesLicenseTerms()), 1);
        assertEq(pilTemplate.getExpireTime(defaultTermsId, block.timestamp), 0, "expire time should be 0");
        assertTrue(pilTemplate.exists(defaultTermsId), "license terms should exist");

        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        assertEq(socialRemixTermsId, 2);
        (royaltyPolicy, royaltyData, mintingFee, currency) = pilTemplate.getRoyaltyPolicy(socialRemixTermsId);
        assertEq(royaltyPolicy, address(0));
        assertEq(royaltyData, abi.encode(0));
        assertEq(mintingFee, 0);
        assertEq(currency, address(0));
        assertTrue(pilTemplate.isLicenseTransferable(socialRemixTermsId));
        assertEq(pilTemplate.getLicenseTermsId(PILFlavors.nonCommercialSocialRemixing()), 2);
        assertEq(pilTemplate.getExpireTime(socialRemixTermsId, block.timestamp), 0, "expire time should be 0");
        assertTrue(pilTemplate.exists(socialRemixTermsId), "license terms should exist");

        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        assertEq(commUseTermsId, 3);
        (royaltyPolicy, royaltyData, mintingFee, currency) = pilTemplate.getRoyaltyPolicy(commUseTermsId);
        assertEq(royaltyPolicy, address(royaltyPolicyLAP));
        assertEq(royaltyData, abi.encode(0));
        assertEq(mintingFee, 100);
        assertEq(currency, address(erc20));
        assertTrue(pilTemplate.isLicenseTransferable(commUseTermsId));
        assertEq(
            pilTemplate.getLicenseTermsId(PILFlavors.commercialUse(100, address(erc20), address(royaltyPolicyLAP))),
            3
        );
        assertEq(pilTemplate.getExpireTime(commUseTermsId, block.timestamp), 0, "expire time should be 0");
        assertEq(pilTemplate.totalRegisteredLicenseTerms(), 3);

        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        assertEq(commRemixTermsId, 4);
        (royaltyPolicy, royaltyData, mintingFee, currency) = pilTemplate.getRoyaltyPolicy(commRemixTermsId);
        assertEq(royaltyPolicy, address(royaltyPolicyLAP));
        assertEq(royaltyData, abi.encode(10));
        assertEq(mintingFee, 100);
        assertEq(currency, address(erc20));
        assertTrue(pilTemplate.isLicenseTransferable(commRemixTermsId));
        assertEq(
            pilTemplate.getLicenseTermsId(
                PILFlavors.commercialRemix(100, 10, address(royaltyPolicyLAP), address(erc20))
            ),
            4
        );
        assertEq(pilTemplate.getExpireTime(commRemixTermsId, block.timestamp), 0, "expire time should be 0");
        assertTrue(pilTemplate.exists(commRemixTermsId), "license terms should exist");

        assertEq(pilTemplate.totalRegisteredLicenseTerms(), 4);

        uint256[] memory licenseTermsIds = new uint256[](4);
        licenseTermsIds[0] = defaultTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        licenseTermsIds[2] = commUseTermsId;
        licenseTermsIds[3] = commRemixTermsId;
        assertEq(pilTemplate.getEarlierExpireTime(licenseTermsIds, block.timestamp), 0);

        assertEq(pilTemplate.toJson(defaultTermsId), _DefaultToJson());
    }
    // register license terms twice
    function test_PILicenseTemplate_registerLicenseTerms_twice() public {
        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        uint256 defaultTermsId1 = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        assertEq(defaultTermsId, defaultTermsId1);
    }

    function test_PILicenseTemplate_registerLicenseTerms_revert_InvalidInputs() public {
        // mintingFee is 0
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__RoyaltyPolicyNotWhitelisted.selector);
        pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({ mintingFee: 0, currencyToken: address(erc20), royaltyPolicy: address(0x9999) })
        );
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CurrencyTokenNotWhitelisted.selector);
        pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(0x333),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CurrencyTokenNotWhitelisted.selector);
        pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(0x333),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__RoyaltyPolicyRequiresCurrencyToken.selector);
        pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(0),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        PILTerms memory terms = PILFlavors.nonCommercialSocialRemixing();
        terms.commercialAttribution = true;
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddAttribution.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.nonCommercialSocialRemixing();
        terms.commercializerChecker = address(0x9999);
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddCommercializers.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.nonCommercialSocialRemixing();
        terms.commercialRevShare = 10;
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddRevShare.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.nonCommercialSocialRemixing();
        terms.royaltyPolicy = address(royaltyPolicyLAP);
        terms.currency = address(erc20);
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddRoyaltyPolicy.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.commercialUse({
            mintingFee: 100,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        terms.royaltyPolicy = address(0);
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CommercialEnabled_RoyaltyPolicyRequired.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.commercialUse({
            mintingFee: 100,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        terms.commercializerChecker = address(0x9999);
        vm.expectRevert(
            abi.encodeWithSelector(
                PILicenseTemplateErrors.PILicenseTemplate__CommercializerCheckerDoesNotSupportHook.selector,
                address(0x9999)
            )
        );
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.defaultValuesLicenseTerms();
        terms.derivativesAttribution = true;
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddAttribution.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.defaultValuesLicenseTerms();
        terms.derivativesApproval = true;
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddApproval.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms = PILFlavors.defaultValuesLicenseTerms();
        terms.derivativesReciprocal = true;
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddReciprocal.selector);
        pilTemplate.registerLicenseTerms(terms);
    }

    // get license terms ID by PILTerms struct
    function test_PILicenseTemplate_getLicenseTermsId() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        assertEq(
            pilTemplate.getLicenseTermsId(PILFlavors.commercialUse(100, address(erc20), address(royaltyPolicyLAP))),
            commUseTermsId
        );

        assertEq(
            pilTemplate.getLicenseTermsId(PILFlavors.commercialUse(999, address(123), address(royaltyPolicyLAP))),
            0
        );
    }

    // get license terms struct by ID
    function test_PILicenseTemplate_getLicenseTerms() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        PILTerms memory terms = pilTemplate.getLicenseTerms(commUseTermsId);
        assertEq(terms.mintingFee, 100);
        assertEq(terms.currency, address(erc20));
        assertEq(terms.royaltyPolicy, address(royaltyPolicyLAP));
    }

    // test license terms exists
    function test_PILicenseTemplate_exists() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        assertTrue(pilTemplate.exists(commUseTermsId));
        assertFalse(pilTemplate.exists(999));
    }

    // test verifyMintLicenseToken
    function test_PILicenseTemplate_verifyMintLicenseToken() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        bool result = pilTemplate.verifyMintLicenseToken(commUseTermsId, ipId2, ipId1, 1);
        assertTrue(result);
    }

    function test_PILicenseTemplate_verifyMintLicenseToken_FromDerivativeIp_ButNotAttachedLicense() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commUseTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commUseTermsId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");

        uint256 anotherTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());

        bool result = pilTemplate.verifyMintLicenseToken(anotherTermsId, ipOwner3, ipId2, 1);
        assertFalse(result);
    }

    function test_PILicenseTemplate_verifyMintLicenseToken_FromDerivativeIp_NotReciprocal() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.prank(ipOwner1);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commUseTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commUseTermsId;
        vm.prank(ipOwner2);
        licensingModule.registerDerivative(ipId2, parentIpIds, licenseTermsIds, address(pilTemplate), "");

        bool result = pilTemplate.verifyMintLicenseToken(commUseTermsId, ipOwner3, ipId2, 1);
        assertFalse(result);
    }

    // test verifyRegisterDerivative
    function test_PILicenseTemplate_verifyRegisterDerivative() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        bool result = pilTemplate.verifyRegisterDerivative(ipId2, ipId1, commUseTermsId, ipOwner2);
        assertTrue(result);
    }

    function test_PILicenseTemplate_verifyRegisterDerivative_WithApproval() public {
        PILTerms memory terms = PILFlavors.nonCommercialSocialRemixing();
        terms.derivativesApproval = true;
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipId1);
        pilTemplate.setApproval(ipId1, socialRemixTermsId, ipId2, true);
        assertTrue(pilTemplate.isDerivativeApproved(ipId1, socialRemixTermsId, ipId2));

        bool result = pilTemplate.verifyRegisterDerivative(ipId2, ipId1, socialRemixTermsId, ipOwner2);
        assertTrue(result);
    }

    function test_PILicenseTemplate_verifyRegisterDerivative_WithoutApproval() public {
        PILTerms memory terms = PILFlavors.nonCommercialSocialRemixing();
        terms.derivativesApproval = true;
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipId1);
        pilTemplate.setApproval(ipId1, socialRemixTermsId, ipId2, false);
        assertFalse(pilTemplate.isDerivativeApproved(ipId1, socialRemixTermsId, ipId2));

        bool result = pilTemplate.verifyRegisterDerivative(ipId2, ipId1, socialRemixTermsId, ipOwner2);
        assertFalse(result);
    }

    function test_PILicenseTemplate_verifyRegisterDerivative_derivativeNotAllowed() public {
        PILTerms memory terms = PILFlavors.defaultValuesLicenseTerms();
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);
        bool result = pilTemplate.verifyRegisterDerivative(ipId2, ipId1, socialRemixTermsId, ipOwner2);
        assertFalse(result);
    }

    // test verifyCompatibleLicenses
    function test_PILicenseTemplate_verifyCompatibleLicenses() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = commUseTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        assertFalse(pilTemplate.verifyCompatibleLicenses(licenseTermsIds));

        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        licenseTermsIds[0] = defaultTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        assertFalse(pilTemplate.verifyCompatibleLicenses(licenseTermsIds));

        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        assertFalse(pilTemplate.verifyCompatibleLicenses(licenseTermsIds));

        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        assertTrue(pilTemplate.verifyCompatibleLicenses(licenseTermsIds));
    }

    // test verifyRegisterDerivativeForAllParents
    function test_PILicenseTemplate_verifyRegisterDerivativeForAllParents() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        uint256[] memory licenseTermsIds = new uint256[](2);
        licenseTermsIds[0] = commUseTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        address[] memory parentIpIds = new address[](2);
        parentIpIds[0] = ipId1;
        parentIpIds[1] = ipId3;
        assertFalse(pilTemplate.verifyRegisterDerivativeForAllParents(ipId2, parentIpIds, licenseTermsIds, ipOwner2));

        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        licenseTermsIds[0] = defaultTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        assertFalse(pilTemplate.verifyRegisterDerivativeForAllParents(ipId2, parentIpIds, licenseTermsIds, ipOwner2));

        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        assertFalse(pilTemplate.verifyRegisterDerivativeForAllParents(ipId2, parentIpIds, licenseTermsIds, ipOwner2));

        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        assertTrue(pilTemplate.verifyRegisterDerivativeForAllParents(ipId2, parentIpIds, licenseTermsIds, ipOwner2));
    }

    // test isLicenseTransferable
    function test_PILicenseTemplate_isLicenseTransferable() public {
        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        assertTrue(pilTemplate.isLicenseTransferable(defaultTermsId));

        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        assertTrue(pilTemplate.isLicenseTransferable(socialRemixTermsId));

        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        assertTrue(pilTemplate.isLicenseTransferable(commUseTermsId));

        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        assertTrue(pilTemplate.isLicenseTransferable(commRemixTermsId));

        PILTerms memory terms = pilTemplate.getLicenseTerms(commRemixTermsId);
        terms.transferable = false;
        uint256 nonTransferableTermsId = pilTemplate.registerLicenseTerms(terms);
        assertFalse(pilTemplate.isLicenseTransferable(nonTransferableTermsId));
    }

    function test_PILicenseTemplate_getEarlierExpiredTime_WithEmptyLicenseTerms() public {
        uint256[] memory licenseTermsIds = new uint256[](0);
        assertEq(pilTemplate.getEarlierExpireTime(licenseTermsIds, block.timestamp), 0);
    }

    function test_PILicenseTemplate_name() public {
        assertEq(pilTemplate.name(), "pil");
    }

    function test_PILicenseTemplate_getMetadataURI() public {
        assertEq(
            pilTemplate.getMetadataURI(),
            "https://github.com/storyprotocol/protocol-core/blob/main/PIL-Beta-2024-02.pdf"
        );
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _DefaultToJson() internal pure returns (string memory) {
        /* solhint-disable */
        return
            '{"trait_type": "Expiration", "value": "never"},{"trait_type": "Currency", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "Commercial Use", "value": "false"},{"trait_type": "Commercial Attribution", "value": "false"},{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": 0},{"trait_type": "Commercial Revenue Celling", "value": 0},{"trait_type": "Commercializer Check", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "Derivatives Allowed", "value": "false"},{"trait_type": "Derivatives Attribution", "value": "false"},{"trait_type": "Derivatives Revenue Celling", "value": 0},{"trait_type": "Derivatives Approval", "value": "false"},{"trait_type": "Derivatives Reciprocal", "value": "false"},';
        /* solhint-enable */
    }
}
