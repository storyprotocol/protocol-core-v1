// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";
import { Test } from "forge-std/Test.sol";

import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { Governance } from "contracts/governance/Governance.sol";

import { MockAccessController } from "test/foundry/mocks/access/MockAccessController.sol";
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { MockModule } from "test/foundry/mocks/module/MockModule.sol";

contract IPAccountStorageTest is Test {
    IPAccountRegistry public registry;
    IPAccountImpl public implementation;
    MockERC721 public nft = new MockERC721("MockERC721");
    ERC6551Registry public erc6551Registry = new ERC6551Registry();
    MockAccessController public accessController = new MockAccessController();
    ModuleRegistry public moduleRegistry;
    MockModule public module;
    Governance public governance;
    IIPAccount public ipAccount;

    function setUp() public {
        governance = new Governance(address(this));
        moduleRegistry = new ModuleRegistry(address(governance));
        implementation = new IPAccountImpl();
        registry = new IPAccountRegistry(address(erc6551Registry), address(accessController), address(implementation));
        module = new MockModule(address(registry), address(moduleRegistry), "MockModule");
        address owner = vm.addr(1);
        uint256 tokenId = 100;
        nft.mintId(owner, tokenId);
        ipAccount = IIPAccount(payable(registry.registerIpAccount(block.chainid, address(nft), tokenId)));
    }

    function test_IPAccountStorage_storeBytes() public {
        ipAccount.setBytes("test", abi.encodePacked("test"));
        assertEq(ipAccount.getBytes("test"), "test");
    }

    function test_IPAccountStorage_readBytes_DifferentNamespace() public {
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encodePacked("test"));
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), "test");
    }

    function test_IPAccountStorage_storeAddressArray() public {
        address[] memory addresses = new address[](2);
        addresses[0] = vm.addr(1);
        addresses[1] = vm.addr(2);
        ipAccount.setBytes("test", abi.encode(addresses));
        address[] memory result = abi.decode(ipAccount.getBytes("test"), (address[]));
        assertEq(result[0], vm.addr(1));
        assertEq(result[1], vm.addr(2));
    }

    function test_IPAccountStorage_readAddressArray_differentNameSpace() public {
        address[] memory addresses = new address[](2);
        addresses[0] = vm.addr(1);
        addresses[1] = vm.addr(2);
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encode(addresses));
        vm.prank(vm.addr(2));
        address[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), (address[]));
        assertEq(result[0], vm.addr(1));
        assertEq(result[1], vm.addr(2));
    }

    function test_IPAccountStorage_storeUint256Array() public {
        uint256[] memory uints = new uint256[](2);
        uints[0] = 1;
        uints[1] = 2;
        ipAccount.setBytes("test", abi.encode(uints));
        uint256[] memory result = abi.decode(ipAccount.getBytes("test"), (uint256[]));
        assertEq(result[0], 1);
        assertEq(result[1], 2);
    }

    function test_IPAccountStorage_readUint256Array_differentNameSpace() public {
        uint256[] memory uints = new uint256[](2);
        uints[0] = 1;
        uints[1] = 2;
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encode(uints));
        vm.prank(vm.addr(2));
        uint256[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), (uint256[]));
        assertEq(result[0], 1);
        assertEq(result[1], 2);
    }

    function test_IPAccountStorage_storeStringArray() public {
        string[] memory strings = new string[](2);
        strings[0] = "test1";
        strings[1] = "test2";
        ipAccount.setBytes("test", abi.encode(strings));
        string[] memory result = abi.decode(ipAccount.getBytes("test"), (string[]));
        assertEq(result[0], "test1");
        assertEq(result[1], "test2");
    }

    function test_IPAccountStorage_readStringArray_differentNameSpace() public {
        string[] memory strings = new string[](2);
        strings[0] = "test1";
        strings[1] = "test2";
        vm.prank(vm.addr(1));
        ipAccount.setBytes("test", abi.encode(strings));
        vm.prank(vm.addr(2));
        string[] memory result = abi.decode(ipAccount.getBytes(_toBytes32(vm.addr(1)), "test"), (string[]));
        assertEq(result[0], "test1");
        assertEq(result[1], "test2");
    }

    function test_IPAccountStorage_storeUint256() public {
        ipAccount.setUint256("test", 1);
        assertEq(ipAccount.getUint256("test"), 1);
    }

    function test_IPAccountStorage_readUint256_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setUint256("test", 1);
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getUint256(_toBytes32(vm.addr(1)), "test"), 1);
    }

    function test_IPAccountStorage_storeBool() public {
        ipAccount.setBool("test", true);
        assertTrue(ipAccount.getBool("test"));
    }

    function test_IPAccountStorage_readBool_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setBool("test", true);
        vm.prank(vm.addr(2));
        assertTrue(ipAccount.getBool(_toBytes32(vm.addr(1)), "test"));
    }

    function test_IPAccountStorage_storeString() public {
        ipAccount.setString("test", "test");
        assertEq(ipAccount.getString("test"), "test");
    }

    function test_IPAccountStorage_readString_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setString("test", "test");
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getString(_toBytes32(vm.addr(1)), "test"), "test");
    }

    function test_IPAccountStorage_storeAddress() public {
        ipAccount.setAddress("test", vm.addr(1));
        assertEq(ipAccount.getAddress("test"), vm.addr(1));
    }

    function test_IPAccountStorage_readAddress_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setAddress("test", vm.addr(1));
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getAddress(_toBytes32(vm.addr(1)), "test"), vm.addr(1));
    }

    function test_IPAccountStorage_storeBytes32() public {
        ipAccount.setBytes32("test", bytes32(uint256(111)));
        assertEq(ipAccount.getBytes32("test"), bytes32(uint256(111)));
    }

    function test_IPAccountStorage_readBytes32_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setBytes32("test", bytes32(uint256(111)));
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes32(_toBytes32(vm.addr(1)), "test"), bytes32(uint256(111)));
    }

    function test_IPAccountStorage_storeBytes32String() public {
        ipAccount.setBytes32("test", "testData");
        assertEq(ipAccount.getBytes32("test"), "testData");
    }

    function test_IPAccountStorage_readBytes32String_differentNameSpace() public {
        vm.prank(vm.addr(1));
        ipAccount.setBytes32("test", "testData");
        vm.prank(vm.addr(2));
        assertEq(ipAccount.getBytes32(_toBytes32(vm.addr(1)), "test"), "testData");
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
