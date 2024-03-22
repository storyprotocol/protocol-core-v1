// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { CoreMetadataModule } from "../../../../contracts/modules/metadata/CoreMetadataModule.sol";
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

    function test_CoreMetadata_Description() public {
        vm.prank(alice);
        coreMetadataModule.setIpDescription(address(ipAccount), "My Description");
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_DESCRIPTION"), "My Description");
    }

    function test_CoreMetadata_Description_Two_IPAccounts() public {
        vm.prank(alice);
        coreMetadataModule.setIpDescription(address(ipAccount), "My Description");
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_DESCRIPTION"), "My Description");

        mockNFT.mintId(alice, 2);
        IIPAccount ipAccount2 = IIPAccount(payable(ipAssetRegistry.register(address(mockNFT), 2)));
        vm.label(address(ipAccount2), "IPAccount2");

        vm.prank(alice);
        coreMetadataModule.setIpDescription(address(ipAccount2), "My Description2");
        assertEq(ipAccount2.getString(address(coreMetadataModule), "IP_DESCRIPTION"), "My Description2");
    }

    function test_CoreMetadata_DescriptionTwice() public {
        vm.prank(alice);
        coreMetadataModule.setIpDescription(address(ipAccount), "My Description");
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_DESCRIPTION"), "My Description");

        vm.expectRevert(Errors.CoreMetadataModule__MetadataAlreadySet.selector);
        vm.prank(alice);
        coreMetadataModule.setIpDescription(address(ipAccount), "My New Description");
    }

    function test_CoreMetadata_Description_InvalidIpAccount() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__NotIpAccount.selector, address(0x1234)));
        vm.prank(alice);
        coreMetadataModule.setIpDescription(address(0x1234), "My Description");
    }

    function test_CoreMetadata_Description_InvalidCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                bob,
                address(coreMetadataModule),
                coreMetadataModule.setIpDescription.selector
            )
        );
        vm.prank(bob);
        coreMetadataModule.setIpDescription(address(ipAccount), "My Description");
    }

    function test_CoreMetadata_ContentHash() public {
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

    function test_CoreMetadata_All() public {
        vm.startPrank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        coreMetadataModule.setIpDescription(address(ipAccount), "My Description");
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
        vm.stopPrank();
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_NAME"), "My IP");
        assertEq(ipAccount.getString(address(coreMetadataModule), "IP_DESCRIPTION"), "My Description");
        assertEq(ipAccount.getBytes32(address(coreMetadataModule), "IP_CONTENT_HASH"), bytes32("0x1234"));
    }
}
