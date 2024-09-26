/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { Test } from "forge-std/Test.sol";
import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { Create3Deployer } from "@create3-deployer/contracts/Create3Deployer.sol";

// contract
import { IPAccountRegistry } from "../../../contracts/registries/IPAccountRegistry.sol";

// test
import { DeployHelper } from "../../../script/foundry/utils/DeployHelper.sol";
import { LicensingHelper } from "./LicensingHelper.t.sol";
import { MockERC20 } from "../mocks/token/MockERC20.sol";
import { MockERC721 } from "../mocks/token/MockERC721.sol";
import { MockRoyaltyPolicyLAP } from "../mocks/policy/MockRoyaltyPolicyLAP.sol";
import { Users, UsersLib } from "./Users.t.sol";
import { LicenseRegistryHarness } from "../mocks/module/LicenseRegistryHarness.sol";
import { MockIPGraph } from "../mocks/MockIPGraph.sol";
import { MockArbitrationPolicy } from "../mocks/dispute/MockArbitrationPolicy.sol";

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

    ERC6551Registry internal ERC6551_REGISTRY = new ERC6551Registry();
    Create3Deployer internal CREATE3_DEPLOYER = new Create3Deployer();
    uint256 internal CREATE3_DEFAULT_SEED = 0;
    IPAccountRegistry internal ipAccountRegistry;

    MockERC20 internal erc20 = new MockERC20();
    MockERC20 internal erc20bb = new MockERC20();

    /// @dev Aliases for mock assets.
    MockERC20 internal mockToken; // alias for erc20
    MockERC20 internal USDC; // alias for mockToken/erc20
    MockERC20 internal LINK; // alias for erc20bb
    MockERC721 internal mockNFT;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 MockToken (6 decimals)
    uint256 internal constant MAX_ROYALTY_APPROVAL = 10000 ether;
    address internal constant TREASURY_ADDRESS = address(200);

    address internal lrHarnessImpl;
    MockIPGraph ipGraph = MockIPGraph(address(0x1B));
    MockArbitrationPolicy mockArbitrationPolicy;

    constructor()
        DeployHelper(
            address(ERC6551_REGISTRY),
            address(CREATE3_DEPLOYER),
            address(erc20),
            ARBITRATION_PRICE,
            MAX_ROYALTY_APPROVAL,
            TREASURY_ADDRESS,
            address(0)
        )
    {}

    /// @notice Sets up the base test contract.
    function setUp() public virtual {
        vm.etch(address(0x1B), address(new MockIPGraph()).code);

        u = UsersLib.createMockUsers(vm);

        admin = u.admin;
        alice = u.alice;
        bob = u.bob;
        carl = u.carl;
        dan = u.dan;

        // deploy all contracts via DeployHelper
        super.run(
            CREATE3_DEFAULT_SEED,
            false, // runStorageLayoutCheck
            false, // writeDeploys
            "test" // version
        );

        initLicensingHelper(address(pilTemplate), address(royaltyPolicyLAP), address(erc20));

        // Set aliases
        mockToken = erc20;
        USDC = erc20;
        LINK = erc20bb;
        mockNFT = new MockERC721("Ape");

        dealMockAssets();

        ipAccountRegistry = IPAccountRegistry(ipAssetRegistry);
        lrHarnessImpl = address(
            new LicenseRegistryHarness(address(licensingModule), address(disputeModule), address(ipGraphACL))
        );

        mockArbitrationPolicy = new MockArbitrationPolicy(address(disputeModule), address(USDC), ARBITRATION_PRICE);
        vm.startPrank(u.admin);
        disputeModule.whitelistArbitrationPolicy(address(mockArbitrationPolicy), true);
        disputeModule.whitelistArbitrationRelayer(address(mockArbitrationPolicy), address(u.relayer), true);
        disputeModule.setBaseArbitrationPolicy(address(mockArbitrationPolicy));
        mockArbitrationPolicy.setTreasury(TREASURY_ADDRESS);
        vm.stopPrank();
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

    function useMock_RoyaltyPolicyLAP() internal {
        address impl = address(new MockRoyaltyPolicyLAP());
        vm.etch(address(royaltyPolicyLAP), impl.code);
    }

    function _disputeIp(address disputeInitiator, address ipAddrToDispute) internal returns (uint256 disputeId) {
        vm.startPrank(disputeInitiator);
        USDC.approve(address(mockArbitrationPolicy), ARBITRATION_PRICE);
        bytes32 disputeEvidenceHashExample = 0xb7b94ecbd1f9f8cb209909e5785fb2858c9a8c4b220c017995a75346ad1b5db5;
        disputeId = disputeModule.raiseDispute(ipAddrToDispute, disputeEvidenceHashExample, "PLAGIARISM", "");
        vm.stopPrank();

        vm.prank(u.relayer); // admin is a judge
        disputeModule.setDisputeJudgement(disputeId, true, "");
    }
}
