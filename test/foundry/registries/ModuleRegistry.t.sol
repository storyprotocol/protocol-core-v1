// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { Errors } from "contracts/lib/Errors.sol";

import { MODULE_TYPE_DEFAULT, MODULE_TYPE_HOOK } from "contracts/lib/modules/Module.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IHookModule } from "contracts/interfaces/modules/base/IHookModule.sol";

import { MockModule } from "../mocks/module/MockModule.sol";
import { ICustomModule, CustomModule } from "../mocks/CustomModuleType.sol";
import { MockTokenGatedHook } from "../mocks/MockTokenGatedHook.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract ModuleRegistryTest is BaseTest {
    MockModule public module;
    CustomModule public customModule;
    MockTokenGatedHook public tokenGatedHook;

    function setUp() public override {
        super.setUp();

        module = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule");
        customModule = new CustomModule();
        tokenGatedHook = new MockTokenGatedHook();

        // run tests as u.admin
        changePrank(u.admin);
    }

    function test_ModuleRegistry_registerModule() public {
        moduleRegistry.registerModule("MockModule", address(module));
        assertEq(moduleRegistry.getModule("MockModule"), address(module));
        assertTrue(moduleRegistry.isRegistered(address(module)));
        assertEq(moduleRegistry.getModuleType(address(module)), MODULE_TYPE_DEFAULT);
        assertEq(moduleRegistry.getModuleTypeInterfaceId(MODULE_TYPE_DEFAULT), type(IModule).interfaceId);
    }

    function test_ModuleRegistry_revert_registerModule_moduleAddressIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleAddressZeroAddress.selector));
        moduleRegistry.registerModule("MockModule", address(0));
    }

    function test_ModuleRegistry_revert_registerModule_moduleAddressIsNotContract() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleAddressNotContract.selector));
        moduleRegistry.registerModule("MockModule", address(0xbeefbeef));
    }

    function test_ModuleRegistry_revert_registerModule_moduleAlreadyRegistered() public {
        moduleRegistry.registerModule("MockModule", address(module));
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleAlreadyRegistered.selector));
        moduleRegistry.registerModule("MockModule", address(module));
    }

    function test_ModuleRegistry_revert_registerModule_nameEmptyString() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameEmptyString.selector));
        moduleRegistry.registerModule("", address(module));
    }

    function test_ModuleRegistry_revert_registerModule_nameAlreadyRegistered() public {
        moduleRegistry.registerModule("MockModule", address(module));
        MockModule newModule = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "NewMockModule");
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameAlreadyRegistered.selector));
        moduleRegistry.registerModule("MockModule", address(newModule));
    }

    function test_ModuleRegistry_revert_registerModule_nameDoesNotMatch() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameDoesNotMatch.selector));
        moduleRegistry.registerModule("WrongMockModuleName", address(module));
    }

    function test_ModuleRegistry_removeModule() public {
        moduleRegistry.registerModule("MockModule", address(module));
        assertEq(moduleRegistry.getModule("MockModule"), address(module));
        assertTrue(moduleRegistry.isRegistered(address(module)));
        moduleRegistry.removeModule("MockModule");
        assertEq(moduleRegistry.getModule("MockModule"), address(0));
        assertFalse(moduleRegistry.isRegistered(address(module)));
    }

    function test_ModuleRegistry_revert_removeModule_nameEmptyString() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameEmptyString.selector));
        moduleRegistry.removeModule("");
    }

    function test_ModuleRegistry_revert_removeModule_moduleNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleNotRegistered.selector));
        moduleRegistry.removeModule("MockModuleMockMock");
    }

    function test_ModuleRegistry_registerModuleWithModuleType() public {
        moduleRegistry.registerModule("MockModule", address(module), MODULE_TYPE_DEFAULT);
        assertEq(moduleRegistry.getModule("MockModule"), address(module));
        assertTrue(moduleRegistry.isRegistered(address(module)));
        assertEq(moduleRegistry.getModuleType(address(module)), MODULE_TYPE_DEFAULT);
    }

    function test_ModuleRegistry_revert_registerModuleWithModuleTypeTwice() public {
        moduleRegistry.registerModule("MockModule", address(module), MODULE_TYPE_DEFAULT);
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleAlreadyRegistered.selector));
        moduleRegistry.registerModule("MockModule", address(module), MODULE_TYPE_DEFAULT);
    }

    function test_ModuleRegistry_revert_registerModuleWithModuleTypeThatDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleTypeNotRegistered.selector));
        moduleRegistry.registerModule("MockModule", address(module), "NonExistentModuleType");
    }

    function test_ModuleRegistry_revert_registerModuleWithModuleTypeThatIsEmptyString() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleTypeEmptyString.selector));
        moduleRegistry.registerModule("MockModule", address(module), "");
    }

    function test_ModuleRegistry_registerModuleType() public {
        moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, type(IHookModule).interfaceId);
        assertEq(moduleRegistry.getModuleTypeInterfaceId(MODULE_TYPE_HOOK), type(IHookModule).interfaceId);
    }

    function test_ModuleRegistry_revert_registerModuleTypeTwice() public {
        moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, type(IHookModule).interfaceId);
        assertEq(moduleRegistry.getModuleTypeInterfaceId(MODULE_TYPE_HOOK), type(IHookModule).interfaceId);
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleTypeAlreadyRegistered.selector));
        moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, type(IHookModule).interfaceId);
    }

    function test_ModuleRegistry_revert_registerModuleType_interfaceIdZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__InterfaceIdZero.selector));
        moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, 0);
    }

    function test_ModuleRegistry_revert_registerModuleType_nameEmptyString() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameEmptyString.selector));
        moduleRegistry.registerModuleType("", type(IHookModule).interfaceId);
    }

    function test_ModuleRegistry_registerModuleWithHookModuleType() public {
        moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, type(IHookModule).interfaceId);
        moduleRegistry.registerModule("MockTokenGatedHook", address(tokenGatedHook), MODULE_TYPE_HOOK);
        assertEq(moduleRegistry.getModule("MockTokenGatedHook"), address(tokenGatedHook));
        assertTrue(moduleRegistry.isRegistered(address(tokenGatedHook)));
        assertEq(moduleRegistry.getModuleType(address(tokenGatedHook)), MODULE_TYPE_HOOK);
    }

    function test_ModuleRegistry_revert_registerHookDoesNotMatchInterfaceId() public {
        moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, type(IHookModule).interfaceId);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.ModuleRegistry__ModuleNotSupportExpectedModuleTypeInterfaceId.selector)
        );
        moduleRegistry.registerModule("CustomModule", address(customModule), MODULE_TYPE_HOOK);
    }

    function test_ModuleRegistry_removeModuleType() public {
        moduleRegistry.registerModuleType(MODULE_TYPE_HOOK, type(IHookModule).interfaceId);
        assertEq(moduleRegistry.getModuleTypeInterfaceId(MODULE_TYPE_HOOK), type(IHookModule).interfaceId);
        moduleRegistry.removeModuleType(MODULE_TYPE_HOOK);
        assertEq(moduleRegistry.getModuleTypeInterfaceId(MODULE_TYPE_HOOK), 0);
    }
    function test_ModuleRegistry_revert_removeModuleType_nameEmptyString() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameEmptyString.selector));
        moduleRegistry.removeModuleType("");
    }
    function test_ModuleRegistry_revert_removeModuleType_moduleTypeNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleTypeNotRegistered.selector));
        moduleRegistry.removeModuleType("NonExistentModuleType");
    }
    function test_ModuleRegistry_registryNewCustomModuleType() public {
        moduleRegistry.registerModuleType("CustomModuleType", type(ICustomModule).interfaceId);
        assertEq(moduleRegistry.getModuleTypeInterfaceId("CustomModuleType"), type(ICustomModule).interfaceId);
    }
    function test_ModuleRegistry_registerModuleWithCustomModuleType() public {
        moduleRegistry.registerModuleType("CustomModuleType", type(ICustomModule).interfaceId);
        moduleRegistry.registerModule("CustomModule", address(customModule), "CustomModuleType");
        assertEq(moduleRegistry.getModule("CustomModule"), address(customModule));
        assertTrue(moduleRegistry.isRegistered(address(customModule)));
        assertEq(moduleRegistry.getModuleType(address(customModule)), "CustomModuleType");
    }

    function test_ModuleRegistry_registerModuleWithCustomModuleTypeTwiceAndRemoveIt() public {
        moduleRegistry.registerModuleType("CustomModuleType", type(ICustomModule).interfaceId);
        moduleRegistry.registerModule("CustomModule", address(customModule), "CustomModuleType");
        moduleRegistry.removeModule("CustomModule");
        moduleRegistry.registerModule("CustomModule", address(customModule), "CustomModuleType");
        assertEq(moduleRegistry.getModule("CustomModule"), address(customModule));
        assertTrue(moduleRegistry.isRegistered(address(customModule)));
        assertEq(moduleRegistry.getModuleType(address(customModule)), "CustomModuleType");
    }
}
