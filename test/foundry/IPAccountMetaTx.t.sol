// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";
import { MetaTx } from "../../contracts/lib/MetaTx.sol";
import { AccessPermission } from "../../contracts/lib/AccessPermission.sol";
import { Errors } from "../../contracts/lib/Errors.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { MockMetaTxModule } from "./mocks/module/MockMetaTxModule.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";
import { MockAccessControlledModule } from "test/foundry/mocks/module/MockAccessControlledModule.sol";

contract IPAccountMetaTxTest is BaseTest {
    MockModule public module;
    MockAccessControlledModule public accessControlledModule;
    MockMetaTxModule public metaTxModule;

    uint256 public ownerPrivateKey;
    uint256 public callerPrivateKey;
    address public owner;
    address public caller;

    function setUp() public override {
        super.setUp();
        buildDeployAccessCondition(DeployAccessCondition({ accessController: true, governance: false }));
        buildDeployRegistryCondition(DeployRegistryCondition({ moduleRegistry: true, licenseRegistry: false }));
        deployConditionally();
        postDeploymentSetup();

        ownerPrivateKey = 0xA11111;
        callerPrivateKey = 0xB22222;
        owner = vm.addr(ownerPrivateKey);
        caller = vm.addr(callerPrivateKey);

        module = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "Module1WithPermission");
        accessControlledModule = new MockAccessControlledModule(
            address(accessController),
            address(ipAccountRegistry),
            address(moduleRegistry),
            "AccessControlledModule"
        );
        metaTxModule = new MockMetaTxModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            address(accessController)
        );

        vm.startPrank(u.admin);
        moduleRegistry.registerModule("Module1WithPermission", address(module));
        moduleRegistry.registerModule("MockMetaTxModule", address(metaTxModule));
        moduleRegistry.registerModule("AccessControlledModule", address(accessControlledModule));
        vm.stopPrank();
    }

    // test called by unauthorized module with signature
    // test signature expired
    // test signature invalid
    // test signature does not match to parameters
    // test signature is not signed by signer
    // test signature signed by unauthorized signer
    // test signature signed by another contract
    // test signature signed by unauthorized contract
    // test setPermission with signature
    // reuse the signature

    function test_IPAccount_ExecutionPassWithSignature() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);
        vm.prank(caller);
        bytes memory result = metaTxModule.callAnotherModuleWithSignature(
            payable(address(ipAccount)),
            owner,
            deadline,
            signature
        );
        assertEq("test", abi.decode(result, (string)));

        assertEq(ipAccount.state(), 1);
    }

    function test_IPAccount_setPermissionWithSignature() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(accessController),
                    value: 0,
                    data: abi.encodeWithSignature(
                        "setPermission(address,address,address,bytes4,uint8)",
                        address(ipAccount),
                        address(metaTxModule),
                        address(module),
                        bytes4(0),
                        AccessPermission.ALLOW
                    ),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);
        vm.prank(caller);
        bytes memory result = metaTxModule.setPermissionThenCallOtherModules(
            payable(address(ipAccount)),
            owner,
            deadline,
            signature
        );
        assertEq("test", abi.decode(result, (string)));

        assertEq(ipAccount.state(), 2);
    }

    function test_IPAccount_setPermissionWithSignatureThenCallAccessControlledModule() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(accessController),
                    value: 0,
                    data: abi.encodeWithSignature(
                        "setPermission(address,address,address,bytes4,uint8)",
                        address(ipAccount),
                        address(metaTxModule),
                        address(accessControlledModule),
                        bytes4(0),
                        AccessPermission.ALLOW
                    ),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);
        vm.prank(caller);
        string memory result = metaTxModule.setPermissionThenCallOtherAccessControlledModule(
            payable(address(ipAccount)),
            owner,
            deadline,
            signature
        );
        assertEq("test", result);

        assertEq(ipAccount.state(), 1);
    }

    function test_IPAccount_revert_SignatureExpired() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = 0;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccount__ExpiredSignature.selector));
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), owner, deadline, signature);
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_InvalidSignature() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        // bad signature
        bytes memory invalidSignature = abi.encodePacked(r, s, v + 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccount__InvalidSignature.selector));
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), owner, deadline, invalidSignature);
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_SignatureNotMatchExecuteTargetFunction() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("UnMatchedFunction(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccount__InvalidSignature.selector));
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), owner, deadline, signature);
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_WrongSigner() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        // wrong signer
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(callerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccount__InvalidSignature.selector));
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), owner, deadline, signature);
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_SignatureForAnotherIPAccount() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint256 tokenId2 = 101;
        mockNFT.mintId(owner, tokenId2);
        address account2 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId2);
        IIPAccount ipAccount2 = IIPAccount(payable(account2));

        uint deadline = block.timestamp + 1000;

        // signature for another ipAccount
        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(account2),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount2.state(),
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccount__InvalidSignature.selector));
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), owner, deadline, signature);
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_signedByNonOwner() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        // signed by non-owner
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(callerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(caller),
                address(module),
                module.executeSuccessfully.selector
            )
        );
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), caller, deadline, signature);
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_UseSignatureTwice() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        // first time pass
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), owner, deadline, signature);
        assertEq(ipAccount.state(), 1);
        // second time fail
        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccount__InvalidSignature.selector));
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), owner, deadline, signature);
        assertEq(ipAccount.state(), 1);
    }

    function test_IPAccount_revert_signerZeroAddress() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);
        // bad signature
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(Errors.IPAccount__InvalidSigner.selector));
        vm.prank(caller);
        metaTxModule.callAnotherModuleWithSignature(payable(address(ipAccount)), address(0), deadline, signature);
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_workflowFailureWithSig() public {
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        uint deadline = block.timestamp + 1000;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(address(ipAccount)),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({
                    to: address(module),
                    value: 0,
                    data: abi.encodeWithSignature("executeSuccessfully(string)", "test"),
                    nonce: ipAccount.state() + 1,
                    deadline: deadline
                })
            )
        );

        // signed by non-owner
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        bytes memory signature = abi.encodePacked(r, s, v);
        MockModule module3WithoutPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module3WithoutPermission"
        );
        vm.prank(u.admin);
        moduleRegistry.registerModule("Module3WithoutPermission", address(module3WithoutPermission));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(metaTxModule),
                address(module3WithoutPermission),
                module3WithoutPermission.executeNoReturn.selector
            )
        );
        vm.prank(caller);
        metaTxModule.workflowFailureWithSignature(payable(address(ipAccount)), owner, deadline, signature);
        assertEq(ipAccount.state(), 0);
    }
}
