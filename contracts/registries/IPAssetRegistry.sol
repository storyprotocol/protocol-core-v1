// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IIPAccount } from "../interfaces/IIPAccount.sol";
import { GroupIPAssetRegistry } from "./GroupIPAssetRegistry.sol";
import { IIPAssetRegistry } from "../interfaces/registries/IIPAssetRegistry.sol";
import { ProtocolPausableUpgradeable } from "../pause/ProtocolPausableUpgradeable.sol";
import { IPAccountRegistry } from "../registries/IPAccountRegistry.sol";
import { Errors } from "../lib/Errors.sol";
import { IPAccountStorageOps } from "../lib/IPAccountStorageOps.sol";

/// @title IP Asset Registry
/// @notice This contract acts as the source of truth for all IP registered in
///         Story Protocol. An IP is identified by its contract address, token
///         id, and coin type, meaning any NFT may be conceptualized as an IP.
///         Once an IP is registered into the protocol, a corresponding IP
///         asset is generated, which references an IP resolver for metadata
///         attribution and an IP account for protocol authorization.
///         IMPORTANT: The IP account address, besides being used for protocol
///                    auth, is also the canonical IP identifier for the IP NFT.
contract IPAssetRegistry is
    IIPAssetRegistry,
    IPAccountRegistry,
    ProtocolPausableUpgradeable,
    GroupIPAssetRegistry,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the IPAssetRegistry
    /// @notice Tracks the total number of IP assets in existence.
    /// @param totalSupply The total number of IP assets registered.
    /// @param treasury The address of the treasury that receives registration fees.
    /// @param feeToken The address of the token used to pay registration fees.
    /// @param feeAmount The amount of the registration fee.
    /// @custom:storage-location erc7201:story-protocol.IPAssetRegistry
    struct IPAssetRegistryStorage {
        uint256 totalSupply;
        address treasury;
        address feeToken;
        uint96 feeAmount;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.IPAssetRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IPAssetRegistryStorageLocation =
        0x987c61809af5a42943abd137c7acff8426aab6f7a1f5c967a03d1d718ba5cf00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address erc6551Registry,
        address ipAccountImpl,
        address groupingModule,
        address ipAccountImplBeacon
    ) IPAccountRegistry(erc6551Registry, ipAccountImpl, ipAccountImplBeacon) GroupIPAssetRegistry(groupingModule) {
        _disableInitializers();
    }

    /// @notice Initializes the IPAssetRegistry contract.
    /// @param accessManager The address of the access manager.
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.IPAssetRegistry__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @notice Registers an NFT as an IP asset and creates an IP account for it.
    ///         if the IP was already registered, return the IP address.
    /// @dev The IP required metadata name and URI are derived from the NFT's metadata.
    /// @param chainid The chain identifier of where the IP NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @return id The address of the newly registered IP.
    function register(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId
    ) external whenNotPaused returns (address id) {
        id = _register({
            chainid: chainid,
            tokenContract: tokenContract,
            tokenId: tokenId,
            registerFeePayer: msg.sender
        });
    }

    function _register(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId,
        address registerFeePayer
    ) internal override returns (address id) {
        id = _registerIpAccount(chainid, tokenContract, tokenId);
        IIPAccount ipAccount = IIPAccount(payable(id));

        // return if the IP was already registered
        if (bytes(ipAccount.getString("NAME")).length != 0) {
            return id;
        }

        IPAssetRegistryStorage storage $ = _getIPAssetRegistryStorage();
        // Pay registration fee
        uint96 feeAmount = $.feeAmount;
        if (feeAmount > 0) {
            address feeToken = $.feeToken;
            address treasury = $.treasury;
            IERC20(feeToken).safeTransferFrom(registerFeePayer, treasury, uint256(feeAmount));
            emit IPRegistrationFeePaid(registerFeePayer, treasury, feeToken, feeAmount);
        }

        (string memory name, string memory uri) = _getNameAndUri(chainid, tokenContract, tokenId);
        uint256 registrationDate = block.timestamp;
        ipAccount.setString("NAME", name);
        ipAccount.setString("URI", uri);
        ipAccount.setUint256("REGISTRATION_DATE", registrationDate);

        $.totalSupply++;

        emit IPRegistered(id, chainid, tokenContract, tokenId, name, uri, registrationDate);
    }

    /// @notice Sets the registration fee for IP assets.
    /// @param treasury The address of the treasury that will receive the fee.
    /// @param feeToken The address of the token used to pay the fee.
    /// @param feeAmount The amount of the fee.
    function setRegistrationFee(address treasury, address feeToken, uint96 feeAmount) external restricted {
        if (feeAmount > 0) {
            if (treasury == address(0)) revert Errors.IPAssetRegistry__ZeroAddress("treasury");
            if (feeToken == address(0)) revert Errors.IPAssetRegistry__ZeroAddress("feeToken");
        }
        IPAssetRegistryStorage storage $ = _getIPAssetRegistryStorage();
        $.feeToken = feeToken;
        $.feeAmount = feeAmount;
        $.treasury = treasury;
        emit RegistrationFeeSet(treasury, feeToken, feeAmount);
    }

    /// @notice Upgrades the IP account implementation.
    /// @param newIpAccountImpl The address of the new IP account implementation.
    function upgradeIPAccountImpl(address newIpAccountImpl) external restricted {
        _upgradeIPAccountImpl(newIpAccountImpl);
    }

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return ipId The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return super.ipAccount(chainId, tokenContract, tokenId);
    }

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return isRegistered Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool) {
        return _isRegistered(id);
    }

    /// @notice Gets the total number of IP assets registered in the protocol.
    function totalSupply() external view returns (uint256) {
        return _getIPAssetRegistryStorage().totalSupply;
    }

    /// @notice Retrieves the treasury address for IP assets.
    /// @return treasury The address of the treasury.
    function getTreasury() external view returns (address) {
        return _getIPAssetRegistryStorage().treasury;
    }

    /// @notice Retrieves the registration fee token for IP assets.
    /// @return feeToken The address of the token used to pay the fee.
    function getFeeToken() external view returns (address) {
        return _getIPAssetRegistryStorage().feeToken;
    }

    /// @notice Retrieves the registration fee amount for IP assets.
    /// @return feeAmount The amount of the fee.
    function getFeeAmount() external view returns (uint96) {
        return _getIPAssetRegistryStorage().feeAmount;
    }

    /// @dev Retrieves the name and URI of from IP NFT.
    function _getNameAndUri(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (string memory name, string memory uri) {
        if (chainid != block.chainid) {
            name = string.concat(chainid.toString(), ": ", tokenContract.toHexString(), " #", tokenId.toString());
            uri = "";
            return (name, uri);
        }
        // Handle NFT on the same chain
        if (!tokenContract.supportsInterface(type(IERC721).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721(tokenContract);
        }

        if (IERC721(tokenContract).ownerOf(tokenId) == address(0)) {
            revert Errors.IPAssetRegistry__InvalidToken(tokenContract, tokenId);
        }

        if (!tokenContract.supportsInterface(type(IERC721Metadata).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721Metadata(tokenContract);
        }

        name = string.concat(
            block.chainid.toString(),
            ": ",
            IERC721Metadata(tokenContract).name(),
            " #",
            tokenId.toString()
        );
        uri = IERC721Metadata(tokenContract).tokenURI(tokenId);
    }

    function _isRegistered(address id) internal view override returns (bool) {
        if (id == address(0)) return false;
        if (id.code.length == 0) return false;
        if (!ERC165Checker.supportsInterface(id, type(IIPAccount).interfaceId)) return false;
        (uint chainId, address tokenContract, uint tokenId) = IIPAccount(payable(id)).token();
        if (id != ipAccount(chainId, tokenContract, tokenId)) return false;
        return bytes(IIPAccount(payable(id)).getString("NAME")).length != 0;
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of IPAssetRegistry.
    function _getIPAssetRegistryStorage() private pure returns (IPAssetRegistryStorage storage $) {
        assembly {
            $.slot := IPAssetRegistryStorageLocation
        }
    }
}
