// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { ERC721Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { ILicenseNFT } from "../interfaces/registries/ILicenseNFT.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { IDisputeModule } from "../interfaces/modules/dispute/IDisputeModule.sol";
import { Errors } from "../lib/Errors.sol";
import { GovernableUpgradeable } from "../governance/GovernableUpgradeable.sol";
import { ILicenseTemplate } from "../interfaces/modules/licensing/ILicenseTemplate.sol";

/// @title LicenseNFT aka LNFT
contract LicenseNFT is ERC721Upgradeable, GovernableUpgradeable, UUPSUpgradeable, ILicenseNFT {
    using Strings for *;

    /// @notice Emitted for metadata updates, per EIP-4906
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @dev Storage of the LicenseNFT
    /// @custom:storage-location erc7201:story-protocol.LicenseNFT
    struct LicenseNFTStorage {
        string imageUrl;
        ILicensingModule licensingModule;
        IDisputeModule disputeModule;
        uint256 totalMintedTokens;
        mapping(uint256 tokenId => LicenseTokenMetadata) licenseTokenMetadatas;
    }

    // TODO: update the storage location
    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicenseNFT")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicenseNFTStorageLocation =
        0x5ed898e10dedf257f39672a55146f3fecade9da16f4ff022557924a10d60a900;

    modifier onlyLicensingModule() {
        if (msg.sender != address(_getLicenseNFTStorage().licensingModule)) {
            revert Errors.LicenseNFT__CallerNotLicensingModule();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address governance, string memory imageUrl) public initializer {
        __ERC721_init("Programmable IP License NFT", "PILNFT");
        __GovernableUpgradeable_init(governance);
        __UUPSUpgradeable_init();
        _getLicenseNFTStorage().imageUrl = imageUrl;
    }

    /// @dev Sets the LicensingModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newLicensingModule The address of the LicensingModule
    function setLicensingModule(address newLicensingModule) external onlyProtocolAdmin {
        if (newLicensingModule == address(0)) {
            revert Errors.LicenseNFT__ZeroLicensingModule();
        }
        LicenseNFTStorage storage $ = _getLicenseNFTStorage();
        $.licensingModule = ILicensingModule(newLicensingModule);
    }

    function setDisputeModule(address newDisputeModule) external onlyProtocolAdmin {
        if (newDisputeModule == address(0)) {
            revert Errors.LicenseNFT__ZeroDisputeModule();
        }
        LicenseNFTStorage storage $ = _getLicenseNFTStorage();
        $.disputeModule = IDisputeModule(newDisputeModule);
    }

    /// @dev Sets the Licensing Image URL.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param url The URL of the Licensing Image
    function setLicensingImageUrl(string calldata url) external onlyProtocolAdmin {
        LicenseNFTStorage storage $ = _getLicenseNFTStorage();
        $.imageUrl = url;
        emit BatchMetadataUpdate(1, $.totalMintedTokens);
    }

    function mintLicenseTokens(
        address originalIpId,
        address licenseTemplate,
        uint256 licenseConfigId,
        uint256 amount, // mint amount
        address minter,
        address receiver
    ) external onlyLicensingModule returns (uint256 startLicenseTokenId, uint256 endLicenseTokenId) {
        LicenseTokenMetadata memory licenseTokenMetadata = LicenseTokenMetadata({
            originalIpId: originalIpId,
            licenseTemplate: licenseTemplate,
            licenseConfigId: licenseConfigId,
            transferable: ILicenseTemplate(licenseTemplate).isTransferable(licenseConfigId),
            mintedAt: block.timestamp,
            expiresAt: ILicenseTemplate(licenseTemplate).getExpireTime(block.timestamp, licenseConfigId)
        });

        LicenseNFTStorage storage $ = _getLicenseNFTStorage();
        startLicenseTokenId = $.totalMintedTokens;
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = $.totalMintedTokens++;
            $.licenseTokenMetadatas[tokenId] = licenseTokenMetadata;
            _mint(receiver, tokenId);
            emit LicenseTokenMinted(minter, receiver, tokenId, licenseTokenMetadata);
        }
        endLicenseTokenId = $.totalMintedTokens - 1;
    }

    function burnLicenseTokens(address holder, uint256[] calldata tokenIds) external onlyLicensingModule {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
    }

    function validateLicenseTokensForDerivative(
        address derivativeIpId,
        address derivativeIpOwner,
        uint256[] calldata tokenIds
    )
        external
        view
        returns (address licenseTemplate, address[] memory originalIpIds, uint256[] memory licenseConfigIds)
    {
        LicenseNFTStorage storage $ = _getLicenseNFTStorage();
        licenseTemplate = $.licenseTokenMetadatas[tokenIds[0]].licenseTemplate;
        originalIpIds = new address[](tokenIds.length);
        licenseConfigIds = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            LicenseTokenMetadata memory ltm = $.licenseTokenMetadatas[tokenIds[i]];
            if (ltm.expiresAt < block.timestamp) {
                revert Errors.LicenseNFT__LicenseTokenExpired(tokenIds[i], ltm.expiresAt, block.timestamp);
            }
            if (ownerOf(tokenIds[i]) != derivativeIpOwner) {
                revert Errors.LicenseNFT__NotLicenseTokenOwner(tokenIds[i], derivativeIpOwner, ownerOf(tokenIds[i]));
            }
            if (licenseTemplate != ltm.licenseTemplate) {
                revert Errors.LicenseNFT__AllLicenseTokensMustFromSameLicenseTemplate(
                    licenseTemplate,
                    ltm.licenseTemplate
                );
            }
            if (isLicenseTokenRevoked(tokenIds[i])) {
                revert Errors.LicenseNFT__RevokedLicense(tokenIds[i]);
            }

            originalIpIds[i] = ltm.originalIpId;
            licenseConfigIds[i] = ltm.licenseConfigId;
        }
    }

    function totalMintedTokens() external view returns (uint256) {
        return _getLicenseNFTStorage().totalMintedTokens;
    }

    /// @notice Returns the license data for the given license ID
    /// @param licenseConfigId The ID of the license
    /// @return licenseData The license data
    function licenseTokenMetadata(uint256 licenseConfigId) external view returns (LicenseTokenMetadata memory) {
        return _getLicenseNFTStorage().licenseTokenMetadatas[licenseConfigId];
    }

    /// @notice Returns the ID of the IP asset that is the licensor of the given license ID
    /// @param licenseConfigId The ID of the license
    function originalIpId(uint256 licenseConfigId) external view returns (address) {
        return _getLicenseNFTStorage().licenseTokenMetadatas[licenseConfigId].originalIpId;
    }

    /// @notice Returns the canonical protocol-wide LicensingModule
    function licensingModule() external view returns (ILicensingModule) {
        return _getLicenseNFTStorage().licensingModule;
    }

    /// @notice Returns true if the license has been revoked (original IP tagged after a dispute in
    /// the dispute module). If the tag is removed, the license is not revoked anymore.
    /// @return isRevoked True if the license is revoked
    function isLicenseTokenRevoked(uint256 tokenId) public view returns (bool) {
        LicenseNFTStorage storage $ = _getLicenseNFTStorage();
        return $.disputeModule.isIpTagged($.licenseTokenMetadatas[tokenId].originalIpId);
    }

    /// @notice ERC721 OpenSea metadata JSON representation of the LNFT parameters
    /// @dev Expect LicenseTemplate.toJson to return {'trait_type: 'value'},{'trait_type': 'value'},...,{...}
    /// (last attribute must not have a comma at the end)
    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        LicenseNFTStorage storage $ = _getLicenseNFTStorage();

        LicenseTokenMetadata memory ltm = $.licenseTokenMetadatas[id];
        string memory originalIpIdHex = ltm.originalIpId.toHexString();

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
                originalIpIdHex,
                '",',
                // solhint-disable-next-line max-length
                '"image": "',
                $.imageUrl,
                '",',
                '"attributes": ['
            )
        );

        json = string(abi.encodePacked(json, ILicenseTemplate(ltm.licenseTemplate).toJson(ltm.licenseConfigId)));

        // append the common license attributes
        json = string(
            abi.encodePacked(
                json,
                '{"trait_type": "Licensor", "value": "',
                originalIpIdHex,
                '"},',
                '{"trait_type": "License Template", "value": "',
                ltm.licenseTemplate.toHexString(),
                '"},',
                '{"trait_type": "Transferable", "value": "',
                ltm.transferable ? "true" : "false",
                '"},',
                '{"trait_type": "Revoked", "value": "',
                isLicenseTokenRevoked(id) ? "true" : "false",
                '"}'
            )
        );

        // close the attributes array and the json metadata object
        json = string(abi.encodePacked(json, "]}"));

        /* solhint-enable */

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        LicenseNFTStorage storage $ = _getLicenseNFTStorage();
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            LicenseTokenMetadata memory ltm = $.licenseTokenMetadatas[tokenId];
            if (isLicenseTokenRevoked(tokenId)) {
                revert Errors.LicenseNFT__RevokedLicense(tokenId);
            }
            if (!ltm.transferable) {
                // True if from == licensor
                if (from != ltm.originalIpId) {
                    revert Errors.LicenseNFT__NotTransferable();
                }
            }
        }
        return super._update(to, tokenId, auth);
    }

    ////////////////////////////////////////////////////////////////////////////
    //                         Upgrades related                               //
    ////////////////////////////////////////////////////////////////////////////

    function _getLicenseNFTStorage() internal pure returns (LicenseNFTStorage storage $) {
        assembly {
            $.slot := LicenseNFTStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyProtocolAdmin {}
}
