// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* solhint-disable quotes */
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { ICoreMetadataModule } from "../../../../contracts/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { IPAccountStorageOps } from "../../../../contracts/lib/IPAccountStorageOps.sol";

contract CoreMetadataModuleTest is BaseTest {
    using IPAccountStorageOps for IIPAccount;

    IIPAccount private ipAccount;

    function setUp() public override {
        super.setUp();

        mockNFT.mintId(alice, 1);

        ipAccount = IIPAccount(payable(ipAssetRegistry.register(block.chainid, address(mockNFT), 1)));

        vm.label(address(ipAccount), "IPAccount1");
    }

    function test_CoreMetadata_NftTokenURI() public {
        vm.expectEmit();
        emit ICoreMetadataModule.NFTTokenURISet(address(ipAccount), mockNFT.tokenURI(1), bytes32(0));

        vm.prank(alice);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32(0));
        assertEq(ipAccount.getString(address(coreMetadataModule), "NFT_TOKEN_URI"), mockNFT.tokenURI(1));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "NFT_METADATA_HASH"), bytes32(0));
    }

    function test_CoreMetadata_NftTokenURI_Two_IPAccounts() public {
        vm.prank(alice);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32("0x1234"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "NFT_TOKEN_URI"), mockNFT.tokenURI(1));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "NFT_METADATA_HASH"), bytes32("0x1234"));

        mockNFT.mintId(alice, 2);
        IIPAccount ipAccount2 = IIPAccount(payable(ipAssetRegistry.register(block.chainid, address(mockNFT), 2)));
        vm.label(address(ipAccount2), "IPAccount2");

        vm.prank(alice);
        coreMetadataModule.updateNftTokenURI(address(ipAccount2), bytes32("0x5678"));
        assertEq(ipAccount2.getString(address(coreMetadataModule), "NFT_TOKEN_URI"), mockNFT.tokenURI(2));
        assertEq(ipAccount2.getBytes32(address(coreMetadataModule), "NFT_METADATA_HASH"), bytes32("0x5678"));
    }

    function test_CoreMetadata_revert_NftTokenURI_Immutable() public {
        assertFalse(coreMetadataModule.isMetadataFrozen(address(ipAccount)));
        vm.prank(alice);
        coreMetadataModule.freezeMetadata(address(ipAccount));
        assertTrue(coreMetadataModule.isMetadataFrozen(address(ipAccount)));
        assertTrue(ipAccount.getBool(address(coreMetadataModule), "IMMUTABLE"));

        vm.prank(alice);
        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadyFrozen.selector);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32(0));
    }

    function test_CoreMetadata_NftTokenURI_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.updateNftTokenURI(address(0x1234), bytes32(0));
    }

    function test_CoreMetadata_NftTokenURI_InvalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                bob,
                address(coreMetadataModule),
                coreMetadataModule.updateNftTokenURI.selector
            )
        );
        vm.prank(bob);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32(0));
    }

    function test_CoreMetadata_MetadataURI() public {
        vm.expectEmit();
        emit ICoreMetadataModule.MetadataURISet(address(ipAccount), "My MetadataURI", bytes32("0x1234"));

        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32("0x1234"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x1234"));
    }

    function test_CoreMetadata_MetadataURI_Two_IPAccounts() public {
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32("0x1234"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x1234"));

        mockNFT.mintId(alice, 2);
        IIPAccount ipAccount2 = IIPAccount(payable(ipAssetRegistry.register(block.chainid, address(mockNFT), 2)));
        vm.label(address(ipAccount2), "IPAccount2");

        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount2), "My MetadataURI2", bytes32("0x5678"));
        assertEq(ipAccount2.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI2");
        assertEq(ipAccount2.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x5678"));
    }

    function test_CoreMetadata_revert_MetadataURI_Immutable() public {
        assertFalse(coreMetadataModule.isMetadataFrozen(address(ipAccount)));
        vm.prank(alice);
        coreMetadataModule.freezeMetadata(address(ipAccount));
        assertTrue(coreMetadataModule.isMetadataFrozen(address(ipAccount)));
        assertTrue(ipAccount.getBool(address(coreMetadataModule), "IMMUTABLE"));

        vm.prank(alice);
        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadyFrozen.selector);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32(0));
    }

    function test_CoreMetadata_MetadataURI_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(0x1234), "My MetadataURI", bytes32(0));
    }

    function test_CoreMetadata_MetadataURI_InvalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                bob,
                address(coreMetadataModule),
                coreMetadataModule.setMetadataURI.selector
            )
        );
        vm.prank(bob);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32(0));
    }

    function test_CoreMetadata_Batch() public {
        vm.startPrank(alice);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32("0x1234"));
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32("0x5678"));
        vm.stopPrank();
        assertEq(ipAccount.getString(address(coreMetadataModule), "NFT_TOKEN_URI"), mockNFT.tokenURI(1));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "NFT_METADATA_HASH"), bytes32("0x1234"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x5678"));
    }

    function test_CoreMetadata_All() public {
        vm.prank(alice);
        coreMetadataModule.setAll(address(ipAccount), "My MetadataURI", bytes32("0x1234"), bytes32("0x5678"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "NFT_TOKEN_URI"), mockNFT.tokenURI(1));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "NFT_METADATA_HASH"), bytes32("0x5678"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x1234"));
    }

    function test_CoreMetadata_revert_All_Immutable() public {
        assertFalse(coreMetadataModule.isMetadataFrozen(address(ipAccount)));
        vm.prank(alice);
        coreMetadataModule.freezeMetadata(address(ipAccount));
        assertTrue(coreMetadataModule.isMetadataFrozen(address(ipAccount)));
        assertTrue(ipAccount.getBool(address(coreMetadataModule), "IMMUTABLE"));

        vm.prank(alice);
        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadyFrozen.selector);
        coreMetadataModule.setAll(address(ipAccount), "My New MetadataURI", bytes32("0x5678"), bytes32("0x1234"));
    }

    function test_CoreMetadata_All_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.setAll(address(0x1234), "My MetadataURI", bytes32("0x1234"), bytes32("0x5678"));
    }

    function test_CoreMetadata_All_InvalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                bob,
                address(coreMetadataModule),
                coreMetadataModule.setAll.selector
            )
        );
        vm.prank(bob);
        coreMetadataModule.setAll(address(ipAccount), "My MetadataURI", bytes32("0x1234"), bytes32("0x5678"));
    }

    function test_CoreMetadata_Immutable_Two_IPAccounts() public {
        vm.startPrank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI", bytes32("0x1234"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x1234"));
        coreMetadataModule.setAll(address(ipAccount), "My New MetadataURI", bytes32("0x2222"), bytes32("0x5678"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My New MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x2222"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "NFT_TOKEN_URI"), mockNFT.tokenURI(1));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "NFT_METADATA_HASH"), bytes32("0x5678"));

        vm.expectEmit();
        emit ICoreMetadataModule.MetadataFrozen(address(ipAccount));
        coreMetadataModule.freezeMetadata(address(ipAccount));
        assertTrue(ipAccount.getBool(address(coreMetadataModule), "IMMUTABLE"));

        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadyFrozen.selector);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI2", bytes32("0x5678"));
        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadyFrozen.selector);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32("0x1234"));

        mockNFT.mintId(alice, 2);
        IIPAccount ipAccount2 = IIPAccount(payable(ipAssetRegistry.register(block.chainid, address(mockNFT), 2)));
        vm.label(address(ipAccount2), "IPAccount2");

        coreMetadataModule.setMetadataURI(address(ipAccount2), "My MetadataURI2", bytes32("0x5678"));
        assertEq(ipAccount2.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI2");
        assertEq(ipAccount2.getBytes32(address(coreMetadataModule), "METADATA_HASH"), bytes32("0x5678"));
        assertFalse(ipAccount2.getBool(address(coreMetadataModule), "IMMUTABLE"));
        vm.stopPrank();
    }

    function test_CoreMetadata_Immutable_InvalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                bob,
                address(coreMetadataModule),
                coreMetadataModule.freezeMetadata.selector
            )
        );
        vm.prank(bob);
        coreMetadataModule.freezeMetadata(address(ipAccount));
    }

    function test_CoreMetadata_updateNftTokenURI_ContainsDoubleQuote() public {
        string memory maliciousNftTokenURI = string.concat(
            'malicious-nft-token-uri/"}, ',
            '{"trait_type": "RegistrationDate", ',
            '"value": "malicious-registration-date"}'
        );

        vm.prank(alice);
        mockNFT.setTokenURI(1, maliciousNftTokenURI);
        vm.prank(alice);
        coreMetadataModule.updateNftTokenURI(address(ipAccount), bytes32("0x1234"));
        // Check that the NFT token URI is properly escaped
        string memory storedURI = coreMetadataViewModule.getNftTokenURI(address(ipAccount));

        assertEq(
            storedURI,
            string.concat(
                "https://storyprotocol.xyz/erc721/",
                'malicious-nft-token-uri/\\"}, ',
                '{\\"trait_type\\": \\"RegistrationDate\\", ',
                '\\"value\\": \\"malicious-registration-date\\"}'
            )
        );
    }

    function test_CoreMetadata_setMetadataURI_ContainsDoubleQuote() public {
        string memory maliciousMetadataURI = string.concat(
            'ipfs://malicious-metadata-uri/"}, ',
            '{"trait_type": "NFTMetadataHash", ',
            '"value": "malicious-metadata-hash"}'
        );

        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), maliciousMetadataURI, bytes32(0));
        string memory storedURI = coreMetadataViewModule.getMetadataURI(address(ipAccount));

        assertEq(
            storedURI,
            string.concat(
                'ipfs://malicious-metadata-uri/\\"}, ',
                '{\\"trait_type\\": \\"NFTMetadataHash\\", ',
                '\\"value\\": \\"malicious-metadata-hash\\"}'
            )
        );
    }

    function test_CoreMetadata_setAll_ContainsDoubleQuote() public {
        string memory maliciousMetadataURI = string.concat(
            'ipfs://malicious-metadata-uri/"}, ',
            '{"trait_type": "NFTMetadataHash", ',
            '"value": "malicious-metadata-hash"}'
        );

        string memory maliciousNftTokenURI = string.concat(
            'malicious-nft-token-uri/"}, ',
            '{"trait_type": "RegistrationDate", ',
            '"value": "malicious-registration-date"}'
        );

        // malicious metadata uri, valid nft token uri
        vm.startPrank(alice);
        mockNFT.setTokenURI(1, maliciousNftTokenURI);
        coreMetadataModule.setAll(address(ipAccount), maliciousMetadataURI, bytes32(0), bytes32(0));
        vm.stopPrank();

        string memory storedNftTokenURI = coreMetadataViewModule.getNftTokenURI(address(ipAccount));
        string memory storedMetadataURI = coreMetadataViewModule.getMetadataURI(address(ipAccount));
        assertEq(
            storedNftTokenURI,
            string.concat(
                "https://storyprotocol.xyz/erc721/",
                'malicious-nft-token-uri/\\"}, ',
                '{\\"trait_type\\": \\"RegistrationDate\\", ',
                '\\"value\\": \\"malicious-registration-date\\"}'
            )
        );

        assertEq(
            storedMetadataURI,
            string.concat(
                'ipfs://malicious-metadata-uri/\\"}, ',
                '{\\"trait_type\\": \\"NFTMetadataHash\\", ',
                '\\"value\\": \\"malicious-metadata-hash\\"}'
            )
        );
    }
}
