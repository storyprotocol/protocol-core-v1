// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol contract errors.
library Errors {
    ////////////////////////////////////////////////////////////////////////////
    //                                IP Account                              //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Controller.
    error IPAccount__ZeroAccessController();

    /// @notice Invalid signer provided.
    error IPAccount__InvalidSigner();

    /// @notice Invalid signature provided, must be an EIP-712 signature.
    error IPAccount__InvalidSignature();

    /// @notice Signature is expired.
    error IPAccount__ExpiredSignature();

    /// @notice Provided calldata is invalid.
    error IPAccount__InvalidCalldata();

    ////////////////////////////////////////////////////////////////////////////
    //                            IP Account Storage                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Caller writing to IP Account storage is not a registered module.
    error IPAccountStorage__NotRegisteredModule(address module);

    ////////////////////////////////////////////////////////////////////////////
    //                           IP Account Registry                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for IP Account implementation.
    error IPAccountRegistry_ZeroIpAccountImpl();

    ////////////////////////////////////////////////////////////////////////////
    //                            IP Asset Registry                           //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error IPAssetRegistry__ZeroAccessManager();

    /// @notice The IP asset has already been registered.
    error IPAssetRegistry__AlreadyRegistered();

    /// @notice The NFT token contract is not valid ERC721 contract.
    error IPAssetRegistry__UnsupportedIERC721(address contractAddress);

    /// @notice The NFT token contract does not support ERC721Metadata.
    error IPAssetRegistry__UnsupportedIERC721Metadata(address contractAddress);

    /// @notice The NFT token id does not exist or invalid.
    error IPAssetRegistry__InvalidToken(address contractAddress, uint256 tokenId);

    ////////////////////////////////////////////////////////////////////////////
    //                            License Registry                            //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error LicenseRegistry__ZeroAccessManager();

    /// @notice Zero address provided for Licensing Module.
    error LicenseRegistry__ZeroLicensingModule();

    /// @notice Zero address provided for Dispute Module.
    error LicenseRegistry__ZeroDisputeModule();

    /// @notice Caller is not the Licensing Module.
    error LicenseRegistry__CallerNotLicensingModule();

    /// @notice Emitted when trying to transfer a license that is not transferable (by policy)
    error LicenseRegistry__NotTransferable();

    /// @notice License Template is not registered in the License Registry.
    error LicenseRegistry__UnregisteredLicenseTemplate(address licenseTemplate);

    /// @notice License Terms or License Template not found.
    error LicenseRegistry__LicenseTermsNotExists(address licenseTemplate, uint256 licenseTermsId);

    /// @notice Licensor IP does not have the provided license terms attached.
    error LicenseRegistry__LicensorIpHasNoLicenseTerms(address ipId, address licenseTemplate, uint256 licenseTermsId);

    /// @notice Invalid License Template address provided.
    error LicenseRegistry__NotLicenseTemplate(address licenseTemplate);

    /// @notice IP is expired.
    error LicenseRegistry__IpExpired(address ipId);

    /// @notice Parent IP is expired.
    error LicenseRegistry__ParentIpExpired(address ipId);

    /// @notice Parent IP is dispute tagged.
    error LicenseRegistry__ParentIpTagged(address ipId);

    /// @notice Parent IP does not have the provided license terms attached.
    error LicenseRegistry__ParentIpHasNoLicenseTerms(address ipId, uint256 licenseTermsId);

    /// @notice Empty Parent IP list provided.
    error LicenseRegistry__NoParentIp();

    /// @notice Provided derivative IP already has license terms attached.
    error LicenseRegistry__DerivativeIpAlreadyHasLicense(address childIpId);

    /// @notice Provided derivative IP is already registered.
    error LicenseRegistry__DerivativeAlreadyRegistered(address childIpId);

    /// @notice Provided derivative IP is the same as the parent IP.
    error LicenseRegistry__DerivativeIsParent(address ipId);

    /// @notice Provided license template does not match the parent IP's current license template.
    error LicenseRegistry__ParentIpUnmatchedLicenseTemplate(address ipId, address licenseTemplate);

    /// @notice Index out of bounds.
    error LicenseRegistry__IndexOutOfBounds(address ipId, uint256 index, uint256 length);

    /// @notice Provided license template and terms ID is already attached to IP.
    error LicenseRegistry__LicenseTermsAlreadyAttached(address ipId, address licenseTemplate, uint256 licenseTermsId);

    /// @notice Provided license template does not match the IP's current license template.
    error LicenseRegistry__UnmatchedLicenseTemplate(address ipId, address licenseTemplate, address newLicenseTemplate);

    /// @notice Provided license template and terms ID is a duplicate.
    error LicenseRegistry__DuplicateLicense(address ipId, address licenseTemplate, uint256 licenseTermsId);

    ////////////////////////////////////////////////////////////////////////////
    //                             License Token                              //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error LicenseToken__ZeroAccessManager();

    /// @notice Zero address provided for Licensing Module.
    error LicenseToken__ZeroLicensingModule();

    /// @notice Zero address provided for Dispute Module.
    error LicenseToken__ZeroDisputeModule();

    /// @notice Caller is not the Licensing Module.
    error LicenseToken__CallerNotLicensingModule();

    /// @notice License token is revoked.
    error LicenseToken__RevokedLicense(uint256 tokenId);

    /// @notice License token is not transferable.
    error LicenseToken__NotTransferable();

    /// @notice License token is expired.
    error LicenseToken__LicenseTokenExpired(uint256 tokenId, uint256 expiredAt, uint256 currentTimestamp);

    /// @notice License token is not owned by the caller.
    error LicenseToken__NotLicenseTokenOwner(uint256 tokenId, address iPowner, address tokenOwner);

    /// @notice All license tokens must be from the same license template.
    error LicenseToken__AllLicenseTokensMustFromSameLicenseTemplate(
        address licenseTemplate,
        address anotherLicenseTemplate
    );

    ////////////////////////////////////////////////////////////////////////////
    //                           Licensing Module                             //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error LicensingModule__ZeroAccessManager();

    /// @notice Receiver is zero address.
    error LicensingModule__ReceiverZeroAddress();

    /// @notice Mint amount is zero.
    error LicensingModule__MintAmountZero();

    /// @notice IP is dispute tagged.
    error LicensingModule__DisputedIpId();

    /// @notice License template and terms ID is not found.
    error LicensingModule__LicenseTermsNotFound(address licenseTemplate, uint256 licenseTermsId);

    /// @notice Derivative IP cannot add license terms.
    error LicensingModule__DerivativesCannotAddLicenseTerms();

    /// @notice Receiver check failed.
    error LicensingModule__ReceiverCheckFailed(address receiver);

    /// @notice IP list and license terms list length mismatch.
    error LicensingModule__LicenseTermsLengthMismatch(uint256 ipLength, uint256 licenseTermsLength);

    /// @notice Parent IP list is empty.
    error LicensingModule__NoParentIp();

    /// @notice Incompatible royalty policy.
    error LicensingModule__IncompatibleRoyaltyPolicy(address royaltyPolicy, address anotherRoyaltyPolicy);

    /// @notice License template and terms are not compatible for the derivative IP.
    error LicensingModule__LicenseNotCompatibleForDerivative(address childIpId);

    /// @notice License token list is empty.
    error LicensingModule__NoLicenseToken();

    /// @notice License tokens are not compatible for the derivative IP.
    error LicensingModule__LicenseTokenNotCompatibleForDerivative(address childIpId, uint256[] licenseTokenIds);

    /// @notice License template denied minting license token during the verification stage.
    error LicensingModule__LicenseDenyMintLicenseToken(
        address licenseTemplate,
        uint256 licenseTermsId,
        address licensorIpId
    );

    ////////////////////////////////////////////////////////////////////////////
    //                             Dispute Module                             //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error DisputeModule__ZeroAccessManager();

    /// @notice Zero address provided for License Registry.
    error DisputeModule__ZeroLicenseRegistry();

    /// @notice Zero address provided for IP Asset Registry.
    error DisputeModule__ZeroIPAssetRegistry();

    /// @notice Zero address provided for Access Controller.
    error DisputeModule__ZeroAccessController();

    /// @notice Zero address provided for Arbitration Policy.
    error DisputeModule__ZeroArbitrationPolicy();

    /// @notice Zero address provided for Arbitration Relayer.
    error DisputeModule__ZeroArbitrationRelayer();

    /// @notice Zero bytes provided for Dispute Tag.
    error DisputeModule__ZeroDisputeTag();

    /// @notice Zero bytes provided for Dispute Evidence.
    error DisputeModule__ZeroLinkToDisputeEvidence();

    /// @notice Not a whitelisted arbitration policy.
    error DisputeModule__NotWhitelistedArbitrationPolicy();

    /// @notice Not a whitelisted arbitration relayer.
    error DisputeModule__NotWhitelistedArbitrationRelayer();

    /// @notice Not a whitelisted dispute tag.
    error DisputeModule__NotWhitelistedDisputeTag();

    /// @notice Not the dispute initiator.
    error DisputeModule__NotDisputeInitiator();

    /// @notice Not in dispute state, the dispute is not IN_DISPUTE.
    error DisputeModule__NotInDisputeState();

    /// @notice Not able to resolve a dispute, either the dispute is IN_DISPUTE or empty.
    error DisputeModule__NotAbleToResolve();

    /// @notice Not a registered IP.
    error DisputeModule__NotRegisteredIpId();

    /// @notice Provided parent IP and the parent dispute's target IP is different.
    error DisputeModule__ParentIpIdMismatch();

    /// @notice Provided parent dispute's target IP is not dispute tagged.
    error DisputeModule__ParentNotTagged();

    /// @notice Provided parent dispute's target IP is not the derivative IP's parent.
    error DisputeModule__NotDerivative();

    /// @notice Provided parent dispute has not been resolved.
    error DisputeModule__ParentDisputeNotResolved();

    ////////////////////////////////////////////////////////////////////////////
    //                         ArbitrationPolicy SP                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error ArbitrationPolicySP__ZeroAccessManager();

    /// @notice Zero address provided for Dispute Module.
    error ArbitrationPolicySP__ZeroDisputeModule();

    /// @notice Zero address provided for Payment Token.
    error ArbitrationPolicySP__ZeroPaymentToken();

    /// @notice Caller is not the Dispute Module.
    error ArbitrationPolicySP__NotDisputeModule();

    ////////////////////////////////////////////////////////////////////////////
    //                            Royalty Module                              //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error RoyaltyModule__ZeroAccessManager();

    /// @notice Zero address provided for Dispute Module.
    error RoyaltyModule__ZeroDisputeModule();

    /// @notice Zero address provided for License Registry.
    error RoyaltyModule__ZeroLicenseRegistry();

    /// @notice Zero address provided for Licensing Module.
    error RoyaltyModule__ZeroLicensingModule();

    /// @notice Zero address provided for Royalty Policy.
    error RoyaltyModule__ZeroRoyaltyPolicy();

    /// @notice Zero address provided for Royalty Token.
    error RoyaltyModule__ZeroRoyaltyToken();

    /// @notice Not a whitelisted royalty policy.
    error RoyaltyModule__NotWhitelistedRoyaltyPolicy();

    /// @notice Not a whitelisted royalty token.
    error RoyaltyModule__NotWhitelistedRoyaltyToken();

    /// @notice Royalty policy for IP is unset.
    error RoyaltyModule__NoRoyaltyPolicySet();

    /// @notice Royalty policy between IPs are incompatible (different).
    error RoyaltyModule__IncompatibleRoyaltyPolicy();

    /// @notice Caller is unauthorized.
    error RoyaltyModule__NotAllowedCaller();

    /// @notice IP can only mint licenses of selected royalty policy.
    error RoyaltyModule__CanOnlyMintSelectedPolicy();

    /// @notice Parent IP list for linking is empty.
    error RoyaltyModule__NoParentsOnLinking();

    /// @notice IP is expired.
    error RoyaltyModule__IpIsExpired();

    /// @notice IP is dipute tagged.
    error RoyaltyModule__IpIsTagged();

    ////////////////////////////////////////////////////////////////////////////
    //                            Royalty Policy LAP                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error RoyaltyPolicyLAP__ZeroAccessManager();

    /// @notice Zero address provided for IP Royalty Vault Beacon.
    error RoyaltyPolicyLAP__ZeroIpRoyaltyVaultBeacon();

    /// @notice Zero address provided for Royalty Module.
    error RoyaltyPolicyLAP__ZeroRoyaltyModule();

    /// @notice Zero address provided for Licensing Module.
    error RoyaltyPolicyLAP__ZeroLicensingModule();

    /// @notice Caller is not the Royalty Module.
    error RoyaltyPolicyLAP__NotRoyaltyModule();

    /// @notice Size of parent IP list is above the LAP royalty policy limit.
    error RoyaltyPolicyLAP__AboveParentLimit();

    /// @notice Amount of ancestors for derivative IP is above the LAP royalty policy limit.
    error RoyaltyPolicyLAP__AboveAncestorsLimit();

    /// @notice Total royalty stack exceeds the protocol limit.
    error RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

    /// @notice Size of parent royalties list and parent IP list mismatch.
    error RoyaltyPolicyLAP__InvalidParentRoyaltiesLength();

    /// @notice IP cannot be linked to a parent, because it is either already linked to parents or derivatives (root).
    error RoyaltyPolicyLAP__UnlinkableToParents();

    /// @notice Policy is already initialized and IP is at the ancestors limit, so it can't mint more licenses.
    error RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense();

    ////////////////////////////////////////////////////////////////////////////
    //                             IP Royalty Vault                           //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Royalty Policy LAP.
    error IpRoyaltyVault__ZeroRoyaltyPolicyLAP();

    /// @notice Zero address provided for Dispute Module.
    error IpRoyaltyVault__ZeroDisputeModule();

    /// @notice Caller is not the Royalty Policy LAP.
    error IpRoyaltyVault__NotRoyaltyPolicyLAP();

    /// @notice Snapshot interval is too short, wait for the interval to pass for the next snapshot.
    error IpRoyaltyVault__SnapshotIntervalTooShort();

    /// @notice Royalty Tokens is already claimed.
    error IpRoyaltyVault__AlreadyClaimed();

    /// @notice Royalty Tokens claimer is not an ancestor of derivative IP.
    error IpRoyaltyVault__ClaimerNotAnAncestor();

    /// @notice IP is dispute tagged.
    error IpRoyaltyVault__IpTagged();

    /// @notice IP Royalty Vault is paused.
    error IpRoyaltyVault__EnforcedPause();

    ////////////////////////////////////////////////////////////////////////////
    //                             Module Registry                            //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error ModuleRegistry__ZeroAccessManager();

    /// @notice Module is zero address.
    error ModuleRegistry__ModuleAddressZeroAddress();

    /// @notice Provided module address is not a contract.
    error ModuleRegistry__ModuleAddressNotContract();

    /// @notice Module is already registered.
    error ModuleRegistry__ModuleAlreadyRegistered();

    /// @notice Provided module name is empty string.
    error ModuleRegistry__NameEmptyString();

    /// @notice Provided module name is already regsitered.
    error ModuleRegistry__NameAlreadyRegistered();

    /// @notice Module name does not match the given name.
    error ModuleRegistry__NameDoesNotMatch();

    /// @notice Module is not registered
    error ModuleRegistry__ModuleNotRegistered();

    /// @notice Provided interface ID is zero bytes4.
    error ModuleRegistry__InterfaceIdZero();

    /// @notice Module type is already registered.
    error ModuleRegistry__ModuleTypeAlreadyRegistered();

    /// @notice Module type is not registered.
    error ModuleRegistry__ModuleTypeNotRegistered();

    /// @notice Module address does not support the interface ID (module type).
    error ModuleRegistry__ModuleNotSupportExpectedModuleTypeInterfaceId();

    /// @notice Module type is empty string.
    error ModuleRegistry__ModuleTypeEmptyString();

    ////////////////////////////////////////////////////////////////////////////
    //                            Access Controller                           //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error AccessController__ZeroAccessManager();

    /// @notice IP Account is zero address.
    error AccessController__IPAccountIsZeroAddress();

    /// @notice IP Account is not a valid SP IP Account address.
    error AccessController__IPAccountIsNotValid(address ipAccount);

    /// @notice Signer is zero address.
    error AccessController__SignerIsZeroAddress();

    /// @notice Caller is not the IP Account or its owner.
    error AccessController__CallerIsNotIPAccountOrOwner();

    /// @notice Invalid permission value, must be 0 (ABSTAIN), 1 (ALLOW) or 2 (DENY).
    error AccessController__PermissionIsNotValid();

    /// @notice Both the caller and recipient (to) are not registered modules.
    error AccessController__BothCallerAndRecipientAreNotRegisteredModule(address signer, address to);

    /// @notice Permission denied.
    error AccessController__PermissionDenied(address ipAccount, address signer, address to, bytes4 func);

    ////////////////////////////////////////////////////////////////////////////
    //                            Access Controlled                           //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address passed.
    error AccessControlled__ZeroAddress();

    /// @notice IP Account is not a valid SP IP Account address.
    error AccessControlled__NotIpAccount(address ipAccount);

    /// @notice Caller is not the IP Account.
    error AccessControlled__CallerIsNotIpAccount(address caller);

    ////////////////////////////////////////////////////////////////////////////
    //                          Core Metadata Module                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Core metadata is already frozen (immutable).
    error CoreMetadataModule__MetadataAlreadyFrozen();

    ////////////////////////////////////////////////////////////////////////////
    //                          Protocol Pause Admin                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address passed.
    error ProtocolPauseAdmin__ZeroAddress();

    /// @notice Adding a contract that is paused.
    error ProtocolPauseAdmin__AddingPausedContract();

    /// @notice Contract is already added to the pausable list.
    error ProtocolPauseAdmin__PausableAlreadyAdded();

    /// @notice Removing a contract that is not in the pausable list.
    error ProtocolPauseAdmin__PausableNotFound();
}
