/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";

import { Script, stdJson } from "forge-std/Script.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { PILFlavors } from "contracts/lib/PILFlavors.sol";
import { PILicenseTemplate, PILTerms } from "contracts/modules/licensing/PILicenseTemplate.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";
import "test/foundry/mocks/token/MockERC721.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import "test/foundry/mocks/MockIPGraph.sol";

import "test/foundry/mocks/token/MockERC721.sol";

contract TestACL is Script {
    using stdJson for string;
    address internal CREATE3_DEPLOYER = 0x384a891dFDE8180b054f04D66379f16B7a678Ad6;

    address public multisig;
    address public deployer;
    ICreate3Deployer create3Deployer;
    address internal protocolAccessManagerAddr;
    address internal ipAssetRegistryAddr;
    address internal licensingModuleAddr;
    address internal licenseRegistryAddr;
    address internal royaltyModuleAddr;
    address internal coreMetadataModuleAddr;
    address internal accessControllerAddr;
    address internal pilTemplateAddr;
    address internal licenseTokenAddr;

    function run() public {
        vm.etch(address(0x1A), address(new MockIPGraph()).code);
        uint256 deployerPrivateKey;
        _readStoryProtocolCoreAddresses();
        console2.log("Testing StoryACL");
        console2.log("licenseRegistryAddr:", licenseRegistryAddr);
        console2.log("royaltyModuleAddr:", royaltyModuleAddr);
        console2.log("licensingModuleAddr:", licensingModuleAddr);

        deployerPrivateKey = vm.envUint("STORY_PRIVATEKEY");
        deployer = vm.envAddress("STORY_DEPLOYER_ADDRESS");
        multisig = vm.envAddress("STORY_MULTISIG_ADDRESS");


        vm.startBroadcast(deployerPrivateKey);
        MockERC721 mockERC721 = new MockERC721("MockERC721");
        uint256 tokenId1 = mockERC721.mint(deployer);
        console2.log("Minted tokenId:", tokenId1);
        uint256 tokenId2 = mockERC721.mint(deployer);
        console2.log("Minted tokenId:", tokenId2);
        uint256 tokenId3 = mockERC721.mint(deployer);
        console2.log("Minted tokenId:", tokenId3);

        address ipId1 = IPAssetRegistry(ipAssetRegistryAddr).register(block.chainid, address(mockERC721), tokenId1);
        address ipId2 = IPAssetRegistry(ipAssetRegistryAddr).register(block.chainid, address(mockERC721), tokenId2);
        address ipId3 = IPAssetRegistry(ipAssetRegistryAddr).register(block.chainid, address(mockERC721), tokenId3);
        console2.log("Registered IP:", ipId1);
        console2.log("Registered IP:", ipId2);
        console2.log("Registered IP:", ipId3);


        address[] memory parents = new address[](1);
        parents[0] = ipId1;
        uint256[] memory licenseTermsIds = new uint256[](1);
        licenseTermsIds[0] = 1;
        LicensingModule(licensingModuleAddr).registerDerivative(ipId2, parents, licenseTermsIds, pilTemplateAddr, "");
        console2.log("Registered Derivative:", ipId2);


        vm.stopBroadcast();
    }

    function _readStoryProtocolCoreAddresses() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            string(abi.encodePacked("/deploy-out/deployment-", Strings.toString(block.chainid), ".json"))
        );
        string memory json = vm.readFile(path);
        protocolAccessManagerAddr = json.readAddress(".main.ProtocolAccessManager");
        ipAssetRegistryAddr = json.readAddress(".main.IPAssetRegistry");
        licensingModuleAddr = json.readAddress(".main.LicensingModule");
        licenseRegistryAddr = json.readAddress(".main.LicenseRegistry");
        royaltyModuleAddr = json.readAddress(".main.RoyaltyModule");
        coreMetadataModuleAddr = json.readAddress(".main.CoreMetadataModule");
        accessControllerAddr = json.readAddress(".main.AccessController");
        pilTemplateAddr = json.readAddress(".main.PILicenseTemplate");
        licenseTokenAddr = json.readAddress(".main.LicenseToken");
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
