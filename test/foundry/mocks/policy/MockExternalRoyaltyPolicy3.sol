// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165, ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// solhint-disable-next-line max-line-length
import { IExternalRoyaltyPolicy } from "../../../../contracts/interfaces/modules/royalty/policies/IExternalRoyaltyPolicy.sol";

contract MockExternalRoyaltyPolicy3 is ERC165, IExternalRoyaltyPolicy {
    function getPolicyRtsRequiredToLink(address ipId, uint32 licensePercent) external view returns (uint32) {
        return 100 * 10 ** 6;
    }

    /// @notice IERC165 interface support
    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == this.getPolicyRtsRequiredToLink.selector || super.supportsInterface(interfaceId);
    }
}
