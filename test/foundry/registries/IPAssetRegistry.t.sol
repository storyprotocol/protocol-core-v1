// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IP } from "contracts/lib/IP.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

/// @title IP Asset Registry Testing Contract
/// @notice Contract for testing core IP registration.
contract IPAssetRegistryTest is BaseTest {
    // Default IP record attributes.
    string public constant IP_NAME = "IPAsset";
    string public constant IP_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant IP_HASH = "0x0f";
    string public constant IP_EXTERNAL_URL = "https://storyprotocol.xyz";

    /// @notice Placeholder for test resolver addresses.
    address public resolver = vm.addr(0x6969);
    address public resolver2 = vm.addr(0x6978);

    IPAssetRegistry public registry;

    address public tokenAddress;
    uint256 public tokenId;
    address public ipId;

    /// @notice Initializes the IP asset registry testing contract.
    function setUp() public virtual override {
        super.setUp();
        buildDeployRegistryCondition(
            DeployRegistryCondition({
                licenseRegistry: false, // don't use
                moduleRegistry: false // use mock
            })
        );
        deployConditionally();
        postDeploymentSetup();

        registry = ipAssetRegistry;

        tokenAddress = address(mockNFT);
        tokenId = mockNFT.mintId(alice, 99);

        assertEq(ipAccountRegistry.getIPAccountImpl(), address(ipAccountImpl));
        ipId = _getIPAccount(tokenId);
    }

    /// @notice Tests retrieval of IP canonical IDs.
    function test_IPAssetRegistry_IpId() public {
        assertEq(registry.ipId(block.chainid, tokenAddress, tokenId), _getIPAccount(tokenId));
    }

    /// @notice Tests operator approvals.
    function test_IPAssetRegistry_SetApprovalForAll() public {
        vm.prank(alice);
        registry.setApprovalForAll(bob, true);
        bytes memory metadata = _generateMetadata();
        vm.prank(bob);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, true, metadata);
    }

    /// @notice Tests registration of IP assets without licenses.
    function test_IPAssetRegistry_Register() public {
        uint256 totalSupply = registry.totalSupply();

        // Ensure unregistered IP preconditions are satisfied.
        assertEq(registry.resolver(ipId), address(0));
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        bytes memory metadata = _generateMetadata();

        // Ensure all expected events are emitted.
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(ipId, resolver);
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            address(registry.metadataProvider()),
            metadata
        );
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, true, metadata);

        /// Ensures IP asset post-registration conditions are met.
        assertEq(registry.resolver(ipId), resolver);
        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(registry.isRegistered(ipId));
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests registration of IP assets with licenses.
    function test_IPAssetRegistry_RegisterWithLicenses() public {
        uint256 totalSupply = registry.totalSupply();

        // Ensure unregistered IP preconditions are satisfied.
        assertEq(registry.resolver(ipId), address(0));
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        bytes memory metadata = _generateMetadata();
        uint256[] memory licenses = new uint256[](2);
        licenses[0] = 1;
        licenses[1] = 2;

        // Ensure all expected events are emitted.
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(ipId, resolver);
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            address(registry.metadataProvider()),
            metadata
        );
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, true, metadata);

        /// Ensures IP asset post-registration conditions are met.
        assertEq(registry.resolver(ipId), resolver);
        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(registry.isRegistered(ipId));
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests registration of IP assets with lazy account creation.
    function test_IPAssetRegistry_RegisterWithoutAccount() public {
        uint256 totalSupply = registry.totalSupply();
        // Ensure unregistered IP preconditions are satisfied.
        assertEq(registry.resolver(ipId), address(0));
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));

        bytes memory metadata = _generateMetadata();
        // Ensure all expected events are emitted.
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(ipId, resolver);
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            address(registry.metadataProvider()),
            metadata
        );
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, metadata);

        /// Ensures IP asset post-registration conditions are met.
        assertEq(registry.resolver(ipId), resolver);
        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests registration of IP assets works with existing IP accounts.
    function test_IPAssetRegistry_RegisterExistingAccount() public {
        registry.registerIpAccount(block.chainid, tokenAddress, tokenId);
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        bytes memory metadata = _generateMetadata();
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, true, metadata);
    }

    /// @notice Tests registration of IP reverts when an IP has already been registered.
    function test_IPAssetRegistry_Register_Reverts_ExistingRegistration() public {
        bytes memory metadata = _generateMetadata();
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, metadata);
        vm.expectRevert(Errors.IPAssetRegistry__AlreadyRegistered.selector);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, metadata);
    }

    /// @notice Tests IP resolver setting works.
    function test_IPAssetRegistry_SetResolver() public {
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, true, _generateMetadata());

        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(ipId, resolver2);
        vm.prank(alice);
        registry.setResolver(ipId, resolver2);
    }

    /// @notice Tests IP resolver setting reverts if an IP is not yet registered.
    function test_IPAssetRegistry_SetResolver_Reverts_NotYetRegistered() public {
        vm.startPrank(alice);
        vm.expectRevert(Errors.IPAssetRegistry__NotYetRegistered.selector);
        registry.setResolver(ipId, resolver);
    }

    /// @notice Helper function for generating an account address.
    function _getIPAccount(uint256 contractId) internal view returns (address) {
        return
            erc6551Registry.account(
                address(ipAccountImpl),
                ipAccountRegistry.IP_ACCOUNT_SALT(),
                block.chainid,
                tokenAddress,
                contractId
            );
    }

    function _generateMetadata() internal view returns (bytes memory) {
        return
            abi.encode(
                IP.MetadataV1({
                    name: IP_NAME,
                    hash: IP_HASH,
                    registrationDate: uint64(block.timestamp),
                    registrant: alice,
                    uri: IP_EXTERNAL_URL
                })
            );
    }
}
