// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";
import { Errors } from "../../contracts/lib/Errors.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";

contract IPAccountTest is BaseTest {
    MockModule public module;

    function setUp() public override {
        super.setUp();

        module = new MockModule(address(ipAssetRegistry), address(moduleRegistry), "MockModule");

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

        address deployedAccount = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        assertTrue(deployedAccount != address(0));

        assertEq(predictedAccount, deployedAccount);

        // Create account twice
        deployedAccount = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);
        assertEq(predictedAccount, deployedAccount);
    }

    // TODO: Fix this test, "vm.addr(2)" hits error AccessController__BothCallerAndRecipientAreNotRegisteredModule
    // but we want to test for "AccessController__PermissionDenied" for vm.addr(2) (which is not a module or IPAccount)
    /*function test_IPAccount_TokenAndOwnership() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

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
                vm.addr(2),
                address(0),
                bytes4(0)
            )
        );
        ipAccount.isValidSigner(vm.addr(2), "");
        assertEq(ipAccount.isValidSigner(owner, ""), IERC6551Account.isValidSigner.selector);

        // Transfer token to new owner and make sure account owner changes
        address newOwner = vm.addr(2);
        vm.prank(owner);
        mockNFT.safeTransferFrom(owner, newOwner, tokenId);
        assertEq(ipAccount.isValidSigner(newOwner, ""), IERC6551Account.isValidSigner.selector);
    }*/

    function test_IPAccount_OwnerExecutionPass() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        uint256 subTokenId = 111;
        mockNFT.mintId(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(module),
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "test")
        );
        assertEq("test", abi.decode(result, (string)));

        assertEq(ipAccount.state(), 1);
    }

    function test_IPAccount_revert_NonOwnerNoPermissionToExecute() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        address account = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

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

        address account = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

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
        address account = ipAssetRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);

        address otherOwner = vm.addr(2);
        uint256 otherTokenId = 200;
        mockNFT.mintId(otherOwner, otherTokenId);
        vm.prank(otherOwner);
        mockNFT.safeTransferFrom(otherOwner, account, otherTokenId);
        assertEq(mockNFT.balanceOf(account), 1);
        assertEq(mockNFT.ownerOf(otherTokenId), account);
    }
}
