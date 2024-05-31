// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { CoreMetadataViewModule } from "../../../../contracts/modules/metadata/CoreMetadataViewModule.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IPAccountStorageOps } from "../../../../contracts/lib/IPAccountStorageOps.sol";

contract CoreMetadataViewModuleTest is BaseTest {
    using IPAccountStorageOps for IIPAccount;
    using Strings for *;

    IIPAccount private ipAccount;

    function setUp() public override {
        super.setUp();

        mockNFT.mintId(alice, 99);

        ipAccount = IIPAccount(payable(ipAssetRegistry.register(block.chainid, address(mockNFT), 99)));

        vm.label(address(ipAccount), "IPAccount1");
    }

    function test_CoreMetadataViewModule_GetAllMetadata() public {
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32("0x1234"));

        assertEq(coreMetadataViewModule.getMetadataURI(address(ipAccount)), "My MetadataURI");
        assertEq(coreMetadataViewModule.getOwner(address(ipAccount)), alice);
        assertEq(coreMetadataViewModule.getNftTokenURI(address(ipAccount)), "https://storyprotocol.xyz/erc721/99");
        assertEq(coreMetadataViewModule.getNftMetadataHash(address(ipAccount)), bytes32(0));
        assertEq(coreMetadataViewModule.getRegistrationDate(address(ipAccount)), block.timestamp);
        assertEq(coreMetadataViewModule.getMetadataHash(address(ipAccount)), bytes32("0x1234"));
    }

    function test_CoreMetadataViewModule_GetAllMetadata_without_SetAnyCoreMetadata() public {
        assertEq(coreMetadataViewModule.getMetadataURI(address(ipAccount)), "");
        assertEq(coreMetadataViewModule.getOwner(address(ipAccount)), alice);
        assertEq(coreMetadataViewModule.getNftTokenURI(address(ipAccount)), "https://storyprotocol.xyz/erc721/99");
        assertEq(coreMetadataViewModule.getNftMetadataHash(address(ipAccount)), bytes32(0));
        assertEq(coreMetadataViewModule.getRegistrationDate(address(ipAccount)), block.timestamp);
        assertEq(coreMetadataViewModule.getMetadataHash(address(ipAccount)), bytes32(0));
    }

    function test_CoreMetadataViewModule_JsonString() public {
        vm.prank(alice);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32("0x5678"));
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32("0x1234"));
        assertEq(
            _getExpectedJsonString(mockNFT.tokenURI(99), bytes32("0x5678"), "My MetadataURI", bytes32("0x1234")),
            coreMetadataViewModule.getJsonString(address(ipAccount))
        );
    }

    function test_CoreMetadataViewModule_GetCoreMetadataStrut() public {
        vm.prank(alice);
        coreMetadataModule.setAll(address(ipAccount), "My MetadataURI", bytes32("0x1234"), bytes32("0x5678"));
        CoreMetadataViewModule.CoreMetadata memory coreMetadata = coreMetadataViewModule.getCoreMetadata(
            address(ipAccount)
        );
        assertEq(coreMetadata.metadataURI, "My MetadataURI");
        assertEq(coreMetadata.metadataHash, bytes32("0x1234"));
        assertEq(coreMetadata.registrationDate, block.timestamp);
        assertEq(coreMetadata.owner, alice);
        assertEq(coreMetadata.nftTokenURI, "https://storyprotocol.xyz/erc721/99");
        assertEq(coreMetadata.nftMetadataHash, bytes32("0x5678"));
    }

    function test_CoreMetadataViewModule_GetJsonStr_without_CoreMetadata() public {
        assertEq(
            _getExpectedJsonString(mockNFT.tokenURI(99), bytes32(0), "", bytes32(0)),
            coreMetadataViewModule.getJsonString(address(ipAccount))
        );
    }

    function test_CoreMetadataViewModule_isSupported() public {
        assertTrue(coreMetadataViewModule.isSupported(address(ipAccount)));
    }

    function test_CoreMetadataViewModule_revert_isSupported() public {
        mockNFT.mintId(alice, 999);
        address nonIpAsset = erc6551Registry.createAccount(
            ipAccountRegistry.IP_ACCOUNT_IMPL(),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            address(mockNFT),
            999
        );
        assertFalse(coreMetadataViewModule.isSupported(nonIpAsset));
    }

    function _getExpectedJsonString(
        string memory nftTokenURI,
        bytes32 nftMedataHash,
        string memory metadataURI,
        bytes32 metadataHash
    ) internal view returns (string memory) {
        /* solhint-disable */
        string memory baseJson = string(
            abi.encodePacked('{"name": "IP Asset # ', Strings.toHexString(address(ipAccount)), '", "attributes": [')
        );

        string memory ipAttributes = string(
            abi.encodePacked(
                '{"trait_type": "Owner", "value": "',
                Strings.toHexString(alice),
                '"},'
                '{"trait_type": "MetadataHash", "value": "',
                Strings.toHexString(uint256(metadataHash), 32),
                '"},'
                '{"trait_type": "MetadataURI", "value": "',
                metadataURI,
                '"},'
                '{"trait_type": "NFTMetadataHash", "value": "',
                Strings.toHexString(uint256(nftMedataHash), 32),
                '"},'
                '{"trait_type": "NFTTokenURI", "value": "',
                nftTokenURI,
                '"},'
                '{"trait_type": "Registration Date", "value": "',
                Strings.toString(block.timestamp),
                '"}'
            )
        );
        /* solhint-enable */
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(string(abi.encodePacked(baseJson, ipAttributes, "]}"))))
                )
            );
    }
}
