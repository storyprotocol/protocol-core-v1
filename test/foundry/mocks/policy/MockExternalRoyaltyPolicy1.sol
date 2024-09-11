// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// solhint-disable-next-line max-line-length
import { IExternalRoyaltyPolicy } from "../../../../contracts/interfaces/modules/royalty/policies/IExternalRoyaltyPolicy.sol";

contract MockExternalRoyaltyPolicy1 is IExternalRoyaltyPolicy {
    function getPolicyRtsRequiredToLink(address ipId, uint32 licensePercent) external view returns (uint32) {
        return licensePercent * 2;
    }
}
