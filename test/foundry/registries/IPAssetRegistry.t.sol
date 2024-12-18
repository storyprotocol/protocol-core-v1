// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IPAccountStorageOps } from "contracts/lib/IPAccountStorageOps.sol";
import { ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { MockERC721WithoutMetadata } from "test/foundry/mocks/token/MockERC721WithoutMetadata.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

contract MockIPAccountRegistry is IPAccountRegistry {
    constructor(address erc6551Registry, address ipAccountImpl) IPAccountRegistry(erc6551Registry, ipAccountImpl) {}

    function registerIpAccount(uint256 chainId, address tokenContract, uint256 tokenId) public returns (address) {
        return _registerIpAccount(chainId, tokenContract, tokenId);
    }
}

/// @title IP Asset Registry Testing Contract
/// @notice Contract for testing core IP registration.
contract IPAssetRegistryTest is BaseTest {
    using IPAccountStorageOps for IIPAccount;
    using ShortStrings for *;
    using Strings for *;
    // Default IP record attributes.
    string public constant IP_NAME = "IPAsset";
    string public constant IP_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant IP_HASH = "0x0f";
    string public constant IP_EXTERNAL_URL = "https://storyprotocol.xyz";

    IPAssetRegistry public registry;

    address public tokenAddress;
    uint256 public tokenId;
    address public ipId;

    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /// @notice Initializes the IP asset registry testing contract.
    function setUp() public virtual override {
        super.setUp();

        registry = ipAssetRegistry;

        tokenAddress = address(mockNFT);
        tokenId = mockNFT.mintId(alice, 99);

        assertEq(ipAccountRegistry.getIPAccountImpl(), address(ipAccountImpl));
        ipId = _getIPAccount(block.chainid, tokenId);
    }

    /// @notice Tests retrieval of IP canonical IDs.
    function test_IPAssetRegistry_IpId() public {
        assertEq(registry.ipId(block.chainid, tokenAddress, tokenId), _getIPAccount(block.chainid, tokenId));
    }

    /// @notice Tests registration of IP permissionlessly.
    function test_IPAssetRegistry_RegisterPermissionless() public {
        uint256 totalSupply = registry.totalSupply();

        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));
        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            name,
            "https://storyprotocol.xyz/erc721/99",
            block.timestamp
        );
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId);

        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "NAME"), name);
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "URI"), "https://storyprotocol.xyz/erc721/99");
        assertEq(IIPAccount(payable(ipId)).getUint256(address(registry), "REGISTRATION_DATE"), block.timestamp);
    }

    function test_IPAssetRegistry_SetRegisterFee() public {
        address treasury = address(0x123);
        vm.prank(u.admin);
        vm.expectEmit();
        emit IIPAssetRegistry.RegistrationFeeSet(treasury, address(erc20), 1000);
        registry.setRegistrationFee(treasury, address(erc20), 1000);

        assertEq(registry.getTreasury(), treasury, "Treasury not set");
        assertEq(registry.getFeeToken(), address(erc20), "Fee token not set");
        assertEq(registry.getFeeAmount(), 1000, "Fee amount not set");
    }

    function test_IPAssetRegistry_revert_SetRegisterFeeZeroTreasury() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.IPAssetRegistry__ZeroAddress.selector, "treasury"));
        vm.prank(u.admin);
        registry.setRegistrationFee(address(0), address(erc20), 1000);
    }

    function test_IPAssetRegistry_revert_SetRegisterFeeZeroTokenAddress() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.IPAssetRegistry__ZeroAddress.selector, "feeToken"));
        vm.prank(u.admin);
        registry.setRegistrationFee(address(0x123), address(0), 1000);
    }

    function test_IPAssetRegistry_resetRegisterFeeBackToZero() public {
        address treasury = address(0x123);
        vm.prank(u.admin);
        vm.expectEmit();
        emit IIPAssetRegistry.RegistrationFeeSet(treasury, address(erc20), 1000);
        registry.setRegistrationFee(treasury, address(erc20), 1000);

        assertEq(registry.getTreasury(), treasury, "Treasury not set");
        assertEq(registry.getFeeToken(), address(erc20), "Fee token not set");
        assertEq(registry.getFeeAmount(), 1000, "Fee amount not set");

        vm.prank(u.admin);
        vm.expectEmit();
        emit IIPAssetRegistry.RegistrationFeeSet(address(0), address(0), 0);
        registry.setRegistrationFee(address(0), address(0), 0);

        assertEq(registry.getTreasury(), address(0), "Treasury not reset");
        assertEq(registry.getFeeToken(), address(0), "Fee token not reset");
        assertEq(registry.getFeeAmount(), 0, "Fee amount not reset");
    }

    /// @notice Tests registration of IP permissionlessly.
    function test_IPAssetRegistry_RegisterWithPayRegisterFee() public {
        address treasury = address(0x123);
        vm.prank(u.admin);
        vm.expectEmit();
        emit IIPAssetRegistry.RegistrationFeeSet(treasury, address(erc20), 1000);
        registry.setRegistrationFee(treasury, address(erc20), 1000);

        erc20.mint(alice, 1000);
        vm.prank(alice);
        erc20.approve(address(registry), 1000);

        uint256 totalSupply = registry.totalSupply();

        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistrationFeePaid(alice, treasury, address(erc20), 1000);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            name,
            "https://storyprotocol.xyz/erc721/99",
            block.timestamp
        );
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId);

        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "NAME"), name);
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "URI"), "https://storyprotocol.xyz/erc721/99");
        assertEq(IIPAccount(payable(ipId)).getUint256(address(registry), "REGISTRATION_DATE"), block.timestamp);
    }

    function test_IPAssetRegistry_RegisterWithPayRegisterFee_Twice() public {
        address treasury = address(0x123);
        vm.prank(u.admin);
        vm.expectEmit();
        emit IIPAssetRegistry.RegistrationFeeSet(treasury, address(erc20), 1000);
        registry.setRegistrationFee(treasury, address(erc20), 1000);

        erc20.mint(alice, 1000);
        uint256 alicePreviousBalance = erc20.balanceOf(alice);
        vm.prank(alice);
        erc20.approve(address(registry), 1000);

        uint256 totalSupply = registry.totalSupply();

        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistrationFeePaid(alice, treasury, address(erc20), 1000);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            name,
            "https://storyprotocol.xyz/erc721/99",
            block.timestamp
        );
        vm.prank(alice);
        address ipId = registry.register(block.chainid, tokenAddress, tokenId);

        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "NAME"), name);
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "URI"), "https://storyprotocol.xyz/erc721/99");
        assertEq(IIPAccount(payable(ipId)).getUint256(address(registry), "REGISTRATION_DATE"), block.timestamp);
        assertEq(erc20.balanceOf(treasury), 1000);
        assertEq(erc20.balanceOf(alice), alicePreviousBalance - 1000);

        totalSupply = registry.totalSupply();
        alicePreviousBalance = erc20.balanceOf(alice);

        vm.prank(alice);
        address newIpId = registry.register(block.chainid, tokenAddress, tokenId);

        assertEq(ipId, newIpId);
        assertEq(erc20.balanceOf(treasury), 1000);
        assertEq(erc20.balanceOf(alice), alicePreviousBalance);
        assertEq(totalSupply, registry.totalSupply());
        assertTrue(IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "NAME"), name);
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "URI"), "https://storyprotocol.xyz/erc721/99");
        assertEq(IIPAccount(payable(ipId)).getUint256(address(registry), "REGISTRATION_DATE"), block.timestamp);
    }

    /// @notice Tests registration of IP permissionlessly.
    function test_IPAssetRegistry_revert_RegisterNotEnoughRegisterFee() public {
        address treasury = address(0x123);
        vm.prank(u.admin);
        vm.expectEmit();
        emit IIPAssetRegistry.RegistrationFeeSet(treasury, address(erc20), 1000);
        registry.setRegistrationFee(treasury, address(erc20), 1000);

        erc20.mint(alice, 100);
        vm.prank(alice);
        erc20.approve(address(registry), 100);

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, address(registry), 100, 1000));
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId);
    }

    /// @notice Tests registration of IP permissionlessly for IPAccount already created.
    function test_IPAssetRegistry_RegisterPermissionless_IPAccountAlreadyExist() public {
        uint256 totalSupply = registry.totalSupply();
        erc6551Registry.createAccount(
            ipAccountRegistry.IP_ACCOUNT_IMPL(),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            tokenAddress,
            tokenId
        );
        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            name,
            "https://storyprotocol.xyz/erc721/99",
            block.timestamp
        );
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId);

        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "NAME"), name);
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "URI"), "https://storyprotocol.xyz/erc721/99");
        assertEq(IIPAccount(payable(ipId)).getUint256(address(registry), "REGISTRATION_DATE"), block.timestamp);
    }

    /// @notice Tests registration of the same IP twice.
    function test_IPAssetRegistry_revert_RegisterPermissionlessTwice() public {
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));

        vm.prank(alice);
        string memory name = string.concat(block.chainid.toString(), ": Ape #99");
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            name,
            "https://storyprotocol.xyz/erc721/99",
            block.timestamp
        );
        address ipId = registry.register(block.chainid, tokenAddress, tokenId);

        vm.prank(alice);
        address ipIdAgain = registry.register(block.chainid, tokenAddress, tokenId);
        assertEq(ipId, ipIdAgain);
    }

    function test_IPAssetRegistry_revert_paused() public {
        vm.prank(u.admin);
        registry.pause();

        vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        registry.register(1, tokenAddress, tokenId);
    }

    /// @notice Tests registration of IP with non ERC721 token.
    function test_IPAssetRegistry_revert_InvalidTokenContract() public {
        // not an ERC721 contract
        vm.expectRevert(abi.encodeWithSelector(Errors.IPAssetRegistry__UnsupportedIERC721.selector, address(0x12345)));
        registry.register(block.chainid, address(0x12345), 1);

        // not implemented ERC721Metadata contract
        MockERC721WithoutMetadata erc721WithoutMetadata = new MockERC721WithoutMetadata();
        erc721WithoutMetadata.mint(alice, 1);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.IPAssetRegistry__UnsupportedIERC721Metadata.selector, erc721WithoutMetadata)
        );
        registry.register(block.chainid, address(erc721WithoutMetadata), 1);
    }

    /// @notice Tests registration of IP with non-exist NFT.
    function test_IPAssetRegistry_revert_InvalidNFTToken() public {
        MockERC721WithoutMetadata erc721WithoutMetadata = new MockERC721WithoutMetadata();
        erc721WithoutMetadata.mint(alice, 1);
        // non exist token id
        vm.expectRevert(
            abi.encodeWithSelector(Errors.IPAssetRegistry__InvalidToken.selector, erc721WithoutMetadata, 999)
        );
        registry.register(block.chainid, address(erc721WithoutMetadata), 999);
    }

    function test_IPAssetRegistry_not_registered() public {
        assertTrue(!registry.isRegistered(address(0)));
        assertTrue(!registry.isRegistered(address(0x12345)));
        assertTrue(!registry.isRegistered(address(this)));
        mockNFT.mintId(alice, 1000);
        assertTrue(
            !registry.isRegistered(
                erc6551Registry.createAccount(
                    ipAccountRegistry.IP_ACCOUNT_IMPL(),
                    ipAccountRegistry.IP_ACCOUNT_SALT(),
                    block.chainid,
                    address(mockNFT),
                    1000
                )
            )
        );
    }

    /// @notice Tests registration of IP NFT from other chain.
    function test_IPAssetRegistry_RegisterPermissionless_CrossChain() public {
        uint256 totalSupply = registry.totalSupply();
        tokenAddress = address(0x12345);
        tokenId = 1;
        uint256 chainid = 55555555;

        ipId = _getIPAccount(chainid, tokenId);

        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAssetRegistry, chainid, tokenAddress, tokenId));
        string memory name = string.concat(
            chainid.toString(),
            ": ",
            tokenAddress.toHexString(),
            " #",
            tokenId.toString()
        );
        vm.expectEmit();
        emit IIPAssetRegistry.IPRegistered(ipId, chainid, tokenAddress, tokenId, name, "", block.timestamp);
        address registeredIpId = registry.register(chainid, tokenAddress, tokenId);

        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(IPAccountChecker.isRegistered(ipAssetRegistry, chainid, tokenAddress, tokenId));
        assertEq(IIPAccount(payable(ipId)).getString(address(registry), "NAME"), name);
        assertEq(IIPAccount(payable(ipId)).getUint256(address(registry), "REGISTRATION_DATE"), block.timestamp);
    }

    /// @notice Tests registration of the same IP twice from cross chain.
    function test_IPAssetRegistry_revert_RegisterPermissionlessTwice_CrossChain() public {
        tokenAddress = address(0x12345);
        tokenId = 1;
        uint256 chainid = 55555555;

        ipId = _getIPAccount(chainid, tokenId);
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAssetRegistry, block.chainid, tokenAddress, tokenId));

        address ipId = registry.register(chainid, tokenAddress, tokenId);

        address ipIdAgain = registry.register(chainid, tokenAddress, tokenId);
        assertEq(ipId, ipIdAgain);
    }

    function test_IPAssetRegistry_revert_registerWithDummyIPAccountRegister() public {
        MockIPAccountRegistry mockIpAccountRegistry = new MockIPAccountRegistry(
            ipAccountRegistry.ERC6551_PUBLIC_REGISTRY(),
            ipAccountRegistry.IP_ACCOUNT_IMPL()
        );
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        mockNFT.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = mockIpAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);
        assertTrue(!IPAccountChecker.isIpAccount(ipAssetRegistry, account));
    }

    /// @notice Helper function for generating an account address.
    function _getIPAccount(uint256 chainid, uint256 _tokenId) internal view returns (address) {
        return
            erc6551Registry.account(
                address(ipAccountImpl),
                ipAccountRegistry.IP_ACCOUNT_SALT(),
                chainid,
                tokenAddress,
                _tokenId
            );
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}
