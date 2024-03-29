// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract
import { IAccessController } from "../../../contracts/interfaces/access/IAccessController.sol";
import { IIPAccountRegistry } from "../../../contracts/interfaces/registries/IIPAccountRegistry.sol";
import { ILicensingModule } from "../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicyLAP } from "../../../contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
// solhint-disable-next-line max-line-length
import { PILPolicyFrameworkManager, PILPolicy, RegisterPILPolicyParams } from "../../../contracts/modules/licensing/PILPolicyFrameworkManager.sol";
import { TestProxyHelper } from "./TestProxyHelper.sol";
// test

contract LicensingHelper {
    IAccessController private ACCESS_CONTROLLER; // keep private to avoid collision with `BaseIntegration`

    IIPAccountRegistry private IP_ACCOUNT_REGISTRY; // keep private to avoid collision with `BaseIntegration`

    ILicensingModule private LICENSING_MODULE; // keep private to avoid collision with `BaseIntegration`

    IRoyaltyModule private ROYALTY_MODULE; // keep private to avoid collision with `BaseIntegration`

    IRoyaltyPolicyLAP private ROYALTY_POLICY_LAP; // keep private to avoid collision with `BaseIntegration`

    IERC20 private erc20;

    mapping(string frameworkName => uint256 frameworkId) internal frameworkIds;

    mapping(string policyName => uint256 globalPolicyId) internal policyIds;

    mapping(string policyName => RegisterPILPolicyParams policy) internal policies;

    mapping(string policyFrameworkManagerName => address policyFrameworkManagerAddr) internal pfm;

    string[] internal emptyStringArray = new string[](0);

    function initLicensingHelper(
        address _accessController,
        address _ipAccountRegistry,
        address _licensingModule,
        address _royaltyModule,
        address _royaltyPolicy,
        address _erc20
    ) public {
        ACCESS_CONTROLLER = IAccessController(_accessController);
        IP_ACCOUNT_REGISTRY = IIPAccountRegistry(_ipAccountRegistry);
        LICENSING_MODULE = ILicensingModule(_licensingModule);
        ROYALTY_MODULE = IRoyaltyModule(_royaltyModule);
        ROYALTY_POLICY_LAP = IRoyaltyPolicyLAP(_royaltyPolicy);
        erc20 = IERC20(_erc20);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        MODIFIERS: LICENSE FRAMEWORK (MANAGERS)
    //////////////////////////////////////////////////////////////////////////*/

    modifier withLFM_PIL() {
        _setPILPolicyFrameworkManager();
        _;
    }

    modifier withPILPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal
    ) {
        _mapPILPolicySimple(name, commercial, derivatives, reciprocal, 100);
        _addPILPolicyFromMapping(name, address(_pilFramework()));
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _setPILPolicyFrameworkManager() internal {
        _deployPILFramework("license Url");
        LICENSING_MODULE.registerPolicyFrameworkManager(pfm["pil"]);
    }

    function _deployPILFramework(string memory licenseUrl) internal returns (address) {
        PILPolicyFrameworkManager impl = new PILPolicyFrameworkManager(
            address(ACCESS_CONTROLLER),
            address(IP_ACCOUNT_REGISTRY),
            address(LICENSING_MODULE)
        );
        pfm["pil"] = TestProxyHelper.deployUUPSProxy(
            address(impl),
            abi.encodeCall(PILPolicyFrameworkManager.initialize, ("PIL_MINT_PAYMENT", licenseUrl))
        );
        return pfm["pil"];
    }

    function _pilFramework() internal view returns (PILPolicyFrameworkManager) {
        return PILPolicyFrameworkManager(pfm["pil"]);
    }

    function _addPILPolicy(
        string memory policyName,
        bool transferable,
        address royaltyPolicy,
        PILPolicy memory policy
    ) internal {
        string memory pName = string(abi.encodePacked("pil_", policyName));
        policies[pName] = RegisterPILPolicyParams({
            transferable: transferable,
            royaltyPolicy: royaltyPolicy,
            mintingFee: 0,
            mintingFeeToken: address(0),
            policy: policy
        });
        policyIds[pName] = PILPolicyFrameworkManager(pfm["pil"]).registerPolicy(policies[pName]);
    }

    function _addPILPolicyWihtMintPayment(
        string memory policyName,
        bool transferable,
        address royaltyPolicy,
        uint256 mintingFee,
        address mintingFeeToken,
        PILPolicy memory policy
    ) internal {
        string memory pName = string(abi.encodePacked("pil_", policyName));
        policies[pName] = RegisterPILPolicyParams({
            transferable: transferable,
            royaltyPolicy: royaltyPolicy,
            mintingFee: mintingFee,
            mintingFeeToken: mintingFeeToken,
            policy: policy
        });
        policyIds[pName] = PILPolicyFrameworkManager(pfm["pil"]).registerPolicy(policies[pName]);
    }

    function _mapPILPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal,
        uint32 commercialRevShare
    ) internal {
        string memory pName = string(abi.encodePacked("pil_", name));
        policies[pName] = RegisterPILPolicyParams({
            transferable: true,
            royaltyPolicy: commercial ? address(ROYALTY_POLICY_LAP) : address(0),
            mintingFee: commercial ? 1 ether : 0,
            mintingFeeToken: commercial ? address(erc20) : address(0),
            policy: PILPolicy({
                attribution: true,
                commercialUse: commercial,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: commercial ? commercialRevShare : 0,
                derivativesAllowed: derivatives,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: reciprocal,
                territories: emptyStringArray,
                distributionChannels: emptyStringArray,
                contentRestrictions: emptyStringArray
            })
        });
    }

    function _mapPILPolicyCommercial(
        string memory name,
        bool derivatives,
        bool reciprocal,
        uint32 commercialRevShare,
        address royaltyPolicy,
        uint256 mintingFee,
        address mintingFeeToken
    ) internal {
        string memory pName = string(abi.encodePacked("pil_", name));
        policies[pName] = RegisterPILPolicyParams({
            transferable: true,
            royaltyPolicy: royaltyPolicy,
            mintingFee: mintingFee,
            mintingFeeToken: mintingFeeToken,
            policy: PILPolicy({
                attribution: true,
                commercialUse: true,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: commercialRevShare,
                derivativesAllowed: derivatives,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: reciprocal,
                territories: emptyStringArray,
                distributionChannels: emptyStringArray,
                contentRestrictions: emptyStringArray
            })
        });
    }

    function _addPILPolicyFromMapping(string memory name, address pilFramework) internal returns (uint256) {
        string memory pName = string(abi.encodePacked("pil_", name));
        policyIds[pName] = PILPolicyFrameworkManager(pilFramework).registerPolicy(policies[pName]);
        return policyIds[pName];
    }

    function _registerPILPolicyFromMapping(string memory name) internal returns (uint256) {
        string memory pName = string(abi.encodePacked("pil_", name));
        policyIds[pName] = PILPolicyFrameworkManager(pfm["pil"]).registerPolicy(policies[pName]);
        return policyIds[pName];
    }

    function _getMappedPilPolicy(string memory name) internal view returns (PILPolicy storage) {
        string memory pName = string(abi.encodePacked("pil_", name));
        return policies[pName].policy;
    }

    function _getMappedPilParams(string memory name) internal view returns (RegisterPILPolicyParams storage) {
        string memory pName = string(abi.encodePacked("pil_", name));
        return policies[pName];
    }

    function _getPilPolicyId(string memory name) internal view returns (uint256) {
        string memory pName = string(abi.encodePacked("pil_", name));
        return policyIds[pName];
    }
}
