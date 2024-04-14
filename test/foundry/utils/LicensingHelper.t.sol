// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IRoyaltyPolicyLAP } from "../../../contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { PILTerms } from "../../../contracts/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { PILicenseTemplate } from "../../../contracts/modules/licensing/PILicenseTemplate.sol";
import { PILFlavors } from "../../../contracts/lib/PILFlavors.sol";

contract LicensingHelper {
    PILicenseTemplate private pilTemplate; // keep private to avoid collision with `BaseIntegration`

    IRoyaltyPolicyLAP private royaltyPolicyLAP; // keep private to avoid collision with `BaseIntegration`

    IERC20 private erc20; // keep private to avoid collision with `BaseIntegration`

    mapping(string selectionName => PILTerms) internal selectedPILicenseTerms;
    mapping(string selectionName => uint256 licenseTermsId) internal selectedPILicenseTermsId;

    string[] internal emptyStringArray = new string[](0);

    function initLicensingHelper(address _pilTemplate, address _royaltyPolicyLAP, address _erc20) public {
        pilTemplate = PILicenseTemplate(_pilTemplate);
        royaltyPolicyLAP = IRoyaltyPolicyLAP(_royaltyPolicyLAP);
        erc20 = IERC20(_erc20);
    }

    function registerSelectedPILicenseTerms(
        string memory selectionName,
        PILTerms memory selectedPILicenseTerms_
    ) public returns (uint256 pilSelectedLicenseTermsId) {
        string memory _selectionName = string(abi.encodePacked("PIL_", selectionName));
        pilSelectedLicenseTermsId = pilTemplate.registerLicenseTerms(selectedPILicenseTerms_);
        // pilSelectedLicenseTermsId = pilTemplate.getLicenseTermsId(selectedPILicenseTerms_);

        selectedPILicenseTerms[selectionName] = selectedPILicenseTerms_;
        selectedPILicenseTermsId[selectionName] = pilSelectedLicenseTermsId;
    }

    function registerSelectedPILicenseTerms_Commercial(
        string memory selectionName,
        bool transferable,
        bool derivatives,
        bool reciprocal,
        uint32 commercialRevShare,
        uint256 mintingFee
    ) public returns (uint256 pilSelectedLicenseTermsId) {
        pilSelectedLicenseTermsId = registerSelectedPILicenseTerms(
            selectionName,
            mapSelectedPILicenseTerms_Commercial(transferable, derivatives, reciprocal, commercialRevShare, mintingFee)
        );
    }

    function registerSelectedPILicenseTerms_NonCommercial(
        string memory selectionName,
        bool transferable,
        bool derivatives,
        bool reciprocal
    ) public returns (uint256 pilSelectedLicenseTermsId) {
        pilSelectedLicenseTermsId = registerSelectedPILicenseTerms(
            selectionName,
            mapSelectedPILicenseTerms_NonCommercial(transferable, derivatives, reciprocal)
        );
    }

    function registerSelectedPILicenseTerms_NonCommercialSocialRemixing()
        public
        returns (uint256 pilSelectedLicenseTermsId)
    {
        pilSelectedLicenseTermsId = registerSelectedPILicenseTerms(
            "nc_social_remix",
            PILFlavors.nonCommercialSocialRemixing()
        );
    }

    function mapSelectedPILicenseTerms_Commercial(
        bool transferable,
        bool derivatives,
        bool reciprocal,
        uint32 commercialRevShare,
        uint256 mintingFeeToken
    ) public returns (PILTerms memory) {
        return
            PILTerms({
                transferable: transferable,
                royaltyPolicy: address(royaltyPolicyLAP),
                mintingFee: 1 ether,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: commercialRevShare,
                commercialRevCelling: 0,
                derivativesAllowed: derivatives,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: reciprocal,
                derivativeRevCelling: 0,
                currency: address(erc20),
                uri: ""
            });
    }

    function mapSelectedPILicenseTerms_NonCommercial(
        bool transferable,
        bool derivatives,
        bool reciprocal
    ) public returns (PILTerms memory) {
        return
            PILTerms({
                transferable: transferable,
                royaltyPolicy: address(0),
                mintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                commercialRevCelling: 0,
                derivativesAllowed: derivatives,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: reciprocal,
                derivativeRevCelling: 0,
                currency: address(0),
                uri: ""
            });
    }

    function getSelectedPILicenseTerms(string memory selectionName) internal view returns (PILTerms memory) {
        string memory _selectionName = string(abi.encodePacked("PIL_", selectionName));
        return selectedPILicenseTerms[selectionName];
    }

    function getSelectedPILicenseTermsId(string memory selectionName) internal view returns (uint256) {
        string memory _selectionName = string(abi.encodePacked("PIL_", selectionName));
        return selectedPILicenseTermsId[selectionName];
    }
}
