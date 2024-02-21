// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

import { MockModule } from "../../mocks/module/MockModule.sol";
import { MockCoreMetadataViewModule } from "../../mocks/module/MockCoreMetadataViewModule.sol";
import { MockAllMetadataViewModule } from "../../mocks/module/MockAllMetadataViewModule.sol";
import { MockMetadataModule } from "../../mocks/module/MockMetadataModule.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";



contract MetadataModuleTest is BaseTest {

    MockModule public module;
    MockCoreMetadataViewModule public coreMetadataViewModule;
    MockAllMetadataViewModule public allMetadataViewModule;
    MockMetadataModule public metadataModule;

    function setUp() public override {
        super.setUp();
        deployConditionally();
        postDeploymentSetup();

        metadataModule = new MockMetadataModule(address(accessController), address(ipAssetRegistry));
        module = new MockModule(address(ipAssetRegistry), address(moduleRegistry), "MockModule");
        coreMetadataViewModule = new MockCoreMetadataViewModule(address(ipAssetRegistry));
        allMetadataViewModule = new MockAllMetadataViewModule(address(ipAssetRegistry), address(metadataModule));
    }

    function test_Metadata_CoreMetadata() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId);

        assertEq(coreMetadataViewModule.getName(ipAccount), "Ape #100");
        assertEq(coreMetadataViewModule.registrationDate(ipAccount), block.timestamp);
        assertEq(coreMetadataViewModule.owner(ipAccount), owner);
        assertEq(coreMetadataViewModule.uri(ipAccount), mockNFT.tokenURI(100));
    }

    function test_Metadata_OptionalMetadata() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId);

        vm.prank(owner);
        metadataModule.setIpDescription(ipAccount, "This is a mock ERC721 token");
        vm.prank(owner);
        metadataModule.setIpType(ipAccount, "STORY");

        assertEq(coreMetadataViewModule.getName(ipAccount), "Ape #100");
        assertEq(coreMetadataViewModule.registrationDate(ipAccount), block.timestamp);
        assertEq(coreMetadataViewModule.owner(ipAccount), owner);
        assertEq(coreMetadataViewModule.uri(ipAccount), mockNFT.tokenURI(100));
        assertEq(allMetadataViewModule.description(ipAccount), "This is a mock ERC721 token");
        assertEq(allMetadataViewModule.ipType(ipAccount), "STORY");
    }

    function test_Metadata_revert_setImmutableOptionalMetadataTwice() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId);

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

        mockNFT.mintId(owner, tokenId);

        address ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId);

        vm.prank(owner);
        metadataModule.setIpDescription(ipAccount, "This is a mock ERC721 token");
        vm.prank(owner);
        metadataModule.setIpType(ipAccount, "STORY");

        assertEq(allMetadataViewModule.getName(ipAccount), "Ape #100");
        assertEq(allMetadataViewModule.registrationDate(ipAccount), block.timestamp);
        assertEq(allMetadataViewModule.owner(ipAccount), owner);
        assertEq(allMetadataViewModule.uri(ipAccount), mockNFT.tokenURI(100));
        assertEq(allMetadataViewModule.description(ipAccount), "This is a mock ERC721 token");
        assertEq(allMetadataViewModule.ipType(ipAccount), "STORY");
    }

    function test_Metadata_UnsupportedViewModule() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId);

        assertTrue(coreMetadataViewModule.isSupported(ipAccount));
        assertFalse(allMetadataViewModule.isSupported(ipAccount));
    }
}
