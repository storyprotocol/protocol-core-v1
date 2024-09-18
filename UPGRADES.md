# Upgrade process

When performing an upgrade on EVM contracts, the biggest risk is to introduce storage layout collisions. This may degrade a contract storage, which can do things like change token balances, change a stored address to other contract for garbage data, etc.

These errors might harder to detect, even happening some time after deployment.

In order to prevent this:

## 1. Make sure the implementations follow ERC7201

check the project README.md for more info

## 2. [Use OZ upgrades](https://docs.openzeppelin.com/upgrades-plugins/1.x/api-core) to test for storage layout incompatibility

2.1. Get diff between tags to scope the changes, for example

https://github.com/storyprotocol/protocol-core-v1/compare/v1.0.0...v1.1.0

2.2. Keep a file with the versions of the old tag and dependencies, so the test compiles and oz upgrades can compare storage layouts.

example:

https://github.com/Ramarti/protocol-core-v1/blob/v1.1.0_upgrade_script/contracts/old/v1.0.0.sol

This is largely a manual task, but there is a process and some commands that could help

2.2.1 First, git clone the old tag in a folder inside the repo. Make sure it’s gitignored, you must delete later

```jsx
git clone --depth 1 --branch v1.0.0 git@github.com:storyprotocol/protocol-core-v1.git v1.0.0
```

2.2.2 Now we should find and rename the old contract names to reflect the version, like `DisputeModule_V1_0_0` 

After this, there are 2 ways to make them compile

a) Fix the stray absolute import path for relative ones.

b) Flatten everything into a file. You can flatten the files with

```jsx
forge flatten contracts/old/v1.0.0/contracts/modules/dispute/DisputeModule.sol > contracts/old/DisputeModule.sol
```

then you can use the VSCode extension [Combine Code in Folder](https://marketplace.visualstudio.com/items?itemName=ToanBui.combine-code-in-folder) and manual labor.

2.2.3 Add this tags to the newer implementations of the contracts, so the script can compare. For example

```solidity
/// @custom:oz-upgrades-from contracts/old/v1.0.0.sol:AccessController_V1_0_0
contract AccessController is IAccessController, ProtocolPausableUpgradeable, UUPSUpgradeable {
```

2.2.4 Now when we run the tests, they will run the storage layout checker script and we will get a list with errors to correct.

Note, some are going to be false positives, especially Solady and UpgradeableBeacon. Once we fix all of them, we may need to disable the verification so the tests can run

## 3. Write a script to deploy the new contracts and implementations

Inherit from UpgradedImplHelper to compile the upgrade structs that `_writeUpgradeProposals()` need to generate the output file
Upgrading is a multi step process, we need to schedule first, then execute. Having an intermediary file helps the auditability
of the process.

Remember to use CREATE3 for new proxy contracts

Example:

```solidity
contract DeployerV1_2 is JsonDeploymentHandler, BroadcastManager, UpgradedImplHelper {
    ///

    string constant PREV_VERSION = "v1.1.1";
    string constant PROPOSAL_VERSION = "v1.2.0";


    constructor() JsonDeploymentHandler("main") {
        create3Deployer = ICreate3Deployer(CREATE3_DEPLOYER);
    }

    function run() public virtual {
        _readDeployment(PREV_VERSION); // JsonDeploymentHandler.s.sol
        // Load existing contracts
        protocolAccessManager = AccessManager(_readAddress("ProtocolAccessManager"));
        /// ...

        _beginBroadcast(); // BroadcastManager.s.sol

        UpgradeProposal[] memory proposals = deploy();
        _writeUpgradeProposals(PREV_VERSION, PROPOSAL_VERSION, proposals); // JsonDeploymentHandler.s.sol

        _endBroadcast(); // BroadcastManager.s.sol
    }

    function deploy() public returns (UpgradeProposal[] memory) {
        string memory contractKey;
        address impl;

        // Deploy new contracts
        _predeploy("RoyaltyPolicyLRP");
        impl = address(new RoyaltyPolicyLRP(address(royaltyModule)));
        royaltyPolicyLRP = RoyaltyPolicyLRP(
            TestProxyHelper.deployUUPSProxy(
                create3Deployer,
                _getSalt(type(RoyaltyPolicyLRP).name),
                impl,
                abi.encodeCall(RoyaltyPolicyLRP.initialize, address(protocolAccessManager))
            )
        );
        require(
            _getDeployedAddress(type(RoyaltyPolicyLRP).name) == address(royaltyPolicyLRP),
            "Deploy: Royalty Policy Address Mismatch"
        );
        require(_loadProxyImpl(address(royaltyPolicyLRP)) == impl, "RoyaltyPolicyLRP Proxy Implementation Mismatch");
        impl = address(0);
        _postdeploy("RoyaltyPolicyLRP", address(royaltyPolicyLRP));
        
        //...

        // Deploy new implementations
        contractKey = "LicenseToken";
        _predeploy(contractKey);
        impl = address(new LicenseToken(licensingModule, disputeModule));
        upgradeProposals.push(UpgradeProposal({ key: contractKey, proxy: address(licenseToken), newImpl: impl }));
        impl = address(0);

        //...

        _logUpgradeProposals();
        
        return upgradeProposals;
    }
}
```

For `IPRoyaltyVault`, set as proxy the address of the contract that is `IVaultController`

Output will look something like:

`deploy-out/upgrade-v1.1.1-to-v1.2.0-1513.json`
```
{
  "main": {
    "GroupingModule-NewImpl": "0xa1A9b2cBb4fFEeF7226Eaee9A5b71007bDCa721F",
    "GroupingModule-Proxy": "0xeD1eF5749468B1805952757F53aB4C9037cD3ed6",
    // ...
  }
}
```

## 4. Write contracts inheriting UpgradeExecutor

`script/foundry/utils/upgrades/UpgradeExecutor.s.sol` has the logic to read the upgrade proposal file, and act on Access Manager

```solidity
/// @notice Upgrade modes
enum UpgradeModes {
     SCHEDULE, // Schedule upgrades in AccessManager
    EXECUTE, // Execute scheduled upgrades
    CANCEL // Cancel scheduled upgrades
}
/// @notice End result of the script
enum Output {
    TX_EXECUTION, // One Tx per operation
    BATCH_TX_EXECUTION, // Use AccessManager to batch actions in 1 tx through (multicall)
    BATCH_TX_JSON // Prepare raw bytes for multisig. Multisig may batch txs (e.g. Gnosis Safe JSON input in tx builder)
}
```

Example of concrete version upgrade (depending on the mode, one of the xxxUpgrades() methods will be called)

```solidity
contract ExecuteV1_2 is UpgradeExecutor {
    
    constructor() UpgradeExecutor(
        "v1.1.1", // From version
        "v1.2.0", // To version
        UpgradeModes.EXECUTE, // Schedule, Cancel or Execute upgrade
        Output.BATCH_TX_EXECUTION // Output mode
    ) {}

    function _scheduleUpgrades() internal virtual override {
        console2.log("Scheduling upgrades  -------------");
        _scheduleUpgrade("GroupingModule");
        /...
    }

    function _executeUpgrades() internal virtual override {
        console2.log("Executing upgrades  -------------");
        _executeUpgrade("IpRoyaltyVault");
        /...
    }

    function _cancelScheduledUpgrades() internal virtual override {
        console2.log("Cancelling upgrades  -------------");
        _cancelScheduledUpgrade("GroupingModule");
        /...
    }
}
```

## 5. Execute the scripts

Script name will deppend on your file names. For example:

Deployment (remember to verify)
```
forge script script/foundry/deployment/upgrades/DeployerV1_2.s.sol --fork-url https://testnet.storyrpc.io --broadcast --verify --verifier blockscout --verifier-url https://testnet.storyscan.xyz/api\?
```

Executing the transaction
```
forge script script/foundry/deployment/upgrades/ExecuteV1_2.s.sol --fork-url https://testnet.storyrpc.io --broadcast
```
