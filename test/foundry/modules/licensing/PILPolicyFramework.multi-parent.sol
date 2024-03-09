// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { PILFrameworkErrors } from "contracts/lib/PILFrameworkErrors.sol";
// solhint-disable-next-line max-line-length
import { RegisterPILPolicyParams } from "contracts/interfaces/modules/licensing/IPILPolicyFrameworkManager.sol";
import { PILPolicyFrameworkManager } from "contracts/modules/licensing/PILPolicyFrameworkManager.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract PILPolicyFrameworkMultiParentTest is BaseTest {
    PILPolicyFrameworkManager internal pilFramework;
    string internal licenseUrl = "https://example.com/license";
    address internal ipId1;
    address internal ipId2;
    address internal ipId3;
    address internal ipId4;

    uint256[] internal licenses;

    mapping(address => address) internal ipIdToOwner;

    modifier withPILPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal
    ) {
        _mapPILPolicySimple(name, commercial, derivatives, reciprocal, 100);
        _addPILPolicyFromMapping(name, address(pilFramework));
        _;
    }

    modifier withLicense(
        string memory policyName,
        address ipId,
        address owner
    ) {
        uint256 policyId = _getPilPolicyId(policyName);

        Licensing.Policy memory policy = licensingModule.policy(policyId);

        vm.prank(ipIdToOwner[ipId]);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId, 1, owner, "");
        licenses.push(licenseId);
        _;
    }

    function setUp() public override {
        super.setUp();
        buildDeployRegistryCondition(DeployRegistryCondition({ licenseRegistry: true, moduleRegistry: false }));
        buildDeployModuleCondition(
            DeployModuleCondition({ disputeModule: false, royaltyModule: false, licensingModule: true })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ royaltyPolicyLAP: true, arbitrationPolicySP: false }));
        deployConditionally();
        postDeploymentSetup();

        // Call `getXXX` here to either deploy mock or use real contracted deploy via the
        // deployConditionally() call above.
        // TODO: three options, auto/mock/real in deploy condition, so no need to call getXXX
        accessController = IAccessController(getAccessController());
        licensingModule = ILicensingModule(getLicensingModule());
        royaltyModule = IRoyaltyModule(getRoyaltyModule());

        pilFramework = new PILPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "PILPolicyFrameworkManager",
            licenseUrl
        );

        licensingModule.registerPolicyFrameworkManager(address(pilFramework));

        mockNFT.mintId(bob, 1);
        mockNFT.mintId(bob, 2);
        mockNFT.mintId(bob, 3);
        mockNFT.mintId(alice, 4);

        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 1);
        ipIdToOwner[ipId1] = bob;
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 2);
        ipIdToOwner[ipId2] = bob;
        ipId3 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 3);
        ipIdToOwner[ipId3] = bob;
        ipId4 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 4);
        ipIdToOwner[ipId4] = alice;
        vm.label(ipId1, "IP1");
        vm.label(ipId2, "IP2");
        vm.label(ipId3, "IP3");
        vm.label(ipId4, "IP4");
    }

    function test_PILPolicyFramework_multiParent_AliceSets3Parents_SamePolicyReciprocal()
        public
        withPILPolicySimple("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
        withLicense("reciprocal", ipId3, alice)
    {
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
        assertEq(licensingModule.totalParentsForIpId(ipId4), 3);
        address[] memory parents = licensingModule.parentIpIds(ipId4);
        for (uint256 i = 0; i < licenses.length; i++) {
            Licensing.License memory license = licenseRegistry.license(licenses[i]);
            assertEq(parents[i], license.licensorIpId);
        }
        assertEq(licensingModule.totalPoliciesForIp(false, ipId4), 0);
        assertEq(licensingModule.totalPoliciesForIp(true, ipId4), 1);
        assertTrue(licensingModule.isPolicyIdSetForIp(true, ipId4, _getPilPolicyId("reciprocal")));
    }

    function test_PILPolicyFramework_multiParent_revert_AliceSets3Parents_OneNonReciprocal()
        public
        withPILPolicySimple("reciprocal", true, true, true)
        withPILPolicySimple("non_reciprocal", true, true, false)
        withLicense("reciprocal", ipId1, alice)
        withLicense("non_reciprocal", ipId2, alice)
        withLicense("reciprocal", ipId3, alice)
    {
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__ReciprocalValueMismatch.selector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
    }

    function test_PILPolicyFramework_multiParent_revert_AliceSets3Parents_3ReciprocalButDifferent()
        public
        withPILPolicySimple("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
    {
        // Save a new policy (change some value to change the policyId)
        _mapPILPolicySimple("other", true, true, true, 100);
        _getMappedPilPolicy("other").attribution = !_getMappedPilPolicy("other").attribution;
        _addPILPolicyFromMapping("other", address(pilFramework));

        vm.prank(ipId3);
        licenses.push(licensingModule.mintLicense(_getPilPolicyId("other"), ipId3, 1, alice, ""));
        vm.expectRevert(PILFrameworkErrors.PILPolicyFrameworkManager__ReciprocalButDifferentPolicyIds.selector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
    }

    function test_PILPolicyFramework_multiParent_NonReciprocalCommercial() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;
        // Commercial use (success)
        _testSuccessCompat(inputA, inputB, 2);
    }

    function test_PILPolicyFramework_multiParent_revert_NonReciprocalCommercial() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;
        // Commercial use (revert)
        inputA.policy.commercialUse = true;
        inputB.policy.commercialUse = false;
        inputB.policy.commercialRevShare = 0;
        inputB.mintingFee = 0;
        inputB.mintingFeeToken = address(0);
        inputB.royaltyPolicy = address(0x0);
        // TODO: passing in two different royaltyPolicy addresses
        // solhint-disable-next-line max-line-length
        _testRevertCompat(inputA, inputB, Errors.LicensingModule__IncompatibleLicensorCommercialPolicy.selector);
    }

    function test_PILPolicyFramework_multiParent_NonReciprocalDerivatives() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Derivatives (success)
        _testSuccessCompat(inputA, inputB, 2);
    }

    function test_PILPolicyFramework_multiParent_NonReciprocalTerritories() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");

        // Territories (success same)
        inputA.policy.territories = new string[](1);
        inputA.policy.territories[0] = "US";
        inputB.policy.territories = new string[](1);
        inputB.policy.territories[0] = "US";
        inputB.policy.attribution = !inputB.policy.attribution; // generates different policyId
        _testSuccessCompat(inputA, inputB, 2);
    }

    function test_PILPolicyFramework_multiParent_revert_NonReciprocalTerritories() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Territories (revert)
        inputA.policy.territories = new string[](1);
        inputA.policy.territories[0] = "US";
        inputB.policy.territories = new string[](1);
        inputB.policy.territories[0] = "UK";
        _testRevertCompat(inputA, inputB, PILFrameworkErrors.PILPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function test_PILPolicyFramework_multiParent_NonReciprocalDistributionChannels() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");

        // Territories (success same)
        inputA.policy.distributionChannels = new string[](1);
        inputA.policy.distributionChannels[0] = "web";
        inputB.policy.distributionChannels = new string[](1);
        inputB.policy.distributionChannels[0] = "web";
        inputB.policy.attribution = !inputB.policy.attribution; // generates different policyId
        _testSuccessCompat(inputA, inputB, 2);
    }

    function test_PILPolicyFramework_multiParent_revert_NonReciprocalDistributionChannels() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Distribution channels (revert)
        inputA.policy.distributionChannels = new string[](1);
        inputA.policy.distributionChannels[0] = "web";
        inputB.policy.distributionChannels = new string[](1);
        inputB.policy.distributionChannels[0] = "mobile";
        _testRevertCompat(inputA, inputB, PILFrameworkErrors.PILPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function test_PILPolicyFramework_multiParent_NonReciprocalContentRestrictions() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");

        // Territories (success same)
        inputA.policy.contentRestrictions = new string[](1);
        inputA.policy.contentRestrictions[0] = "web";
        inputB.policy.contentRestrictions = new string[](1);
        inputB.policy.contentRestrictions[0] = "web";
        inputB.policy.attribution = !inputB.policy.attribution; // generates different policyId
        _testSuccessCompat(inputA, inputB, 2);
    }

    function test_PILPolicyFramework_multiParent_revert_NonReciprocalContentRestrictions() public {
        // First we create 2 policies.
        _mapPILPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputA = _getMappedPilParams("pol_a");
        _mapPILPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterPILPolicyParams memory inputB = _getMappedPilParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputA.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Content restrictions (revert)
        inputA.policy.contentRestrictions = new string[](1);
        inputA.policy.contentRestrictions[0] = "adult";
        inputB.policy.contentRestrictions = new string[](1);
        inputB.policy.contentRestrictions[0] = "child";
        _testRevertCompat(inputA, inputB, PILFrameworkErrors.PILPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function _test_register_mint_AB(
        RegisterPILPolicyParams memory inputA,
        RegisterPILPolicyParams memory inputB
    ) internal returns (uint256 polAId, uint256 polBId) {
        polAId = pilFramework.registerPolicy(inputA);
        vm.prank(ipId1);
        licenses.push(licensingModule.mintLicense(polAId, ipId1, 1, alice, ""));

        polBId = pilFramework.registerPolicy(inputB);
        vm.prank(ipId2);
        licenses.push(licensingModule.mintLicense(polBId, ipId2, 2, alice, ""));
    }

    function _testRevertCompat(
        RegisterPILPolicyParams memory inputA,
        RegisterPILPolicyParams memory inputB,
        bytes4 errorSelector
    ) internal {
        _test_register_mint_AB(inputA, inputB);

        vm.expectRevert(errorSelector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
        licenses = new uint256[](0);
    }

    function _testSuccessCompat(
        RegisterPILPolicyParams memory inputA,
        RegisterPILPolicyParams memory inputB,
        uint256 expectedPolicies
    ) internal {
        (uint256 polAId, uint256 polBId) = _test_register_mint_AB(inputA, inputB);

        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
        assertEq(licensingModule.totalParentsForIpId(ipId4), 2);

        address[] memory parents = licensingModule.parentIpIds(ipId4);
        for (uint256 i = 0; i < licenses.length; i++) {
            Licensing.License memory license = licenseRegistry.license(licenses[i]);
            assertEq(parents[i], license.licensorIpId);
        }
        assertEq(licensingModule.totalPoliciesForIp(false, ipId4), 0);
        assertEq(licensingModule.totalPoliciesForIp(true, ipId4), expectedPolicies);
        assertTrue(licensingModule.isPolicyIdSetForIp(true, ipId4, polAId));
        assertTrue(licensingModule.isPolicyIdSetForIp(true, ipId4, polBId));
        licenses = new uint256[](0); // To call this function multiple times
    }
}
