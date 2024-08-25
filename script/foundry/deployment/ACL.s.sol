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

contract StoryACL {
    uint256 public length;

    function addWhitelistAddress(address addr) external {
        uint256 slot = length++;
        assembly {
            sstore(slot, addr)
        }
    }

    function getWhitelistAddress(uint256 index) external view returns (address) {
        address addr;
        uint256 slot = index + 1;
        assembly {
            addr := sload(slot)
        }
        return addr;
    }

    function getWhitelistLength() external view returns (uint256) {
        return length;
    }

    function revokeWhitelistAddress(uint256 index) external {
        assembly {
            sstore(index, 0)
        }
    }

    // is whitelisted
    function isWhitelisted(address addr) external view returns (bool) {
        for (uint256 i = 1; i <= length; i++) {
            address whitelistAddr;
            assembly {
                whitelistAddr := sload(i)
            }
            if (whitelistAddr == addr) {
                return true;
            }
        }
        return false;
    }
}

contract DeployStoryACL is Script {
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
        uint256 deployerPrivateKey;
        _readStoryProtocolCoreAddresses();
        console2.log("Deploying StoryACL");
        console2.log("licenseRegistryAddr:", licenseRegistryAddr);
        console2.log("royaltyModuleAddr:", royaltyModuleAddr);
        console2.log("licensingModuleAddr:", licensingModuleAddr);

        deployerPrivateKey = vm.envUint("STORY_PRIVATEKEY");
        deployer = vm.envAddress("STORY_DEPLOYER_ADDRESS");
        multisig = vm.envAddress("STORY_MULTISIG_ADDRESS");

        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
        address[] memory whitelist = new address[](3);
        whitelist[0] = licenseRegistryAddr;
        whitelist[1] = royaltyModuleAddr;
        whitelist[2] = licensingModuleAddr;

        vm.startBroadcast(deployerPrivateKey);
        string memory contractKey = "StoryAcl";
        //        uint256 seed = 1000;
        _predeploy(contractKey);
        StoryACL storyAcl = StoryACL(
            create3Deployer.deploy(
                keccak256(abi.encode("TheStoryPrecompileACL")),
                abi.encodePacked(
                    type(StoryACL).creationCode,
                    abi.encode(licenseRegistryAddr),
                    abi.encode(royaltyModuleAddr),
                    abi.encode(licensingModuleAddr)
                )
            )
        );
        _postdeploy(contractKey, address(storyAcl));

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
