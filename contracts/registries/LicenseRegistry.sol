// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { Initializable } from  "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IPolicyFrameworkManager } from "../interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { ILicenseRegistry } from "../interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { IDisputeModule } from "../interfaces/modules/dispute/IDisputeModule.sol";
import { Errors } from "../lib/Errors.sol";
import { Licensing } from "../lib/Licensing.sol";
import { DataUniqueness } from "../lib/DataUniqueness.sol";

/// @title LicenseRegistry aka LNFT
/// @notice Registry of License NFTs, which represent licenses granted by IP ID licensors to create derivative IPs.
contract LicenseRegistry is ILicenseRegistry, ERC1155Upgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for *;

    /// @notice Emitted for metadata updates, per EIP-4906
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @notice Name of the Programmable IP License NFT
    string public name;

    /// @notice Symbol of the Programmable IP License NFT
    string public symbol;

    /// @notice URL of the Licensing Image
    string public imageUrl;

    // TODO: deploy with CREATE2 to make this immutable
    /// @notice Returns the canonical protocol-wide LicensingModule
    ILicensingModule public LICENSING_MODULE;

    /// @notice Returns the canonical protocol-wide DisputeModule
    IDisputeModule public DISPUTE_MODULE;

    /// @dev Maps the hash of the license data to the licenseId
    mapping(bytes32 licenseHash => uint256 licenseId) private _hashedLicenses;

    /// @dev Maps the licenseId to the license data
    mapping(uint256 licenseId => Licensing.License licenseData) private _licenses;

    /// @dev Tracks the number of licenses registered in the protocol, it will not decrease when a license is burnt.
    uint256 private _mintedLicenses;

    /// @dev We have to implement this modifier instead of inheriting `LicensingModuleAware` because LicensingModule
    /// constructor requires the licenseRegistry address, which would create a circular dependency. Thus, we use the
    /// function `setLicensingModule` to set the licensing module address after deploying the module.
    modifier onlyLicensingModule() {
        if (msg.sender != address(LICENSING_MODULE)) {
            revert Errors.LicenseRegistry__CallerNotLicensingModule();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address manager, string memory url) initializer public {
        __ERC1155_init("");
        __AccessManaged_init(manager);
        __UUPSUpgradeable_init();
        name = "Programmable IP License NFT";
        symbol = "PILNFT";
    }

    /// @dev Sets the DisputeModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newDisputeModule The address of the DisputeModule
    function setDisputeModule(address newDisputeModule) external restricted {
        if (newDisputeModule == address(0)) {
            revert Errors.LicenseRegistry__ZeroDisputeModule();
        }
        DISPUTE_MODULE = IDisputeModule(newDisputeModule);
    }

    /// @dev Sets the LicensingModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newLicensingModule The address of the LicensingModule
    function setLicensingModule(address newLicensingModule) external restricted {
        if (newLicensingModule == address(0)) {
            revert Errors.LicenseRegistry__ZeroLicensingModule();
        }
        LICENSING_MODULE = ILicensingModule(newLicensingModule);
    }

    /// @dev Sets the Licensing Image URL.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param url The URL of the Licensing Image
    function setLicensingImageUrl(string calldata url) external restricted {
        imageUrl = url;
        emit BatchMetadataUpdate(1, _mintedLicenses);
    }

    /// @notice Mints license NFTs representing a policy granted by a set of ipIds (licensors). This NFT needs to be
    /// burned in order to link a derivative IP with its parents. If this is the first combination of policy and
    /// licensors, a new licenseId will be created. If not, the license is fungible and an id will be reused.
    /// @dev Only callable by the licensing module.
    /// @param policyId The ID of the policy to be minted
    /// @param licensorIpId_ The ID of the IP granting the license (ie. licensor)
    /// @param transferable True if the license is transferable
    /// @param amount Number of licenses to mint. License NFT is fungible for same policy and same licensors
    /// @param receiver Receiver address of the minted license NFT(s).
    /// @return licenseId The ID of the minted license NFT(s).
    function mintLicense(
        uint256 policyId,
        address licensorIpId_,
        bool transferable,
        uint256 amount, // mint amount
        address receiver
    ) external onlyLicensingModule returns (uint256 licenseId) {
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
            emit LicenseMinted(msg.sender, receiver, licenseId, amount, licenseData);
        }
        _mint(receiver, licenseId, amount, "");
        return licenseId;
    }

    function burnLicenses(address holder, uint256[] calldata licenseIds) external onlyLicensingModule {
        uint256[] memory values = new uint256[](licenseIds.length);
        for (uint256 i = 0; i < licenseIds.length; i++) {
            values[i] = 1;
        }
        // Burn licenses
        _burnBatch(holder, licenseIds, values);
    }

    /// @notice Returns the number of licenses registered in the protocol.
    /// @dev Token ID counter total count.
    /// @return mintedLicenses The number of minted licenses
    function mintedLicenses() external view returns (uint256) {
        return _mintedLicenses;
    }

    /// @notice Returns true if holder has positive balance for the given license ID.
    /// @return isLicensee True if holder is the licensee for the license (owner of the license NFT), or derivative IP
    /// owner if the license was added to the IP by linking (burning a license).
    function isLicensee(uint256 licenseId, address holder) external view returns (bool) {
        return balanceOf(holder, licenseId) > 0;
    }

    /// @notice Returns the license data for the given license ID
    /// @param licenseId The ID of the license
    /// @return licenseData The license data
    function license(uint256 licenseId) external view returns (Licensing.License memory) {
        return _licenses[licenseId];
    }

    /// @notice Returns the ID of the IP asset that is the licensor of the given license ID
    /// @param licenseId The ID of the license
    /// @return licensorIpId The ID of the licensor
    function licensorIpId(uint256 licenseId) external view returns (address) {
        return _licenses[licenseId].licensorIpId;
    }

    /// @notice Returns the policy ID for the given license ID
    /// @param licenseId The ID of the license
    /// @return policyId The ID of the policy
    function policyIdForLicense(uint256 licenseId) external view returns (uint256) {
        return _licenses[licenseId].policyId;
    }

    /// @notice Returns true if the license has been revoked (licensor tagged after a dispute in
    /// the dispute module). If the tag is removed, the license is not revoked anymore.
    /// @param licenseId The id of the license to check
    /// @return isRevoked True if the license is revoked
    function isLicenseRevoked(uint256 licenseId) public view returns (bool) {
        // For beta, any tag means revocation, for mainnet we need more context.
        // TODO: signal metadata update when tag changes.
        return DISPUTE_MODULE.isIpTagged(_licenses[licenseId].licensorIpId);
    }

    /// @notice ERC1155 OpenSea metadata JSON representation of the LNFT parameters
    /// @dev Expect PFM.policyToJson to return {'trait_type: 'value'},{'trait_type': 'value'},...,{...}
    /// (last attribute must not have a comma at the end)
    function uri(uint256 id) public view virtual override returns (string memory) {
        Licensing.License memory licenseData = _licenses[id];
        Licensing.Policy memory pol = LICENSING_MODULE.policy(licenseData.policyId);

        string memory licensorIpIdHex = licenseData.licensorIpId.toHexString();

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata

        // base json, open the attributes array
        string memory json = string(
            abi.encodePacked(
                "{",
                '"name": "Story Protocol License #',
                id.toString(),
                '",',
                '"description": "License agreement stating the terms of a Story Protocol IPAsset",',
                '"external_url": "https://protocol.storyprotocol.xyz/ipa/',
                licensorIpIdHex,
                '",',
                // solhint-disable-next-line max-length
                '"image": "',
                imageUrl,
                '",',
                '"attributes": ['
            )
        );

        // append the policy specific attributes (last attribute added by PFM should have a comma at the end)
        // TODO: Safeguard mechanism to make sure the attributes added by PFM do NOT overlap with the common traits
        // defined above. Currently, we add the common license attributes after adding the PFM attributes to override.
        // But OpenSea might take the value of the first duplicate.
        json = string(
            abi.encodePacked(json, IPolicyFrameworkManager(pol.policyFramework).policyToJson(pol.frameworkData))
        );

        // append the common license attributes
        json = string(
            abi.encodePacked(
                json,
                '{"trait_type": "Licensor", "value": "',
                licensorIpIdHex,
                '"},',
                '{"trait_type": "Policy Framework", "value": "',
                pol.policyFramework.toHexString(),
                '"},',
                '{"trait_type": "Transferable", "value": "',
                licenseData.transferable ? "true" : "false",
                '"},',
                '{"trait_type": "Revoked", "value": "',
                isLicenseRevoked(id) ? "true" : "false",
                '"}'
            )
        );

        // close the attributes array and the json metadata object
        json = string(abi.encodePacked(json, "]}"));

        /* solhint-enable */

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    /// @dev Pre-hook for ERC1155's _update() called on transfers.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // We are interested in transfers, minting and burning are checked in mintLicense and
        // linkIpToParent in LicensingModule respectively
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                Licensing.License memory lic = _licenses[ids[i]];
                // TODO: Hook for verify transfer params
                if (isLicenseRevoked(ids[i])) {
                    revert Errors.LicenseRegistry__RevokedLicense();
                }
                if (!lic.transferable) {
                    // True if from == licensor
                    if (from != lic.licensorIpId) {
                        revert Errors.LicenseRegistry__NotTransferable();
                    }
                }
            }
        }
        super._update(from, to, ids, values);
    }

    /// @dev Hook to authorize the upgrade according to UUPSUgradeable
    /// Must be called by ProtocolRoles.UPGRADER
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation)
        internal
        restricted
        override
    {}
}
