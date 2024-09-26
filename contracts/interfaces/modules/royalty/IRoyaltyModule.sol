// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "../../modules/base/IModule.sol";

/// @title RoyaltyModule interface
interface IRoyaltyModule is IModule {
    /// @notice Event emitted when the treasury is set
    /// @param treasury The address of the treasury
    event TreasurySet(address treasury);

    /// @notice Event emitted when the royalty fee is set
    /// @param royaltyFeePercent The royalty fee percent
    event RoyaltyFeePercentSet(uint256 royaltyFeePercent);

    /// @notice Event emitted when a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);

    /// @notice Event emitted when a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @param allowed Indicates if the royalty token is whitelisted or not
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);

    /// @notice Event emitted when royalties are paid
    /// @param receiverIpId The ID of IP asset that receives the royalties
    /// @param payerIpId The ID of IP asset that pays the royalties
    /// @param sender The address that pays the royalties on behalf of the payer ID of IP asset
    /// @param token The token that is used to pay the royalties
    /// @param amount The amount that is paid
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);

    /// @notice Event emitted when the license minting fee is paid
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token that is used to pay the royalties
    /// @param amount The amount paid
    event LicenseMintingFeePaid(address receiverIpId, address payerAddress, address token, uint256 amount);

    /// @notice Event emitted when a royalty policy is registered
    /// @param externalRoyaltyPolicy The address of the external royalty policy
    event ExternalRoyaltyPolicyRegistered(address externalRoyaltyPolicy);

    /// @notice Event emitted when the IP graph limits are updated
    /// @param maxParents The maximum number of parents an IP asset can have
    /// @param maxAncestors The maximum number of ancestors an IP asset can have
    /// @param accumulatedRoyaltyPoliciesLimit The maximum number of accumulated royalty policies an IP asset can have
    event IpGraphLimitsUpdated(uint256 maxParents, uint256 maxAncestors, uint256 accumulatedRoyaltyPoliciesLimit);

    /// @notice Event emitted when a license is minted
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param royaltyPolicy The royalty policy address of the license being minted
    /// @param licensePercent The license percentage of the license being minted
    /// @param externalData The external data custom to the royalty policy being minted
    event LicensedWithRoyalty(address ipId, address royaltyPolicy, uint32 licensePercent, bytes externalData);

    /// @notice Event emitted when an IP asset is linked to parents
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseRoyaltyPolicies The royalty policies of the each parent license being used to link
    /// @param licensesPercent The license percentage of the licenses of each parent being used to link
    /// @param externalData The external data custom to each the royalty policy being used to link
    event LinkedToParents(
        address ipId,
        address[] parentIpIds,
        address[] licenseRoyaltyPolicies,
        uint32[] licensesPercent,
        bytes externalData
    );

    /// @notice Event emitted when an IP royalty vault is deployed
    /// @param ipId The ipId of IP asset
    /// @param ipRoyaltyVault The address of the royalty vault
    event IpRoyaltyVaultDeployed(address ipId, address ipRoyaltyVault);

    /// @notice Sets the treasury address
    /// @dev Enforced to be only callable by the protocol admin
    /// @param treasury The address of the treasury
    function setTreasury(address treasury) external;

    /// @notice Sets the royalty fee percentage
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyFeePercent The royalty fee percentage
    function setRoyaltyFeePercent(uint32 royaltyFeePercent) external;

    /// @notice Sets the ip graph limits
    /// @dev Enforced to be only callable by the protocol admin
    /// @param parentLimit The maximum number of parents an IP asset can have
    /// @param ancestorLimit The maximum number of ancestors an IP asset can have
    /// @param accumulatedRoyaltyPoliciesLimit The maximum number of accumulated royalty policies an IP asset can have
    function setIpGraphLimits(
        uint256 parentLimit,
        uint256 ancestorLimit,
        uint256 accumulatedRoyaltyPoliciesLimit
    ) external;

    /// @notice Whitelist a royalty policy
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external;

    /// @notice Whitelist a royalty token
    /// @dev Enforced to be only callable by the protocol admin
    /// @param token The token address
    /// @param allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address token, bool allowed) external;

    /// @notice Registers an external royalty policy
    /// @param externalRoyaltyPolicy The address of the external royalty policy
    function registerExternalRoyaltyPolicy(address externalRoyaltyPolicy) external;

    /// @notice Executes royalty related logic on license minting
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param royaltyPolicy The royalty policy address of the license being minted
    /// @param licensePercent The license percentage of the license being minted
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address ipId,
        address royaltyPolicy,
        uint32 licensePercent,
        bytes calldata externalData
    ) external;

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licensesPercent The license percentage of the licenses being minted
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        address[] calldata licenseRoyaltyPolicies,
        uint32[] calldata licensesPercent,
        bytes calldata externalData
    ) external;

    /// @notice Allows the function caller to pay royalties to the receiver IP asset on behalf of the payer IP asset.
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerIpId The ipId that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;

    /// @notice Allows to pay the minting fee for a license
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payLicenseMintingFee(address receiverIpId, address payerAddress, address token, uint256 amount) external;

    /// @notice Returns the number of ancestors for a given IP asset
    /// @param ipId The ID of IP asset
    function getAncestorsCount(address ipId) external returns (uint256);

    /// @notice Indicates if an IP asset has a specific ancestor IP asset
    /// @param ipId The ID of IP asset
    /// @param ancestorIpId The ID of the ancestor IP asset
    function hasAncestorIp(address ipId, address ancestorIpId) external returns (bool);

    /// @notice Returns the maximum percentage - represents 100%
    function maxPercent() external pure returns (uint32);

    /// @notice Returns the treasury address
    function treasury() external view returns (address);

    /// @notice Returns the royalty fee percentage
    function royaltyFeePercent() external view returns (uint32);

    /// @notice Returns the maximum number of parents
    function maxParents() external view returns (uint256);

    /// @notice Returns the maximum number of total ancestors
    function maxAncestors() external view returns (uint256);

    /// @notice Returns the maximum number of accumulated royalty policies an IP asset can have
    function maxAccumulatedRoyaltyPolicies() external view returns (uint256);

    /// @notice Indicates if a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @return isWhitelisted True if the royalty policy is whitelisted
    function isWhitelistedRoyaltyPolicy(address royaltyPolicy) external view returns (bool);

    /// @notice Indicates if an external royalty policy is registered
    /// @param externalRoyaltyPolicy The address of the external royalty policy
    /// @return isRegistered True if the external royalty policy is registered
    function isRegisteredExternalRoyaltyPolicy(address externalRoyaltyPolicy) external view returns (bool);

    /// @notice Indicates if a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @return isWhitelisted True if the royalty token is whitelisted
    function isWhitelistedRoyaltyToken(address token) external view returns (bool);

    /// @notice Indicates if an address is a royalty vault
    /// @param ipRoyaltyVault The address to check
    /// @return isIpRoyaltyVault True if the address is a royalty vault
    function isIpRoyaltyVault(address ipRoyaltyVault) external view returns (bool);

    /// @notice Indicates the royalty vault for a given IP asset
    /// @param ipId The ID of IP asset
    function ipRoyaltyVaults(address ipId) external view returns (address);

    /// @notice Returns the global royalty stack for whitelisted royalty policies and a given IP asset
    /// @param ipId The ID of IP asset
    function globalRoyaltyStack(address ipId) external view returns (uint32);

    /// @notice Returns the accumulated royalty policies for a given IP asset
    /// @param ipId The ID of IP asset
    function accumulatedRoyaltyPolicies(address ipId) external view returns (address[] memory);

    /// @notice Returns the total lifetime revenue tokens received for a given IP asset
    /// @param ipId The ID of IP asset
    /// @param token The token address
    function totalRevenueTokensReceived(address ipId, address token) external view returns (uint256);
}
