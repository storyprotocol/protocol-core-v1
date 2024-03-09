/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { console2 } from "forge-std/console2.sol"; // console to indicate mock deployment calls.
import { Test } from "forge-std/Test.sol";

// contracts
import { AccessController } from "../../../contracts/AccessController.sol";
// solhint-disable-next-line max-line-length
import { IP_RESOLVER_MODULE_KEY, DISPUTE_MODULE_KEY, ROYALTY_MODULE_KEY, LICENSING_MODULE_KEY } from "../../../contracts/lib/modules/Module.sol";
import { AccessPermission } from "../../../contracts/lib/AccessPermission.sol";
import { LicenseRegistry } from "../../../contracts/registries/LicenseRegistry.sol";
import { RoyaltyModule } from "../../../contracts/modules/royalty/RoyaltyModule.sol";

// test
import { DeployHelper } from "./DeployHelper.t.sol";
import { LicensingHelper } from "./LicensingHelper.t.sol";
import { MockERC20 } from "../mocks/token/MockERC20.sol";
import { MockERC721 } from "../mocks/token/MockERC721.sol";
import { Users, UsersLib } from "./Users.t.sol";

/// @title Base Test Contract
/// @notice This contract provides a set of protocol-related testing utilities
///         that may be extended by testing contracts.
contract BaseTest is Test, DeployHelper, LicensingHelper {
    /// @dev Users struct to abstract away user management when testing
    Users internal u;

    /// @dev Aliases for users
    address internal admin;
    address internal alice;
    address internal bob;
    address internal carl;
    address internal dan;

    /// @dev Aliases for mock assets.
    /// NOTE: Must call `postDeploymentSetup` after `deployConditionally` to set these.
    MockERC20 internal mockToken; // alias for erc20
    MockERC20 internal USDC; // alias for mockToken/erc20
    MockERC20 internal LINK; // alias for erc20bb
    MockERC721 internal mockNFT; // alias for erc721.ape

    /// @notice Sets up the base test contract.
    function setUp() public virtual {
        u = UsersLib.createMockUsers(vm);
        setGovernanceAdmin(u.admin);

        admin = u.admin;
        alice = u.alice;
        bob = u.bob;
        carl = u.carl;
        dan = u.dan;

        vm.label(LIQUID_SPLIT_FACTORY, "LIQUID_SPLIT_FACTORY");
        vm.label(LIQUID_SPLIT_MAIN, "LIQUID_SPLIT_MAIN");
    }

    function postDeploymentSetup() public {
        if (postDeployConditions.accessController_init) initAccessController();
        if (postDeployConditions.moduleRegistry_registerModules) registerModules();
        if (postDeployConditions.royaltyModule_configure) configureRoyaltyModule();
        if (postDeployConditions.disputeModule_configure) configureDisputeModule();
        if (deployConditions.registry.licenseRegistry) configureLicenseRegistry();
        if (deployConditions.policy.royaltyPolicyLAP) configureRoyaltyPolicyLAP();

        bool isMockRoyaltyPolicyLAP = address(royaltyPolicyLAP) == address(0) &&
            address(mockRoyaltyPolicyLAP) != address(0);

        // Initialize licensing helper
        // TODO: conditionally init and use LicensingHelper.
        initLicensingHelper(
            getAccessController(),
            address(ipAccountRegistry),
            getLicensingModule(),
            getRoyaltyModule(),
            isMockRoyaltyPolicyLAP ? address(mockRoyaltyPolicyLAP) : address(royaltyPolicyLAP),
            address(erc20)
        );

        // Set aliases
        mockToken = erc20;
        USDC = erc20;
        LINK = erc20bb;
        mockNFT = erc721.ape;
    }

    function dealMockAssets() public {
        erc20.mint(u.alice, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.bob, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.carl, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.dan, 1000 * 10 ** erc20.decimals());

        erc20bb.mint(u.alice, 1000 * 10 ** erc20bb.decimals());
        erc20bb.mint(u.bob, 1000 * 10 ** erc20bb.decimals());
        erc20bb.mint(u.carl, 1000 * 10 ** erc20bb.decimals());
        erc20bb.mint(u.dan, 1000 * 10 ** erc20bb.decimals());
    }

    /// @dev Initialize the access controller to abstract away access controller initialization when testing
    function initAccessController() public {
        console2.log("BaseTest PostDeploymentSetup: Init Access Controller");
        require(address(ipAccountRegistry) != address(0), "ipAccountRegistry not set");
        vm.startPrank(u.admin);

        // NOTE: accessController is IAccessController, which doesn't expose `initialize` function.
        AccessController(address(accessController)).initialize(address(ipAccountRegistry), getModuleRegistry());

        accessController.setGlobalPermission(
            address(ipAssetRegistry),
            address(licensingModule),
            bytes4(licensingModule.linkIpToParents.selector),
            AccessPermission.ALLOW
        );

        // If REAL IPAssetRegistry and LicensingModule are deployed, set global permissions
        // (NOTE: for now, IPAssetRegistry is always deployed with real contract)
        if (deployConditions.module.licensingModule) {
            accessController.setGlobalPermission(
                address(ipAssetRegistry),
                address(licensingModule),
                bytes4(licensingModule.linkIpToParents.selector),
                AccessPermission.ALLOW
            );

            accessController.setGlobalPermission(
                address(ipAssetRegistry),
                address(licensingModule),
                bytes4(licensingModule.addPolicyToIp.selector),
                AccessPermission.ALLOW
            );
        }

        vm.stopPrank();
    }

    /// @dev Register modules to abstract away module registration when testing
    function registerModules() public {
        console2.log("BaseTest PostDeploymentSetup: Register Modules");
        vm.startPrank(u.admin);
        // TODO: option to register "hookmodule", which will trigger the call below:
        //       moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, type(IHookModule).interfaceId);
        if (address(ipResolver) != address(0)) {
            moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
        }
        if (address(disputeModule) != address(0)) {
            moduleRegistry.registerModule(DISPUTE_MODULE_KEY, address(disputeModule));
        }
        if (address(licensingModule) != address(0)) {
            moduleRegistry.registerModule(LICENSING_MODULE_KEY, address(licensingModule));
        }
        if (address(royaltyModule) != address(0)) {
            moduleRegistry.registerModule(ROYALTY_MODULE_KEY, address(royaltyModule));
        }
        vm.stopPrank();
    }

    /// @dev Pre-set configs to abstract away configs when testing with royalty module
    function configureRoyaltyModule() public {
        console2.log("BaseTest PostDeploymentSetup: Configure Royalty Module");
        require(address(royaltyModule) != address(0), "royaltyModule not set");

        vm.startPrank(u.admin);
        RoyaltyModule(address(royaltyModule)).setLicensingModule(getLicensingModule());
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);
        if (address(royaltyPolicyLAP) != address(0)) {
            royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        }
        vm.stopPrank();
    }

    /// @dev Pre-set configs to abstract away configs when testing with dispute module
    function configureDisputeModule() public {
        console2.log("BaseTest PostDeploymentSetup: Configure Dispute Module");
        require(address(disputeModule) != address(0), "disputeModule not set");

        vm.startPrank(u.admin);
        disputeModule.whitelistDisputeTag("PLAGIARISM", true);
        if (address(arbitrationPolicySP) != address(0)) {
            disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);
            disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), u.admin, true);
            disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP));
        }
        vm.stopPrank();
    }

    function configureLicenseRegistry() public {
        console2.log("BaseTest PostDeploymentSetup: Configure License Registry");
        require(address(licenseRegistry) != address(0), "licenseRegistry not set");

        vm.startPrank(u.admin);
        // Need to cast to LicenseRegistry to set dispute and licensing module, as interface doesn't expose those fns.
        LicenseRegistry(address(licenseRegistry)).setDisputeModule(getDisputeModule());
        LicenseRegistry(address(licenseRegistry)).setLicensingModule(getLicensingModule());
        vm.stopPrank();
    }

    function configureRoyaltyPolicyLAP() public {
        console2.log("BaseTest PostDeploymentSetup: Configure Royalty Policy LAP");
        require(address(royaltyPolicyLAP) != address(0), "royaltyPolicyLAP not set");

        vm.startPrank(u.admin);
        royaltyPolicyLAP.setAncestorsVaultImplementation(address(ancestorsVaultImpl));
        vm.stopPrank();
    }

    function _getIpId(MockERC721 mnft, uint256 tokenId) internal view returns (address ipId) {
        return _getIpId(address(mnft), tokenId);
    }

    function _getIpId(address mnft, uint256 tokenId) internal view returns (address ipId) {
        return ipAccountRegistry.ipAccount(block.chainid, mnft, tokenId);
    }
}
