// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// solhint-disable quotes

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { PILicenseTemplateErrors } from "../../../../contracts/lib/PILicenseTemplateErrors.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";
import { PILTerms } from "../../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";

// test
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { MockTokenGatedHook } from "../../mocks/MockTokenGatedHook.sol";

contract PILicenseTemplateTest is BaseTest {
    using Strings for *;

    MockERC721 internal gatedNftFoo = new MockERC721{ salt: bytes32(uint256(1)) }("GatedNftFoo");
    MockERC721 internal gatedNftBar = new MockERC721{ salt: bytes32(uint256(2)) }("GatedNftBar");

    MockTokenGatedHook internal verifiedTokenGatedHook = new MockTokenGatedHook();
    MockTokenGatedHook internal unverifiedTokenGatedHook = new MockTokenGatedHook();

    mapping(uint256 => address) internal ipAcct;
    mapping(uint256 => address) internal ipOwner;
    mapping(uint256 => uint256) internal tokenIds;

    address internal licenseHolder = address(0x101);

    function setUp() public override {
        super.setUp();

        ipOwner[1] = u.alice;
        ipOwner[2] = u.bob;
        ipOwner[3] = u.carl;
        ipOwner[5] = u.dan;

        // Create IPAccounts
        tokenIds[1] = mockNFT.mint(ipOwner[1]);
        tokenIds[2] = mockNFT.mint(ipOwner[2]);
        tokenIds[3] = mockNFT.mint(ipOwner[3]);
        tokenIds[5] = mockNFT.mint(ipOwner[5]);

        ipAcct[1] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[1]);
        ipAcct[2] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[2]);
        ipAcct[3] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[3]);
        ipAcct[5] = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenIds[5]);

        vm.label(ipAcct[1], "IPAccount1");
        vm.label(ipAcct[2], "IPAccount2");
        vm.label(ipAcct[3], "IPAccount3");
        vm.label(ipAcct[5], "IPAccount5");

        vm.prank(u.admin);
        moduleRegistry.registerModule("MockTokenGatedHook", address(verifiedTokenGatedHook));
    }
    // this contract is for testing for each PILicenseTemplate's functions
    // register license terms with PILTerms struct
    function test_PILicenseTemplate_registerLicenseTerms__() public {
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        assertEq(socialRemixTermsId, 1);
        (address royaltyPolicy, uint32 royaltyPercent, uint256 mintingFee, address currency) = pilTemplate
            .getRoyaltyPolicy(socialRemixTermsId);
        assertEq(royaltyPolicy, address(0));
        assertEq(royaltyPercent, 0);
        assertEq(mintingFee, 0);
        assertEq(currency, address(0));
        assertTrue(pilTemplate.isLicenseTransferable(socialRemixTermsId));
        assertEq(pilTemplate.getLicenseTermsId(PILFlavors.nonCommercialSocialRemixing()), 1);
        assertEq(pilTemplate.getExpireTime(socialRemixTermsId, block.timestamp), 0, "expire time should be 0");
        assertTrue(pilTemplate.exists(socialRemixTermsId), "license terms should exist");

        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        assertEq(defaultTermsId, 2);
        (royaltyPolicy, royaltyPercent, mintingFee, currency) = pilTemplate.getRoyaltyPolicy(defaultTermsId);
        assertEq(royaltyPolicy, address(0), "royaltyPolicy should be address(0)");
        assertEq(royaltyPercent, 0, "royaltyPercent should be empty");
        assertEq(mintingFee, 0, "mintingFee should be 0");
        assertEq(currency, address(0), "currency should be address(0)");
        assertTrue(pilTemplate.isLicenseTransferable(defaultTermsId), "license should be transferable");
        assertEq(pilTemplate.getLicenseTermsId(PILFlavors.defaultValuesLicenseTerms()), 2);
        assertEq(pilTemplate.getExpireTime(defaultTermsId, block.timestamp), 0, "expire time should be 0");
        assertTrue(pilTemplate.exists(defaultTermsId), "license terms should exist");

        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        assertEq(commUseTermsId, 3);
        (royaltyPolicy, royaltyPercent, mintingFee, currency) = pilTemplate.getRoyaltyPolicy(commUseTermsId);
        assertEq(royaltyPolicy, address(royaltyPolicyLAP));
        assertEq(royaltyPercent, 0);
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
        (royaltyPolicy, royaltyPercent, mintingFee, currency) = pilTemplate.getRoyaltyPolicy(commRemixTermsId);
        assertEq(royaltyPolicy, address(royaltyPolicyLAP));
        assertEq(royaltyPercent, 10);
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

    function test_PILicenseTemplate_registerLicenseTerms_revert_MintingFeeRequiresRoyaltyPolicy() public {
        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(0),
            defaultMintingFee: 100e6,
            expiration: 0,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativeRevCeiling: 0,
            currency: address(erc20),
            uri: ""
        });
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__MintingFeeRequiresRoyaltyPolicy.selector);
        pilTemplate.registerLicenseTerms(terms);
    }

    function test_PILicenseTemplate_registerLicenseTerms_withCommercializerChecker() public {
        PILTerms memory terms = PILFlavors.commercialUse({
            mintingFee: 100,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        terms.commercializerChecker = address(verifiedTokenGatedHook);
        terms.commercializerCheckerData = abi.encode(address(gatedNftFoo));

        uint256 termsIdBefore = pilTemplate.totalRegisteredLicenseTerms();
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(terms);
        assertEq(commUseTermsId, termsIdBefore + 1);
        (address royaltyPolicy, uint32 royaltyPercent, uint256 mintingFee, address currency) = pilTemplate
            .getRoyaltyPolicy(commUseTermsId);
        assertEq(royaltyPolicy, address(royaltyPolicyLAP));
        assertEq(royaltyPercent, 0);
        assertEq(mintingFee, 100);
        assertEq(currency, address(erc20));
        assertEq(pilTemplate.getLicenseTerms(commUseTermsId).commercializerChecker, address(verifiedTokenGatedHook));
        assertEq(
            pilTemplate.getLicenseTerms(commUseTermsId).commercializerCheckerData,
            abi.encode(address(gatedNftFoo))
        );
    }

    function test_PILicenseTemplate_revert_registerLicenseTerms_CommercializerCheckerNotRegistered() public {
        PILTerms memory terms = PILFlavors.commercialUse({
            mintingFee: 100,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        terms.commercializerChecker = address(unverifiedTokenGatedHook);
        terms.commercializerCheckerData = abi.encode(address(gatedNftFoo));
        vm.expectRevert(
            abi.encodeWithSelector(
                PILicenseTemplateErrors.PILicenseTemplate__CommercializerCheckerNotRegistered.selector,
                address(unverifiedTokenGatedHook)
            )
        );
        pilTemplate.registerLicenseTerms(terms);
    }

    function test_PILicenseTemplate_revert_registerRevCeiling() public {
        PILTerms memory terms = PILFlavors.defaultValuesLicenseTerms();
        terms.commercialRevCeiling = 10;
        vm.expectRevert(PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddRevCeiling.selector);
        pilTemplate.registerLicenseTerms(terms);

        terms.commercialRevCeiling = 0;
        terms.derivativeRevCeiling = 10;
        vm.expectRevert(
            PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddDerivativeRevCeiling.selector
        );
        pilTemplate.registerLicenseTerms(terms);

        terms.commercialRevCeiling = 0;
        terms.commercialUse = true;
        terms.royaltyPolicy = address(royaltyPolicyLAP);
        terms.currency = address(erc20);
        terms.derivativesAllowed = false;
        terms.derivativeRevCeiling = 10;
        vm.expectRevert(
            PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddDerivativeRevCeiling.selector
        );
        pilTemplate.registerLicenseTerms(terms);
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
            mintingFee: 0,
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
        assertEq(terms.defaultMintingFee, 100);
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
        bool result = pilTemplate.verifyMintLicenseToken(commUseTermsId, ipAcct[2], ipAcct[1], 1);
        assertTrue(result);
    }

    function test_PILicenseTemplate_verifyMintLicenseToken_FromDerivativeIp_ButNotAttachedLicense() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        vm.prank(ipOwner[1]);
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commRemixTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commRemixTermsId;
        vm.prank(ipOwner[2]);
        licensingModule.registerDerivative(
            ipAcct[2],
            parentIpIds,
            licenseTermsIds,
            address(pilTemplate),
            "",
            0,
            100e6,
            0
        );

        uint256 anotherTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        bool result = pilTemplate.verifyMintLicenseToken(anotherTermsId, ipOwner[3], ipAcct[2], 1);
        assertFalse(result);
    }

    function test_PILicenseTemplate_verifyMintLicenseToken_FromDerivativeIp_NotReciprocal() public {
        // create a terms that allow derivative but not allow derivative of derivative
        PILTerms memory commNoReciprocalTerms = PILFlavors.commercialUse({
            mintingFee: 0,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        commNoReciprocalTerms.derivativesAllowed = true;

        uint256 commNoReciprocalTermsId = pilTemplate.registerLicenseTerms(commNoReciprocalTerms);
        vm.prank(ipOwner[1]);
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), commNoReciprocalTermsId);

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = commNoReciprocalTermsId;
        vm.prank(ipOwner[2]);
        licensingModule.registerDerivative(
            ipAcct[2],
            parentIpIds,
            licenseTermsIds,
            address(pilTemplate),
            "",
            0,
            100e6,
            0
        );

        bool result = pilTemplate.verifyMintLicenseToken(commNoReciprocalTermsId, ipOwner[3], ipAcct[2], 1);
        assertFalse(result);
    }

    function test_PILicenseTemplate_verifyMintLicenseToken_LicenseTermsIdNonExist() public {
        uint256 nonExistCommUseTermsId = 999;

        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = nonExistCommUseTermsId;

        bool result = pilTemplate.verifyMintLicenseToken(nonExistCommUseTermsId, ipOwner[2], ipAcct[1], 1);
        assertFalse(result);
    }

    // test verifyRegisterDerivative
    function test_PILicenseTemplate_verifyRegisterDerivative_ForCommercialUse() public {
        uint256 commUseTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        bool result = pilTemplate.verifyRegisterDerivative(ipAcct[2], ipAcct[1], commUseTermsId, ipOwner[2]);
        assertFalse(result);
    }

    function test_PILicenseTemplate_verifyRegisterDerivative_ForCommercialRemix() public {
        uint256 commRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        bool result = pilTemplate.verifyRegisterDerivative(ipAcct[2], ipAcct[1], commRemixTermsId, ipOwner[2]);
        assertTrue(result);
    }

    // test verifyRegisterDerivative
    function test_PILicenseTemplate_verifyRegisterDerivative_NotDerivativesReciprocal() public {
        // register license terms allow derivative but not allow derivative of derivative
        PILTerms memory terms = PILFlavors.nonCommercialSocialRemixing();
        terms.derivativesReciprocal = false;
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);

        // register derivative
        vm.prank(ipOwner[1]);
        licensingModule.attachLicenseTerms(ipAcct[1], address(pilTemplate), socialRemixTermsId);
        address[] memory parentIpIds = new address[](1);
        parentIpIds[0] = ipAcct[1];
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = socialRemixTermsId;
        vm.prank(ipOwner[2]);
        licensingModule.registerDerivative(
            ipAcct[2],
            parentIpIds,
            licenseTermsIds,
            address(pilTemplate),
            "",
            0,
            100e6,
            0
        );

        // checking register derivative of derivative, expect false
        bool result = pilTemplate.verifyRegisterDerivative(ipAcct[3], ipAcct[2], socialRemixTermsId, ipOwner[3]);
        assertFalse(result);
    }

    function test_PILicenseTemplate_verifyRegisterDerivative_WithApproval() public {
        PILTerms memory terms = PILFlavors.nonCommercialSocialRemixing();
        terms.derivativesApproval = true;
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipAcct[1]);
        pilTemplate.setApproval(ipAcct[1], socialRemixTermsId, ipAcct[2], true);
        assertTrue(pilTemplate.isDerivativeApproved(ipAcct[1], socialRemixTermsId, ipAcct[2]));

        bool result = pilTemplate.verifyRegisterDerivative(ipAcct[2], ipAcct[1], socialRemixTermsId, ipOwner[2]);
        assertTrue(result);
    }

    function test_PILicenseTemplate_verifyRegisterDerivative_WithoutApproval() public {
        PILTerms memory terms = PILFlavors.nonCommercialSocialRemixing();
        terms.derivativesApproval = true;
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);
        vm.prank(ipAcct[1]);
        pilTemplate.setApproval(ipAcct[1], socialRemixTermsId, ipAcct[2], false);
        assertFalse(pilTemplate.isDerivativeApproved(ipAcct[1], socialRemixTermsId, ipAcct[2]));

        bool result = pilTemplate.verifyRegisterDerivative(ipAcct[2], ipAcct[1], socialRemixTermsId, ipOwner[2]);
        assertFalse(result);
    }

    function test_PILicenseTemplate_verifyRegisterDerivative_derivativeNotAllowed() public {
        PILTerms memory terms = PILFlavors.defaultValuesLicenseTerms();
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(terms);
        bool result = pilTemplate.verifyRegisterDerivative(ipAcct[2], ipAcct[1], socialRemixTermsId, ipOwner[2]);
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

        uint256 anotherCommRemixTermsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 200,
                commercialRevShare: 20,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = anotherCommRemixTermsId;
        assertFalse(pilTemplate.verifyCompatibleLicenses(licenseTermsIds));

        licenseTermsIds[0] = commRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
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
        parentIpIds[0] = ipAcct[1];
        parentIpIds[1] = ipAcct[3];
        assertFalse(
            pilTemplate.verifyRegisterDerivativeForAllParents(ipAcct[2], parentIpIds, licenseTermsIds, ipOwner[2])
        );

        uint256 defaultTermsId = pilTemplate.registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
        uint256 socialRemixTermsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        licenseTermsIds[0] = defaultTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        assertFalse(
            pilTemplate.verifyRegisterDerivativeForAllParents(ipAcct[2], parentIpIds, licenseTermsIds, ipOwner[2])
        );

        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = commRemixTermsId;
        assertFalse(
            pilTemplate.verifyRegisterDerivativeForAllParents(ipAcct[2], parentIpIds, licenseTermsIds, ipOwner[2])
        );

        licenseTermsIds[0] = socialRemixTermsId;
        licenseTermsIds[1] = socialRemixTermsId;
        assertTrue(
            pilTemplate.verifyRegisterDerivativeForAllParents(ipAcct[2], parentIpIds, licenseTermsIds, ipOwner[2])
        );
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

    function test_PILicenseTemplate_getLicenseURI() public {
        PILTerms memory terms = PILFlavors.commercialUse({
            mintingFee: 100,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        terms.uri = "license.url";
        uint256 termsId = pilTemplate.registerLicenseTerms(terms);
        assertEq(pilTemplate.getLicenseTermsURI(termsId), "license.url");
    }

    function test_PILicenseTemplate_differentLicenseURI() public {
        PILTerms memory terms = PILFlavors.commercialUse({
            mintingFee: 100,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        terms.uri = "license.url";
        uint256 termsId = pilTemplate.registerLicenseTerms(terms);
        assertEq(pilTemplate.getLicenseTermsURI(termsId), "license.url");

        PILTerms memory terms1 = PILFlavors.commercialUse({
            mintingFee: 100,
            currencyToken: address(erc20),
            royaltyPolicy: address(royaltyPolicyLAP)
        });
        terms1.uri = "another.license.url";
        uint256 termsId1 = pilTemplate.registerLicenseTerms(terms1);

        assertEq(pilTemplate.getLicenseTermsURI(termsId1), "another.license.url");
        assertEq(pilTemplate.getLicenseTermsURI(termsId), "license.url");
        assertEq(pilTemplate.getLicenseTermsId(terms1), termsId1);
        assertEq(pilTemplate.getLicenseTermsId(terms), termsId);
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
            "https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf"
        );
    }

    function test_PILicenseTemplate_registerLicenseTerms_PILTermsURIContainsDoubleQuote() public {
        string memory maliciousUri1 = string.concat(
            '"}], ',
            '"name" : "", ',
            '"description" : "", ',
            '"external_url" : "", ',
            '"image" : "", ',
            '"attributes" : [], ',
            '"old_attributes" : [{"ok" : ""}'
        );

        uint256 termsId = pilTemplate.registerLicenseTerms(
            PILTerms({
                transferable: true,
                royaltyPolicy: address(0),
                defaultMintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                commercialRevCeiling: 0,
                derivativesAllowed: false,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCeiling: 0,
                currency: address(0),
                uri: maliciousUri1
            })
        );

        string memory termsInJson = pilTemplate.toJson(termsId);

        assertEq(
            termsInJson,
            string.concat(
                '{"trait_type": "Royalty Policy", "value": "0x0000000000000000000000000000000000000000"},',
                '{"trait_type": "Default Minting Fee", "value": "0"},',
                '{"trait_type": "Expiration", "value": "never"},',
                '{"trait_type": "Currency", "value": "0x0000000000000000000000000000000000000000"},',
                // all special characters are escaped
                string.concat(
                    '{"trait_type": "URI", "value": "\\"}], ',
                    '\\"name\\" : \\"\\", ',
                    '\\"description\\" : \\"\\", ',
                    '\\"external_url\\" : \\"\\", ',
                    '\\"image\\" : \\"\\", ',
                    '\\"attributes\\" : [], ',
                    '\\"old_attributes\\" : [{\\"ok\\" : \\"\\"}"},'
                ),
                '{"trait_type": "Commercial Use", "value": "false"},',
                '{"trait_type": "Commercial Attribution", "value": "false"},',
                '{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": 0},',
                '{"trait_type": "Commercial Revenue Ceiling", "value": 0},',
                '{"trait_type": "Commercializer Checker", "value": "0x0000000000000000000000000000000000000000"},',
                '{"trait_type": "Derivatives Allowed", "value": "false"},',
                '{"trait_type": "Derivatives Attribution", "value": "false"},',
                '{"trait_type": "Derivatives Revenue Ceiling", "value": 0},',
                '{"trait_type": "Derivatives Approval", "value": "false"},',
                '{"trait_type": "Derivatives Reciprocal", "value": "false"},'
            )
        );
    }

    function test_PILicenseTemplate_canOverrideRoyaltyPercent() public {
        // license terms id is 0
        assertFalse(pilTemplate.canOverrideRoyaltyPercent(0, 100));

        // terms is not commercial use
        uint256 termsId = pilTemplate.registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
        assertFalse(pilTemplate.canOverrideRoyaltyPercent(termsId, 100));

        // new royalty percent is 0
        termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 100,
                currencyToken: address(erc20),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );
        assertTrue(pilTemplate.canOverrideRoyaltyPercent(termsId, 0));

        // new royalty percent is greater than commercial rev share
        termsId = pilTemplate.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 100,
                commercialRevShare: 10,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(erc20)
            })
        );
        assertTrue(pilTemplate.canOverrideRoyaltyPercent(termsId, 100));

        // new royalty percent is less than commercial rev share
        assertFalse(pilTemplate.canOverrideRoyaltyPercent(termsId, 5));
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _DefaultToJson() internal pure returns (string memory) {
        /* solhint-disable */
        return
            '{"trait_type": "Royalty Policy", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "Default Minting Fee", "value": "0"},{"trait_type": "Expiration", "value": "never"},{"trait_type": "Currency", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "URI", "value": "https://github.com/piplabs/pil-document/blob/ad67bb632a310d2557f8abcccd428e4c9c798db1/off-chain-terms/Default.json"},{"trait_type": "Commercial Use", "value": "false"},{"trait_type": "Commercial Attribution", "value": "false"},{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": 0},{"trait_type": "Commercial Revenue Ceiling", "value": 0},{"trait_type": "Commercializer Checker", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "Derivatives Allowed", "value": "false"},{"trait_type": "Derivatives Attribution", "value": "false"},{"trait_type": "Derivatives Revenue Ceiling", "value": 0},{"trait_type": "Derivatives Approval", "value": "false"},{"trait_type": "Derivatives Reciprocal", "value": "false"},';
        /* solhint-enable */
    }
}
