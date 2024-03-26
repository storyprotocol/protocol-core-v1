// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { CoreMetadataModule } from "../../../../contracts/modules/metadata/CoreMetadataModule.sol";
import { CoreMetadataViewModule } from "../../../../contracts/modules/metadata/CoreMetadataViewModule.sol";
import { CORE_METADATA_MODULE_KEY } from "../../../../contracts/lib/modules/Module.sol";
import { CORE_METADATA_VIEW_MODULE_KEY } from "../../../../contracts/lib/modules/Module.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IPAccountStorageOps } from "../../../../contracts/lib/IPAccountStorageOps.sol";

contract CoreMetadataViewModuleTest is BaseTest {
    using IPAccountStorageOps for IIPAccount;
    using Strings for *;

    CoreMetadataModule public coreMetadataModule;
    CoreMetadataViewModule public coreMetadataViewModule;
    IIPAccount private ipAccount;

    function setUp() public override {
        super.setUp();
        buildDeployAccessCondition(DeployAccessCondition({ accessController: true, governance: true }));
        buildDeployRegistryCondition(DeployRegistryCondition({ licenseRegistry: false, moduleRegistry: true }));
        deployConditionally();
        postDeploymentSetup();

        mockNFT.mintId(alice, 99);

        ipAccount = IIPAccount(payable(ipAssetRegistry.register(address(mockNFT), 99)));

        vm.label(address(ipAccount), "IPAccount1");

        coreMetadataModule = new CoreMetadataModule(address(accessController), address(ipAssetRegistry));
        coreMetadataViewModule = new CoreMetadataViewModule(address(ipAssetRegistry), address(moduleRegistry));

        vm.startPrank(u.admin);
        moduleRegistry.registerModule(CORE_METADATA_MODULE_KEY, address(coreMetadataModule));
        moduleRegistry.registerModule(CORE_METADATA_VIEW_MODULE_KEY, address(coreMetadataViewModule));
        vm.stopPrank();

        coreMetadataViewModule.updateCoreMetadataModule();
    }

    function test_CoreMetadataViewModule_GetAllMetadata() public {
        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));

        assertEq(coreMetadataViewModule.getName(address(ipAccount)), "My IP");
        assertEq(coreMetadataViewModule.getOwner(address(ipAccount)), alice);
        assertEq(coreMetadataViewModule.getUri(address(ipAccount)), "https://storyprotocol.xyz/erc721/99");
        assertEq(coreMetadataViewModule.getRegistrationDate(address(ipAccount)), block.timestamp);
        assertEq(coreMetadataViewModule.getContentHash(address(ipAccount)), bytes32("0x1234"));
    }

    function test_CoreMetadataViewModule_GetAllMetadata_without_CoreMetadata() public {
        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        assertEq(coreMetadataViewModule.getName(address(ipAccount)), name);
        assertEq(coreMetadataViewModule.getOwner(address(ipAccount)), alice);
        assertEq(coreMetadataViewModule.getUri(address(ipAccount)), "https://storyprotocol.xyz/erc721/99");
        assertEq(coreMetadataViewModule.getRegistrationDate(address(ipAccount)), block.timestamp);
        assertEq(coreMetadataViewModule.getContentHash(address(ipAccount)), bytes32(0));
    }

    function test_CoreMetadataViewModule_JsonString() public {
        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
        assertEq(
            _getExpectedJsonString("My IP", bytes32("0x1234")),
            coreMetadataViewModule.getJsonString(address(ipAccount))
        );
    }

    function test_CoreMetadataViewModule_GetCoreMetadataStrut() public {
        vm.prank(alice);
        coreMetadataModule.setIpMetadata(address(ipAccount), "My IP", bytes32("0x1234"));
        CoreMetadataViewModule.CoreMetadata memory coreMetadata = coreMetadataViewModule.getCoreMetadata(
            address(ipAccount)
        );
        assertEq(coreMetadata.name, "My IP");
        assertEq(coreMetadata.contentHash, bytes32("0x1234"));
        assertEq(coreMetadata.registrationDate, block.timestamp);
        assertEq(coreMetadata.owner, alice);
        assertEq(coreMetadata.uri, "https://storyprotocol.xyz/erc721/99");
    }

    function test_CoreMetadataViewModule_GetJsonStr_without_CoreMetadata() public {
        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        assertEq(_getExpectedJsonString(name, bytes32(0)), coreMetadataViewModule.getJsonString(address(ipAccount)));
    }

    function _getExpectedJsonString(string memory name, bytes32 contentHash) internal view returns (string memory) {
        /* solhint-disable */
        string memory baseJson = string(
            abi.encodePacked('{"name": "IP Asset # ', Strings.toHexString(address(ipAccount)), '", "attributes": [')
        );

        string memory ipAttributes = string(
            abi.encodePacked(
                '{"trait_type": "Name", "value": "',
                name,
                '"},'
                '{"trait_type": "Owner", "value": "',
                Strings.toHexString(alice),
                '"},'
                '{"trait_type": "ContentHash", "value": "',
                Strings.toHexString(uint256(contentHash), 32),
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
