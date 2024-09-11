// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IModule } from "../base/IModule.sol";

/// @title ILicensingHook
/// @notice This interface defines the hook functions that are called by the LicensingModule when
/// executing licensing functions.
/// IP owners can configure the hook to a specific license terms or all licenses of an IP Asset.
/// @dev Developers can create a contract that implements this interface to implement various checks
/// and determine the minting price.
/// Initially, the hooks must be registered as modules in the ModuleRegistry.
interface ILicensingHook is IModule {
    /// @notice This function is called when the LicensingModule mints license tokens.
    /// @dev The hook can be used to implement various checks and determine the minting price.
    /// The hook should revert if the minting is not allowed.
    /// @param caller The address of the caller who calling the mintLicenseTokens() function.
    /// @param licensorIpId The ID of licensor IP from which issue the license tokens.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template,
    /// which is used to mint license tokens.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver who receive the license tokens.
    /// @param hookData The data to be used by the licensing hook.
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens.
    function beforeMintLicenseTokens(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external returns (uint256 totalMintingFee);

    /// @notice This function is called before finalizing LicensingModule.registerDerivative(), after calling
    /// LicenseRegistry.registerDerivative().
    /// @dev The hook can be used to implement various checks and determine the minting price.
    /// The hook should revert if the registering of derivative is not allowed.
    /// @param childIpId The derivative IP ID.
    /// @param parentIpId The parent IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param hookData The data to be used by the licensing hook.
    /// @return mintingFee The minting fee to be paid when register child IP to the parent IP as derivative.
    function beforeRegisterDerivative(
        address caller,
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bytes calldata hookData
    ) external returns (uint256 mintingFee);

    /// @notice This function is called when the LicensingModule calculates/predict the minting fee for license tokens.
    /// @dev The hook should guarantee the minting fee calculation is correct and return the minting fee which is
    /// the exact same amount with returned by beforeMintLicenseTokens().
    /// The hook should revert if the minting fee calculation is not allowed.
    /// @param caller The address of the caller who calling the mintLicenseTokens() function.
    /// @param licensorIpId The ID of licensor IP from which issue the license tokens.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template,
    /// which is used to mint license tokens.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver who receive the license tokens.
    /// @param hookData The data to be used by the licensing hook.
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens.
    function calculateMintingFee(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external view returns (uint256 totalMintingFee);
}
