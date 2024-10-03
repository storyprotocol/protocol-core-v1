// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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

    /// @notice Execute operation type is not supported.
    error IPAccount__InvalidOperation();

    ////////////////////////////////////////////////////////////////////////////
    //                          CoreMetadataModule                            //
    ////////////////////////////////////////////////////////////////////////////
    error CoreMetadataModule__ZeroAccessManager();

    ////////////////////////////////////////////////////////////////////////////
    //                            IP Account Storage                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Caller writing to IP Account storage is not a registered module.
    error IPAccountStorage__NotRegisteredModule(address module);

    /// @notice Zero address provided for IP Asset Registry.
    error IPAccountStorage__ZeroIpAssetRegistry();

    /// @notice Zero address provided for License Registry.
    error IPAccountStorage__ZeroLicenseRegistry();

    /// @notice Zero address provided for Module Registry.
    error IPAccountStorage__ZeroModuleRegistry();

    /// @notice Invalid batch lengths provided.
    error IPAccountStorage__InvalidBatchLengths();

    ////////////////////////////////////////////////////////////////////////////
    //                           IP Account Registry                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for IP Account implementation.
    error IPAccountRegistry_ZeroIpAccountImpl();

    /// @notice Zero address provided for ERC6551 Registry.
    error IPAccountRegistry_ZeroERC6551Registry();

    ////////////////////////////////////////////////////////////////////////////
    //                        Group IP Asset Registry                         //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The caller to Group IP Asset Registry is not the Grouping Module.
    error GroupIPAssetRegistry__CallerIsNotGroupingModule(address caller);

    /// @notice The give address is not a registered Group IP.
    error GroupIPAssetRegistry__NotRegisteredGroupIP(address groupId);

    /// @notice The give address is not a registered IPA.
    error GroupIPAssetRegistry__NotRegisteredIP(address ipId);

    /// @notice Zero address provided for Group Reward Pool.
    error GroupIPAssetRegistry__InvalidGroupRewardPool(address rewardPool);

    /// @notice Zero address provided for Group Reward Pool.
    error GroupingModule__ZeroGroupRewardPool();

    /// @notice The reward pool is invalid not support the required interfaces.
    error GroupingModule__InvalidGroupRewardPool(address rewardPool);

    /// @notice Zero address provided for Royalty Module.
    error GroupingModule__ZeroRoyaltyModule();

    /// @notice Zero address provided for Module Registry.
    error GroupingModule__ZeroLicenseRegistry();

    /// @notice Zero address provided for Access Manager in initializer.
    error GroupingModule__ZeroAccessManager();

    /// @notice Zero address provided for Group NFT.
    error GroupingModule__ZeroGroupNFT();

    /// @notice Zero address provided for IP Asset Registry.
    error GroupingModule__ZeroIpAssetRegistry();

    /// @notice Zero address provided for License Token.
    error GroupingModule__ZeroLicenseToken();

    /// @notice Invalid address of GroupNFT that does not support IGroupNFT interface.
    error GroupingModule__InvalidGroupNFT(address groupNFT);

    /// @notice Group Pool is not registered.
    error GroupIPAssetRegistry__GroupRewardPoolNotRegistered(address groupPool);

    /// @notice The group ip has derivative IPs.
    error GroupingModule__GroupFrozenDueToHasDerivativeIps(address groupId);

    /// @notice The group ip has no attached any license terms.
    error GroupingModule__GroupIPHasNoLicenseTerms(address groupId);

    /// @notice The IP has no attached the same license terms of Group IPA.
    error GroupingModule__IpHasNoGroupLicenseTerms(address groupId, address licenseTemplate, uint256 licenseTermsId);

    /// @notice The Group IP's license terms should not have minting fee.
    error GroupingModule__GroupIPHasMintingFee(address groupId, address licenseTemplate, uint256 licenseTermsId);

    /// @notice The caller to GroupingModule is not the Licensing Module.
    error GroupingModule__CallerIsNotLicensingModule(address caller);

    /// @notice Cannot add group to group.
    error GroupingModule__CannotAddGroupToGroup(address groupId, address childGroupId);

    /// @notice The Group IP has been frozen.
    error GroupIPAssetRegistry__GroupFrozen(address groupId);

    /// @notice The Group IP has not been frozen.
    error GroupIPAssetRegistry__GroupNotFrozen(address groupId);

    /// @notice The Group IP has been frozen due to already mint license tokens.
    error GroupingModule__GroupFrozenDueToAlreadyMintLicenseTokens(address groupId);

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

    /// @notice Zero address provided for IP Asset Registry.
    error LicensingModule__ZeroRoyaltyModule();

    /// @notice Zero address provided for Licensing Module.
    error LicensingModule__ZeroLicenseRegistry();

    /// @notice Zero address provided for Dispute Module.
    error LicensingModule__ZeroDisputeModule();

    /// @notice Zero address provided for License Token.
    error LicensingModule__ZeroLicenseToken();

    /// @notice Zero address provided for Module Registry.
    error LicensingModule__ZeroModuleRegistry();

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

    /// @notice Provided derivative IP has already had child IP.
    error LicenseRegistry__DerivativeIpAlreadyHasChild(address childIpId);

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

    /// @notice Zero address provided for License Template.
    error LicenseRegistry__ZeroLicenseTemplate();

    /// @notice Failed to add parent IPs to IP graph.
    error LicenseRegistry__AddParentIpToIPGraphFailed(address childIpId, address[] parentIpIds);

    /// @notice Zero address provided for IP Graph ACL.
    error LicenseRegistry__ZeroIPGraphACL();

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

    /// @notice License token is not owned by the either caller or child IP.
    error LicenseToken__CallerAndChildIPNotTokenOwner(
        uint256 tokenId,
        address caller,
        address childIpIp,
        address actualTokenOwner
    );

    /// @notice License token is not owned by the caller.
    error LicenseToken__NotLicenseTokenOwner(uint256 tokenId, address ipOwner, address tokenOwner);

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

    /// @notice minting a license for non-registered IP.
    error LicensingModule__LicensorIpNotRegistered();

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

    /// @notice Licensing hook is invalid either not support ILicensingHook interface or not registered as module
    error LicensingModule__InvalidLicensingHook(address hook);

    /// @notice The license terms ID is invalid or license template doesn't exist.
    error LicensingModule__InvalidLicenseTermsId(address licenseTemplate, uint256 licenseTermsId);

    /// @notice Grouping Module is zero address.
    error LicensingModule__ZeroGroupingModule();

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

    /// @notice IN_DISPUTE tag is not allowed to be whitelisted.
    error DisputeModule__NotAllowedToWhitelist();

    /// @notice Zero bytes provided for Dispute Evidence.
    error DisputeModule__ZeroDisputeEvidenceHash();

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

    /// @notice Zero address provided for Treasury.
    error RoyaltyModule__ZeroTreasury();

    /// @notice Zero address provided for Royalty Policy.
    error RoyaltyModule__ZeroRoyaltyPolicy();

    /// @notice Zero address provided for Royalty Token.
    error RoyaltyModule__ZeroRoyaltyToken();

    /// @notice Zero maximum parents provided.
    error RoyaltyModule__ZeroMaxParents();

    /// @notice Zero maximum ancestors provided.
    error RoyaltyModule__ZeroMaxAncestors();

    /// @notice Zero address provided for parent ipId.
    error RoyaltyModule__ZeroParentIpId();

    /// @notice Above maximum percentage.
    error RoyaltyModule__AboveMaxPercent();

    /// @notice Caller is unauthorized.
    error RoyaltyModule__NotAllowedCaller();

    /// @notice Parent IP list for linking is empty.
    error RoyaltyModule__NoParentsOnLinking();

    /// @notice IP is dipute tagged.
    error RoyaltyModule__IpIsTagged();

    /// @notice Last position IP is not able to mint more licenses.
    error RoyaltyModule__LastPositionNotAbleToMintLicense();

    /// @notice The IP is not allowed to link to parents.
    error RoyaltyModule__UnlinkableToParents();

    /// @notice Size of parent IP list is above limit.
    error RoyaltyModule__AboveParentLimit();

    /// @notice Amount of ancestors for derivative IP is above the limit.
    error RoyaltyModule__AboveAncestorsLimit();

    /// @notice Royalty policy is already whitelisted or registered.
    error RoyaltyModule__PolicyAlreadyWhitelistedOrRegistered();

    /// @notice Royalty Policy is not whitelisted or registered.
    error RoyaltyModule__NotWhitelistedOrRegisteredRoyaltyPolicy();

    /// @notice Receiver ipId has no royalty vault.
    error RoyaltyModule__ZeroReceiverVault();

    /// @notice Zero amount provided.
    error RoyaltyModule__ZeroAmount();

    /// @notice Zero value for accumulated royalty policies limit.
    error RoyaltyModule__ZeroAccumulatedRoyaltyPoliciesLimit();

    /// @notice Above accumulated royalty policies limit.
    error RoyaltyModule__AboveAccumulatedRoyaltyPoliciesLimit();

    /// @notice Zero address for ip asset registry.
    error RoyaltyModule__ZeroIpAssetRegistry();

    /// @notice Not a whitelisted royalty token.
    error RoyaltyModule__NotWhitelistedRoyaltyToken();

    ////////////////////////////////////////////////////////////////////////////
    //                            Royalty Policy LAP                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Access Manager in initializer.
    error RoyaltyPolicyLAP__ZeroAccessManager();

    /// @notice Zero address provided for Royalty Module.
    error RoyaltyPolicyLAP__ZeroRoyaltyModule();

    /// @notice Zero address provided for IP Graph ACL.
    error RoyaltyPolicyLAP__ZeroIPGraphACL();

    /// @notice Caller is not the Royalty Module.
    error RoyaltyPolicyLAP__NotRoyaltyModule();

    /// @notice IP is dispute tagged.
    error RoyaltyPolicyLAP__IpTagged();

    /// @notice IP is not allowed to claim revenue tokens.
    error RoyaltyPolicyLAP__AlreadyClaimed();

    /// @notice Claimer is not an ancestor of the IP.
    error RoyaltyPolicyLAP__ClaimerNotAnAncestor();

    /// @notice Not all revenue tokens have been claimed yet.
    error RoyaltyPolicyLAP__NotAllRevenueTokensHaveBeenClaimed();

    /// @notice There is no vault associated with the IP.
    error RoyaltyPolicyLAP__InvalidTargetIpId();

    /// @notice Zero claimable royalty.
    error RoyaltyPolicyLAP__ZeroClaimableRoyalty();

    /// @notice Amount exceeds the claimable royalty.
    error RoyaltyPolicyLAP__ExceedsClaimableRoyalty();

    /// @notice Above maximum percentage.
    error RoyaltyPolicyLAP__AboveMaxPercent();

    /// @notice Zero amount provided.
    error RoyaltyPolicyLAP__ZeroAmount();

    ////////////////////////////////////////////////////////////////////////////
    //                            Royalty Policy LRP                          //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Caller is not the Royalty Module.
    error RoyaltyPolicyLRP__NotRoyaltyModule();

    /// @notice Zero address provided for IP Graph ACL.
    error RoyaltyPolicyLRP__ZeroIPGraphACL();

    /// @notice Zero address provided for Royalty Module.
    error RoyaltyPolicyLRP__ZeroRoyaltyModule();

    /// @notice Zero address provided for Access Manager in initializer.
    error RoyaltyPolicyLRP__ZeroAccessManager();

    /// @notice Zero claimable royalty.
    error RoyaltyPolicyLRP__ZeroClaimableRoyalty();

    /// @notice Claimer is not an ancestor of the IP.
    error RoyaltyPolicyLRP__ExceedsClaimableRoyalty();

    /// @notice Above maximum percentage.
    error RoyaltyPolicyLRP__AboveMaxPercent();

    /// @notice Zero amount provided.
    error RoyaltyPolicyLRP__ZeroAmount();

    ////////////////////////////////////////////////////////////////////////////
    //                         IP Royalty Vault                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for Dispute Module.
    error IpRoyaltyVault__ZeroDisputeModule();

    /// @notice Zero address provided for Royalty Module.
    error IpRoyaltyVault__ZeroRoyaltyModule();

    /// @notice Caller is not Royalty Module.
    error IpRoyaltyVault__NotAllowedToAddTokenToVault();

    /// @notice Wait for the interval to pass for the next snapshot.
    error IpRoyaltyVault__InsufficientTimeElapsedSinceLastSnapshot();

    /// @notice No new revenue since the last snapshot.
    error IpRoyaltyVault__NoNewRevenueSinceLastSnapshot();

    /// @notice There is no ip royalty vault for the provided IP.
    error IpRoyaltyVault__InvalidTargetIpId();

    /// @notice No claimable tokens.
    error IpRoyaltyVault__NoClaimableTokens();

    /// @notice Not a whitelisted royalty token.
    error IpRoyaltyVault__NotWhitelistedRoyaltyToken();

    /// @notice IP Royalty Vault is paused.
    error IpRoyaltyVault__EnforcedPause();

    /// @notice The vault which is claiming does not belong to an ancestor IP.
    error IpRoyaltyVault__VaultDoesNotBelongToAnAncestor();

    /// @notice Zero amount provided.
    error IpRoyaltyVault__ZeroAmount();

    /// @notice Vaults must claim as self.
    error IpRoyaltyVault__VaultsMustClaimAsSelf();

    ////////////////////////////////////////////////////////////////////////////
    //                            Vault Controller                            //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for IP Royalty Vault Beacon.
    error VaultController__ZeroIpRoyaltyVaultBeacon();

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

    /// @notice Zero address provided for IP Account Registry.
    error AccessController__ZeroIPAccountRegistry();

    /// @notice Zero address provided for Module Registry.
    error AccessController__ZeroModuleRegistry();

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

    /// @notice Both recipient (to) and function selectors are zero address means delegate all permissions to signer.
    error AccessController__ToAndFuncAreZeroAddressShouldCallSetAllPermissions();

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

    ////////////////////////////////////////////////////////////////////////////
    //                               IPGraphACL                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice The address is not whitelisted.
    error IPGraphACL__NotWhitelisted(address addr);

    ////////////////////////////////////////////////////////////////////////////
    //                               Group IPA                                //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Caller is not the IPA Asset Registry.
    error GroupNFT__CallerNotGroupingModule(address caller);

    /// @notice Zero address provided for Access Manager.
    error GroupNFT__ZeroAccessManager();

    ////////////////////////////////////////////////////////////////////////////
    //                           EvenSplitGroup                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @notice Zero address provided for GroupingModule.
    error EvenSplitGroupPool__ZeroGroupingModule();

    /// @notice Zero address provided for RoyaltyModule.
    error EvenSplitGroupPool__ZeroRoyaltyModule();

    /// @notice Zero address provided for IPAssetRegistry.
    error EvenSplitGroupPool__ZeroIPAssetRegistry();

    /// @notice Caller is not the GroupingModule.
    error EvenSplitGroupPool__CallerIsNotGroupingModule(address caller);

    /// @notice Unregistered currency token.
    error EvenSplitGroupPool__UnregisteredCurrencyToken(address currencyToken);

    /// @notice Unregistered group IP.
    error EvenSplitGroupPool__UnregisteredGroupIP(address groupId);
}
