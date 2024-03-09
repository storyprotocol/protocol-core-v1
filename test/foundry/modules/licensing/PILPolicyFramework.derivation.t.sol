// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { PILPolicyFrameworkManager } from "contracts/modules/licensing/PILPolicyFrameworkManager.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract PILPolicyFrameworkCompatibilityTest is BaseTest {
    PILPolicyFrameworkManager internal pilFramework;

    string internal licenseUrl = "https://example.com/license";
    address internal ipId1;
    address internal ipId2;

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

    modifier withAliceOwningDerivativeIp2(string memory policyName) {
        // Must add the policy first to set the royalty policy (if policy is commercial)
        // Otherwise, minting license will fail because there's no royalty policy set for license policy,
        // AND bob (the caller) is not the owner of IPAccount 1.
        vm.startPrank(bob);
        uint256 licenseId = licensingModule.mintLicense(_getPilPolicyId(policyName), ipId1, 1, alice, "");

        vm.startPrank(alice);
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;
        licensingModule.linkIpToParents(licenseIds, ipId2, "");
        vm.stopPrank();
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
        mockNFT.mintId(alice, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 2);
        vm.label(ipId1, "IP1");
        vm.label(ipId2, "IP2");

        vm.label(LIQUID_SPLIT_FACTORY, "LIQUID_SPLIT_FACTORY");
        vm.label(LIQUID_SPLIT_MAIN, "LIQUID_SPLIT_MAIN");
    }

    /////////////////////////////////////////////////////////////
    //////  SETTING POLICIES IN ORIGINAL WORK (NO PARENTS) //////
    /////////////////////////////////////////////////////////////

    function test_PILPolicyFramework_originalWork_bobAddsDifferentPoliciesAndAliceMints()
        public
        withPILPolicySimple("comm_deriv", true, true, false)
        withPILPolicySimple("comm_non_deriv", true, false, false)
    {
        // Bob can add different policies on IP1 without compatibility checks.
        vm.startPrank(bob);
        licensingModule.addPolicyToIp(ipId1, _getPilPolicyId("comm_deriv"));
        licensingModule.addPolicyToIp(ipId1, _getPilPolicyId("comm_non_deriv"));
        vm.stopPrank();

        bool isInherited = false;
        assertEq(licensingModule.totalPoliciesForIp(isInherited, ipId1), 2);
        assertTrue(
            licensingModule.isPolicyIdSetForIp(isInherited, ipId1, _getPilPolicyId("comm_deriv")),
            "comm_deriv not set"
        );
        assertTrue(
            licensingModule.isPolicyIdSetForIp(isInherited, ipId1, _getPilPolicyId("comm_non_deriv")),
            "comm_non_deriv not set"
        );

        // Others can mint licenses to make derivatives of IP1 from each different policy,
        // as long as they pass the verifications
        uint256 licenseId1 = licensingModule.mintLicense(_getPilPolicyId("comm_deriv"), ipId1, 1, dan, "");
        assertEq(licenseRegistry.balanceOf(dan, licenseId1), 1, "dan doesn't have license1");

        uint256 licenseId2 = licensingModule.mintLicense(_getPilPolicyId("comm_non_deriv"), ipId1, 1, dan, "");
        assertEq(licenseRegistry.balanceOf(dan, licenseId2), 1, "dan doesn't have license2");
    }

    function test_PILPolicyFramework_originalWork_bobMintsWithDifferentPolicies()
        public
        withPILPolicySimple("comm_deriv", true, true, false)
        withPILPolicySimple("comm_non_deriv", true, false, false)
    {
        // Bob can add different policies on IP1 without compatibility checks.
        vm.startPrank(bob);
        uint256 licenseId1 = licensingModule.mintLicense(_getPilPolicyId("comm_deriv"), ipId1, 2, dan, "");
        assertEq(licenseRegistry.balanceOf(dan, licenseId1), 2, "dan doesn't have license1");

        uint256 licenseId2 = licensingModule.mintLicense(_getPilPolicyId("comm_non_deriv"), ipId1, 1, dan, "");
        assertEq(licenseRegistry.balanceOf(dan, licenseId2), 1, "dan doesn't have license2");
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////
    //////       LICENSES THAT DONT ALLOW DERIVATIVES          //////
    /////////////////////////////////////////////////////////////////

    function test_PILPolicyFramework_non_derivative_license()
        public
        withPILPolicySimple("non_comm_no_deriv", true, false, false)
    {
        // Bob can add different policies on IP1 without compatibility checks.
        vm.startPrank(bob);
        uint256 licenseId1 = licensingModule.mintLicense(_getPilPolicyId("non_comm_no_deriv"), ipId1, 2, alice, "");
        assertEq(licenseRegistry.balanceOf(alice, licenseId1), 2, "dan doesn't have license1");
        vm.stopPrank();

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId1;
        vm.expectRevert(Errors.LicensingModule__LinkParentParamFailed.selector);
        vm.startPrank(alice);
        licensingModule.linkIpToParents(licenseIds, ipId2, "");
        vm.stopPrank();
    }

    /////////////////////////////////////////////////////////////////
    //////  SETTING POLICIES IN DERIVATIVE WORK (WITH PARENTS) //////
    /////////////////////////////////////////////////////////////////

    function test_PILPolicyFramework_derivative_revert_cantMintDerivativeOfDerivative()
        public
        withPILPolicySimple("comm_non_recip", true, true, false)
        withAliceOwningDerivativeIp2("comm_non_recip")
    {
        vm.expectRevert(Errors.LicensingModule__MintLicenseParamFailed.selector);
        vm.startPrank(dan);
        licensingModule.mintLicense(_getPilPolicyId("comm_non_recip"), ipId2, 1, dan, "");

        vm.expectRevert(Errors.LicensingModule__MintLicenseParamFailed.selector);
        vm.startPrank(alice);
        licensingModule.mintLicense(_getPilPolicyId("comm_non_recip"), ipId2, 1, alice, "");
    }

    function test_PILPolicyFramework_derivative_revert_AliceCantSetPolicyOnDerivativeOfDerivative()
        public
        withPILPolicySimple("comm_non_recip", true, true, false)
        withPILPolicySimple("comm_deriv", true, true, false)
        withAliceOwningDerivativeIp2("comm_non_recip")
    {
        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getPilPolicyId("comm_deriv"));

        _mapPILPolicySimple("other_policy", true, true, false, 100);
        _getMappedPilPolicy("other_policy").attribution = false;
        _addPILPolicyFromMapping("other_policy", address(pilFramework));

        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getPilPolicyId("other_policy"));
    }

    /////////////////////////////////////////////////////////////////
    //////                RECIPROCAL DERIVATIVES               //////
    /////////////////////////////////////////////////////////////////

    function test_PILPolicyFramework_reciprocal_danMintsLicenseFromIp2()
        public
        withPILPolicySimple("comm_reciprocal", true, true, true)
        withAliceOwningDerivativeIp2("comm_reciprocal")
    {
        vm.prank(dan);
        uint256 licenseId = licensingModule.mintLicense(_getPilPolicyId("comm_reciprocal"), ipId2, 1, dan, "");
        assertEq(licenseRegistry.balanceOf(dan, licenseId), 1, "dan doesn't have license");
    }

    function test_PILPolicyFramework_reciprocal_AliceMintsLicenseForP1inIP2()
        public
        withPILPolicySimple("comm_reciprocal", true, true, true)
        withAliceOwningDerivativeIp2("comm_reciprocal")
    {
        vm.prank(alice);
        uint256 licenseId = licensingModule.mintLicense(_getPilPolicyId("comm_reciprocal"), ipId2, 1, alice, "");
        assertEq(licenseRegistry.balanceOf(alice, licenseId), 1, "Alice doesn't have license");
    }

    function test_PILPolicyFramework_reciprocal_revert_AliceTriesToSetPolicyInReciprocalDeriv()
        public
        withPILPolicySimple("comm_reciprocal", true, true, true)
        withPILPolicySimple("other_policy", true, true, false)
        withAliceOwningDerivativeIp2("comm_reciprocal")
    {
        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getPilPolicyId("other_policy"));

        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getPilPolicyId("comm_reciprocal"));
    }
}
