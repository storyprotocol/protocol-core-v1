// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "../../../../contracts/lib/AccessPermission.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

// test
import { MockERC20 } from "../../mocks/token/MockERC20.sol";
import { MockERC721 } from "../../mocks/token/MockERC721.sol";
import { MockERC1155 } from "../../mocks/token/MockERC1155.sol";
import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TokenWithdrawalModuleTest is BaseTest {
    using Strings for *;

    MockERC20 private tErc20 = new MockERC20();
    MockERC721 private tErc721 = new MockERC721("MockERC721");
    MockERC1155 private tErc1155 = new MockERC1155("uri");

    IIPAccount private ipAcct1;
    IIPAccount private ipAcct2;

    uint256 private mintAmount20 = 100 * 10 ** tErc20.decimals();

    address private randomFrontend = address(0x123);

    function setUp() public override {
        super.setUp();

        // Create IPAccounts (Alice is the owner)
        mockNFT.mintId(alice, 1);
        mockNFT.mintId(alice, 2);

        ipAcct1 = IIPAccount(payable(ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 1)));
        ipAcct2 = IIPAccount(payable(ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 2)));

        vm.label(address(ipAcct1), "IPAccount1");
        vm.label(address(ipAcct2), "IPAccount2");
    }

    modifier testERC20_mintToIpAcct1() {
        _expectBalanceERC20(address(ipAcct1), 0);
        tErc20.mint(address(ipAcct1), mintAmount20);
        _expectBalanceERC20(address(ipAcct1), mintAmount20);
        _expectBalanceERC20(address(ipAcct2), 0);
        _;
    }

    function test_TokenWithdrawalModule_withdrawERC20() public testERC20_mintToIpAcct1 {
        _approveERC20(alice, ipAcct1, address(tokenWithdrawalModule));

        vm.prank(alice);
        tokenWithdrawalModule.withdrawERC20(payable(ipAcct1), address(tErc20), mintAmount20 / 2);

        _expectBalanceERC20(address(ipAcct1), mintAmount20 / 2);
        _expectBalanceERC20(alice, mintAmount20 / 2);

        vm.prank(alice);
        ipAcct1.execute(
            address(tokenWithdrawalModule),
            0,
            abi.encodeWithSelector(
                tokenWithdrawalModule.withdrawERC20.selector,
                payable(ipAcct1),
                address(tErc20),
                mintAmount20 / 2
            )
        );

        _expectBalanceERC20(address(ipAcct1), 0);
        _expectBalanceERC20(alice, mintAmount20);
    }

    function test_TokenWithdrawalModule_withdrawERC20_delegatedCall() public testERC20_mintToIpAcct1 {
        // signer: tokenWithdrawalModule
        // to: tErc20
        // func: transfer
        _approveERC20(alice, ipAcct1, address(tokenWithdrawalModule));

        // signer: randomFrontend
        // to: tokenWithdrawalModule
        // func: withdrawERC20
        vm.prank(alice);
        ipAcct1.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAcct1),
                randomFrontend,
                address(tokenWithdrawalModule),
                tokenWithdrawalModule.withdrawERC20.selector,
                AccessPermission.ALLOW
            )
        );

        vm.prank(randomFrontend);
        tokenWithdrawalModule.withdrawERC20(payable(ipAcct1), address(tErc20), mintAmount20 / 2);

        _expectBalanceERC20(address(ipAcct1), mintAmount20 / 2);
        _expectBalanceERC20(alice, mintAmount20 / 2);

        vm.prank(randomFrontend);
        ipAcct1.execute(
            address(tokenWithdrawalModule),
            0,
            abi.encodeWithSelector(
                tokenWithdrawalModule.withdrawERC20.selector,
                payable(ipAcct1),
                address(tErc20),
                mintAmount20 / 2
            )
        );

        _expectBalanceERC20(address(ipAcct1), 0);
        _expectBalanceERC20(alice, mintAmount20);
    }

    function test_TokenWithdrawalModule_withdrawERC20_revert_malicious_anotherERC20Transfer()
        public
        testERC20_mintToIpAcct1
    {
        address maliciousFrontend = address(0x456);

        MockERC20 anotherErc20 = new MockERC20();

        anotherErc20.mint(address(ipAcct1), 1000);
        assertEq(anotherErc20.balanceOf(address(ipAcct1)), 1000, "ERC20 balance does not match");

        // Approve TokenWithdrawalModule to transfer tErc20 from IPAccount1
        // signer: tokenWithdrawalModule
        // to: tErc20
        // func: transfer
        _approveERC20(alice, ipAcct1, address(tokenWithdrawalModule));

        // Approve TokenWithdrawalModule to transfer anotherErc20 from IPAccount1
        // signer: tokenWithdrawalModule
        // to: anotherErc20
        // func: transfer
        vm.prank(address(ipAcct1));
        accessController.setPermission(
            address(ipAcct1),
            address(tokenWithdrawalModule),
            address(anotherErc20),
            anotherErc20.transfer.selector,
            AccessPermission.ALLOW
        );

        // Approve a frontend contract to transfer token on behalf of a user (IPAccount1)
        // signer: maliciousFrontend
        // to: tokenWithdrawalModule
        // func: withdrawERC20
        vm.prank(alice);
        ipAcct1.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAcct1),
                maliciousFrontend,
                address(tokenWithdrawalModule),
                tokenWithdrawalModule.withdrawERC20.selector,
                AccessPermission.ALLOW
            )
        );

        //
        // ======= Malicious behavior =======
        // Alice (owner of IPAccount1) only wants the frontend to transfer tErc20. However, because there's no
        // restriction on delegation, the malicious frontend can transfer anotherErc20 as well.
        // ==================================
        //

        vm.startPrank(maliciousFrontend);
        tokenWithdrawalModule.withdrawERC20(payable(ipAcct1), address(tErc20), 1000);
        tokenWithdrawalModule.withdrawERC20(payable(ipAcct1), address(anotherErc20), 1000);
        vm.stopPrank();

        // another token is drained
        assertEq(tErc20.balanceOf(alice), 1000, "ERC20 balance does not match");
        assertEq(anotherErc20.balanceOf(alice), 1000, "ERC20 balance does not match");
    }

    function test_TokenWithdrawalModule_withdrawERC20_revert_moduleCaller_invalidAccess()
        public
        testERC20_mintToIpAcct1
    {
        _approveERC20(alice, ipAcct1, address(tokenWithdrawalModule));

        _expectInvalidAccess(
            address(ipAcct1),
            address(this),
            address(tokenWithdrawalModule),
            tokenWithdrawalModule.withdrawERC20.selector
        );
        tokenWithdrawalModule.withdrawERC20(payable(ipAcct1), address(tErc20), mintAmount20);

        _expectBalanceERC20(address(ipAcct1), mintAmount20);
    }

    function test_TokenWithdrawalModule_withdrawERC721() public {
        uint256 tokenId = tErc721.mint(address(ipAcct1));
        _expectOwnerERC721(address(ipAcct1), tokenId);

        _approveERC721(alice, ipAcct1, address(tokenWithdrawalModule));

        vm.prank(alice);
        tokenWithdrawalModule.withdrawERC721(payable(ipAcct1), address(tErc721), tokenId);

        _expectOwnerERC721(alice, tokenId);
    }

    function test_TokenWithdrawalModule_withdrawERC721_revert_moduleCaller_invalidAccess() public {
        uint256 tokenId = tErc721.mint(address(ipAcct1));
        _expectOwnerERC721(address(ipAcct1), tokenId);

        _approveERC721(alice, ipAcct1, address(tokenWithdrawalModule));

        _expectInvalidAccess(
            address(ipAcct1),
            address(this),
            address(tokenWithdrawalModule),
            tokenWithdrawalModule.withdrawERC721.selector
        );
        tokenWithdrawalModule.withdrawERC721(payable(ipAcct1), address(tErc721), tokenId);

        _expectOwnerERC721(address(ipAcct1), tokenId);
    }

    function test_TokenWithdrawalModule_withdrawERC1155() public {
        uint256 tokenId = 1;
        uint256 mintAmount1155 = 100;
        tErc1155.mintId(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(alice, tokenId, 0);

        _approveERC1155(alice, ipAcct1, address(tokenWithdrawalModule));

        vm.prank(alice);
        tokenWithdrawalModule.withdrawERC1155(payable(ipAcct1), address(tErc1155), tokenId, mintAmount1155);

        _expectBalanceERC1155(address(ipAcct1), tokenId, 0);
        _expectBalanceERC1155(alice, tokenId, mintAmount1155);
    }

    function test_TokenWithdrawalModule_withdrawERC1155_revert_moduleCaller_invalidAccess() public {
        uint256 tokenId = 1;
        uint256 mintAmount1155 = 100;
        tErc1155.mintId(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(alice, tokenId, 0);

        _approveERC1155(alice, ipAcct1, address(tokenWithdrawalModule));

        _expectInvalidAccess(
            address(ipAcct1),
            address(this),
            address(tokenWithdrawalModule),
            tokenWithdrawalModule.withdrawERC1155.selector
        );
        tokenWithdrawalModule.withdrawERC1155(payable(ipAcct1), address(tErc1155), tokenId, mintAmount1155);

        _expectBalanceERC1155(address(ipAcct1), tokenId, mintAmount1155);
        _expectBalanceERC1155(alice, tokenId, 0);
    }

    //
    // Helpers
    //

    function _approveERC20(address owner, IIPAccount ipAccount, address signer) internal {
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                // ipAccount, signer, to, func, permission
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(tErc20),
                tErc20.transfer.selector,
                AccessPermission.ALLOW
            )
        );
    }

    function _approveERC721(address owner, IIPAccount ipAccount, address signer) internal {
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                // ipAccount, signer, to, func, permission
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(tErc721),
                tErc721.transferFrom.selector,
                AccessPermission.ALLOW
            )
        );
    }

    function _approveERC1155(address owner, IIPAccount ipAccount, address signer) internal {
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                // ipAccount, signer, to, func, permission
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(tErc1155),
                tErc1155.safeTransferFrom.selector,
                AccessPermission.ALLOW
            )
        );
    }

    function _expectBalanceERC20(address account, uint256 expected) internal {
        assertEq(tErc20.balanceOf(account), expected, "ERC20 balance does not match");
    }

    function _expectOwnerERC721(address account, uint256 tokenId) internal {
        assertEq(tErc721.ownerOf(tokenId), account, "Owner does not match");
    }

    function _expectBalanceERC1155(address account, uint256 tokenId, uint256 expected) internal {
        assertEq(tErc1155.balanceOf(account, tokenId), expected, "ERC1155 balance does not match");
    }

    function _expectInvalidAccess(address ipAccount, address signer, address to, bytes4 func) internal {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.AccessController__PermissionDenied.selector, ipAccount, signer, to, func)
        );
    }
}
