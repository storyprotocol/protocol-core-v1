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
        coreMetadataModule.setIpDescription(address(ipAccount), "My Description");
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));

        assertEq(coreMetadataViewModule.getName(address(ipAccount)), "My IP");
        assertEq(coreMetadataViewModule.getDescription(address(ipAccount)), "My Description");
        assertEq(coreMetadataViewModule.getOwner(address(ipAccount)), alice);
        assertEq(coreMetadataViewModule.getUri(address(ipAccount)), "https://storyprotocol.xyz/erc721/99");
        assertEq(coreMetadataViewModule.getRegistrationDate(address(ipAccount)), block.timestamp);
        assertEq(coreMetadataViewModule.getContentHash(address(ipAccount)), bytes32("0x1234"));
    }

    function test_CoreMetadataViewModule_GetAllMetadata_without_CoreMetadata() public {
        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        assertEq(coreMetadataViewModule.getName(address(ipAccount)), name);
        assertEq(coreMetadataViewModule.getDescription(address(ipAccount)), "");
        assertEq(coreMetadataViewModule.getOwner(address(ipAccount)), alice);
        assertEq(coreMetadataViewModule.getUri(address(ipAccount)), "https://storyprotocol.xyz/erc721/99");
        assertEq(coreMetadataViewModule.getRegistrationDate(address(ipAccount)), block.timestamp);
        assertEq(coreMetadataViewModule.getContentHash(address(ipAccount)), bytes32(0));
    }

    function test_CoreMetadataViewModule_TokenURI() public {
        vm.prank(alice);
        coreMetadataModule.setIpName(address(ipAccount), "My IP");
        vm.prank(alice);
        coreMetadataModule.setIpDescription(address(ipAccount), "My Description");
        vm.prank(alice);
        coreMetadataModule.setIpContentHash(address(ipAccount), bytes32("0x1234"));
        assertEq(
            _getExpectedTokenURI("My IP", "My Description", bytes32("0x1234")),
            coreMetadataViewModule.tokenURI(address(ipAccount))
        );
    }

    function test_CoreMetadataViewModule_TokenURI_without_CoreMetadata() public {
        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        assertEq(_getExpectedTokenURI(name, "", bytes32(0)), coreMetadataViewModule.tokenURI(address(ipAccount)));
    }

    function _getExpectedTokenURI(
        string memory name,
        string memory description,
        bytes32 contentHash
    ) internal view returns (string memory) {
        /* solhint-disable */
        string memory baseJson = string(
            abi.encodePacked(
                '{"name": "IP Asset # ',
                Strings.toHexString(address(ipAccount)),
                '", "description": "',
                description,
                '", "attributes": ['
            )
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
