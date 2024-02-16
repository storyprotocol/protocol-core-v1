// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { Test } from "forge-std/Test.sol";

import { IPAccountImpl } from "../../../../contracts/IPAccountImpl.sol";
import { IPAssetRegistry } from "../../../../contracts/registries/IPAssetRegistry.sol";
import { ModuleRegistry } from "../../../../contracts/registries/ModuleRegistry.sol";
import { Governance } from "../../../../contracts/governance/Governance.sol";

import { MockAccessController } from "../../mocks/access/MockAccessController.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { MockModule } from "../../mocks/module/MockModule.sol";
import { MockCoreMetadataViewModule } from "../../mocks/module/MockCoreMetadataViewModule.sol";
import { MockAllMetadataViewModule } from "../../mocks/module/MockAllMetadataViewModule.sol";
import { MockMetadataModule } from "../../mocks/module/MockMetadataModule.sol";

contract MetadataModuleTest is Test {
    IPAssetRegistry public registry;
    IPAccountImpl public implementation;
    MockERC721 public nft = new MockERC721("MockERC721");
    ERC6551Registry public erc6551Registry = new ERC6551Registry();
    MockAccessController public accessController = new MockAccessController();
    ModuleRegistry public moduleRegistry;
    MockModule public module;
    Governance public governance;
    MockCoreMetadataViewModule public coreMetadataViewModule;
    MockAllMetadataViewModule public allMetadataViewModule;
    MockMetadataModule public metadataModule;

    function setUp() public {
        governance = new Governance(address(this));
        moduleRegistry = new ModuleRegistry(address(governance));
        implementation = new IPAccountImpl();
        registry = new IPAssetRegistry(
            address(accessController),
            address(erc6551Registry),
            address(implementation),
            address(moduleRegistry),
            address(governance)
        );
        metadataModule = new MockMetadataModule(address(accessController), address(registry));
        module = new MockModule(address(registry), address(moduleRegistry), "MockModule");
        coreMetadataViewModule = new MockCoreMetadataViewModule(address(registry));
        allMetadataViewModule = new MockAllMetadataViewModule(address(registry), address(metadataModule));
    }

    function test_Metadata_CoreMetadata() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        address ipAccount = registry.register(block.chainid, address(nft), tokenId);

        assertEq(coreMetadataViewModule.getName(ipAccount), "MockERC721 #100");
        assertEq(coreMetadataViewModule.registrationDate(ipAccount), block.timestamp);
        assertEq(coreMetadataViewModule.owner(ipAccount), owner);
        assertEq(coreMetadataViewModule.uri(ipAccount), nft.tokenURI(100));
    }

    function test_Metadata_OptionalMetadata() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        address ipAccount = registry.register(block.chainid, address(nft), tokenId);

        vm.prank(owner);
        metadataModule.setIpDescription(ipAccount, "This is a mock ERC721 token");
        vm.prank(owner);
        metadataModule.setIpType(ipAccount, "STORY");

        assertEq(coreMetadataViewModule.getName(ipAccount), "MockERC721 #100");
        assertEq(coreMetadataViewModule.registrationDate(ipAccount), block.timestamp);
        assertEq(coreMetadataViewModule.owner(ipAccount), owner);
        assertEq(coreMetadataViewModule.uri(ipAccount), nft.tokenURI(100));
        assertEq(allMetadataViewModule.description(ipAccount), "This is a mock ERC721 token");
        assertEq(allMetadataViewModule.ipType(ipAccount), "STORY");
    }

    function test_Metadata_revert_setImmutableOptionalMetadataTwice() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        address ipAccount = registry.register(block.chainid, address(nft), tokenId);

        vm.prank(owner);
        metadataModule.setIpDescription(ipAccount, "This is a mock ERC721 token");
        vm.prank(owner);
        metadataModule.setIpType(ipAccount, "STORY");

        vm.expectRevert("MockMetadataModule: metadata already set");
        vm.prank(owner);
        metadataModule.setIpDescription(ipAccount, "This is a mock ERC721 token");

        vm.expectRevert("MockMetadataModule: metadata already set");
        vm.prank(owner);
        metadataModule.setIpType(ipAccount, "STORY");
    }

    function test_Metadata_ViewAllMetadata() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        address ipAccount = registry.register(block.chainid, address(nft), tokenId);

        vm.prank(owner);
        metadataModule.setIpDescription(ipAccount, "This is a mock ERC721 token");
        vm.prank(owner);
        metadataModule.setIpType(ipAccount, "STORY");

        assertEq(allMetadataViewModule.getName(ipAccount), "MockERC721 #100");
        assertEq(allMetadataViewModule.registrationDate(ipAccount), block.timestamp);
        assertEq(allMetadataViewModule.owner(ipAccount), owner);
        assertEq(allMetadataViewModule.uri(ipAccount), nft.tokenURI(100));
        assertEq(allMetadataViewModule.description(ipAccount), "This is a mock ERC721 token");
        assertEq(allMetadataViewModule.ipType(ipAccount), "STORY");
    }

    function test_Metadata_UnsupportedViewModule() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        address ipAccount = registry.register(block.chainid, address(nft), tokenId);

        assertTrue(coreMetadataViewModule.isSupported(ipAccount));
        assertFalse(allMetadataViewModule.isSupported(ipAccount));
    }
}
