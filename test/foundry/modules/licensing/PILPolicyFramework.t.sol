// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { PILFrameworkErrors } from "contracts/lib/PILFrameworkErrors.sol";
// solhint-disable-next-line max-line-length
import { PILPolicy, RegisterPILPolicyParams } from "contracts/interfaces/modules/licensing/IPILPolicyFrameworkManager.sol";
import { PILPolicyFrameworkManager } from "contracts/modules/licensing/PILPolicyFrameworkManager.sol";

import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { MockTokenGatedHook } from "test/foundry/mocks/MockTokenGatedHook.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract PILPolicyFrameworkTest is BaseTest {
    PILPolicyFrameworkManager internal pilFramework;

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public licenseHolder = address(0x101);
    MockERC721 internal gatedNftFoo = new MockERC721("GatedNftFoo");
    MockTokenGatedHook internal tokenGatedHook = new MockTokenGatedHook();

    function setUp() public override {
        super.setUp();
        buildDeployRegistryCondition(DeployRegistryCondition({ licenseRegistry: true, moduleRegistry: false }));
        buildDeployModuleCondition(
            DeployModuleCondition({ disputeModule: false, royaltyModule: false, licensingModule: true })
        );
        buildDeployPolicyCondition(
            DeployPolicyCondition({
                arbitrationPolicySP: false,
                royaltyPolicyLAP: true // deploy to set address for commercial licenses
            })
        );
        deployConditionally();
        postDeploymentSetup();

        // Call `getXXX` here to either deploy mock or use real contracted deploy via the
        // deployConditionally() call above.
        // TODO: three options, auto/mock/real in deploy condition, so no need to call getXXX
        accessController = IAccessController(getAccessController());
        licensingModule = ILicensingModule(getLicensingModule());

        pilFramework = new PILPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "PILPolicyFrameworkManager",
            licenseUrl
        );

        licensingModule.registerPolicyFrameworkManager(address(pilFramework));

        mockNFT.mintId(alice, 1);
        mockNFT.mintId(alice, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 2);
    }

    function test_PILPolicyFrameworkManager__valuesSetCorrectly() public {
        string[] memory territories = new string[](2);
        territories[0] = "test1";
        territories[1] = "test2";
        string[] memory distributionChannels = new string[](1);
        distributionChannels[0] = "test3";
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.policy.territories = territories;
        inputA.policy.distributionChannels = distributionChannels;
        uint256 policyId = pilFramework.registerPolicy(inputA);
        PILPolicy memory policy = pilFramework.getPILPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(inputA.policy)));
    }

    function test_PILPolicyFrameworkManager__verifyLink_false_commercializerCheckerFailedVerify() public {
        PILPolicy memory policyData = PILPolicy({
            attribution: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(tokenGatedHook), // 0 token balance for ipId1
            commercializerCheckerData: abi.encode(address(gatedNftFoo)),
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray
        });

        vm.prank(address(licensingModule));
        bool verified = pilFramework.verifyLink(0, alice, ipId1, address(0), abi.encode(policyData));
        assertFalse(verified);
    }

    function test_PILPolicyFrameworkManager__verifyMint_false_commercializerCheckerFailedVerify() public {
        PILPolicy memory policyData = PILPolicy({
            attribution: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(tokenGatedHook), // 0 token balance for ipId1
            commercializerCheckerData: abi.encode(address(gatedNftFoo)),
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray
        });

        vm.prank(address(licensingModule));
        bool verified = pilFramework.verifyMint(alice, false, ipId1, alice, 2, abi.encode(policyData));
        assertFalse(verified);
    }

    function test_PILPolicyFrameworkManager__verifyMint_revert_commercializerCheckerFailedVerify() public {
        PILPolicy memory policyData = PILPolicy({
            attribution: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(tokenGatedHook), // 0 token balance for ipId1
            commercializerCheckerData: abi.encode(address(gatedNftFoo)),
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray
        });

        vm.prank(address(licensingModule));
        bool verified = pilFramework.verifyMint(alice, false, ipId1, alice, 2, abi.encode(policyData));
        assertFalse(verified);
    }

    function test_PILPolicyFrameworkManager__getAggregator_revert_emptyAggregator() public {
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__RightsNotFound.selector);
        pilFramework.getAggregator(ipId1);
    }

    /////////////////////////////////////////////////////////////
    //////              COMMERCIAL USE TERMS               //////
    /////////////////////////////////////////////////////////////

    function test_PILPolicyFrameworkManager__commercialUseDisabled_revert_settingIncompatibleTerms() public {
        // If commercial values are NOT allowed
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");

        // CHECK: commercialAttribution = true should revert
        inputA.policy.commercialAttribution = true;
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddAttribution.selector);
        pilFramework.registerPolicy(inputA);

        // reset
        inputA.policy.commercialAttribution = false;

        // CHECK: Non empty commercializers should revert
        inputA.policy.commercializerChecker = address(tokenGatedHook);
        inputA.policy.commercializerCheckerData = abi.encode(address(gatedNftFoo));
        vm.expectRevert(
            PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers.selector
        );
        pilFramework.registerPolicy(inputA);

        // reset
        inputA.policy.commercializerChecker = address(0);
        inputA.policy.commercializerCheckerData = "";

        // CHECK: No rev share should be set; revert
        inputA.policy.commercialRevShare = 1;
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddRevShare.selector);
        pilFramework.registerPolicy(inputA);

        // reset
        inputA.policy.commercialRevShare = 0;

        // CHECK: royaltyPolicy != address(0) should revert
        inputA.royaltyPolicy = address(0x123123);
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddRoyaltyPolicy.selector);
        pilFramework.registerPolicy(inputA);

        // reset
        inputA.royaltyPolicy = address(0);

        // CHECK: mintingFee > 0 should revert
        inputA.mintingFee = 100;
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__CommercialDisabled_CantAddMintingFee.selector);
        pilFramework.registerPolicy(inputA);

        // reset
        inputA.mintingFee = 0;
    }

    function test_PILPolicyFrameworkManager__commercialUseEnabled_revert_settingIncompatibleTerms() public {
        // If commercial values are NOT allowed
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");

        // CHECK: royaltyPolicy == address(0) should revert
        inputA.royaltyPolicy = address(0);
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__CommercialEnabled_RoyaltyPolicyRequired.selector);
        pilFramework.registerPolicy(inputA);

        // reset
        inputA.royaltyPolicy = address(0x123123);
    }

    function test_PILPolicyFrameworkManager__commercialUseEnabled_valuesSetCorrectly() public {
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.policy.commercialAttribution = true;
        inputA.policy.commercializerChecker = address(0);
        inputA.policy.commercializerCheckerData = "";
        uint256 policyId = pilFramework.registerPolicy(inputA);
        PILPolicy memory policy = pilFramework.getPILPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(inputA.policy)));
    }

    function test_PILPolicyFrameworkManager__commercialUseEnabled_invalidCommercializerChecker() public {
        address invalidCommercializerChecker = address(new MockERC721("Fake Commercializer Checker"));
        bytes memory invalideCommercializerCheckerData = abi.encode(address(0x456));

        PILPolicy memory policyData = PILPolicy({
            attribution: false,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: invalidCommercializerChecker,
            commercializerCheckerData: abi.encode(address(gatedNftFoo)),
            commercialRevShare: 123123,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray
        });

        RegisterPILPolicyParams memory input = RegisterPILPolicyParams({
            transferable: true,
            royaltyPolicy: address(0xbeef),
            mintingFee: 0,
            mintingFeeToken: address(0),
            policy: policyData
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook.selector,
                invalidCommercializerChecker
            )
        );
        pilFramework.registerPolicy(input);

        input.policy.commercializerChecker = address(tokenGatedHook);
        input.policy.commercializerCheckerData = invalideCommercializerCheckerData;
        vm.expectRevert("MockTokenGatedHook: Invalid token address");
        pilFramework.registerPolicy(input);
    }

    function test_PILPolicyFrameworkManager__derivatives_notAllowed_revert_settingIncompatibleTerms() public {
        // If no derivative values allowed
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: false,
            reciprocal: false,
            commercialRevShare: 123123
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.policy.derivativesAttribution = true;
        // derivativesAttribution = true should revert
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution.selector);
        pilFramework.registerPolicy(inputA);
        // Requesting approval for derivatives should revert
        inputA.policy.derivativesAttribution = false;
        inputA.policy.derivativesApproval = true;
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__DerivativesDisabled_CantAddApproval.selector);
        pilFramework.registerPolicy(inputA);
        // Setting reciprocal license should revert
        inputA.policy.derivativesApproval = false;
        inputA.policy.derivativesReciprocal = true;
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal.selector);
        pilFramework.registerPolicy(inputA);
    }

    function test_PILPolicyFrameworkManager__derivatives_valuesSetCorrectly() public {
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.policy.derivativesAttribution = true;
        uint256 policyId = pilFramework.registerPolicy(inputA);
        PILPolicy memory policy = pilFramework.getPILPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(inputA.policy)));
    }

    /////////////////////////////////////////////////////////////
    //////                  APPROVAL TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_PILPolicyFrameworkManager_derivatives_withApproval_revert_linkNotApproved() public {
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.policy.derivativesApproval = true;
        uint256 policyId = pilFramework.registerPolicy(inputA);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, alice, "");
        assertFalse(pilFramework.isDerivativeApproved(licenseId, ipId2));

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        pilFramework.setApproval(licenseId, ipId2, false);
        assertFalse(pilFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.expectRevert(Errors.LicensingModule__LinkParentParamFailed.selector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenseIds, ipId2, "");
    }

    function test_PILPolicyFrameworkManager__derivatives_withApproval_linkApprovedIpId() public {
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 0
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.policy.derivativesApproval = true;
        uint256 policyId = pilFramework.registerPolicy(inputA);

        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, alice, "");
        assertFalse(pilFramework.isDerivativeApproved(licenseId, ipId2));

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        pilFramework.setApproval(licenseId, ipId2, true);
        assertTrue(pilFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(alice);
        licensingModule.linkIpToParents(licenseIds, ipId2, "");
        assertTrue(licensingModule.isParent(ipId1, ipId2));
    }

    /////////////////////////////////////////////////////////////
    //////                  TRANSFER TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_PILPolicyFrameworkManager__transferrable() public {
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.transferable = true;
        uint256 policyId = pilFramework.registerPolicy(inputA);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 0);
        assertEq(licenseRegistry.balanceOf(licenseHolder2, licenseId), 1);
    }

    function test_PILPolicyFrameworkManager__nonTransferrable_revertIfTransferExceptFromLicensor() public {
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        inputA.transferable = false;
        uint256 policyId = pilFramework.registerPolicy(inputA);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.startPrank(licenseHolder);
        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        vm.stopPrank();
    }

    function test_PILPolicyFrameworkManager__policyToJson() public {
        string[] memory territories = new string[](2);
        territories[0] = "test1";
        territories[1] = "test2";
        string[] memory distributionChannels = new string[](1);
        distributionChannels[0] = "test3";

        PILPolicy memory policyData = PILPolicy({
            attribution: false,
            commercialUse: false,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: true,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            territories: territories,
            distributionChannels: distributionChannels,
            contentRestrictions: emptyStringArray
        });

        string memory actualJson = pilFramework.policyToJson(abi.encode(policyData));
        /* solhint-disable */
        string
            memory expectedJson = '{"trait_type": "Attribution", "value": "false"},{"trait_type": "Commercial Use", "value": "false"},{"trait_type": "Commercial Attribution", "value": "true"},{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": 0},{"trait_type": "Commercializer Check", "value": "0x0000000000000000000000000000000000000000"},{"trait_type": "Derivatives Allowed", "value": "true"},{"trait_type": "Derivatives Attribution", "value": "false"},{"trait_type": "Derivatives Approval", "value": "false"},{"trait_type": "Derivatives Reciprocal", "value": "false"},{"trait_type": "Territories", "value": ["test1","test2"]},{"trait_type": "Distribution Channels", "value": ["test3"]},';
        /* solhint-enable */

        assertEq(actualJson, expectedJson);
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
