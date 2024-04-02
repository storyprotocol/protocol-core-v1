// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface ILicenseTemplate is IERC165 {
    event LicenseRegistered(uint256 indexed licenseId, address indexed licenseTemplate, bytes licenseData);

    function name() external view returns (string memory);
    function getLicenseString(uint256 licenseId) external view returns (string memory);
    function getMetadataURI() external view returns (string memory);

    function exists(uint256 licenseId) external view returns (bool);
    function isTransferable(uint256 licenseId) external view returns (bool);
    function getExpireTime(uint256 start, uint256[] licenseIds) external view returns (uint);

    function verifyMintLicenseToken(
        uint256 licenseId,
        address licensee,
        address licensorIpId,
        uint256 mintAmount
    ) external view returns (bool);
    function verifyRegisterDerivative(
        uint256 licenseId,
        address licensee,
        address derivativeIpId,
        address originalIpId
    ) external view override returns (bool);
    function verifyCompatibleLicenses(uint256[] calldata licenseIds) external view returns (bool);
}
