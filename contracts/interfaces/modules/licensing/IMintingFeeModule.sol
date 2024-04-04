// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IModule } from "../base/IModule.sol";

interface IMintingFeeModule is IModule {
    function getTotalMintingFee(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) external view returns (uint256);
}
