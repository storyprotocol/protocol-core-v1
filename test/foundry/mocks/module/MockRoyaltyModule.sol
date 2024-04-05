// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { IRoyaltyModule } from "../../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";

contract MockRoyaltyModule is BaseModule, IRoyaltyModule {
    string public constant override name = "ROYALTY_MODULE";

    address public LICENSING_MODULE;

    address public DISPUTE_MODULE;

    mapping(address royaltyPolicy => bool allowed) public isWhitelistedRoyaltyPolicy;

    mapping(address token => bool) public isWhitelistedRoyaltyToken;

    mapping(address ipId => address royaltyPolicy) public royaltyPolicies;

    constructor() {}

    function setDisputeModule(address _disputeModule) external {
        DISPUTE_MODULE = _disputeModule;
    }

    function setLicensingModule(address _licensingModule) external {
        LICENSING_MODULE = _licensingModule;
    }

    function licensingModule() external view override returns (address) {
        return LICENSING_MODULE;
    }

    function disputeModule() external view override returns (address) {
        return DISPUTE_MODULE;
    }

    function whitelistRoyaltyPolicy(address _royaltyPolicy, bool _allowed) external {
        isWhitelistedRoyaltyPolicy[_royaltyPolicy] = _allowed;
    }

    function whitelistRoyaltyToken(address _token, bool _allowed) external {
        isWhitelistedRoyaltyToken[_token] = _allowed;
    }

    function onLicenseMinting(
        address _ipId,
        address _royaltyPolicy,
        bytes calldata _licenseData,
        bytes calldata _externalData
    ) external {
        // address royaltyPolicyIpId = royaltyPolicies[_ipId];
        // IRoyaltyPolicy(_royaltyPolicy).onLicenseMinting(_ipId, _licenseData, _externalData);
    }

    function onLinkToParents(
        address _ipId,
        address _royaltyPolicy,
        address[] calldata _parentIpIds,
        bytes[] memory _licenseData,
        bytes calldata _externalData
    ) external {
        royaltyPolicies[_ipId] = _royaltyPolicy;
        // IRoyaltyPolicy(_royaltyPolicy).onLinkToParents(_ipId, _parentIpIds, _licenseData, _externalData);
    }

    function payRoyaltyOnBehalf(address _receiverIpId, address _payerIpId, address _token, uint256 _amount) external {
        address payerRoyaltyPolicy = royaltyPolicies[_payerIpId];
        // IRoyaltyPolicy(payerRoyaltyPolicy).onRoyaltyPayment(msg.sender, _receiverIpId, _token, _amount);
    }

    function payLicenseMintingFee(address receiverIpId, address payerAddress, address token, uint256 amount) external {}

    function payLicenseMintingFee(
        address receiverIpId,
        address payerAddress,
        address licenseRoyaltyPolicy,
        address token,
        uint256 amount
    ) external {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IRoyaltyModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
