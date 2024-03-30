/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
// TODO: fix the install of this plugin for safer deployments
// import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { TestProxyHelper } from "test/foundry/utils/TestProxyHelper.sol";

// contracts
import { AccessController } from "contracts/access/AccessController.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IRoyaltyPolicyLAP } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { PILFlavors } from "contracts/lib/PILFlavors.sol";
// solhint-disable-next-line max-line-length
import { DISPUTE_MODULE_KEY, ROYALTY_MODULE_KEY, LICENSING_MODULE_KEY, TOKEN_WITHDRAWAL_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty/RoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { DisputeModule } from "contracts/modules/dispute/DisputeModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute/policies/ArbitrationPolicySP.sol";
import { TokenWithdrawalModule } from "contracts/modules/external/TokenWithdrawalModule.sol";
// solhint-disable-next-line max-line-length
import { PILPolicyFrameworkManager, PILPolicy, RegisterPILPolicyParams } from "contracts/modules/licensing/PILPolicyFrameworkManager.sol";
import { MODULE_TYPE_HOOK } from "contracts/lib/modules/Module.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IHookModule } from "contracts/interfaces/modules/base/IHookModule.sol";

// script
import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "../../../script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../../../script/foundry/utils/JsonDeploymentHandler.s.sol";
import { StorageLayoutChecker } from "../../../script/foundry/utils/upgrades/StorageLayoutCheck.s.sol";

// test
import { MockERC20 } from "test/foundry/mocks/token/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { MockTokenGatedHook } from "test/foundry/mocks/MockTokenGatedHook.sol";

contract Main is Script, BroadcastManager, JsonDeploymentHandler, StorageLayoutChecker {
    using StringUtil for uint256;
    using stdJson for string;

    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    IPAccountImpl internal ipAccountImpl;

    // Registry
    IPAccountRegistry internal ipAccountRegistry;
    IPAssetRegistry internal ipAssetRegistry;
    LicenseRegistry internal licenseRegistry;
    ModuleRegistry internal moduleRegistry;

    // Core Module
    LicensingModule internal licensingModule;
    DisputeModule internal disputeModule;
    RoyaltyModule internal royaltyModule;

    // External Module
    TokenWithdrawalModule internal tokenWithdrawalModule;

    // Policy
    ArbitrationPolicySP internal arbitrationPolicySP;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    PILPolicyFrameworkManager internal pilPfm;

    // Misc.
    Governance internal governance;
    AccessController internal accessController;

    // Mocks
    MockERC20 internal erc20;
    MockERC721 internal erc721;

    // Hooks
    MockTokenGatedHook internal mockTokenGatedHook;

    mapping(uint256 tokenId => address ipAccountAddress) internal ipAcct;

    mapping(string policyName => uint256 policyId) internal policyIds;

    mapping(string frameworkName => address frameworkAddr) internal frameworkAddrs;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 MockToken
    uint256 internal constant MAX_ROYALTY_APPROVAL = 10000 ether;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public virtual override {
        // This will run OZ storage layout check for all contracts. Requires --ffi flag.
        super.run();
        _beginBroadcast(); // BroadcastManager.s.sol

        bool configByMultisig;
        try vm.envBool("DEPLOYMENT_CONFIG_BY_MULTISIG") returns (bool mult) {
            configByMultisig = mult;
        } catch {
            configByMultisig = false;
        }
        console2.log("configByMultisig:", configByMultisig);

        if (configByMultisig) {
            _deployProtocolContracts(multisig);
        } else {
            _deployProtocolContracts(deployer);
            _configureDeployment();
        }

        _writeDeployment(); // write deployment json to deployments/deployment-{chainId}.json
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _deployProtocolContracts(address accessControlDeployer) private {
        string memory contractKey;

        // Mock Assets (deploy first)

        contractKey = "MockERC20";
        _predeploy(contractKey);
        erc20 = new MockERC20();
        _postdeploy(contractKey, address(erc20));

        contractKey = "MockERC721";
        _predeploy(contractKey);
        erc721 = new MockERC721("MockERC721");
        _postdeploy(contractKey, address(erc721));

        // Core Protocol Contracts

        contractKey = "Governance";
        _predeploy(contractKey);
        governance = new Governance(accessControlDeployer);
        _postdeploy(contractKey, address(governance));

        contractKey = "AccessController";
        _predeploy(contractKey);

        address impl = address(new AccessController());
        accessController = AccessController(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(AccessController.initialize, address(governance)))
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(accessController));

        contractKey = "IPAccountImpl";
        _predeploy(contractKey);
        ipAccountImpl = new IPAccountImpl(address(accessController));
        _postdeploy(contractKey, address(ipAccountImpl));

        contractKey = "ModuleRegistry";
        _predeploy(contractKey);
        impl = address(new ModuleRegistry());
        moduleRegistry = ModuleRegistry(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(ModuleRegistry.initialize, address(governance)))
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(moduleRegistry));

        contractKey = "IPAccountRegistry";
        _predeploy(contractKey);
        ipAccountRegistry = new IPAccountRegistry(ERC6551_REGISTRY, address(ipAccountImpl));
        _postdeploy(contractKey, address(ipAccountRegistry));

        contractKey = "IPAssetRegistry";
        _predeploy(contractKey);
        ipAssetRegistry = new IPAssetRegistry(
            ERC6551_REGISTRY,
            address(ipAccountImpl),
            address(governance)
        );
        _postdeploy(contractKey, address(ipAssetRegistry));

        contractKey = "RoyaltyModule";
        _predeploy(contractKey);
        impl = address(new RoyaltyModule());
        royaltyModule = RoyaltyModule(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(RoyaltyModule.initialize, (address(governance))))
        );
        impl = address(0);
        _postdeploy(contractKey, address(royaltyModule));

        contractKey = "DisputeModule";
        _predeploy(contractKey);
        impl = address(new DisputeModule(address(accessController), address(ipAssetRegistry)));
        disputeModule = DisputeModule(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(DisputeModule.initialize, (address(governance))))
        );
        impl = address(0);
        _postdeploy(contractKey, address(disputeModule));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        impl = address(new LicenseRegistry());
        licenseRegistry = LicenseRegistry(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(
                    LicenseRegistry.initialize,
                    (
                        address(governance),
                        "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"
                    )
                )
            )
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "LicensingModule";
        _predeploy(contractKey);

        impl = address(
            new LicensingModule(
                address(accessController),
                address(ipAccountRegistry),
                address(royaltyModule),
                address(licenseRegistry),
                address(disputeModule)
            )
        );
        licensingModule = LicensingModule(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(LicensingModule.initialize, address(governance)))
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy(contractKey, address(licensingModule));

        contractKey = "TokenWithdrawalModule";
        _predeploy(contractKey);
        tokenWithdrawalModule = new TokenWithdrawalModule(address(accessController), address(ipAccountRegistry));
        _postdeploy(contractKey, address(tokenWithdrawalModule));

        //
        // Story-specific Contracts
        //

        contractKey = "ArbitrationPolicySP";
        _predeploy(contractKey);
        impl = address(new ArbitrationPolicySP(address(disputeModule), address(erc20), ARBITRATION_PRICE));
        arbitrationPolicySP = ArbitrationPolicySP(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(ArbitrationPolicySP.initialize, (address(governance))))
        );
        impl = address(0);
        _postdeploy(contractKey, address(arbitrationPolicySP));

        contractKey = "RoyaltyPolicyLAP";
        _predeploy(contractKey);
        impl = address(new RoyaltyPolicyLAP(address(royaltyModule), address(licensingModule)));

        royaltyPolicyLAP = RoyaltyPolicyLAP(
            TestProxyHelper.deployUUPSProxy(impl, abi.encodeCall(RoyaltyPolicyLAP.initialize, (address(governance))))
        );
        impl = address(0);
        _postdeploy(contractKey, address(royaltyPolicyLAP));

        _predeploy("PILPolicyFrameworkManager");
        impl = address(
            new PILPolicyFrameworkManager(
                address(accessController),
                address(ipAccountRegistry),
                address(licensingModule)
            )
        );
        pilPfm = PILPolicyFrameworkManager(
            TestProxyHelper.deployUUPSProxy(
                impl,
                abi.encodeCall(
                    PILPolicyFrameworkManager.initialize,
                    ("pil", "https://github.com/storyprotocol/protocol-core/blob/main/PIL-Beta-2024-02.pdf")
                )
            )
        );
        impl = address(0); // Make sure we don't deploy wrong impl
        _postdeploy("PILPolicyFrameworkManager", address(pilPfm));

        //
        // Mock Hooks
        //

        contractKey = "MockTokenGatedHook";
        _predeploy(contractKey);
        mockTokenGatedHook = new MockTokenGatedHook();
        _postdeploy(contractKey, address(mockTokenGatedHook));
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }

    function _configureDeployment() private {
        _configureMisc();
        _configureAccessController();
        _configureModuleRegistry();
        _configureRoyaltyRelated();
        _configureDisputeModule();
        _executeInteractions();
    }

    function _configureMisc() private {
        licenseRegistry.setDisputeModule(address(disputeModule));
        licenseRegistry.setLicensingModule(address(licensingModule));
    }

    function _configureAccessController() private {
        accessController.setAddresses(address(ipAccountRegistry), address(moduleRegistry));

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

    function _configureModuleRegistry() private {
        moduleRegistry.registerModule(DISPUTE_MODULE_KEY, address(disputeModule));
        moduleRegistry.registerModule(LICENSING_MODULE_KEY, address(licensingModule));
        moduleRegistry.registerModule(ROYALTY_MODULE_KEY, address(royaltyModule));
        moduleRegistry.registerModule(TOKEN_WITHDRAWAL_MODULE_KEY, address(tokenWithdrawalModule));
    }

    function _configureRoyaltyRelated() private {
        royaltyModule.setLicensingModule(address(licensingModule));
        // whitelist
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);
        // policy
        royaltyPolicyLAP.setSnapshotInterval(7 days);
    }

    function _configureDisputeModule() private {
        // whitelist
        disputeModule.whitelistDisputeTag("PLAGIARISM", true);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);
        address arbitrationRelayer = deployer;
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), arbitrationRelayer, true);

        disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP));
    }

    function _executeInteractions() private {
        for (uint256 i = 1; i <= 5; i++) {
            erc721.mintId(deployer, i);
        }
        erc721.mintId(deployer, 100);
        erc721.mintId(deployer, 101);
        erc721.mintId(deployer, 102);
        erc721.mintId(deployer, 103);
        erc721.mintId(deployer, 104);
        erc721.mintId(deployer, 105);
        erc20.mint(deployer, 100_000_000 ether);

        erc20.approve(address(arbitrationPolicySP), 1000 * ARBITRATION_PRICE); // 1000 * raising disputes
        // For license/royalty payment, on both minting license and royalty distribution
        erc20.approve(address(royaltyPolicyLAP), MAX_ROYALTY_APPROVAL);

        licensingModule.registerPolicyFrameworkManager(address(pilPfm));
        frameworkAddrs["pil"] = address(pilPfm);

        accessController.setGlobalPermission(
            address(ipAssetRegistry),
            address(licensingModule),
            bytes4(0x9f69e70d),
            AccessPermission.ALLOW
        );

        accessController.setGlobalPermission(
            address(ipAssetRegistry),
            address(licenseRegistry),
            bytes4(0), // wildcard
            AccessPermission.ALLOW
        );

        accessController.setGlobalPermission(
            address(ipAssetRegistry),
            address(licenseRegistry),
            bytes4(0), // wildcard
            AccessPermission.ALLOW
        );

        /*///////////////////////////////////////////////////////////////
                                CREATE POLICIES
        ///////////////////////////////////////////////////////////////*/

        // Policy ID 1
        policyIds["social_remixing"] = pilPfm.registerPolicy(PILFlavors.nonCommercialSocialRemixing());

        // Policy ID 2
        policyIds["pil_com_deriv_expensive"] = pilPfm.registerPolicy(
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(royaltyPolicyLAP),
                mintingFee: 1 ether,
                mintingFeeToken: address(erc20),
                policy: PILPolicy({
                    attribution: true,
                    commercialUse: true,
                    commercialAttribution: true,
                    commercializerChecker: address(mockTokenGatedHook),
                    commercializerCheckerData: abi.encode(address(erc721)), // use `erc721` as gated token
                    commercialRevShare: 100,
                    derivativesAllowed: true,
                    derivativesAttribution: false,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            })
        );

        // Policy ID 3
        policyIds["pil_noncom_deriv_reciprocal"] = pilPfm.registerPolicy(
            RegisterPILPolicyParams({
                transferable: false,
                royaltyPolicy: address(0), // no royalty, non-commercial
                mintingFee: 0, // no minting fee, non-commercial
                mintingFeeToken: address(0), // no minting fee token, non-commercial
                policy: PILPolicy({
                    attribution: true,
                    commercialUse: false,
                    commercialAttribution: false,
                    commercializerChecker: address(0),
                    commercializerCheckerData: "",
                    commercialRevShare: 0,
                    derivativesAllowed: true,
                    derivativesAttribution: true,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            })
        );

        /*///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        // IPAccount1 (tokenId 1) with no initial policy
        vm.label(getIpId(erc721, 1), "IPAccount1");
        ipAcct[1] = ipAssetRegistry.register(address(erc721), 1);
        disputeModule.setArbitrationPolicy(ipAcct[1], address(arbitrationPolicySP));

        // IPAccount2 (tokenId 2) and attach policy "pil_noncom_deriv_reciprocal"
        vm.label(getIpId(erc721, 2), "IPAccount2");
        ipAcct[2] = ipAssetRegistry.register(address(erc721), 2);
        licensingModule.addPolicyToIp(ipAcct[2], policyIds["pil_noncom_deriv_reciprocal"]);

        // wildcard allow
        IIPAccount(payable(ipAcct[1])).execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                ipAcct[1],
                deployer,
                address(licenseRegistry),
                bytes4(0),
                AccessPermission.ALLOW
            )
        );

        /*///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IPACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        // Add "pil_com_deriv_expensive" policy to IPAccount1
        licensingModule.addPolicyToIp(ipAcct[1], policyIds["pil_com_deriv_expensive"]);

        /*///////////////////////////////////////////////////////////////
                    LINK IPACCOUNTS TO PARENTS USING LICENSES
        ///////////////////////////////////////////////////////////////*/

        // Mint 2 license of policy "pil_com_deriv_expensive" on IPAccount1
        // Register derivative IP for NFT tokenId 3
        {
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_expensive"],
                ipAcct[1],
                2,
                deployer,
                ""
            );

            ipAcct[3] = getIpId(erc721, 3);
            vm.label(ipAcct[3], "IPAccount3");

            address ipId = ipAssetRegistry.register(address(erc721), 3);
            licensingModule.linkIpToParents(licenseIds, ipId, "");
        }

        // Mint 1 license of policy "pil_noncom_deriv_reciprocal" on IPAccount2
        // Register derivative IP for NFT tokenId 4
        {
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = licensingModule.mintLicense(
                policyIds["pil_noncom_deriv_reciprocal"],
                ipAcct[2],
                1,
                deployer,
                ""
            );

            ipAcct[4] = getIpId(erc721, 4);
            vm.label(ipAcct[4], "IPAccount4");

            ipAcct[4] = ipAssetRegistry.register(address(erc721), 4);

            licensingModule.linkIpToParents(licenseIds, ipAcct[4], "");
        }

        // Multi-parent
        {
            ipAcct[5] = getIpId(erc721, 5);
            vm.label(ipAcct[5], "IPAccount5");

            uint256[] memory licenseIds = new uint256[](2);
            licenseIds[0] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_expensive"],
                ipAcct[1],
                1,
                deployer,
                ""
            );

            licenseIds[1] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_expensive"],
                ipAcct[3], // is child of ipAcct[1]
                1,
                deployer,
                ""
            );

            address ipId = ipAssetRegistry.register(address(erc721), 5);
            licensingModule.linkIpToParents(licenseIds, ipId, "");
        }

        /*///////////////////////////////////////////////////////////////
                            DISPUTE MODULE INTERACTIONS
        ///////////////////////////////////////////////////////////////*/

        // Say, IPAccount4 is accused of plagiarism by IPAccount2
        // Then, a judge (deployer in this example) settles as true.
        // Then, the dispute is resolved.
        {
            uint256 disptueId = disputeModule.raiseDispute(
                ipAcct[4],
                string("evidence-url.com"), // TODO: https://dispute-evidence-url.com => string too long
                "PLAGIARISM",
                ""
            );

            disputeModule.setDisputeJudgement(disptueId, true, "");

            disputeModule.resolveDispute(disptueId);
        }

        // Say, IPAccount3 is accused of plagiarism by IPAccount1
        // But, IPAccount1 later cancels the dispute
        {
            uint256 disputeId = disputeModule.raiseDispute(ipAcct[3], string("https://example.com"), "PLAGIARISM", "");

            disputeModule.cancelDispute(disputeId, bytes("Settled amicably"));
        }
    }

    function getIpId(MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        return ipAssetRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }
}
