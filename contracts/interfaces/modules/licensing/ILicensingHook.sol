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
interface ILicensingHook is IModule {
    function beforeMintLicenseTokens(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external returns (uint256);

    function beforeRegisterDerivative(
        address caller,
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bytes calldata hookData
    ) external returns (uint256);
}
