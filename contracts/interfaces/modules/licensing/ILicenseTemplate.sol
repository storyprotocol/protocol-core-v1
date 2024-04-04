// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface ILicenseTemplate is IERC165 {
    event LicenseConfigRegistered(uint256 indexed licenseConfigId, address indexed licenseTemplate, bytes licenseData);

    function name() external view returns (string memory);
    function toJson(uint256 licenseConfigId) external view returns (string memory);
    function getMetadataURI() external view returns (string memory);

    function totalRegisteredLicenseConfigs() external view returns (uint256);

    function exists(uint256 licenseConfigId) external view returns (bool);
    function isTransferable(uint256 licenseConfigId) external view returns (bool);
    function getEarlierExpireTime(uint256 start, uint256[] calldata licenseConfigIds) external view returns (uint);
    function getExpireTime(uint256 start, uint256 licenseConfigId) external view returns (uint);

    function getRoyaltyPolicy(
        uint256 licenseConfigId
    )
        external
        view
        returns (address royaltyPolicy, bytes memory royaltyData, uint256 mintingLicenseFee, address currencyToken);

    function verifyMintLicenseToken(
        uint256 licenseConfigId,
        address licensee,
        address licensorIpId,
        uint256 mintAmount
    ) external returns (bool);

    function verifyRegisterDerivative(
        address derivativeIpId,
        address originalIpId,
        uint256 licenseConfigId,
        address licensee
    ) external returns (bool);

    function verifyCompatibleLicenses(uint256[] calldata licenseConfigIds) external view returns (bool);

    function verifyRegisterDerivativeForAll(
        address derivativeIpId,
        address[] calldata originalIpId,
        uint256[] calldata licenseConfigIds,
        address derivativeIpOwner
    ) external returns (bool);
}
