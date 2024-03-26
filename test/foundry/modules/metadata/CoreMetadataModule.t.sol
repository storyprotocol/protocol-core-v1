// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { CoreMetadataModule } from "../../../../contracts/modules/metadata/CoreMetadataModule.sol";
import { ICoreMetadataModule } from "../../../../contracts/interfaces/modules/metadata/ICoreMetadataModule.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { CORE_METADATA_MODULE_KEY } from "../../../../contracts/lib/modules/Module.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { IPAccountStorageOps } from "../../../../contracts/lib/IPAccountStorageOps.sol";

contract CoreMetadataModuleTest is BaseTest {
    using IPAccountStorageOps for IIPAccount;

    CoreMetadataModule public coreMetadataModule;
    IIPAccount private ipAccount;

    function setUp() public override {
        super.setUp();
        buildDeployAccessCondition(DeployAccessCondition({ accessController: true, governance: true }));
        buildDeployRegistryCondition(DeployRegistryCondition({ licenseRegistry: false, moduleRegistry: true }));
        deployConditionally();
        postDeploymentSetup();

        mockNFT.mintId(alice, 1);

        ipAccount = IIPAccount(payable(ipAssetRegistry.register(address(mockNFT), 1)));

        vm.label(address(ipAccount), "IPAccount1");

        coreMetadataModule = new CoreMetadataModule(address(accessController), address(ipAssetRegistry));

        vm.prank(u.admin);
        moduleRegistry.registerModule(CORE_METADATA_MODULE_KEY, address(coreMetadataModule));
    }

    function test_CoreMetadata_Name() public {
        vm.expectEmit();
        emit ICoreMetadataModule.IPNameSet(address(ipAccount), "My IP");

        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_NAME"), "My IP");
    }

    function test_CoreMetadata_Name_Two_IPAccounts() public {
        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_NAME"), "My IP");

        mockNFT.mintId(alice, 2);
        IIPAccount ipAccount2 = IIPAccount(payable(ipAssetRegistry.register(address(mockNFT), 2)));
        vm.label(address(ipAccount2), "IPAccount2");

        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount2), "My IP2");
        assertEq(ipAccount2.getString(address(coreMetadataModule), "IP_NAME"), "My IP2");
    }

    function test_CoreMetadata_NameTwice() public {
        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_NAME"), "My IP");

        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadySet.selector);
        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My New IP");
    }

    function test_CoreMetadata_Name_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.setIpName(address(0x1234), "My IP");
    }

    function test_CoreMetadata_Name_InvalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                bob,
                address(coreMetadataModule),
                coreMetadataModule.setIpName.selector
            )
        );
        vm.prank(bob);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
    }

    function test_CoreMetadata_MetadataURI() public {
        vm.expectEmit();
        emit ICoreMetadataModule.MetadataURISet(address(ipAccount), "My MetadataURI");

        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI");
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
    }

    function test_CoreMetadata_MetadataURI_Two_IPAccounts() public {
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI");
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");

        mockNFT.mintId(alice, 2);
        IIPAccount ipAccount2 = IIPAccount(payable(ipAssetRegistry.register(address(mockNFT), 2)));
        vm.label(address(ipAccount2), "IPAccount2");

        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount2), "My MetadataURI2");
        assertEq(ipAccount2.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI2");
    }

    function test_CoreMetadata_MetadataURITwice() public {
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI");
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");

        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadySet.selector);
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(ipAccount), "My New MetadataURI");
    }

    function test_CoreMetadata_MetadataURI_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.setMetadataURI(address(0x1234), "My MetadataURI");
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
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI");
    }

    function test_CoreMetadata_ContentHash() public {
        vm.expectEmit();
        emit ICoreMetadataModule.IPContentHashSet(address(ipAccount), bytes32("0x1234"));

        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "IP_CONTENT_HASH"), bytes32("0x1234"));
    }

    function test_CoreMetadata_ContentHash_Two_IPAccounts() public {
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "IP_CONTENT_HASH"), bytes32("0x1234"));

        mockNFT.mintId(alice, 2);
        IIPAccount ipAccount2 = IIPAccount(payable(ipAssetRegistry.register(address(mockNFT), 2)));
        vm.label(address(ipAccount2), "IPAccount2");

        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount2), bytes32("0x5678"));
        assertEq(ipAccount2.getBytes32(address(coreMetadataModule), "IP_CONTENT_HASH"), bytes32("0x5678"));
    }

    function test_CoreMetadata_ContentHashTwice() public {
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "IP_CONTENT_HASH"), bytes32("0x1234"));

        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadySet.selector);
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x5678"));
    }

    function test_CoreMetadata_ContentHash_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(0x1234), bytes32("0x1234"));
    }

    function test_CoreMetadata_ContentHash_InvalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                bob,
                address(coreMetadataModule),
                coreMetadataModule.setIpContentHash.selector
            )
        );
        vm.prank(bob);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
    }

    function test_CoreMetadata_Batch() public {
        vm.startPrank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        coreMetadataModule.setMetadataURI(address(ipAccount), "My MetadataURI");
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
        vm.stopPrank();
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_NAME"), "My IP");
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "IP_CONTENT_HASH"), bytes32("0x1234"));
    }

    function test_CoreMetadata_All() public {
        vm.prank(alice);
        coreMetadataModule.setAll(address(ipAccount), "My IP", "My MetadataURI", bytes32("0x1234"));
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_NAME"), "My IP");
        assertEq(ipAccount.getString(address(coreMetadataModule), "METADATA_URI"), "My MetadataURI");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "IP_CONTENT_HASH"), bytes32("0x1234"));
    }

    function test_CoreMetadata_AllTwice() public {
        vm.prank(alice);
        coreMetadataModule.setAll(address(ipAccount), "My IP", "My MetadataURI", bytes32("0x1234"));

        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadySet.selector);
        vm.prank(alice);
        coreMetadataModule.setAll(address(ipAccount), "My New IP", "My New MetadataURI", bytes32("0x5678"));
    }

    function test_CoreMetadata_All_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.setAll(address(0x1234), "My IP", "My MetadataURI", bytes32("0x1234"));
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
        coreMetadataModule.setAll(address(ipAccount), "My IP", "My MetadataURI", bytes32("0x1234"));
    }
}
