// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { MockModule } from "../../mocks/module/MockModule.sol";
import { MockCoreMetadataViewModule } from "../../mocks/module/MockCoreMetadataViewModule.sol";
import { MockAllMetadataViewModule } from "../../mocks/module/MockAllMetadataViewModule.sol";
import { MockMetadataModule } from "../../mocks/module/MockMetadataModule.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract MetadataModuleTest is BaseTest {
    MockModule public module;
    MockAllMetadataViewModule public allMetadataViewModule;
    MockMetadataModule public metadataModule;

    function setUp() public override {
        super.setUp();

        metadataModule = new MockMetadataModule(address(accessController), address(ipAssetRegistry));
        module = new MockModule(address(ipAssetRegistry), address(moduleRegistry), "MockModule");

        vm.etch(
            address(coreMetadataViewModule),
            address(new MockCoreMetadataViewModule(address(ipAssetRegistry))).code
        );
        allMetadataViewModule = new MockAllMetadataViewModule(address(ipAssetRegistry), address(metadataModule));

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule", address(module));
        moduleRegistry.registerModule("MockMetadataModule", address(metadataModule));
        vm.stopPrank();
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

        assertEq(allMetadataViewModule.description(ipAccount), "This is a mock ERC721 token");
        assertEq(allMetadataViewModule.ipType(ipAccount), "STORY");
    }

    function test_Metadata_UnsupportedViewModule() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId);

        assertFalse(coreMetadataViewModule.isSupported(ipAccount));
        assertFalse(allMetadataViewModule.isSupported(ipAccount));
    }
}
