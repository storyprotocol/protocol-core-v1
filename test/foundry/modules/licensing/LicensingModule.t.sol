// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { PILFlavors } from "../../../../contracts/lib/PILFlavors.sol";

// test
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract LicensingModuleTest is BaseTest {
    using Strings for *;

    MockERC721 internal nft = new MockERC721("MockERC721");
    MockERC721 internal gatedNftFoo = new MockERC721{ salt: bytes32(uint256(1)) }("GatedNftFoo");
    MockERC721 internal gatedNftBar = new MockERC721{ salt: bytes32(uint256(2)) }("GatedNftBar");

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipId3;
    address public ipOwner = address(0x100); // use static address, otherwise uri check fails because licensor changes
    address public licenseHolder = address(0x101);

    uint256 internal commRemixTermsId;
    uint256 internal commUseTermsId;

    function setUp() public override {
        super.setUp();

        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);

        commRemixTermsId = registerSelectedPILicenseTerms(
            "commercial_remix",
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 0,
                royaltyPolicy: address(royaltyPolicyLAP),
                currencyToken: address(0x123)
            })
        );

        commUseTermsId = registerSelectedPILicenseTerms(
            "commercial_use",
            PILFlavors.commercialUse({
                mintingFee: 0,
                currencyToken: address(0x123),
                royaltyPolicy: address(royaltyPolicyLAP)
            })
        );

        // Create IPAccounts
        nft.mintId(ipOwner, 1);
        nft.mintId(ipOwner, 2);
        nft.mintId(ipOwner, 3);

        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
        ipId3 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 3);

        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
        vm.label(ipId3, "IPAccount3");

        useMock_RoyaltyPolicyLAP();
    }

    function test_LicensingModule_attachLicenseTerms() public {
        vm.prank(ipOwner);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        assertEq(commRemixTermsId, 1, "policyId not 1");
        assertTrue(licenseRegistry.exists(address(pilTemplate), commRemixTermsId));
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId));
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));
    }

    function test_LicensingModule_attachLicenseTerms_sameReusePolicyId() public {
        address licenseTemplate;
        uint256 licenseTermsId;

        vm.startPrank(ipOwner);

        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertTrue(licenseRegistry.exists(address(pilTemplate), commRemixTermsId));
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId));
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);

        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertTrue(licenseRegistry.exists(address(pilTemplate), commRemixTermsId));
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId));
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
    }

    function test_LicensingModule_attachLicenseTerms_TwoPoliciesToOneIpId() public {
        address licenseTemplate;
        uint256 licenseTermsId;

        vm.startPrank(ipOwner);

        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId));
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));

        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commUseTermsId);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 1);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), commUseTermsId));
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commUseTermsId);
        assertFalse(licenseRegistry.isDerivativeIp(ipId1));
    }

    function test_LicensingModule_attachLicenseTerms_revert_policyNotFound() public {
        uint256 undefinedPILTermsId = 111222333222111;
        assertFalse(licenseRegistry.exists(address(pilTemplate), undefinedPILTermsId));

        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__IndexOutOfBounds.selector, ipId1, 0, 0));
        licenseRegistry.getAttachedLicenseTerms(ipId1, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicensingModule__LicenseTermsNotFound.selector,
                address(pilTemplate),
                undefinedPILTermsId
            )
        );
        vm.prank(ipOwner);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), undefinedPILTermsId);
    }

    function test_LicensingModule_attachLicenseTerms_revert_policyAlreadySetForIpId() public {
        address licenseTemplate;
        uint256 licenseTermsId;

        vm.startPrank(ipOwner);

        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        (licenseTemplate, licenseTermsId) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        assertTrue(licenseRegistry.exists(address(pilTemplate), commRemixTermsId));
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId));
        assertEq(licenseTemplate, address(pilTemplate));
        assertEq(licenseTermsId, commRemixTermsId);

        // TODO: This should revert!
        // vm.expectRevert(Errors.LicensingModule__PolicyAlreadySetForIpId.selector);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
    }

    function test_LicensingModule_mintLicenseTokens() public {
        vm.prank(ipOwner);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);
        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId));

        uint256 startLicenseId = attachAndMint_PILCommRemix_LicenseTokens({
            ipId: ipId1,
            amount: 2,
            receiver: licenseHolder
        });
        assertEq(licenseToken.balanceOf(licenseHolder), 2);
        assertEq(licenseToken.tokenOfOwnerByIndex(licenseHolder, 0), startLicenseId);
        assertEq(licenseToken.tokenOfOwnerByIndex(licenseHolder, 1), startLicenseId + 1);
    }

    function test_LIcensingModule_mintLicenseTokens_revert_inputValidations() public {}

    function test_LicensingModule_mintLicenseTokens_revert_callerNotLicensorAndIpIdHasNoPolicy() public {}

    function test_LicensingModule_mintLicenseTokens_ipIdHasNoPolicyButCallerIsLicensor() public {
        vm.prank(IIPAccount(payable(ipId1)).owner());
        uint256 startLicenseId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            amount: 2,
            receiver: ipId1,
            royaltyContext: ""
        });
        assertEq(licenseToken.balanceOf(ipId1), 2);
        assertEq(licenseToken.tokenOfOwnerByIndex(ipId1, 0), startLicenseId);
        assertEq(licenseToken.tokenOfOwnerByIndex(ipId1, 1), startLicenseId + 1);

        // Licensor (IP Account owner) calls via IP Account execute
        // The returned license ID (from decoding `result`) should be the same as above, as we're not creating a new
        // license, but rather minting an existing one (existing ID, minted above).
        vm.prank(IIPAccount(payable(ipId1)).owner());
        bytes memory result = IIPAccount(payable(ipId1)).execute(
            address(licensingModule),
            0,
            abi.encodeWithSignature(
                "mintLicenseTokens(address,address,uint256,uint256,address,bytes)",
                ipId1,
                address(pilTemplate),
                commRemixTermsId,
                2,
                ipId1,
                ""
            )
        );
        assertEq(startLicenseId + 2, abi.decode(result, (uint256)));
        assertEq(licenseToken.balanceOf(ipId1), 4);
        assertEq(licenseToken.tokenOfOwnerByIndex(ipId1, 2), startLicenseId + 2);
        assertEq(licenseToken.tokenOfOwnerByIndex(ipId1, 3), startLicenseId + 3);

        // IP Account calls directly
        vm.prank(ipId1);
        startLicenseId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commUseTermsId, // different selected license terms
            amount: 1,
            receiver: ipId1,
            royaltyContext: ""
        });
        assertEq(licenseToken.balanceOf(ipId1), 5);
        assertEq(licenseToken.tokenOfOwnerByIndex(ipId1, 4), startLicenseId);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_singleParent() public {
        uint256 startLicenseId = attachAndMint_PILCommRemix_LicenseTokens({
            ipId: ipId1,
            amount: 2,
            receiver: licenseHolder
        });
        uint256 endLicenseId = startLicenseId + 1;

        vm.prank(licenseHolder);
        licenseToken.transferFrom(licenseHolder, ipOwner, endLicenseId);
        assertEq(licenseToken.balanceOf(licenseHolder), 1, "not transferred");
        assertEq(licenseToken.ownerOf(startLicenseId), licenseHolder);
        assertEq(licenseToken.ownerOf(endLicenseId), ipOwner);

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = endLicenseId;

        vm.prank(ipOwner);
        licensingModule.registerDerivativeWithLicenseTokens(ipId2, licenseIds, "");

        assertEq(licenseToken.balanceOf(ipOwner), 0, "not burnt");
        assertTrue(licenseRegistry.isDerivativeIp(ipId2));
        assertTrue(licenseRegistry.hasDerivativeIps(ipId1));
        assertEq(licenseRegistry.getParentIpCount(ipId2), 1);
        assertEq(licenseRegistry.getDerivativeIpCount(ipId1), 1);
        assertEq(licenseRegistry.getParentIp(ipId2, 0), ipId1);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId1), 1);
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId2), 1);

        (address lt1, uint256 ltId1) = licenseRegistry.getAttachedLicenseTerms(ipId1, 0);
        (address lt2, uint256 ltId2) = licenseRegistry.getAttachedLicenseTerms(ipId2, 0);
        assertEq(lt1, lt2);
        assertEq(ltId1, ltId2);
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_parentIsChild() public {
        uint256 startLicenseId = attachAndMint_PILCommRemix_LicenseTokens({
            ipId: ipId1,
            amount: 2,
            receiver: ipOwner
        });
        assertEq(startLicenseId, 0);

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = startLicenseId;

        // TODO: this error is not descriptive of this test case.
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense.selector, ipId1));
        vm.prank(ipOwner);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, licenseIds, "");
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_linkTwice() public {
        uint256[] memory licenseIds = new uint256[](1);
        uint256 startLicenseId;

        vm.startPrank(ipOwner);
        licensingModule.attachLicenseTerms(ipId1, address(pilTemplate), commRemixTermsId);

        startLicenseId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId1,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            amount: 2,
            receiver: ipOwner,
            royaltyContext: ""
        });
        assertEq(startLicenseId, 0);

        licenseIds[0] = startLicenseId;

        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseIds, "");

        licensingModule.attachLicenseTerms(ipId2, address(pilTemplate), commRemixTermsId);
        startLicenseId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId2,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            amount: 2,
            receiver: ipOwner,
            royaltyContext: ""
        });
        assertEq(startLicenseId, 2);

        licenseIds[0] = startLicenseId;

        // TODO: this error is not descriptive of this test case.
        vm.expectRevert(abi.encodeWithSelector(Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense.selector, ipId3));
        licensingModule.registerDerivativeWithLicenseTokens(ipId3, licenseIds, "");
        vm.stopPrank();
    }

    function test_LicensingModule_registerDerivativeWithLicenseTokens_revert_notLicensee() public {
        uint256 startLicenseId = attachAndMint_PILCommRemix_LicenseTokens({
            ipId: ipId1,
            amount: 2,
            receiver: ipOwner
        });
        assertEq(startLicenseId, 0);

        vm.stopPrank();

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = startLicenseId;

        // TODO: this error is not descriptive of this test case.
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                ipId1,
                licenseHolder,
                address(licensingModule),
                licensingModule.registerDerivativeWithLicenseTokens.selector
            )
        );
        vm.prank(licenseHolder);
        licensingModule.registerDerivativeWithLicenseTokens(ipId1, licenseIds, "");
    }

    function test_LicensingModule_singleTransfer_verifyOk() public {
        uint256 startLicenseId = attachAndMint_PILCommRemix_LicenseTokens({
            ipId: ipId1,
            amount: 2,
            receiver: licenseHolder
        });
        uint256 endLicenseId = startLicenseId + 1;
        assertEq(startLicenseId, 0);

        address licenseHolder2 = address(0x102);
        assertEq(licenseToken.balanceOf(licenseHolder), 2);
        assertEq(licenseToken.balanceOf(licenseHolder2), 0);

        vm.prank(licenseHolder);
        licenseToken.transferFrom(licenseHolder, licenseHolder2, startLicenseId);

        assertEq(licenseToken.balanceOf(licenseHolder), 1);
        assertEq(licenseToken.balanceOf(licenseHolder2), 1);
        assertEq(licenseToken.ownerOf(startLicenseId), licenseHolder2);
        assertEq(licenseToken.ownerOf(endLicenseId), licenseHolder);
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function attachAndMint_PILCommRemix_LicenseTokens(
        address ipId,
        uint256 amount,
        address receiver
    ) internal returns (uint256 startLicenseId) {
        vm.prank(ipOwner);
        licensingModule.attachLicenseTerms(ipId, address(pilTemplate), commRemixTermsId);

        vm.prank(receiver);
        startLicenseId = licensingModule.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(pilTemplate),
            licenseTermsId: commRemixTermsId,
            amount: amount,
            receiver: receiver,
            royaltyContext: ""
        });
    }
}
