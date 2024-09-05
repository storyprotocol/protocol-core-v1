/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { BaseTest } from "../utils/BaseTest.t.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IPAccountStorageOps } from "contracts/lib/IPAccountStorageOps.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Test } from "forge-std/Test.sol";
import { ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Test harness contract for IPAssetRegistry
/// @dev This contract is used to test the IPAssetRegistry contract, with a definite set of IP Accounts
contract IPAssetRegistryHarness is Test {
    struct IPAccount {
        uint256 chainId;
        address tokenAddress;
        uint256 tokenId;
    }

    IIPAssetRegistry public ipAssetRegistry;
    IPAccount[] public ipAccounts;
    uint256 public ipAccountCount;
    uint256 public registered;

    constructor(address _ipAssetRegistry) {
        ipAccountCount = 4;
        ipAssetRegistry = IIPAssetRegistry(_ipAssetRegistry);
        for (uint256 i = 0; i < ipAccountCount; i++) {
            ipAccounts.push(IPAccount({ chainId: 100 + i, tokenAddress: address(uint160(200 + i)), tokenId: 300 + i }));
        }
    }

    function addIpAccount(uint256 chainId, address tokenAddress, uint256 tokenId) public {
        ipAccounts.push(IPAccount({ chainId: chainId, tokenAddress: tokenAddress, tokenId: tokenId }));
        ipAccountCount++;
    }

    function register(uint8 index) public {
        vm.warp(10000);
        IPAccount memory ipAccount = ipAccounts[index];
        ipAssetRegistry.register(ipAccount.chainId, ipAccount.tokenAddress, ipAccount.tokenId);
        registered++;
    }
}

/// @notice Base invariants for IPAssetRegistry contract
contract IPAssetRegistryBaseInvariants is BaseTest {
    IPAssetRegistryHarness public harness;
    using IPAccountStorageOps for IIPAccount;

    function setUp() public virtual override {
        super.setUp();

        harness = new IPAssetRegistryHarness(address(ipAssetRegistry));

        targetContract(address(harness));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = harness.register.selector;
        targetSelector(FuzzSelector(address(harness), selectors));

        vm.warp(10000);
    }
}

/// @notice Default invariants for IPAssetRegistry contract
contract IPAssetRegistryInvariants is IPAssetRegistryBaseInvariants {
    using IPAccountStorageOps for IIPAccount;
    using ShortStrings for *;
    using Strings for *;

    /// @dev Invariant: totalSupply() <= ipAccountCount()
    /// @notice The total supply of IP Assets should be less than or equal to ipAccountCount,
    /// as we can at max register ipAccountCount IP Accounts in the harness
    function invariant_totalSupply() public virtual {
        uint256 totalSupply = ipAssetRegistry.totalSupply();
        assertTrue(totalSupply <= harness.ipAccountCount(), "totalSupply() <= ipAccountCount()");
    }

    /// @dev Invariant: checkIpId() == totalSupply()
    /// @notice The IP ID should be equal to the IP Account address,
    /// and the total registered IP Accounts should be equal to the total supply
    function invariant_checkIpId() public {
        uint256 registeredIp = 0;
        for (uint256 i = 0; i < harness.ipAccountCount(); i++) {
            (uint256 chainId, address tokenAddress, uint256 tokenId) = harness.ipAccounts(i);
            address ipId = ipAssetRegistry.ipId(chainId, tokenAddress, tokenId);
            address account = ipAssetRegistry.ipAccount(chainId, tokenAddress, tokenId);
            assertEq(account, ipId);

            if (ipAssetRegistry.isRegistered(ipId)) {
                registeredIp++;
            }
        }
        assertEq(registeredIp, ipAssetRegistry.totalSupply(), "registeredIp == totalSupply()");
        assertEq(registeredIp, harness.registered(), "registeredIp == harness.registered");
    }

    /// @dev Invariant: REGISTRATION_DATE != 0
    /// @notice The registration date should be set for all registered IP Accounts
    function invariant_registrationDate() public {
        for (uint256 i = 0; i < harness.ipAccountCount(); i++) {
            (uint256 chainId, address tokenAddress, uint256 tokenId) = harness.ipAccounts(i);
            address ipId = ipAssetRegistry.ipId(chainId, tokenAddress, tokenId);
            if (ipAssetRegistry.isRegistered(ipId)) {
                vm.prank(address(ipAssetRegistry));
                uint256 registrationDate = IIPAccount(payable(ipId)).getUint256("REGISTRATION_DATE");
                assertNotEq(registrationDate, 0, "REGISTRATION_DATE != 0");
            }
        }
    }

    /// @dev Invariant: NAME != "" && URI == token.tokenURI(tokenId)
    /// @notice The name should not be empty and the URI should not be equal to the tokenURI of the NFT
    function invariant_nameAndUri() public {
        for (uint256 i = 0; i < harness.ipAccountCount(); i++) {
            (uint256 chainId, address tokenAddress, uint256 tokenId) = harness.ipAccounts(i);
            address ipId = ipAssetRegistry.ipId(chainId, tokenAddress, tokenId);
            if (ipAssetRegistry.isRegistered(ipId)) {
                vm.prank(address(ipAssetRegistry));
                string memory name = IIPAccount(payable(ipId)).getString("NAME");
                vm.prank(address(ipAssetRegistry));
                string memory uri = IIPAccount(payable(ipId)).getString("URI");
                assertNotEq(name, "", "NAME != ''");
                if (chainId == block.chainid) {
                    assertEq(uri, IERC721Metadata(tokenAddress).tokenURI(tokenId), "URI == tokenURI(tokenId)");
                }
            }
        }
    }
}

/// @notice Invariants for IPAssetRegistry contract when it is paused
contract IPAssetRegistryPausedInvariants is IPAssetRegistryInvariants {
    using IPAccountStorageOps for IIPAccount;

    function setUp() public override {
        super.setUp();

        vm.prank(u.admin);
        ipAssetRegistry.pause();
    }

    /// @dev Invariant: every function call should revert when the contract is paused
    function invariant_allRevert() public {
        for (uint256 i = 0; i < harness.ipAccountCount(); i++) {
            vm.expectRevert(abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
            harness.register(uint8(i));
        }
    }
}

/// @notice Invariants for IPAssetRegistry contract with all IPs already registered
contract IPAssetRegistryAllRegisteredInvariants is IPAssetRegistryInvariants {
    using IPAccountStorageOps for IIPAccount;

    function setUp() public override {
        super.setUp();
        harness.register(0);
        harness.register(1);
        harness.register(2);
        harness.register(3);
    }

    /// @dev Invariant: every registration should revert when the IP Account is already registered
    function invariant_allRevert() public {
        for (uint256 i = 0; i < harness.ipAccountCount(); i++) {
            vm.expectRevert(abi.encodeWithSelector(Errors.IPAssetRegistry__AlreadyRegistered.selector));
            harness.register(uint8(i));
        }
    }
}

/// @notice Mock NFT contracts for testing, with `ownerOf` always returning address(0)
/// and `supportsInterface` returning false for different interfaces
/// @dev This shall make registry revert when trying to register the IP Account
contract BrokenMockNFT1 {
    function supportsInterface(bytes4) external pure returns (bool) {
        return false;
    }

    function ownerOf(uint256) external pure returns (address) {
        return address(0);
    }
}

/// @notice Mock NFT contracts for testing, with `ownerOf` always returning address(1)
/// and `supportsInterface` returning false for different interfaces
/// @dev This shall make registry revert when trying to register the IP Account
contract BrokenMockNFT2 {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    function ownerOf(uint256) external pure returns (address) {
        return address(1);
    }
}

/// @notice Mock NFT contracts for testing, with `ownerOf` always returning address(0)
/// and `supportsInterface` returning false for different interfaces
/// @dev This shall make registry revert when trying to register the IP Account
contract BrokenMockNFT3 {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721).interfaceId;
    }

    function ownerOf(uint256) external pure returns (address) {
        return address(0);
    }
}

/// @notice Mock NFT contracts for testing, with `ownerOf` always returning address(0)
/// and `supportsInterface` returning false for different interfaces
/// @dev This shall make registry revert when trying to register the IP Account
contract BrokenMockNFT4 {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721Metadata).interfaceId;
    }

    function ownerOf(uint256) external pure returns (address) {
        return address(0);
    }
}

/// @notice Mock NFT contracts for testing, with `ownerOf` always returning address(1)
/// and `supportsInterface` returning false for different interfaces
/// @dev This shall make registry revert when trying to register the IP Account
contract BrokenMockNFT5 {
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC721Metadata).interfaceId;
    }

    function ownerOf(uint256) external pure returns (address) {
        return address(1);
    }
}

/// @notice Mock NFT contracts for testing, like WETH
/// @dev This shall make registry revert when trying to register the IP Account
contract BrokenMockNFT6 {
    fallback() external {}
}

/// @notice Invariants for IPAssetRegistry contract when IP to register has the token contract on the same chain
contract IPAssetRegistrySameChainInvariants is IPAssetRegistryInvariants {
    using IPAccountStorageOps for IIPAccount;

    uint256 crossChainIpAccountCount;
    uint256 localChainIpAccountValidContractCount = 4;
    uint256 localChainIpAccountInvalidContractCount = 0;

    function setUp() public override {
        super.setUp();

        crossChainIpAccountCount = harness.ipAccountCount();

        for (uint256 i = 0; i < localChainIpAccountValidContractCount; i++) {
            // register for existing token
            mockNFT.mintId(address(this), 1000 + i);
            harness.addIpAccount(block.chainid, address(mockNFT), 1000 + i);
        }

        address[] memory invalidContracts = new address[](6);
        invalidContracts[0] = address(new BrokenMockNFT1());
        invalidContracts[1] = address(new BrokenMockNFT2());
        invalidContracts[2] = address(new BrokenMockNFT3());
        invalidContracts[3] = address(new BrokenMockNFT4());
        invalidContracts[4] = address(new BrokenMockNFT5());
        invalidContracts[5] = address(new BrokenMockNFT6());

        for (uint256 i = 1; i < invalidContracts.length; i++) {
            harness.addIpAccount(block.chainid, invalidContracts[i], 2000 + i);
            uint8 id = uint8(harness.ipAccountCount() - 1);
            vm.expectRevert();
            harness.register(id);
            localChainIpAccountInvalidContractCount++;
        }
    }

    /// @dev Invariant: totalSupply() <= ipAccountCount() + localChainIpAccountValidContractCount
    function invariant_totalSupply() public override {
        uint256 totalSupply = ipAssetRegistry.totalSupply();
        assertTrue(
            totalSupply <= crossChainIpAccountCount + localChainIpAccountValidContractCount,
            "totalSupply() <= ipAccountCount() + localChainIpAccountValidContractCount"
        );
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
