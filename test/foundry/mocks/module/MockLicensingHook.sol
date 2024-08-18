// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";
import { ILicensingHook } from "contracts/interfaces/modules/licensing/ILicensingHook.sol";

contract MockLicensingHook is BaseModule, ILicensingHook {
    string public constant override name = "MockLicensingHook";

    function beforeMintLicenseTokens(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external returns (uint256 totalMintingFee) {
        address unqualifiedAddress = abi.decode(hookData, (address));
        if (caller == unqualifiedAddress) revert("MockLicensingHook: caller is invalid");
        if (receiver == unqualifiedAddress) revert("MockLicensingHook: receiver is invalid");
        return amount * 100;
    }

    function beforeRegisterDerivative(
        address caller,
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bytes calldata hookData
    ) external returns (uint256 mintingFee) {
        address unqualifiedAddress = abi.decode(hookData, (address));
        if (caller == unqualifiedAddress) revert("MockLicensingHook: caller is invalid");
        return 100;
    }

    function calculateMintingFee(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external view returns (uint256 totalMintingFee) {
        address unqualifiedAddress = abi.decode(hookData, (address));
        if (caller == unqualifiedAddress) revert("MockLicensingHook: caller is invalid");
        if (receiver == unqualifiedAddress) revert("MockLicensingHook: receiver is invalid");
        return amount * 100;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ILicensingHook).interfaceId || super.supportsInterface(interfaceId);
    }
}
