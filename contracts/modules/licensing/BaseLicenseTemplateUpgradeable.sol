// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// contracts
import { ILicenseTemplate } from "../../interfaces/modules/licensing/ILicenseTemplate.sol";

abstract contract BaseLicenseTemplateUpgradeable is ILicenseTemplate, ERC165, Initializable {
    /// @custom:storage-location erc7201:story-protocol.BaseLicenseTemplate
    struct BaseLicenseTemplateStorage {
        string name;
        string metadataURI;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.BaseLicenseTemplate")) - 1))
    // & ~bytes32(uint256(0xff));
    bytes32 private constant BaseLicenseTemplateStorageLocation =
        0xa55803740ac9329334ad7b6cde0ec056cc3ba32125b59c579552512bed001f00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param _name The name of the license template
    /// @param _metadataURI The URL to the off chain metadata
    function __BaseLicenseTemplate_init(string memory _name, string memory _metadataURI) internal onlyInitializing {
        _getBaseLicenseTemplateStorage().name = _name;
        _getBaseLicenseTemplateStorage().metadataURI = _metadataURI;
    }

    /// @notice Returns the name of the license template
    function name() public view override returns (string memory) {
        return _getBaseLicenseTemplateStorage().name;
    }

    /// @notice Returns the URL to the off chain metadata
    function getMetadataURI() public view override returns (string memory) {
        return _getBaseLicenseTemplateStorage().metadataURI;
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ILicenseTemplate).interfaceId || super.supportsInterface(interfaceId);
    }

    function _getBaseLicenseTemplateStorage() internal pure returns (BaseLicenseTemplateStorage storage $) {
        assembly {
            $.slot := BaseLicenseTemplateStorageLocation
        }
    }
}
