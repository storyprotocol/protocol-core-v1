// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC6551Account } from "erc6551/interfaces/IERC6551Account.sol";
import { ERC6551 } from "@solady/src/accounts/ERC6551.sol";

import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../contracts/lib/Errors.sol";
import { IPAccountRegistry } from "../../contracts/registries/IPAccountRegistry.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";

contract MockIPAccountRegistry is IPAccountRegistry {
    constructor(address erc6551Registry, address ipAccountImpl) IPAccountRegistry(erc6551Registry, ipAccountImpl) {}

    function registerIpAccount(uint256 chainId, address tokenContract, uint256 tokenId) public returns (address) {
        return _registerIpAccount(chainId, tokenContract, tokenId);
    }
}

contract IPAccountTest is BaseTest {
    MockModule public module;
    MockIPAccountRegistry public mockIpAccountRegistry;

    function setUp() public override {
        super.setUp();

        module = new MockModule(address(ipAssetRegistry), address(moduleRegistry), "MockModule");
        mockIpAccountRegistry = new MockIPAccountRegistry(
            ipAccountRegistry.ERC6551_PUBLIC_REGISTRY(),
            ipAccountRegistry.IP_ACCOUNT_IMPL()
        );

        vm.startPrank(u.admin); // used twice, name() and registerModule()
        moduleRegistry.registerModule(module.name(), address(module));
        vm.stopPrank();
    }

    function test_IPAccount_Idempotency() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        address predictedAccount = ipAssetRegistry.ipAccount(block.chainid, address(mockNFT), tokenId);

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);

        address deployedAccount = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        assertTrue(deployedAccount != address(0));

        assertEq(predictedAccount, deployedAccount);

        // Create account twice
        deployedAccount = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);
        assertEq(predictedAccount, deployedAccount);
    }

    function test_IPAccount_TokenAndOwnership() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        // Check token and owner functions
        (uint256 chainId_, address tokenAddress_, uint256 tokenId_) = ipAccount.token();
        assertEq(chainId_, block.chainid);
        assertEq(tokenAddress_, address(mockNFT));
        assertEq(tokenId_, tokenId);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(module),
                address(0),
                bytes4(0)
            )
        );
        ipAccount.isValidSigner(address(module), "");
        assertEq(ipAccount.isValidSigner(owner, ""), IERC6551Account.isValidSigner.selector);

        // Transfer token to new owner and make sure account owner changes
        address newOwner = address(module);
        vm.prank(owner);
        mockNFT.transferFrom(owner, newOwner, tokenId);
        assertEq(ipAccount.isValidSigner(newOwner, ""), IERC6551Account.isValidSigner.selector);
    }

    function test_IPAccount_OwnerExecutionPass() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        uint256 subTokenId = 111;
        mockNFT.mintId(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        bytes32 expectedState = keccak256(
            abi.encode(
                ipAccount.state(),
                abi.encodeWithSignature(
                    "execute(address,uint256,bytes)",
                    address(module),
                    0,
                    abi.encodeWithSignature("executeSuccessfully(string)", "test")
                )
            )
        );

        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(module),
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "test")
        );
        assertEq("test", abi.decode(result, (string)));

        assertEq(ipAccount.state(), expectedState);
    }

    function test_IPAccount_isValidSigner() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        // test isValidSigner with owner and empty data
        assertEq(ipAccount.isValidSigner(owner, ""), IERC6551Account.isValidSigner.selector);

        // test isValidSigner with owner and encoded "to" address and "calldata" as data
        bytes memory data = abi.encode(address(module), abi.encodeWithSignature("executeSuccessfully(string)", "test"));
        assertEq(ipAccount.isValidSigner(owner, data), IERC6551Account.isValidSigner.selector);

        assertEq(
            ipAccount.isValidSigner(owner, abi.encode(address(module), "")),
            IERC6551Account.isValidSigner.selector
        );

        // Transfer token to new owner and make sure account owner changes
        address nonOwner = vm.addr(2);
        vm.prank(owner);
        mockNFT.transferFrom(owner, nonOwner, tokenId);
        assertEq(ipAccount.isValidSigner(nonOwner, data), IERC6551Account.isValidSigner.selector);
    }

    function test_IPAccount_isValidSigner_revert_InvalidInputs() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.expectRevert(Errors.IPAccount__InvalidCalldata.selector);
        ipAccount.isValidSigner(address(module), bytes("123"));

        vm.expectRevert(Errors.IPAccount__InvalidCalldata.selector);
        ipAccount.isValidSigner(address(module), bytes("123456789"));

        vm.expectRevert();
        ipAccount.isValidSigner(address(module), abi.encode(address(0x123)));

        vm.expectRevert();
        ipAccount.isValidSigner(address(module), abi.encodeWithSignature("executeSuccessfully(string)", "test"));

        vm.expectRevert(Errors.IPAccount__InvalidCalldata.selector);
        ipAccount.isValidSigner(owner, abi.encode(address(module), bytes("123")));

        // test isValidSigner with non-owner and empty data
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(module),
                address(0),
                bytes4(0)
            )
        );
        ipAccount.isValidSigner(address(module), "");

        // test isValidSigner with non-owner and encoded "to" address and "calldata" as data
        bytes memory data = abi.encode(address(module), abi.encodeWithSignature("executeSuccessfully(string)", "test"));
        address nonOwner = vm.addr(2);
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                nonOwner,
                address(module),
                module.executeSuccessfully.selector
            )
        );
        ipAccount.isValidSigner(nonOwner, data);
    }

    function test_IPAccount_revert_NonOwnerNoPermissionToExecute() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        uint256 subTokenId = 111;
        mockNFT.mintId(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(vm.addr(3));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                vm.addr(3),
                address(module),
                module.executeSuccessfully.selector
            )
        );
        ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeSuccessfully(string)", "test"));
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_OwnerExecuteFailed() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        uint256 subTokenId = 111;
        mockNFT.mintId(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(owner);
        vm.expectRevert("MockModule: executeRevert");
        ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeRevert()"));
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_ERC721Receive() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        address otherOwner = vm.addr(2);
        uint256 otherTokenId = 200;
        mockNFT.mintId(otherOwner, otherTokenId);
        vm.prank(otherOwner);
        mockNFT.safeTransferFrom(otherOwner, account, otherTokenId);
        assertEq(mockNFT.balanceOf(account), 1);
        assertEq(mockNFT.ownerOf(otherTokenId), account);
    }

    function test_IPAccount_ExecuteWithOperationType() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        ERC6551 ipAccount = ERC6551(payable(account));

        bytes32 expectedState = keccak256(
            abi.encode(
                ipAccount.state(),
                abi.encodeWithSignature(
                    "execute(address,uint256,bytes)",
                    address(module),
                    0,
                    abi.encodeWithSignature("executeSuccessfully(string)", "test")
                )
            )
        );

        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(module),
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "test"),
            0
        );
        assertEq("test", abi.decode(result, (string)));

        assertEq(ipAccount.state(), expectedState);
    }

    function test_IPAccount_revert_ExecuteWithUnsupportedOperationType() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        ERC6551 ipAccount = ERC6551(payable(account));

        vm.expectRevert(Errors.IPAccount__InvalidOperation.selector);
        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(module),
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "test"),
            1 // unsupported operation type
        );
    }

    function test_IPAccount_executeBatch() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        ERC6551 ipAccount = ERC6551(payable(account));

        bytes32 firstState = keccak256(
            abi.encode(
                ipAccount.state(),
                abi.encodeWithSignature(
                    "execute(address,uint256,bytes)",
                    address(module),
                    0,
                    abi.encodeWithSignature("executeSuccessfully(string)", "test")
                )
            )
        );

        bytes32 finalState = keccak256(
            abi.encode(
                firstState,
                abi.encodeWithSignature(
                    "execute(address,uint256,bytes)",
                    address(module),
                    0,
                    abi.encodeWithSignature("executeSuccessfully(string)", "another test")
                )
            )
        );

        ERC6551.Call[] memory calls = new ERC6551.Call[](2);
        calls[0] = ERC6551.Call({
            target: address(module),
            value: 0,
            data: abi.encodeWithSignature("executeSuccessfully(string)", "test")
        });
        calls[1] = ERC6551.Call({
            target: address(module),
            value: 0,
            data: abi.encodeWithSignature("executeSuccessfully(string)", "another test")
        });
        vm.prank(owner);
        bytes[] memory results = ipAccount.executeBatch(calls, 0);
        assertEq("test", abi.decode(results[0], (string)));
        assertEq("another test", abi.decode(results[1], (string)));

        assertEq(ipAccount.state(), finalState);
    }
}
