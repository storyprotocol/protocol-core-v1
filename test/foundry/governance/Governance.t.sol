// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IIPAccount } from "../../../contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "../../../contracts/lib/AccessPermission.sol";
import { Errors } from "../../../contracts/lib/Errors.sol";
import { IGovernable } from "../../../contracts/interfaces/governance/IGovernable.sol";
import { GovernanceLib } from "../../../contracts/lib/GovernanceLib.sol";
import { Governance } from "../../../contracts/governance/Governance.sol";

import { MockModule } from "../mocks/module/MockModule.sol";
import { BaseTest } from "../utils/BaseTest.t.sol";

contract GovernanceTest is BaseTest {
    MockModule public mockModule;
    MockModule public moduleWithoutPermission;
    IIPAccount public ipAccount;

    address public owner = vm.addr(1);
    uint256 public tokenId = 100;

    function setUp() public override {
        super.setUp();

        mockNFT.mintId(owner, tokenId);

        address deployedAccount = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);
        ipAccount = IIPAccount(payable(deployedAccount));

        mockModule = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule");
    }

    function test_Governance_registerModuleSuccess() public {
        vm.prank(u.admin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));
    }

    function test_Governance_removeModuleSuccess() public {
        vm.prank(u.admin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));

        vm.prank(u.admin);
        moduleRegistry.removeModule("MockModule");
        assertEq(moduleRegistry.getModule("MockModule"), address(0));
        assertFalse(moduleRegistry.isRegistered(address(mockModule)));
    }

    function test_Governance_setGlobalPermissionSuccess() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
        assertEq(
            accessController.getPermission(address(0), address(mockModule), address(mockModule2), bytes4(0)),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_registerModuleWithNonAdmin() public {
        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_revert_removeModuleWithNonAdmin() public {
        vm.prank(u.admin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));

        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.removeModule("MockModule");
    }

    function test_Governance_revert_setGlobalPermissionNonAdmin() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        vm.prank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));

        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_registerModuleWithNewAdmin() public {
        address newAdmin = vm.addr(3);
        vm.prank(u.admin);
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);

        vm.prank(newAdmin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_setGlobalPermissionWithNewAdmin() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        address newAdmin = vm.addr(3);

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);

        vm.startPrank(newAdmin);
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_registerModuleWithOldAdmin() public {
        address newAdmin = vm.addr(3);

        vm.startPrank(u.admin);
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);
        governance.revokeRole(GovernanceLib.PROTOCOL_ADMIN, u.admin);

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_revert_removeModuleWithOldAdmin() public {
        address newAdmin = vm.addr(3);

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));

        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);
        governance.revokeRole(GovernanceLib.PROTOCOL_ADMIN, u.admin);

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.removeModule("MockModule");
    }

    function test_Governance_revert_setGlobalPermissionWithOldAdmin() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        address newAdmin = vm.addr(3);

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));

        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);
        governance.revokeRole(GovernanceLib.PROTOCOL_ADMIN, u.admin);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_setNewGovernance() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        vm.prank(u.admin);
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        assertEq(IGovernable(address(moduleRegistry)).getGovernance(), address(newGovernance));
    }

    function test_Governance_registerModuleWithNewGov() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        vm.prank(u.admin);
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        vm.prank(newAdmin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_setGlobalPermissionWithNewGov() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        IGovernable(address(accessController)).setGovernance(address(newGovernance));

        vm.startPrank(newAdmin);
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_registerModuleWithOldGov() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);

        vm.startPrank(u.admin);
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_revert_removeModuleWithOldGov() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));

        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.removeModule("MockModule");
    }

    function test_Governance_revert_setGlobalPermissionWithOldGov() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        IGovernable(address(accessController)).setGovernance(address(newGovernance));

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_setNewGovernanceZeroAddr() public {
        vm.prank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ZeroAddress.selector));
        IGovernable(address(moduleRegistry)).setGovernance(address(0));
    }

    function test_Governance_revert_setNewGovernanceNotContract() public {
        vm.prank(u.admin);
        vm.expectRevert();
        IGovernable(address(moduleRegistry)).setGovernance(address(0xbeefbeef));
    }

    function test_Governance_revert_setNewGovernanceNotSupportInterface() public {
        vm.prank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__UnsupportedInterface.selector, "IGovernance"));
        IGovernable(address(moduleRegistry)).setGovernance(address(mockModule));
    }

    function test_Governance_revert_setNewGovernanceInconsistentState() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        vm.prank(newAdmin);
        newGovernance.setState(GovernanceLib.ProtocolState.Paused);

        vm.prank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__InconsistentState.selector));
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
    }

    function test_Governance_revert_setPermissionWhenPaused() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        governance.setState(GovernanceLib.ProtocolState.Paused);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ProtocolPaused.selector));
        accessController.setPermission(
            address(ipAccount),
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_checkPermissionWhenPaused() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        governance.setState(GovernanceLib.ProtocolState.Paused);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ProtocolPaused.selector));
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));
    }

    function test_Governance_revert_checkPermissionUnPausedThenPauseThenUnPause() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        vm.startPrank(u.admin);
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(mockModule),
                address(mockModule2),
                bytes4(0)
            )
        );
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));

        governance.setState(GovernanceLib.ProtocolState.Paused);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ProtocolPaused.selector));
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));

        governance.setState(GovernanceLib.ProtocolState.Unpaused);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(mockModule),
                address(mockModule2),
                bytes4(0)
            )
        );
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));
    }

    function test_Governance_revert_setStateWithNonAdmin() public {
        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        governance.setState(GovernanceLib.ProtocolState.Paused);
    }

    function test_Governance_revert_setSameState() public {
        vm.startPrank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__NewStateIsTheSameWithOldState.selector));
        governance.setState(GovernanceLib.ProtocolState.Unpaused);
    }
}
