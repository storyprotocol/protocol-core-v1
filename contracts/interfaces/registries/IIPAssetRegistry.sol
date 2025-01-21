// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IIPAccountRegistry } from "./IIPAccountRegistry.sol";

/// @title Interface for IP Account Registry
/// @notice This interface manages the registration and tracking of IP Accounts
interface IIPAssetRegistry is IIPAccountRegistry {
    /// @notice Emits when an IP is officially registered into the protocol.
    /// @param ipId The canonical identifier for the IP.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The token contract address of the IP NFT.
    /// @param tokenId The token identifier of the IP.
    /// @param name The name of the IP.
    /// @param uri The URI of the IP.
    /// @param registrationDate The date and time the IP was registered.
    event IPRegistered(
        address ipId,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        string name,
        string uri,
        uint256 registrationDate
    );

    /// @notice Emits when an IP registration fee is paid.
    /// @param payer The address of the account that paid the fee.
    /// @param treasury The address of the treasury that received the fee.
    /// @param feeToken The address of the token used to pay the fee.
    /// @param amount The amount of the fee paid.
    event IPRegistrationFeePaid(
        address indexed payer,
        address indexed treasury,
        address indexed feeToken,
        uint96 amount
    );

    /// @notice Emits when an IP registration fee is set.
    /// @param treasury The address of the treasury that will receive the fee.
    /// @param feeToken The address of the token used to pay the fee.
    /// @param feeAmount The amount of the fee.
    event RegistrationFeeSet(address indexed treasury, address indexed feeToken, uint96 feeAmount);

    /// @notice Sets the registration fee for IP assets.
    /// @param treasury The address of the treasury that will receive the fee.
    /// @param feeToken The address of the token used to pay the fee.
    /// @param feeAmount The amount of the fee.
    function setRegistrationFee(address treasury, address feeToken, uint96 feeAmount) external;

    /// @notice Tracks the total number of IP assets in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Registers an NFT as an IP asset.
    /// @param chainid The chain identifier of where the IP NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @return id The address of the newly registered IP.
    function register(uint256 chainid, address tokenContract, uint256 tokenId) external returns (address id);

    /// @notice Upgrades the IP account implementation.
    /// @param newIpAccountImpl The address of the new IP account implementation.
    function upgradeIPAccountImpl(address newIpAccountImpl) external;

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return ipId The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address);

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return isRegistered Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool);

    /// @notice Retrieves the treasury address for IP assets.
    /// @return treasury The address of the treasury.
    function getTreasury() external view returns (address);

    /// @notice Retrieves the registration fee token for IP assets.
    /// @return feeToken The address of the token used to pay the fee.
    function getFeeToken() external view returns (address);

    /// @notice Retrieves the registration fee amount for IP assets.
    /// @return feeAmount The amount of the fee.
    function getFeeAmount() external view returns (uint96);
}
