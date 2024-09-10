// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
// import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { IERC6551Account } from "erc6551/interfaces/IERC6551Account.sol";

import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";
import { IIPAccountStorage } from "../../contracts/interfaces/IIPAccountStorage.sol";
import { Errors } from "../../contracts/lib/Errors.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";

contract IPAccountImplBTT is BaseTest {
    IIPAccount private ipAcct;
    uint256 private chainId = block.chainid;
    uint256 private tokenId = 55555;

    address private ipOwner;
    address private signer;
    address private to;
    bytes private data;

    bytes private mockModuleDataSuccess = abi.encodeWithSignature("executeSuccessfully(string)", "success");
    bytes private mockModuleDataRevert = abi.encodeWithSignature("executeRevert()");

    function setUp() public override {
        super.setUp();

        ipOwner = u.alice;
        mockNFT.mintId(ipOwner, tokenId);
        ipAcct = IIPAccount(payable(ipAssetRegistry.register(chainId, address(mockNFT), tokenId)));
    }

    function test_IPAccountImpl_supportsInterface() public {
        assertTrue(ipAcct.supportsInterface(type(IIPAccount).interfaceId));
        assertTrue(ipAcct.supportsInterface(type(IIPAccountStorage).interfaceId));
        assertTrue(ipAcct.supportsInterface(type(IERC6551Account).interfaceId));
        assertTrue(ipAcct.supportsInterface(type(IERC721Receiver).interfaceId));
        assertTrue(ipAcct.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertTrue(ipAcct.supportsInterface(type(IERC1155Receiver).interfaceId));
        assertTrue(ipAcct.supportsInterface(type(IERC165).interfaceId));
    }

    function test_IPAccountImpl_token() public {
        (uint256 chainId_, address tokenAddress_, uint256 tokenId_) = ipAcct.token();
        assertEq(chainId_, chainId);
        assertEq(tokenAddress_, address(mockNFT));
        assertEq(tokenId_, tokenId);
    }

    modifier whenDataLenIsGT0AndLT4() {
        data = "123";
        _;
    }

    function test_IPAccountImpl_revert_isValidSigner_whenDataLenIsGT0AndLT4() public whenDataLenIsGT0AndLT4 {
        signer = ipOwner;
        vm.prank(signer);
        vm.expectRevert(Errors.IPAccount__InvalidCalldata.selector);
        assertEq(ipAcct.isValidSigner(signer, data), bytes4(0));
    }

    modifier whenDataLenIsZeroOrGTE4(bytes memory data_) {
        require(data_.length == 0 || data_.length >= 4, "data length must be 0 or >= 4");
        data = data_;
        _;
    }

    modifier whenSignerIsNotOwner() {
        signer = u.bob;
        vm.startPrank(signer);
        _;
    }

    function test_IPAccountImpl_revert_isValidSigner_inAccessControllerFail()
        public
        whenDataLenIsZeroOrGTE4("")
        whenSignerIsNotOwner
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__BothCallerAndRecipientAreNotRegisteredModule.selector,
                address(signer),
                bytes4(0)
            )
        );
        ipAcct.isValidSigner(signer, data);
    }

    modifier whenSignerIsOwner() {
        signer = ipOwner;
        vm.startPrank(signer);
        _;
    }

    function test_IPAccountImpl_isValidSigner_inAccessControllerSucceed()
        public
        whenDataLenIsZeroOrGTE4("")
        whenSignerIsOwner
    {
        assertEq(ipAcct.isValidSigner(signer, data), IERC6551Account.isValidSigner.selector);
    }

    modifier toIsRegisteredModule() {
        vm.stopPrank();
        vm.startPrank(u.admin);
        MockModule mockModule = new MockModule(address(ipAssetRegistry), address(moduleRegistry), "MockModule");
        moduleRegistry.registerModule(mockModule.name(), address(mockModule));
        to = address(mockModule);
        vm.startPrank(signer); // back to the original prank
        _;
    }

    function test_IPAccountImpl_execute_revert_invalidSigner()
        public
        whenDataLenIsZeroOrGTE4(mockModuleDataSuccess)
        whenSignerIsNotOwner
        toIsRegisteredModule
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAcct),
                signer,
                to,
                MockModule.executeSuccessfully.selector
            )
        );
        ipAcct.execute(to, 0, data);
    }

    function test_IPAccountImpl_execute_resultSuccess()
        public
        whenDataLenIsZeroOrGTE4(mockModuleDataSuccess)
        whenSignerIsOwner
        toIsRegisteredModule
    {
        bytes32 expectedState = keccak256(
            abi.encode(ipAcct.state(), abi.encodeWithSelector(ipAcct.execute.selector, to, 0, data))
        );

        vm.expectEmit(address(ipAcct));
        emit IIPAccount.Executed(to, 0, data, expectedState);
        bytes memory result = ipAcct.execute(to, 0, data);

        assertEq(abi.decode(result, (string)), "success");
        assertEq(ipAcct.state(), expectedState);
    }

    function test_IPAccountImpl_execute_resultRevert()
        public
        whenDataLenIsZeroOrGTE4(mockModuleDataRevert)
        whenSignerIsOwner
        toIsRegisteredModule
    {
        bytes32 expectedState = ipAcct.state();

        vm.expectRevert("MockModule: executeRevert");
        ipAcct.execute(to, 0, data);

        assertEq(ipAcct.state(), expectedState);
    }

    function test_IPAccountImpl_receiveERC721() public {
        assertEq(
            IERC721Receiver(address(ipAcct)).onERC721Received(ipOwner, address(0), 111, ""),
            IERC721Receiver.onERC721Received.selector
        );
    }

    function test_IPAccountImpl_receiveERC1155() public {
        assertEq(
            IERC1155Receiver(address(ipAcct)).onERC1155Received(ipOwner, address(0), 111, 1, ""),
            IERC1155Receiver.onERC1155Received.selector
        );

        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);

        assertEq(
            IERC1155Receiver(address(ipAcct)).onERC1155BatchReceived(ipOwner, address(0), ids, values, ""),
            IERC1155Receiver.onERC1155BatchReceived.selector
        );
    }
}
