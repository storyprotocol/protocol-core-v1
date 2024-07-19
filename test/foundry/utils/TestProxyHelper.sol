// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ICreate3Deployer } from "@create3-deployer/contracts/ICreate3Deployer.sol";

library TestProxyHelper {
    /// Deploys a new UUPS proxy with the provided implementation and data
    /// @dev WARNING: DO NOT USE IN PRODUCTION without checking storage layout compatibility
    /// @param impl address of the implementation contract
    /// @param data encoded initializer call
    function deployUUPSProxy(address impl, bytes memory data) internal returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy(impl, data);
        return address(proxy);
    }

    function deployUUPSProxy(
        ICreate3Deployer create3Deployer,
        bytes32 salt,
        address impl,
        bytes memory data
    ) internal returns (address) {
        return create3Deployer.deploy(salt, abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(impl, data)));
    }
}
