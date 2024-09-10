// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { IModule } from "../../../../contracts/interfaces/modules/base/IModule.sol";
import { IIPAccountRegistry } from "../../../../contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IModuleRegistry } from "../../../../contracts/interfaces/registries/IModuleRegistry.sol";
import { IPAccountChecker } from "../../../../contracts/lib/registries/IPAccountChecker.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";

contract MockModule is BaseModule {
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;

    IIPAccountRegistry public ipAccountRegistry;
    IModuleRegistry public moduleRegistry;
    string public name;

    constructor(address _ipAccountRegistry, address _moduleRegistry, string memory _name) {
        ipAccountRegistry = IIPAccountRegistry(_ipAccountRegistry);
        moduleRegistry = IModuleRegistry(_moduleRegistry);
        name = _name;
    }

    function executeSuccessfully(string memory param) external view returns (string memory) {
        require(ipAccountRegistry.isIpAccount(msg.sender), "MockModule: caller is not ipAccount");
        return param;
    }

    function executeNoReturn(string memory) external view {
        require(ipAccountRegistry.isIpAccount(msg.sender), "MockModule: caller is not ipAccount");
    }

    function callAnotherModule(string memory moduleName) external returns (string memory) {
        require(ipAccountRegistry.isIpAccount(payable(msg.sender)), "MockModule: caller is not ipAccount");
        address moduleAddress = moduleRegistry.getModule(moduleName);
        bytes memory output = IIPAccount(payable(msg.sender)).execute(
            moduleAddress,
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", moduleName)
        );
        return abi.decode(output, (string));
    }

    function executeRevert() external pure {
        revert("MockModule: executeRevert");
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
