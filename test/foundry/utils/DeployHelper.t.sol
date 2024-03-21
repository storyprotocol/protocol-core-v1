/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { console2 } from "forge-std/console2.sol"; // console to indicate mock deployment calls.
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";

// contracts
import { AccessController } from "../../../contracts/AccessController.sol";
import { Governance } from "../../../contracts/governance/Governance.sol";
import { IAccessController } from "../../../contracts/interfaces/IAccessController.sol";
import { IGovernance } from "../../../contracts/interfaces/governance/IGovernance.sol";
import { IDisputeModule } from "../../../contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { ILicensingModule } from "../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { ILicenseRegistry } from "../../../contracts/interfaces/registries/ILicenseRegistry.sol";
import { IModuleRegistry } from "../../../contracts/interfaces/registries/IModuleRegistry.sol";
import { IPAccountImpl } from "../../../contracts/IPAccountImpl.sol";
import { IPMetadataProvider } from "../../../contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "../../../contracts/registries/IPAccountRegistry.sol";
import { IPAssetRegistry } from "../../../contracts/registries/IPAssetRegistry.sol";
import { IPAssetRenderer } from "../../../contracts/registries/metadata/IPAssetRenderer.sol";
import { ModuleRegistry } from "../../../contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "../../../contracts/registries/LicenseRegistry.sol";
import { IPResolver } from "../../../contracts/resolvers/IPResolver.sol";
import { RoyaltyModule } from "../../../contracts/modules/royalty/RoyaltyModule.sol";
import { AncestorsVaultLAP } from "../../../contracts/modules/royalty/policies/AncestorsVaultLAP.sol";
import { RoyaltyPolicyLAP } from "../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { DisputeModule } from "../../../contracts/modules/dispute/DisputeModule.sol";
import { LicensingModule } from "../../../contracts/modules/licensing/LicensingModule.sol";
import { ArbitrationPolicySP } from "../../../contracts/modules/dispute/policies/ArbitrationPolicySP.sol";

// test
import { MockAccessController } from "../mocks/access/MockAccessController.sol";
import { MockGovernance } from "../mocks/governance/MockGovernance.sol";
import { MockDisputeModule } from "../mocks/module/MockDisputeModule.sol";
import { MockLicensingModule } from "../mocks/module/MockLicensingModule.sol";
import { MockRoyaltyModule } from "../mocks/module/MockRoyaltyModule.sol";
import { MockArbitrationPolicy } from "../mocks/policy/MockArbitrationPolicy.sol";
import { MockLicenseRegistry } from "../mocks/registry/MockLicenseRegistry.sol";
import { MockModuleRegistry } from "../mocks/registry/MockModuleRegistry.sol";
import { MockERC20 } from "../mocks/token/MockERC20.sol";
import { MockERC721 } from "../mocks/token/MockERC721.sol";
import { TestProxyHelper } from "./TestProxyHelper.sol";


contract DeployHelper {
    // TODO: three options, auto/mock/real in deploy condition, so that we don't need to manually
    //       call getXXX to get mock contract (if there's no real contract deployed).

    struct DeployRegistryCondition {
        // bool ipAccountRegistry; // TODO: Add option for mock IPAccountRegistry
        // bool ipAssetRegistry; // TODO: Add option for mock IPAssetRegistry
        bool licenseRegistry;
        bool moduleRegistry;
    }

    struct DeployModuleCondition {
        bool disputeModule;
        bool royaltyModule;
        bool licensingModule;
    }

    struct DeployAccessCondition {
        bool accessController;
        bool governance;
    }

    struct DeployPolicyCondition {
        bool arbitrationPolicySP;
        bool royaltyPolicyLAP;
    }

    struct DeployMiscCondition {
        bool ipAssetRenderer;
        bool ipMetadataProvider;
        bool ipResolver;
    }

    /// @dev Conditions that determine whether to deploy a contract.
    struct DeployConditions {
        DeployRegistryCondition registry;
        DeployModuleCondition module;
        DeployAccessCondition access;
        DeployPolicyCondition policy;
        DeployMiscCondition misc;
    }

    /// @dev Store deployment info for post-deployment setups.
    struct PostDeployConditions {
        bool accessController_init;
        bool moduleRegistry_registerModules;
        bool royaltyModule_configure;
        bool disputeModule_configure;
    }

    struct MockERC721s {
        MockERC721 ape;
        MockERC721 cat;
        MockERC721 dog;
    }

    // IPAccount
    ERC6551Registry internal erc6551Registry;
    IPAccountImpl internal ipAccountImpl;

    // Registry
    IModuleRegistry internal moduleRegistry;
    IPAccountRegistry internal ipAccountRegistry;
    IPAssetRegistry internal ipAssetRegistry;
    ILicenseRegistry internal licenseRegistry;

    // Module
    IDisputeModule internal disputeModule;
    IRoyaltyModule internal royaltyModule;
    ILicensingModule internal licensingModule;

    // Access
    IGovernance internal governance;
    IAccessController internal accessController;

    // Policy
    ArbitrationPolicySP internal arbitrationPolicySP;
    AncestorsVaultLAP internal ancestorsVaultImpl;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;

    // Misc.
    IPAssetRenderer internal ipAssetRenderer;
    IPMetadataProvider internal ipMetadataProvider;
    IPResolver internal ipResolver;

    // Royalty Policy — 0xSplits Liquid Split (Sepolia)
    address internal constant LIQUID_SPLIT_FACTORY = 0xF678Bae6091Ab6933425FE26Afc20Ee5F324c4aE;
    address internal constant LIQUID_SPLIT_MAIN = 0x57CBFA83f000a38C5b5881743E298819c503A559;

    // Arbitration Policy
    // TODO: custom arbitration price for testing
    uint256 internal constant ARBITRATION_PRICE = 1000; // not decimal exponentiated

    // Mock
    MockERC20 internal erc20;
    MockERC20 internal erc20bb;
    MockERC721s internal erc721;
    MockArbitrationPolicy internal mockArbitrationPolicy;
    // TODO: create mock
    RoyaltyPolicyLAP internal mockRoyaltyPolicyLAP;

    // DeployHelper
    DeployConditions internal deployConditions;
    PostDeployConditions internal postDeployConditions;
    address private governanceAdmin;

    function setGovernanceAdmin(address admin) public {
        governanceAdmin = admin;
    }

    function buildDeployRegistryCondition(DeployRegistryCondition memory d) public {
        deployConditions.registry = d;
    }

    function buildDeployModuleCondition(DeployModuleCondition memory d) public {
        deployConditions.module = d;
    }

    function buildDeployAccessCondition(DeployAccessCondition memory d) public {
        deployConditions.access = d;
    }

    function buildDeployPolicyCondition(DeployPolicyCondition memory d) public {
        deployConditions.policy = d;
    }

    function buildDeployMiscCondition(DeployMiscCondition memory d) public {
        deployConditions.misc = d;
    }

    /// @notice Deploys all contracts for integration test.
    function deployIntegration() public {
        buildDeployRegistryCondition(DeployRegistryCondition(true, true));
        buildDeployModuleCondition(DeployModuleCondition(true, true, true));
        buildDeployAccessCondition(DeployAccessCondition(true, true));
        buildDeployPolicyCondition(DeployPolicyCondition(true, true));
        buildDeployMiscCondition(DeployMiscCondition(true, true, true));

        deployConditionally();
    }

    /// @notice Deploys contracts conditionally based on DeployConditions state variable.
    function deployConditionally() public {
        require(governanceAdmin != address(0), "DeployHelper: Governance admin not set, setGovernanceAdmin(address)");

        DeployConditions memory dc = deployConditions; // alias

        erc6551Registry = new ERC6551Registry();

        _deployMockAssets();

        _deployAccessConditionally(dc.access);

        ipAccountImpl = new IPAccountImpl(address(accessController));

        _deployRegistryConditionally(dc.registry);
        // Registration module requires ipResolver
        _deployIPResolverConditionally(dc.misc);
        _deployModuleConditionally(dc.module);
        _deployPolicyConditionally(dc.policy);
        _deployMiscConditionally(dc.misc);
    }

    function _deployMockAssets() public {
        erc20 = new MockERC20();
        erc20bb = new MockERC20();
        erc721 = MockERC721s({ ape: new MockERC721("Ape"), cat: new MockERC721("Cat"), dog: new MockERC721("Dog") });
    }

    function _deployAccessConditionally(DeployAccessCondition memory d) public {
        if (d.governance) {
            governance = new Governance(governanceAdmin);
            console2.log("DeployHelper: Using REAL Governance");
        }
        if (d.accessController) {
            accessController = new AccessController(getGovernance());
            console2.log("DeployHelper: Using REAL AccessController");
            postDeployConditions.accessController_init = true;
            // Access Controller uses IPAccountRegistry in its initialize function.
            // TODO: Use mock IPAccountRegistry, instead of forcing deployment of actual IPAccountRegistry
            //       contract when using AccessController.
            // deployConditions.registry.ipAccountRegistry = true;
        } else {
            accessController = new MockAccessController();
            console2.log("DeployHelper: Using Mock AccessController");
        }
    }

    function _deployRegistryConditionally(DeployRegistryCondition memory d) public {
        if (d.moduleRegistry) {
            moduleRegistry = new ModuleRegistry(getGovernance());
            console2.log("DeployHelper: Using REAL ModuleRegistry");
            postDeployConditions.moduleRegistry_registerModules = true;
        }

        // TODO: Allow using mock IPAccountRegistry, instead of forcing deployment of actual IPAccountRegistry.
        ipAccountRegistry = new IPAccountRegistry(address(erc6551Registry), address(ipAccountImpl));
        console2.log("DeployHelper: Using REAL IPAccountRegistry");

        // TODO: Allow using mock IPAssetRegistry, instead of forcing deployment of actual IPAssetRegistry.
        ipAssetRegistry = new IPAssetRegistry(
            address(erc6551Registry),
            address(ipAccountImpl),
            getModuleRegistry(),
            getGovernance()
        );
        console2.log("DeployHelper: Using REAL IPAssetRegistry");

        if (d.licenseRegistry) {
            address newIml = address(new LicenseRegistry());
            licenseRegistry = LicenseRegistry(
                TestProxyHelper.deployUUPSProxy(
                    newIml,
                    abi.encodeCall(LicenseRegistry.initialize, (address(getGovernance()), "deploy helper"))
                )
            );
            console2.log("DeployHelper: Using REAL LicenseRegistry");
        }
    }

    function _deployIPResolverConditionally(DeployMiscCondition memory d) public {
        if (d.ipResolver) {
            require(address(ipAssetRegistry) != address(0), "DeployHelper IPResolver: IPAssetRegistry required");
            ipResolver = new IPResolver(getAccessController(), address(ipAssetRegistry));
            console2.log("DeployHelper: Using REAL IPResolver");
        }
    }

    function _deployModuleConditionally(DeployModuleCondition memory d) public {
        if (d.royaltyModule) {
            royaltyModule = new RoyaltyModule(getGovernance());
            console2.log("DeployHelper: Using REAL RoyaltyModule");
            postDeployConditions.royaltyModule_configure = true;
        }
        if (d.disputeModule) {
            require(address(ipAssetRegistry) != address(0), "DeployHelper Module: IPAssetRegistry required");
            disputeModule = new DisputeModule(getAccessController(), address(ipAssetRegistry), getGovernance());
            console2.log("DeployHelper: Using REAL DisputeModule");
            postDeployConditions.disputeModule_configure = true;
        }
        if (d.licensingModule) {
            require(address(ipAccountRegistry) != address(0), "DeployHelper Module: IPAccountRegistry required");
            licensingModule = new LicensingModule(
                getAccessController(),
                address(ipAccountRegistry),
                getRoyaltyModule(),
                getLicenseRegistry(),
                getDisputeModule()
            );
            console2.log("DeployHelper: Using REAL LicensingModule");
        }
    }

    function _deployPolicyConditionally(DeployPolicyCondition memory d) public {
        if (d.arbitrationPolicySP) {
            arbitrationPolicySP = new ArbitrationPolicySP(
                getDisputeModule(),
                address(erc20),
                ARBITRATION_PRICE,
                getGovernance()
            );
            console2.log("DeployHelper: Using REAL ArbitrationPolicySP");
        } else {
            mockArbitrationPolicy = new MockArbitrationPolicy(getDisputeModule(), address(erc20), ARBITRATION_PRICE);
            console2.log("DeployHelper: Using Mock ArbitrationPolicySP");
        }
        if (d.royaltyPolicyLAP) {
            royaltyPolicyLAP = new RoyaltyPolicyLAP(
                getRoyaltyModule(),
                getLicensingModule(),
                LIQUID_SPLIT_FACTORY,
                LIQUID_SPLIT_MAIN,
                getGovernance()
            );
            console2.log("DeployHelper: Using REAL RoyaltyPolicyLAP");

            ancestorsVaultImpl = new AncestorsVaultLAP(address(royaltyPolicyLAP));
            console2.log("DeployHelper: Using REAL AncestorsVaultLAP");
        } else {
            // mockRoyaltyPolicyLAP = new MockRoyaltyPolicyLAP(getRoyaltyModule());
            // console2.log("DeployHelper: Using Mock RoyaltyPolicyLAP");
        }
    }

    function _deployMiscConditionally(DeployMiscCondition memory d) public {
        // Skip IPResolver here, called in `_deployIPResolverConditionally`
        if (d.ipAssetRenderer) {
            require(address(ipAssetRegistry) != address(0), "DeployHelper Misc: IPAssetRegistry required");
            ipAssetRenderer = new IPAssetRenderer(address(ipAssetRegistry), getLicenseRegistry(), getRoyaltyModule());
            console2.log("DeployHelper: Using REAL IPAssetRenderer");
        }
        if (d.ipMetadataProvider) {
            ipMetadataProvider = new IPMetadataProvider(getModuleRegistry());
            console2.log("DeployHelper: Using REAL IPMetadataProvider");
        }
    }

    /// @dev Get or deploy mock Access Controller.
    function getAccessController() public returns (address) {
        if (address(accessController) == address(0)) {
            accessController = new MockAccessController();
            // solhint-disable-next-line no-console
            console2.log("DeployHelper: Using Mock AccessController");
        }
        if (!postDeployConditions.accessController_init) {
            postDeployConditions.accessController_init = true;
        }
        return address(accessController);
    }

    /// @dev Get or deploy mock Dispute Module.
    function getDisputeModule() public returns (address) {
        if (address(disputeModule) == address(0)) {
            disputeModule = new MockDisputeModule();
            // solhint-disable-next-line no-console
            console2.log("DeployHelper: Using Mock DisputeModule");
        }
        if (!postDeployConditions.disputeModule_configure) {
            postDeployConditions.disputeModule_configure = true;
        }
        return address(disputeModule);
    }

    /// @dev Get or deploy mock Governance.
    function getGovernance() public returns (address) {
        if (address(governance) == address(0)) {
            governance = new MockGovernance(governanceAdmin);
            // solhint-disable-next-line no-console
            console2.log("DeployHelper: Using Mock Governance");
        }
        return address(governance);
    }

    /// @dev Get or deploy mock Licensing Module.
    function getLicensingModule() public returns (address) {
        if (address(licensingModule) == address(0)) {
            licensingModule = new MockLicensingModule(getRoyaltyModule(), getLicenseRegistry());
            // solhint-disable-next-line no-console
            console2.log("DeployHelper: Using Mock LicensingModule");
        }
        return address(licensingModule);
    }

    /// @dev Get or deploy mock License Registry.
    function getLicenseRegistry() public returns (address) {
        if (address(licenseRegistry) == address(0)) {
            licenseRegistry = new MockLicenseRegistry();
            // solhint-disable-next-line no-console
            console2.log("DeployHelper: Using Mock LicenseRegistry");
        }
        return address(licenseRegistry);
    }

    /// @dev Get or deploy mock Module Registry.
    function getModuleRegistry() public returns (address) {
        if (address(moduleRegistry) == address(0)) {
            moduleRegistry = new MockModuleRegistry();
            // solhint-disable-next-line no-console
            console2.log("DeployHelper: Using Mock ModuleRegistry");
        }
        if (!postDeployConditions.moduleRegistry_registerModules) {
            postDeployConditions.moduleRegistry_registerModules = true;
        }
        return address(moduleRegistry);
    }

    /// @dev Get or deploy mock Royalty Module.
    function getRoyaltyModule() public returns (address) {
        if (address(royaltyModule) == address(0)) {
            royaltyModule = new MockRoyaltyModule();
            // solhint-disable-next-line no-console
            console2.log("DeployHelper: Using Mock RoyaltyModule");
        }
        if (!postDeployConditions.royaltyModule_configure) {
            postDeployConditions.royaltyModule_configure = true;
        }
        return address(royaltyModule);
    }
}
