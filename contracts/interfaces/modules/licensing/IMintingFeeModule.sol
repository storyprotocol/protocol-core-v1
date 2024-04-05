// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IModule } from "../base/IModule.sol";

/// @title IMintingFeeModule
/// @notice This interface is used to determine the minting fee of a license token.
/// IP owners can configure the MintingFeeModule to a specific license terms or all licenses of an IP Asset.
/// When someone calls the `mintLicenseTokens` function of LicensingModule, the LicensingModule will check whether
/// the license term or IP Asset has been configured with this module. If so, LicensingModule will call this module
/// to determine the minting fee of the license token.
/// @dev Developers can create a contract that implements this interface to implement various algorithms to determine
/// the minting price,
/// for example, a bonding curve formula. This allows IP owners to configure the module to hook into the LicensingModule
/// when minting a license token.
interface IMintingFeeModule is IModule {
    /// @notice Calculates the total minting fee for a given amount of license tokens.
    /// @param ipId The IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param amount The amount of license tokens to mint.
    /// @return The total minting fee.
    function getMintingFee(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) external view returns (uint256);
}
