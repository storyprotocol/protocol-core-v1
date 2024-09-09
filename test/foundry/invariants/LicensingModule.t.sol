/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { Test } from "forge-std/Test.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";
import { TestProxyHelper } from "../utils/TestProxyHelper.sol";

import { PILicenseTemplate, PILTerms } from "contracts/modules/licensing/PILicenseTemplate.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { PILFlavors } from "contracts/lib/PILFlavors.sol";

/// @notice Harness for LicensingModule
contract LicensingModuleHarness is Test {
    /// @notice LicensingModule
    ILicensingModule public licensingModule;

    /// @notice A configured set of ipIds
    address[] public availableIpIds;
    /// @notice A configured set of licenseTemplates
    address[] public availableLicenseTemplates;

    bool public mintedOrRegisterDerivative = false;

    constructor(address _licensingModule) {
        licensingModule = ILicensingModule(_licensingModule);
    }

    /// @notice Set available ipIds and licenseTemplates
    /// @dev This is only callable by setUp function, explicitly excluded from fuzzing via targetSelector
    function set(address[] memory _pils, address[] memory _ipIds) external {
        availableIpIds = _ipIds;
        availableLicenseTemplates = _pils;
    }

    /// @notice Attach license terms to ipId
    /// @dev Using uint8 to replace address for reducing search space
    function attachLicenseTerms(uint8 ipIdNth, uint8 licenseTemplateNth, uint256 licenseTermsId) external {
        require(ipIdNth < availableIpIds.length, "LicensingModuleHarness: invalid ipIdNth");
        require(
            licenseTemplateNth < availableLicenseTemplates.length,
            "LicensingModuleHarness: invalid licenseTemplateNth"
        );
        address ipId = availableIpIds[ipIdNth];
        address licenseTemplate = availableLicenseTemplates[licenseTemplateNth];
        licensingModule.attachLicenseTerms(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Mint license tokens
    /// @dev Using uint8 to replace address for reducing search space
    function mintLicenseTokens(
        uint8 licensorIpIdNth,
        uint8 licenseTemplateNth,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external returns (uint256 startLicenseTokenId) {
        // prevent stuck forever in the minting loop
        require(amount < 10, "LicensingModuleHarness: amount too high");
        require(licensorIpIdNth < availableIpIds.length, "LicensingModuleHarness: invalid licensorIpIdNth");
        require(
            licenseTemplateNth < availableLicenseTemplates.length,
            "LicensingModuleHarness: invalid licenseTemplateNth"
        );
        address licensorIpId = availableIpIds[licensorIpIdNth];
        address licenseTemplate = availableLicenseTemplates[licenseTemplateNth];
        startLicenseTokenId = licensingModule.mintLicenseTokens(
            licensorIpId,
            licenseTemplate,
            licenseTermsId,
            amount,
            receiver,
            royaltyContext
        );

        mintedOrRegisterDerivative = true;
    }

    /// @notice Register derivative
    /// @dev Using uint8 to replace address for reducing search space
    function registerDerivative(
        uint8 childIpIdNth,
        uint8[] calldata parentIpIdsNth,
        uint256[] calldata licenseTermsIds,
        uint8 licenseTemplateNth,
        bytes calldata royaltyContext
    ) external {
        require(childIpIdNth < availableIpIds.length, "LicensingModuleHarness: invalid childIpIdNth");
        require(
            licenseTemplateNth < availableLicenseTemplates.length,
            "LicensingModuleHarness: invalid licenseTemplateNth"
        );
        address childIpId = availableIpIds[childIpIdNth];
        address licenseTemplate = availableLicenseTemplates[licenseTemplateNth];
        address[] memory parentIpIds = new address[](parentIpIdsNth.length);
        for (uint256 i = 0; i < parentIpIdsNth.length; i++) {
            require(parentIpIdsNth[i] < availableIpIds.length, "LicensingModuleHarness: invalid parentIpIdsNth");
            parentIpIds[i] = availableIpIds[parentIpIdsNth[i]];
        }
        licensingModule.registerDerivative(childIpId, parentIpIds, licenseTermsIds, licenseTemplate, royaltyContext);

        mintedOrRegisterDerivative = true;
    }

    /// @notice Register derivative with license tokens
    /// @dev Using uint8 to replace address for reducing search space
    function registerDerivativeWithLicenseTokens(
        uint8 childIpIdNth,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext
    ) external {
        require(childIpIdNth < availableIpIds.length, "LicensingModuleHarness: invalid childIpIdNth");
        address childIpId = availableIpIds[childIpIdNth];
        licensingModule.registerDerivativeWithLicenseTokens(childIpId, licenseTokenIds, royaltyContext);

        mintedOrRegisterDerivative = true;
    }

    /// @notice Set licensing config
    /// @dev Using uint8 to replace address for reducing search space
    function setLicensingConfig(
        uint8 ipIdNth,
        uint8 licenseTemplateNth,
        uint256 licenseTermsId,
        Licensing.LicensingConfig memory licensingConfig
    ) external {
        require(ipIdNth < availableIpIds.length, "LicensingModuleHarness: invalid ipIdNth");
        require(
            licenseTemplateNth < availableLicenseTemplates.length,
            "LicensingModuleHarness: invalid licenseTemplateNth"
        );
        address ipId = availableIpIds[ipIdNth];
        address licenseTemplate = availableLicenseTemplates[licenseTemplateNth];
        licensingModule.setLicensingConfig(ipId, licenseTemplate, licenseTermsId, licensingConfig);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

/// @notice Harness for PILicenseTemplate
contract PILLicenseTemplateHarness {
    PILicenseTemplate public pil;

    constructor(address _pil) {
        pil = PILicenseTemplate(_pil);
    }

    /// @notice Register license terms
    function registerLicenseTerms(PILTerms memory terms) external returns (uint256) {
        return pil.registerLicenseTerms(terms);
    }
}

/// @notice Dummy contract to receive ERC721
contract ERC721Holder {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

/// @dev Scenario 1: Impossible to derive IPs as no terms available
contract LicensingModuleBaseInvariant is BaseTest {
    LicensingModuleHarness public harness;
    ERC721Holder public erc721Holder = new ERC721Holder();

    uint256 public constant maxIpIds = 10;
    uint256 public constant maxLicenseTemplates = 3;

    /// @notice Preconfigured template PILs
    address[] public pils;

    /// @notice Preconfigured ipIds
    address[] public ipIds;

    /// @notice Preconfigured ipIds owned by harness
    address[] public ownedIpIds;

    /// @notice Preconfigured ipIds owned by others (erc721Holder)
    address[] public othersIpIds;

    function setUp() public virtual override {
        super.setUp();

        pils = new address[](maxLicenseTemplates);
        ipIds = new address[](maxIpIds);
        ownedIpIds = new address[](maxIpIds / 2);
        othersIpIds = new address[](maxIpIds / 2);

        harness = new LicensingModuleHarness(address(licensingModule));

        targetContract(address(harness));

        setUpIpIdsAndPils();

        bytes4[] memory selectors = new bytes4[](5);

        selectors[0] = harness.attachLicenseTerms.selector;
        selectors[1] = harness.mintLicenseTokens.selector;
        selectors[2] = harness.registerDerivative.selector;
        selectors[3] = harness.registerDerivativeWithLicenseTokens.selector;
        selectors[4] = harness.setLicensingConfig.selector;

        targetSelector(FuzzSelector({ addr: address(harness), selectors: selectors }));

        vm.deal(address(harness), 100000 ether);

        erc20.mint(address(harness), 100000 ether);

        vm.prank(address(harness));
        erc20.approve(address(royaltyPolicyLAP), type(uint256).max);
    }

    /// @notice Set up ipIds and pils
    function setUpIpIdsAndPils() internal virtual {
        // create initial ipIds with owner as harness
        for (uint256 i = 0; i < maxIpIds / 2; i++) {
            mockNFT.mintId(address(harness), 100 + i);
            address ipId = ipAssetRegistry.register(block.chainid, address(mockNFT), 100 + i);
            ipIds[i] = ipId;
            ownedIpIds[i] = ipId;
        }

        // create initial ipIds with owner as others
        for (uint256 i = 0; i < maxIpIds / 2; i++) {
            mockNFT.mintId(address(erc721Holder), 200 + i);
            address ipId = ipAssetRegistry.register(block.chainid, address(mockNFT), 200 + i);
            ipIds[i + maxIpIds / 2] = ipId;
            othersIpIds[i] = ipId;
        }

        for (uint256 i = 0; i < maxLicenseTemplates; i++) {
            pils[i] = deployPIL(i);
        }

        harness.set(pils, ipIds);
    }

    /// @notice Deploy PILicenseTemplate with a specific seed
    /// @param s The seed to deploy PILicenseTemplate
    function deployPIL(uint256 s) internal returns (address p) {
        PILicenseTemplate pil = new PILicenseTemplate(
            address(accessController),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(royaltyModule)
        );
        p = address(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                keccak256(abi.encodePacked("PILicenseTemplate", s)),
                address(pil),
                abi.encodeCall(
                    PILicenseTemplate.initialize,
                    (
                        address(protocolAccessManager),
                        "pil",
                        "https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf"
                    )
                )
            )
        );
        ILicenseRegistry reg = licensingModule.LICENSE_REGISTRY();
        vm.prank(multisig);
        reg.registerLicenseTemplate(address(p));
    }

    /// @notice Get attached license terms
    function _getAttachedLicenseTerms(
        address ipId,
        uint256 termsId
    ) internal returns (address licenseTemplate, uint256 licenseTermsId) {
        try licenseRegistry.getAttachedLicenseTerms(ipId, termsId) returns (
            address _licenseTemplate,
            uint256 _licenseTermsId
        ) {
            return (_licenseTemplate, _licenseTermsId);
        } catch {
            return (address(0), 0);
        }
    }

    /// @notice Invariant to check all IpIds are either not attached or attached to the known license templates
    function invariant_onlyAttachableToKnownLicenseTemplates() public {
        (address defaultLicenseTemplate, ) = licenseRegistry.getDefaultLicenseTerms();
        for (uint256 i = 0; i < ipIds.length; i++) {
            (address licenseTemplate, ) = _getAttachedLicenseTerms(ipIds[i], 0);
            if (licenseTemplate != address(0)) {
                bool found = false;
                for (uint256 j = 0; j < pils.length; j++) {
                    if (licenseTemplate == pils[j] || licenseTemplate == defaultLicenseTemplate) {
                        found = true;
                        break;
                    }
                }
                assertTrue(found, "LicensingModuleBaseInvariant: licenseTemplate not found");
            }
        }
    }

    /// @notice Invariant to check all IpIds are either not attached or
    /// attached to the known license templates in license registry
    function invariant_attachedMustRecorded() public {
        for (uint256 i = 0; i < ipIds.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = _getAttachedLicenseTerms(ipIds[i], 0);
            if (licenseTemplate != address(0)) {
                address ipId = ipIds[i];
                assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId));
                assertTrue(licenseRegistry.exists(licenseTemplate, licenseTermsId));
            }
        }
    }

    /// @notice Invariant to check all IpIds must have more than 0 attached license terms if attached
    function invariant_count() public {
        for (uint256 i = 0; i < ipIds.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = _getAttachedLicenseTerms(ipIds[i], 0);
            if (licenseTemplate != address(0)) {
                address ipId = ipIds[i];
                assertGe(licenseRegistry.getAttachedLicenseTermsCount(ipId), 1);
            }
        }
    }

    /// @notice Invariant to check all IpIds must have not attached to unknown license terms
    function invariant_nonexistTermId() public {
        for (uint256 i = 0; i < ipIds.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = _getAttachedLicenseTerms(ipIds[i], type(uint256).max);
            assertEq(licenseTemplate, address(0), "LicensingModuleAllAttachedInvariant: licenseTemplate not 0");
            assertEq(licenseTermsId, 0, "LicensingModuleAllAttachedInvariant: licenseTermsId not 0");
        }
    }

    /// @notice Invariant to check that harness has no control over other ipIds
    function invariant_othersIpNotChanged() public {
        for (uint256 i = 0; i < othersIpIds.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = _getAttachedLicenseTerms(othersIpIds[i], 1);
            // shall be uninitialized
            assertEq(licenseTemplate, address(0), "LicensingModuleBaseInvariant: licenseTemplate not 0");
            assertEq(licenseTermsId, 0, "LicensingModuleBaseInvariant: licenseTermsId not 0");
        }
    }

    /// @notice Invariant to check that licenseToken total minted tokens must be greater than or equal to total supply
    /// @dev totalMintedTokens >= totalSupply
    function invariant_licenseTokenSupply() public {
        assertGe(
            licenseToken.totalMintedTokens(),
            licenseToken.totalSupply(),
            "LicensingModuleBaseInvariant: totalMintedTokens not enough"
        );
    }

    /// @notice Invariant to check that all derivative counts shall be consistent and greater than total minted tokens
    function invariant_derivativeCounts() public {
        uint256 cnt = 0;
        uint256 cntReciprocal = 0;
        for (uint256 i = 0; i < ipIds.length; i++) {
            if (licenseRegistry.isDerivativeIp(ipIds[i])) {
                cnt++;
            }
            uint256 ips = licenseRegistry.getDerivativeIpCount(ipIds[i]);

            assertTrue(
                ips == 0 || licenseRegistry.hasDerivativeIps(ipIds[i]),
                "LicensingModuleBaseInvariant: derivative count"
            );
            cntReciprocal += ips;
        }

        assertGe(licenseToken.totalMintedTokens(), cnt, "LicensingModuleBaseInvariant: totalMintedTokens not enough");
        assertEq(cnt, cntReciprocal, "LicensingModuleBaseInvariant: cnt not equal to cntReciprocal");
    }

    /// @notice Invariant to check that all derivative child relationship must be consistent
    function invariant_derivativeChildRelationship() public {
        for (uint256 i = 0; i < ipIds.length; i++) {
            address ipId = ipIds[i];
            if (licenseRegistry.hasDerivativeIps(ipId)) {
                uint256 cnt = licenseRegistry.getDerivativeIpCount(ipId);
                assertGe(cnt, 1, "LicensingModuleBaseInvariant: derivative count");
                for (uint256 j = 0; j < cnt; j++) {
                    address derived = licenseRegistry.getDerivativeIp(ipId, j);
                    assertNotEq(derived, address(0), "LicensingModuleBaseInvariant: derived not 0");
                    assertNotEq(derived, ipId, "LicensingModuleBaseInvariant: derived not equal to ipId");
                    assertTrue(licenseRegistry.isDerivativeIp(derived), "LicensingModuleBaseInvariant: not derivative");
                }
            }
        }
    }

    /// @notice Invariant to check that all derivative parent relationship must be consistent
    function invariant_derivativeParentRelationship() public {
        for (uint256 i = 0; i < ipIds.length; i++) {
            address ipId = ipIds[i];
            if (licenseRegistry.isDerivativeIp(ipId)) {
                uint256 cnt = licenseRegistry.getParentIpCount(ipId);
                assertGe(cnt, 1, "LicensingModuleBaseInvariant: parent count");
                for (uint256 j = 0; j < cnt; j++) {
                    address parent = licenseRegistry.getParentIp(ipId, j);
                    assertNotEq(parent, address(0), "LicensingModuleBaseInvariant: parent not 0");
                    assertNotEq(parent, ipId, "LicensingModuleBaseInvariant: parent not equal to ipId");
                    assertTrue(
                        licenseRegistry.hasDerivativeIps(parent),
                        "LicensingModuleBaseInvariant: not derivative"
                    );
                }
            }
        }
    }

    /// @notice Invariant to check that all ipIds derived must pay the minimum minting fee
    function invariant_licenseConfig() public {
        uint256 totalCost = 0;
        for (uint256 i = 0; i < ipIds.length; i++) {
            address ipId = ipIds[i];

            if (licenseRegistry.hasDerivativeIps(ipId)) {
                uint256 cnt = licenseRegistry.getDerivativeIpCount(ipId);
                assertGe(cnt, 1, "LicensingModuleBaseInvariant: derivative count");

                uint256 min = 0;
                for (uint256 j = 0; j < pils.length; j++) {
                    address template = pils[j];
                    for (uint256 k = 0; k < 10; k++) {
                        Licensing.LicensingConfig memory config = licenseRegistry.getLicensingConfig(ipId, template, k);
                        min = min < config.mintingFee ? min : config.mintingFee;
                    }
                }
                totalCost += min * cnt;
            }
        }

        assertGe(
            100000 ether - erc20.balanceOf(address(harness)),
            totalCost,
            "LicensingModuleBaseInvariant: balance not enough"
        );
    }
}

/// @dev Scenario 2: Exist terms
contract LicensingModuleExistTermsInvariant is LicensingModuleBaseInvariant {
    function setUpIpIdsAndPils() internal override {
        super.setUpIpIdsAndPils();
        for (uint256 j = 0; j < pils.length; j++) {
            uint256 tid = PILicenseTemplate(pils[j]).registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
            assertEq(tid, 1);
        }
    }
}

/// @dev Scenario 3: IPs are attached to the same terms from different templates
contract LicensingModuleWithTermsInvariant is LicensingModuleBaseInvariant {
    mapping(address => address) internal initialIpToTemplate;

    function setUpIpIdsAndPils() internal override {
        super.setUpIpIdsAndPils();
        for (uint256 j = 0; j < pils.length; j++) {
            uint256 tid = PILicenseTemplate(pils[j]).registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
            assertEq(tid, 1);
        }

        for (uint256 i = 0; i < ownedIpIds.length; i++) {
            address ipId = ownedIpIds[i];
            vm.prank(address(harness));
            licensingModule.attachLicenseTerms(ipId, address(pils[i % maxLicenseTemplates]), 1);
            initialIpToTemplate[ipId] = (pils[i % maxLicenseTemplates]);
        }
    }

    /// @notice Invariant to check all ownedIpIds are attached to the same terms from different templates
    function invariant_initialAlwaysAttached() public {
        for (uint256 i = 0; i < ownedIpIds.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = _getAttachedLicenseTerms(ownedIpIds[i], 0);
            address initialLicenseTemplate = initialIpToTemplate[ownedIpIds[i]];
            assertEq(
                licenseTemplate,
                initialLicenseTemplate,
                "LicensingModuleWithTermsInvariant: licenseTemplate not same"
            );
            assertEq(licenseTermsId, 1, "LicensingModuleWithTermsInvariant: licenseTermsId not same");
        }
    }
}

/// @dev Scenario 4: IPs are attached to the same or different terms from different templates
contract LicensingModuleWithTermsDiffTemplatesInvariant is LicensingModuleBaseInvariant {
    mapping(address => address) internal initialIpToTemplate;
    mapping(address => uint256) internal initialIpToTerm;

    function setUpIpIdsAndPils() internal override {
        super.setUpIpIdsAndPils();
        for (uint256 j = 0; j < pils.length; j++) {
            uint256 tid = PILicenseTemplate(pils[j]).registerLicenseTerms(PILFlavors.defaultValuesLicenseTerms());
            assertEq(tid, 1);

            tid = PILicenseTemplate(pils[j]).registerLicenseTerms(PILFlavors.nonCommercialSocialRemixing());
            assertEq(tid, 2);
        }

        for (uint256 i = 0; i < ownedIpIds.length; i++) {
            address ipId = ownedIpIds[i];
            vm.prank(address(harness));
            licensingModule.attachLicenseTerms(ipId, address(pils[i % maxLicenseTemplates]), i % 2);
            initialIpToTemplate[ipId] = (pils[i % maxLicenseTemplates]);
            initialIpToTerm[ipId] = i % 2;
        }
    }

    /// @notice Invariant to check all ownedIpIds are attached to the same terms as initial
    function invariant_initialAlwaysAttached() public {
        for (uint256 i = 0; i < ownedIpIds.length; i++) {
            (address licenseTemplate, uint256 licenseTermsId) = _getAttachedLicenseTerms(ownedIpIds[i], 0);
            address initialLicenseTemplate = initialIpToTemplate[ownedIpIds[i]];
            assertEq(
                licenseTemplate,
                initialLicenseTemplate,
                "LicensingModuleWithTermsInvariant: licenseTemplate not same"
            );
            assertEq(
                licenseTermsId,
                initialIpToTerm[ownedIpIds[i]],
                "LicensingModuleWithTermsInvariant: licenseTermsId not same"
            );
        }
    }
}

/// @notice Scenario 5: IPs are all too expensive to mint
/// @dev All mints / derivatives should revert
contract LicensingModuleExpensiveInvariant is LicensingModuleBaseInvariant {
    function setUpIpIdsAndPils() internal override {
        super.setUpIpIdsAndPils();

        vm.prank(multisig);
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);

        PILTerms memory terms = PILTerms({
            transferable: true,
            royaltyPolicy: address(royaltyPolicyLAP),
            defaultMintingFee: type(uint256).max,
            expiration: 10 days,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: address(erc20),
            uri: ""
        });

        for (uint256 j = 0; j < pils.length; j++) {
            uint256 tid = PILicenseTemplate(pils[j]).registerLicenseTerms(terms);
            assertEq(tid, 1);
        }

        for (uint256 i = 0; i < ownedIpIds.length; i++) {
            address ipId = ownedIpIds[i];
            vm.prank(address(harness));
            licensingModule.attachLicenseTerms(ipId, address(pils[i % maxLicenseTemplates]), 1);
        }

        vm.warp(11 days);
    }

    // /// @notice Minting or registering derivative should not be possible
    // /// @dev All mints / derivatives should revert
    // function invariant_notMintable() public {
    //     assertFalse(harness.mintedOrRegisterDerivative());
    // }
}

/// @notice Scenario 6: Can create pil and attach to ipId
contract LicensingModuleWildcardInvariant is LicensingModuleBaseInvariant {
    function setUpIpIdsAndPils() internal override {
        super.setUpIpIdsAndPils();

        vm.prank(multisig);
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);

        for (uint256 j = 0; j < pils.length; j++) {
            targetContract(address(new PILLicenseTemplateHarness(pils[j])));
        }
    }
}
