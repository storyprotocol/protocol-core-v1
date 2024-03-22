// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import { ILicensingModule } from "../../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { DataUniqueness } from "../../../../contracts/lib/DataUniqueness.sol";
import { Licensing } from "../../../../contracts/lib/Licensing.sol";
import { ILicenseRegistry } from "../../../../contracts/interfaces/registries/ILicenseRegistry.sol";
import { IDisputeModule } from "../../../../contracts/interfaces/modules/dispute/IDisputeModule.sol";

contract MockLicenseRegistry is ERC1155, ILicenseRegistry {
    ILicensingModule public LICENSING_MODULE;
    IDisputeModule public DISPUTE_MODULE;
    mapping(bytes32 licenseHash => uint256 ids) private _hashedLicenses;
    mapping(uint256 licenseIds => Licensing.License licenseData) private _licenses;
    uint256 private _mintedLicenses;

    constructor() ERC1155("") {}

    function setLicensingModule(address newLicensingModule) external {
        LICENSING_MODULE = ILicensingModule(newLicensingModule);
    }

    function disputeModule() external view returns (IDisputeModule) {
        return DISPUTE_MODULE;
    }

    function licensingModule() external view returns (ILicensingModule) {
        return LICENSING_MODULE;
    }

    function mintLicense(
        uint256 policyId,
        address licensorIpId_,
        bool transferable,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId) {
        Licensing.License memory licenseData = Licensing.License({
            policyId: policyId,
            licensorIpId: licensorIpId_,
            transferable: transferable
        });
        bool isNew;
        (licenseId, isNew) = DataUniqueness.addIdOrGetExisting(
            abi.encode(licenseData),
            _hashedLicenses,
            _mintedLicenses
        );
        if (isNew) {
            _mintedLicenses = licenseId;
            _licenses[licenseId] = licenseData;
        }
        _mint(receiver, licenseId, amount, "");
        return licenseId;
    }

    function burnLicenses(address holder, uint256[] calldata licenseIds) external {
        uint256[] memory values = new uint256[](licenseIds.length);
        for (uint256 i = 0; i < licenseIds.length; i++) {
            values[i] = 1;
        }
        _burnBatch(holder, licenseIds, values);
    }

    function mintedLicenses() external view returns (uint256) {
        return _mintedLicenses;
    }

    function isLicensee(uint256 licenseId, address holder) external view returns (bool) {
        return balanceOf(holder, licenseId) > 0;
    }

    function license(uint256 licenseId) external view returns (Licensing.License memory) {
        return _licenses[licenseId];
    }

    function licensorIpId(uint256 licenseId) external view returns (address) {
        return _licenses[licenseId].licensorIpId;
    }

    function policyIdForLicense(uint256 licenseId) external view returns (uint256) {
        return _licenses[licenseId].policyId;
    }

    function isLicenseRevoked(uint256) external pure returns (bool) {
        return false;
    }

    function uri(uint256 id) public pure override returns (string memory) {
        // return uint256 id as string value
        return string(abi.encodePacked("uri_", id));
    }
}
