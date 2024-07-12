# CHANGELOG

## v1.1.0

- Gas optimization in IpRoyaltyVault (#114)
- Expiration time modifications
	- Remove expiration time from License Tokens (#123)
	- Fix expiration time of child IPs to not exceed parent IPs (#129)
- Unified Licensing Hook for minting fee and receiver check hooks (#115)
- Enhance permission management and security with setAllPermissions in Access Controller (#127)
- CREATE3 deployment for deterministic address deployment (#124, #132)
- Migrate to Solady ERC6551 for IP Account (#133)
- Support batch operations in IP Account Storage (#134)
- Fix missing License Terms ID in tokenURI (#136)
- Add issue and pull request templates (#120, #121)
- Miscellaneous changes (#130)
- More tests (#101)

Full Changelog: [v1.0.0...v1.1.0](https://github.com/storyprotocol/protocol-core/compare/v1.0.0...v1.1.0)

## v1.0.0

- Introduce new Licensing System (#33, #37, #64, #75, #94)
	- Licensing Module, License Registry, License Token (ERC-721), and PILicenseTemplate
	- Expiring License Tokens & IP
	- Variable minting pricing of License Tokens via hooks
	- Option to register derivative IPs without minting License Tokens
	- Default Selected License Template and Terms
	- PILicense offchain metadata, currency, and templating
	- Permit linking to parent only once
- Introduce pausability for the protocol by the governance (#76)
- Enhance Access Controller (#89, #97)
	- Improve security by removing global permission
	- Allows IP owners to directly set permissions
	- Allows IP owners to call any external contracts
	- Flatten if structure in `checkPermissions`
- Modify Dispute Module to add a hook and mechanism for permissionless tagging of IPs with disputed parent IPs (#60)
- Add expired getter for IPs for real-time IP expiry tagging in Dispute Module (#87)
- Maintain cross-chain registration for IP Accounts (#55)
- Refactor Governance to OZ Access Manager to leverage timelocked protocol admin functions (#43)
- Limit writes to IPAccountStorage to registered modules (#103)
- Enhancements to the IP Royalty Vault (#32, #78, #90) and Royalty Policy LAP (#91)
- Enhancements for contract upgradeability (#38, #82, #88) and testing of upgradeability (#95)
- Simplify the testing to a single framework for tests and deployment (#36)
- Bolster testing (#36, #52, #64, #85, #111)
- CREATE3 for deterministic address deployments (#104)
- Miscellaneous configs (#50), code cleanup (#52, #112) and structure (#56, #85), and pkg bump (#34)
- Enhance CI/CD (#72, #92)

Full Changelog: [v1.0.0-rc.1...v1.0.0](https://github.com/storyprotocol/protocol-core/compare/v1.0.0-rc.1...v1.0.0)

## v1.0.0-rc.1

- Migrate to upgradable contracts (for some) and toolings (#6, #7, #8, #16, #25)
- Introduce IPAccount Namespace Storage for Open Data Access design and IViewModule for Enhanced Metadata Display (#2)
- Introduce the Core Metadata Module and its View Module for storing and viewing metadata in individual IPAccounts (#15)
- Deprecate Registration Module (#3) and IPAssetRenderer (#14)
- Simplify RoyaltyPolicyLAP logic by removing native token payment (#1) and ancestor hash & royalty context (#4) with additional minor changes.
- Simplify IP registration in IPAssetRegistry and enable permissionless registration on behalf of IP NFT owners (#17)
- Replace SP royalty policy's 0xSplits with custom ERC20 Royalty Vault based on ERC20Snapshot (#26)
- Prevent child IPs from linking to parents more than once in the LicensingModule (#28)
- Refactor codebase structure (#29)
- Enhance CI/CD and repo (#10, #11, #12, #13, #16, #18), bump pkgs (#19...#24), and misc. (#27, #30)

## v1.0.0-beta-rc6

This release patches the beta release of Story Protocol.

- Update License NFT image and names (#141)
- Update PIL dispute terms (#140)

Full Changelog: [v1.0.0-beta-rc5...v1.0.0-beta-rc6](https://github.com/storyprotocol/protocol-core/compare/v1.0.0-beta-rc5...v1.0.0-beta-rc6)

## v1.0.0-beta-rc5

This release marks the official beta release of Story Protocol's smart contracts.

- Allow IPAccount to Execute Calls to External Contracts (#127)
- Add PIL flavors libraries to improve DevEx (#123, #128, #130)
- Add Token Withdrawal Module for token withdrawals for IPAccounts (#131)
- Remove unused TaggingModule (#124)
- Fix Licensing Minting Payment to Account for Mint Amount (#129)
- Update README (#125, #136), Licensing (#135), and Script (#136)

Full Changelog: [v1.0.0-beta-rc4...v1.0.0-beta-rc5](https://github.com/storyprotocol/protocol-core/compare/v1.0.0-beta-rc4...v1.0.0-beta-rc5)

## v1.0.0-beta-rc4

This release marks the unofficial beta release of Story Protocol's smart contracts.

- Integrate the Royalty and Licensing system with new royalty policy (#99)
- Integrate the Dispute and Licensing system (#93)
- Introduce a new Royalty Policy (LAP) for on-chain royalty system (#99, #106)
- Introduce working registration features in IP Asset Registry for registering IP assets, backward compatible with Registration Module (#74, #89)
- Support upfront fee payment on license minting (#113)
- Enhance Modules with Type Support and Introduce Hook Module (#85)
- Enhance Security by Adding Owner Restriction to Permissions (#104)
- Unify the unit and integration testing with a modular test framework (#90)
- Change configurations and linting (#82, #86) and absolute to relative imports (#82, #96)
- Fix logic around license derivatives (#112)
- Fix Caller Parameter in PFM verify (#119)
- Refactor Initialization process of IPAccount registration (#108)
- Clean up and Minimize Base Module Attributes (#81)
- Clean up NatSpec, comments, and standards (#109)
- Add more unit and integration tests (#90, #114)
- Miscellaneous changes (#79, #83, #88, #91, #92, #97, #115, #121)

Full Changelog: [v1.0.0-beta-rc3...v1.0.0-beta-rc4](https://github.com/storyprotocol/protocol-core/compare/v1.0.0-beta-rc3...v1.0.0-beta-rc4)

## v1.0.0-beta-rc3

This release finalizes the external-facing implementation of core modules and registries, as well as the public interfaces and events.

- Split old LicensingRegistry into LicenseRegistry and LicensingModule, where the former stores and deals with all 1155-related data & actions, and the latter stores and facilitates all policy-related data & actions (#72)
- Introduce the IPAssetRegistry that replaces IPRecordRegistry and inherits IPAccountRegistry (#46)
- Add logic and helper contracts to the royalty system using 0xSplits to facilitate enforceable on-chain royalty payment (#53)
- Integrate the core royalty and licensing logic to enforce the terms of commercial license policies with royalty requirements on derivatives (#60, #65, #67)
- Accommodate a modifier-based approach for Access Control; Provide optionality for access control checks; and Improve other AccessController states and functionalities (#45, #63, #70)
- Enable mutable royalty policy settings to provide greater flexibility for IPAccount owners (#67, #73)
- Finalize the canonical metadata provider with flexible provisioning (#49)
- Simplify the concept of frameworks and license policies into PolicyFrameworkManager, which manages all policy registration and executes custom, per-framework actions (#51); Licensing refactored from parameter-based to framework-based flows (#44)
- Enable multi-parent linking for derivatives (#56) and add policy compatibility checks for multi-parent and multi-derivative linking (#61, #66)
- Enhance the UMLPolicyFrameworkManager and UMLPolicy with new structs and fields to execute compatibility checks easily and more efficiently (#65)
- Establish a new integration test framework and test flows and improve existing unit test frameworks (#52, #57, #58)
- Create a basic, functioning Disputer Module with arbitration settings (#62)
- Review interfaces, events, and variables (#76) and GitHub PR actions (#36, #58)
- Refactor contracts for relative imports (#75)

Full Changelog: [v1.0.0-beta-rc2...v1.0.0-beta-rc3](https://github.com/storyprotocol/protocol-core/compare/v1.0.0-beta-rc2...v1.0.0-beta-rc3)

## v1.0.0-beta-rc2

This release introduces new modules, registries, libraries, and other logics into the protocol.

- Define concrete Events and Interfaces for all modules and registries (#25, #28, #29)
- Introduce a simple governance mechanism (#35)
- Add a canonical IPMetadataProvider as the default resolver and add more resolvers (#30)
- Add a basic IPAssetRenderer for rendering canonical metadata associated with each IP Asset (#30)
- Accommodate more flexible Records for resolvers in the IP Record Registry (#30)
- Support meta-transaction (execution with signature) on IPAccount implementation (#32)
- Upgrade License Registry logics for more expressive and comprehensive parameter verifiers (hooks) and license policy enforcement for derivative IPAssets (#23, #31)
- Enhance the deployment script & post-deployment interactions, as well as the Integration tests to capture more use-case flows (#33)
- Enhance the Unit tests for better coverage (#29, #30, #35)

Full Changelog: [v1.0.0-beta-rc1...v1.0.0-beta-rc2](https://github.com/storyprotocol/protocol-core/compare/d0df7d4...v1.0.0-beta-rc2)

## v1.0.0-beta-rc1
