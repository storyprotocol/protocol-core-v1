// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/UUPSUpgradeable.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Utils.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {UpgradeableBeacon} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(newImplementation.code.length > 0);
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 */
library ERC1967Utils {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Storage of the initializable contract.
     *
     * It's implemented on a custom ERC-7201 namespace to reduce the risk of storage collisions
     * when using with upgradeable contracts.
     *
     * @custom:storage-location erc7201:openzeppelin.storage.Initializable
     */
    struct InitializableStorage {
        /**
         * @dev Indicates that the contract has been initialized.
         */
        uint64 _initialized;
        /**
         * @dev Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Initializable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant INITIALIZABLE_STORAGE = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

    /**
     * @dev The contract is already initialized.
     */
    error InvalidInitialization();

    /**
     * @dev The contract is not initializing.
     */
    error NotInitializing();

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint64 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that in the context of a constructor an `initializer` may be invoked any
     * number of times. This behavior in the constructor can be useful during testing and is not expected to be used in
     * production.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        // Cache values to avoid duplicated sloads
        bool isTopLevelCall = !$._initializing;
        uint64 initialized = $._initialized;

        // Allowed calls:
        // - initialSetup: the contract is not in the initializing state and no previous version was
        //                 initialized
        // - construction: the contract is initialized at version 1 (no reininitialization) and the
        //                 current contract is just being deployed
        bool initialSetup = initialized == 0 && isTopLevelCall;
        bool construction = initialized == 1 && address(this).code.length == 0;

        if (!initialSetup && !construction) {
            revert InvalidInitialization();
        }
        $._initialized = 1;
        if (isTopLevelCall) {
            $._initializing = true;
        }
        _;
        if (isTopLevelCall) {
            $._initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: Setting the version to 2**64 - 1 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint64 version) {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing || $._initialized >= version) {
            revert InvalidInitialization();
        }
        $._initialized = version;
        $._initializing = true;
        _;
        $._initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /**
     * @dev Reverts if the contract is not in an initializing state. See {onlyInitializing}.
     */
    function _checkInitializing() internal view virtual {
        if (!_isInitializing()) {
            revert NotInitializing();
        }
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        // solhint-disable-next-line var-name-mixedcase
        InitializableStorage storage $ = _getInitializableStorage();

        if ($._initializing) {
            revert InvalidInitialization();
        }
        if ($._initialized != type(uint64).max) {
            $._initialized = type(uint64).max;
            emit Initialized(type(uint64).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint64) {
        return _getInitializableStorage()._initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _getInitializableStorage()._initializing;
    }

    /**
     * @dev Returns a pointer to the storage namespace.
     */
    // solhint-disable-next-line var-name-mixedcase
    function _getInitializableStorage() private pure returns (InitializableStorage storage $) {
        assembly {
            $.slot := INITIALIZABLE_STORAGE
        }
    }
}

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822Proxiable {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable __self = address(this);

    /**
     * @dev The version of the upgrade interface of the contract. If this getter is missing, both `upgradeTo(address)`
     * and `upgradeToAndCall(address,bytes)` are present, and `upgradeTo` must be used if no function should be called,
     * while `upgradeToAndCall` will invoke the `receive` function if the second argument is the empty byte string.
     * If the getter returns `"5.0.0"`, only `upgradeToAndCall(address,bytes)` is present, and the second argument must
     * be the empty byte string if no function should be called, making it impossible to invoke the `receive` function
     * during an upgrade.
     */
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /**
     * @dev The call is from an unauthorized context.
     */
    error UUPSUnauthorizedCallContext();

    /**
     * @dev The storage `slot` is unsupported as a UUID.
     */
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     *
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) public payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data);
    }

    /**
     * @dev Reverts if the execution is not performed via delegatecall or the execution
     * context is not of a proxy with an ERC1967-compliant implementation pointing to self.
     * See {_onlyProxy}.
     */
    function _checkProxy() internal view virtual {
        if (
            address(this) == __self || // Must be called through delegatecall
            ERC1967Utils.getImplementation() != __self // Must be called through an active proxy
        ) {
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Reverts if the execution is performed via delegatecall.
     * See {notDelegated}.
     */
    function _checkNotDelegated() internal view virtual {
        if (address(this) != __self) {
            // Must not be called through delegatecall
            revert UUPSUnauthorizedCallContext();
        }
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev Performs an implementation upgrade with a security check for UUPS proxies, and additional setup call.
     *
     * As a security check, {proxiableUUID} is invoked in the new implementation, and the return value
     * is expected to be the implementation slot in ERC1967.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function _upgradeToAndCallUUPS(address newImplementation, bytes memory data) private {
        try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
            if (slot != ERC1967Utils.IMPLEMENTATION_SLOT) {
                revert UUPSUnsupportedProxiableUUID(slot);
            }
            ERC1967Utils.upgradeToAndCall(newImplementation, data);
        } catch {
            // The implementation is not UUPS
            revert ERC1967Utils.ERC1967InvalidImplementation(newImplementation);
        }
    }
}

// solhint-disable-next-line max-line-length

/// @title Access Permission Library
/// @notice Library for IPAccount access control permissions.
///         These permissions are used by the AccessController.
library AccessPermission {
    /// @notice ABSTAIN means having not enough information to make decision at current level, deferred decision to up
    /// level permission.
    uint8 public constant ABSTAIN = 0;

    /// @notice ALLOW means the permission is granted to transaction signer to call the function.
    uint8 public constant ALLOW = 1;

    /// @notice DENY means the permission is denied to transaction signer to call the function.
    uint8 public constant DENY = 2;

    /// @notice This struct is used to represent permissions in batch operations within the AccessController.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The permission level for the transaction (0 = ABSTAIN, 1 = ALLOW, 2 = DENY).
    struct Permission {
        address ipAccount;
        address signer;
        address to;
        bytes4 func;
        uint8 permission;
    }
}

interface IAccessController {
    /// @notice Emitted when a permission is set.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the IP account
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The permission level
    event PermissionSet(
        address ipAccountOwner,
        address indexed ipAccount,
        address indexed signer,
        address indexed to,
        bytes4 func,
        uint8 permission
    );

    /// @notice Sets a batch of permissions in a single transaction.
    /// @dev This function allows setting multiple permissions at once. Pausable.
    /// @param permissions An array of `Permission` structs, each representing the permission to be set.
    function setBatchPermissions(AccessPermission.Permission[] memory permissions) external;

    /// @notice Sets the permission for a specific function call
    /// @dev Each policy is represented as a mapping from an IP account address to a signer address to a recipient
    /// address to a function selector to a permission level. The permission level can be 0 (ABSTAIN), 1 (ALLOW), or
    /// 2 (DENY).
    /// @dev By default, all policies are set to 0 (ABSTAIN), which means that the permission is not set.
    /// The owner of ipAccount by default has all permission.
    /// address(0) => wildcard
    /// bytes4(0) => wildcard
    /// Specific permission overrides wildcard permission.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The new permission level
    function setPermission(address ipAccount, address signer, address to, bytes4 func, uint8 permission) external;

    /// @notice Checks the permission level for a specific function call. Reverts if permission is not granted.
    /// Otherwise, the function is a noop.
    /// @dev This function checks the permission level for a specific function call.
    /// If a specific permission is set, it overrides the general (wildcard) permission.
    /// If the current level permission is ABSTAIN, the final permission is determined by the upper level.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    function checkPermission(address ipAccount, address signer, address to, bytes4 func) external view;

    /// @notice Returns the permission level for a specific function call.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @return permission The current permission level for the function call on `to` by the `signer` for `ipAccount`
    function getPermission(address ipAccount, address signer, address to, bytes4 func) external view returns (uint8);
}

/// @title IModuleRegistry
/// @dev This interface defines the methods for a module registry in the Story Protocol.
interface IModuleRegistry {
    /// @notice Emitted when a new module is added to the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleAdded(string name, address indexed module, bytes4 indexed moduleTypeInterfaceId, string moduleType);

    /// @notice Emitted when a module is removed from the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleRemoved(string name, address indexed module);

    /// @notice Returns the address of a registered module by its name.
    /// @param name The name of the module.
    /// @return moduleAddress The address of the module.
    function getModule(string memory name) external view returns (address);

    /// @notice Returns the module type of a registered module by its address.
    /// @param moduleAddress The address of the module.
    /// @return moduleType The type of the module as a string.
    function getModuleType(address moduleAddress) external view returns (string memory);

    /// @notice Returns the interface ID of a registered module type.
    /// @param moduleType The name of the module type.
    /// @return moduleTypeInterfaceId The interface ID of the module type as bytes4.
    function getModuleTypeInterfaceId(string memory moduleType) external view returns (bytes4);

    /// @notice Registers a new module type in the registry associate with an interface.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module type to be registered.
    /// @param interfaceId The interface ID associated with the module type.
    function registerModuleType(string memory name, bytes4 interfaceId) external;

    /// @notice Removes a module type from the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module type to be removed.
    function removeModuleType(string memory name) external;

    /// @notice Registers a new module in the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module.
    /// @param moduleAddress The address of the module.
    function registerModule(string memory name, address moduleAddress) external;

    /// @notice Registers a new module in the registry with an associated module type.
    /// @param name The name of the module to be registered.
    /// @param moduleAddress The address of the module.
    /// @param moduleType The type of the module being registered.
    function registerModule(string memory name, address moduleAddress, string memory moduleType) external;

    /// @notice Removes a module from the registry.
    /// @dev Enforced to be only callable by the protocol admin in governance.
    /// @param name The name of the module.
    function removeModule(string memory name) external;

    /// @notice Checks if a module is registered in the protocol.
    /// @param moduleAddress The address of the module.
    /// @return isRegistered True if the module is registered, false otherwise.
    function isRegistered(address moduleAddress) external view returns (bool);
}

/// @title Interface for IP Account Registry
/// @notice This interface manages the registration and tracking of IP Accounts
interface IIPAccountRegistry {
    /// @notice Event emitted when a new IP Account is created
    /// @param account The address of the new IP Account
    /// @param implementation The address of the IP Account implementation
    /// @param chainId The chain ID where the token contract was deployed
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    event IPAccountRegistered(
        address indexed account,
        address indexed implementation,
        uint256 indexed chainId,
        address tokenContract,
        uint256 tokenId
    );

    /// @notice Returns the IPAccount implementation address
    function IP_ACCOUNT_IMPL() external view returns (address);

    /// @notice Returns the IPAccount salt
    function IP_ACCOUNT_SALT() external view returns (bytes32);

    /// @notice Returns the public ERC6551 registry address
    function ERC6551_PUBLIC_REGISTRY() external view returns (address);

    /// @notice Deploys an IPAccount contract with the IPAccount implementation and returns the address of the new IP
    /// @dev The IPAccount deployment deltegates to public ERC6551 Registry
    /// @param chainId The chain ID where the IP Account will be created
    /// @param tokenContract The address of the token contract to be associated with the IP Account
    /// @param tokenId The ID of the token to be associated with the IP Account
    /// @return ipAccountAddress The address of the newly created IP Account
    function registerIpAccount(uint256 chainId, address tokenContract, uint256 tokenId) external returns (address);

    /// @notice Returns the IPAccount address for the given NFT token.
    /// @param chainId The chain ID where the IP Account is located
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    /// @return ipAccountAddress The address of the IP Account associated with the given NFT token
    function ipAccount(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address);

    /// @notice Returns the IPAccount implementation address.
    /// @return The address of the IPAccount implementation
    function getIPAccountImpl() external view returns (address);
}

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/IERC721Receiver.sol)

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be
     * reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/IERC1155Receiver.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @dev Interface that must be implemented by smart contracts in order to receive
 * ERC-1155 token transfers.
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

/// @dev the ERC-165 identifier for this interface is `0x6faff5f1`
interface IERC6551Account {
    /**
     * @dev Allows the account to receive Ether.
     *
     * Accounts MUST implement a `receive` function.
     *
     * Accounts MAY perform arbitrary logic to restrict conditions
     * under which Ether can be received.
     */
    receive() external payable;

    /**
     * @dev Returns the identifier of the non-fungible token which owns the account.
     *
     * The return value of this function MUST be constant - it MUST NOT change over time.
     *
     * @return chainId       The EIP-155 ID of the chain the token exists on
     * @return tokenContract The contract address of the token
     * @return tokenId       The ID of the token
     */
    function token()
        external
        view
        returns (uint256 chainId, address tokenContract, uint256 tokenId);

    /**
     * @dev Returns a value that SHOULD be modified each time the account changes state.
     *
     * @return The current account state
     */
    function state() external view returns (uint256);

    /**
     * @dev Returns a magic value indicating whether a given signer is authorized to act on behalf
     * of the account.
     *
     * MUST return the bytes4 magic value 0x523e3260 if the given signer is valid.
     *
     * By default, the holder of the non-fungible token the account is bound to MUST be considered
     * a valid signer.
     *
     * Accounts MAY implement additional authorization logic which invalidates the holder as a
     * signer or grants signing permissions to other non-holder accounts.
     *
     * @param  signer     The address to check signing authorization for
     * @param  context    Additional data used to determine whether the signer is valid
     * @return magicValue Magic value indicating whether the signer is valid
     */
    function isValidSigner(address signer, bytes calldata context)
        external
        view
        returns (bytes4 magicValue);
}

// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf

/// @title IPAccount Namespaced Storage Interface
/// @dev Provides a structured way to store IPAccount's state using a namespaced storage pattern.
/// This interface facilitates conflict-free data writing by different Modules into the same IPAccount
/// by utilizing namespaces.
/// The default namespace for write operations is determined by the `msg.sender`, ensuring that only the owning Module
/// (i.e., the Module calling the write functions) can write data into its respective namespace.
/// However, read operations are unrestricted and can access any namespace.
///
/// Rules:
/// - The default namespace for a Module is its own address.
/// - Every Module can read data from any namespace.
/// - Only the owning Module (i.e., the Module whose address is used as the namespace) can write data into
///   its respective namespace.
interface IIPAccountStorage {
    /// @dev Sets a bytes value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The bytes value to be stored.
    function setBytes(bytes32 key, bytes calldata value) external;

    /// @dev Retrieves a bytes value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes value stored under the specified key.
    function getBytes(bytes32 key) external view returns (bytes memory);

    /// @dev Retrieves a bytes value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes value stored under the specified key in the given namespace.
    function getBytes(bytes32 namespace, bytes32 key) external view returns (bytes memory);

    /// @dev Sets a bytes32 value under a given key within the default namespace, determined by `msg.sender`.
    /// @param key The key under which to store the value.
    /// @param value The bytes32 value to be stored.
    function setBytes32(bytes32 key, bytes32 value) external;

    /// @dev Retrieves a bytes32 value by a given key from the default namespace.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key.
    function getBytes32(bytes32 key) external view returns (bytes32);

    /// @dev Retrieves a bytes32 value by a given key from a specified namespace.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(bytes32 namespace, bytes32 key) external view returns (bytes32);
}

/// @title IIPAccount
/// @dev IPAccount is a token-bound account that adopts the EIP-6551 standard.
/// These accounts are deployed at deterministic addresses through the official 6551 account registry.
/// As a deployed smart contract, IPAccount can store IP-related information,
/// like ownership of other NFTs such as license NFT or Royalty NFT.
/// IPAccount can interact with modules by making calls as a normal transaction sender.
/// This allows for seamless operations on the state and data of IP.
/// IPAccount is core identity for all actions.
interface IIPAccount is IERC6551Account, IERC721Receiver, IERC1155Receiver, IIPAccountStorage {
    /// @notice Emitted when a transaction is executed.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether sent.
    /// @param data The data sent along with the transaction.
    /// @param nonce The nonce of the transaction.
    event Executed(address indexed to, uint256 value, bytes data, uint256 nonce);

    /// @notice Emitted when a transaction is executed on behalf of the signer.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether sent.
    /// @param data The data sent along with the transaction.
    /// @param nonce The nonce of the transaction.
    /// @param deadline The deadline of the transaction signature.
    /// @param signer The signer of the transaction.
    /// @param signature The signature of the transaction, EIP-712 encoded.
    event ExecutedWithSig(
        address indexed to,
        uint256 value,
        bytes data,
        uint256 nonce,
        uint256 deadline,
        address indexed signer,
        bytes signature
    );

    /// @notice Returns the IPAccount's internal nonce for transaction ordering.
    function state() external view returns (uint256);

    /// @notice Returns the identifier of the non-fungible token which owns the account
    /// @return chainId The EIP-155 ID of the chain the token exists on
    /// @return tokenContract The contract address of the token
    /// @return tokenId The ID of the token
    function token() external view returns (uint256, address, uint256);

    /// @notice Checks if the signer is valid for the given data
    /// @param signer The signer to check
    /// @param data The data to check against
    /// @return The function selector if the signer is valid, 0 otherwise
    function isValidSigner(address signer, bytes calldata data) external view returns (bytes4);

    /// @notice Returns the owner of the IP Account.
    /// @return owner The address of the owner.
    function owner() external view returns (address);

    /// @notice Executes a transaction from the IP Account on behalf of the signer.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @param signer The signer of the transaction.
    /// @param deadline The deadline of the transaction signature.
    /// @param signature The signature of the transaction, EIP-712 encoded.
    /// @return result The return data from the transaction.
    function executeWithSig(
        address to,
        uint256 value,
        bytes calldata data,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external payable returns (bytes memory);

    /// @notice Executes a transaction from the IP Account.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @return result The return data from the transaction.
    function execute(address to, uint256 value, bytes calldata data) external payable returns (bytes memory);
}

// solhint-disable-next-line max-line-length

// OpenZeppelin Contracts (last updated v5.0.0) (access/manager/AccessManaged.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (access/manager/IAuthority.sol)

/**
 * @dev Standard interface for permissioning originally defined in Dappsys.
 */
interface IAuthority {
    /**
     * @dev Returns true if the caller can invoke on a target the function identified by a function selector.
     */
    function canCall(address caller, address target, bytes4 selector) external view returns (bool allowed);
}

// OpenZeppelin Contracts (last updated v5.0.0) (access/manager/AuthorityUtils.sol)

library AuthorityUtils {
    /**
     * @dev Since `AccessManager` implements an extended IAuthority interface, invoking `canCall` with backwards compatibility
     * for the preexisting `IAuthority` interface requires special care to avoid reverting on insufficient return data.
     * This helper function takes care of invoking `canCall` in a backwards compatible way without reverting.
     */
    function canCallWithDelay(
        address authority,
        address caller,
        address target,
        bytes4 selector
    ) internal view returns (bool immediate, uint32 delay) {
        (bool success, bytes memory data) = authority.staticcall(
            abi.encodeCall(IAuthority.canCall, (caller, target, selector))
        );
        if (success) {
            if (data.length >= 0x40) {
                (immediate, delay) = abi.decode(data, (bool, uint32));
            } else if (data.length >= 0x20) {
                immediate = abi.decode(data, (bool));
            }
        }
        return (immediate, delay);
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (access/manager/IAccessManager.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (access/manager/IAccessManaged.sol)

interface IAccessManaged {
    /**
     * @dev Authority that manages this contract was updated.
     */
    event AuthorityUpdated(address authority);

    error AccessManagedUnauthorized(address caller);
    error AccessManagedRequiredDelay(address caller, uint32 delay);
    error AccessManagedInvalidAuthority(address authority);

    /**
     * @dev Returns the current authority.
     */
    function authority() external view returns (address);

    /**
     * @dev Transfers control to a new authority. The caller must be the current authority.
     */
    function setAuthority(address) external;

    /**
     * @dev Returns true only in the context of a delayed restricted call, at the moment that the scheduled operation is
     * being consumed. Prevents denial of service for delayed restricted calls in the case that the contract performs
     * attacker controlled calls.
     */
    function isConsumingScheduledOp() external view returns (bytes4);
}

// OpenZeppelin Contracts (last updated v5.0.0) (utils/types/Time.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeCast {
    /**
     * @dev Value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedUintDowncast(uint8 bits, uint256 value);

    /**
     * @dev An int value doesn't fit in an uint of `bits` size.
     */
    error SafeCastOverflowedIntToUint(int256 value);

    /**
     * @dev Value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedIntDowncast(uint8 bits, int256 value);

    /**
     * @dev An uint value doesn't fit in an int of `bits` size.
     */
    error SafeCastOverflowedUintToInt(uint256 value);

    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        if (value > type(uint248).max) {
            revert SafeCastOverflowedUintDowncast(248, value);
        }
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        if (value > type(uint240).max) {
            revert SafeCastOverflowedUintDowncast(240, value);
        }
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        if (value > type(uint232).max) {
            revert SafeCastOverflowedUintDowncast(232, value);
        }
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        if (value > type(uint224).max) {
            revert SafeCastOverflowedUintDowncast(224, value);
        }
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        if (value > type(uint216).max) {
            revert SafeCastOverflowedUintDowncast(216, value);
        }
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        if (value > type(uint208).max) {
            revert SafeCastOverflowedUintDowncast(208, value);
        }
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        if (value > type(uint200).max) {
            revert SafeCastOverflowedUintDowncast(200, value);
        }
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        if (value > type(uint192).max) {
            revert SafeCastOverflowedUintDowncast(192, value);
        }
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        if (value > type(uint184).max) {
            revert SafeCastOverflowedUintDowncast(184, value);
        }
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        if (value > type(uint176).max) {
            revert SafeCastOverflowedUintDowncast(176, value);
        }
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        if (value > type(uint168).max) {
            revert SafeCastOverflowedUintDowncast(168, value);
        }
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        if (value > type(uint160).max) {
            revert SafeCastOverflowedUintDowncast(160, value);
        }
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        if (value > type(uint152).max) {
            revert SafeCastOverflowedUintDowncast(152, value);
        }
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        if (value > type(uint144).max) {
            revert SafeCastOverflowedUintDowncast(144, value);
        }
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        if (value > type(uint136).max) {
            revert SafeCastOverflowedUintDowncast(136, value);
        }
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        if (value > type(uint128).max) {
            revert SafeCastOverflowedUintDowncast(128, value);
        }
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        if (value > type(uint120).max) {
            revert SafeCastOverflowedUintDowncast(120, value);
        }
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        if (value > type(uint112).max) {
            revert SafeCastOverflowedUintDowncast(112, value);
        }
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        if (value > type(uint104).max) {
            revert SafeCastOverflowedUintDowncast(104, value);
        }
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        if (value > type(uint96).max) {
            revert SafeCastOverflowedUintDowncast(96, value);
        }
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        if (value > type(uint88).max) {
            revert SafeCastOverflowedUintDowncast(88, value);
        }
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        if (value > type(uint80).max) {
            revert SafeCastOverflowedUintDowncast(80, value);
        }
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        if (value > type(uint72).max) {
            revert SafeCastOverflowedUintDowncast(72, value);
        }
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        if (value > type(uint64).max) {
            revert SafeCastOverflowedUintDowncast(64, value);
        }
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        if (value > type(uint56).max) {
            revert SafeCastOverflowedUintDowncast(56, value);
        }
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        if (value > type(uint48).max) {
            revert SafeCastOverflowedUintDowncast(48, value);
        }
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        if (value > type(uint40).max) {
            revert SafeCastOverflowedUintDowncast(40, value);
        }
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        if (value > type(uint32).max) {
            revert SafeCastOverflowedUintDowncast(32, value);
        }
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        if (value > type(uint24).max) {
            revert SafeCastOverflowedUintDowncast(24, value);
        }
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        if (value > type(uint16).max) {
            revert SafeCastOverflowedUintDowncast(16, value);
        }
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        if (value > type(uint8).max) {
            revert SafeCastOverflowedUintDowncast(8, value);
        }
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        if (value < 0) {
            revert SafeCastOverflowedIntToUint(value);
        }
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(248, value);
        }
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(240, value);
        }
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(232, value);
        }
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(224, value);
        }
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(216, value);
        }
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(208, value);
        }
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(200, value);
        }
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(192, value);
        }
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(184, value);
        }
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(176, value);
        }
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(168, value);
        }
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(160, value);
        }
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(152, value);
        }
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(144, value);
        }
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(136, value);
        }
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(128, value);
        }
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(120, value);
        }
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(112, value);
        }
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(104, value);
        }
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(96, value);
        }
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(88, value);
        }
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(80, value);
        }
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(72, value);
        }
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(64, value);
        }
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(56, value);
        }
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(48, value);
        }
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(40, value);
        }
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(32, value);
        }
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(24, value);
        }
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(16, value);
        }
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        if (downcasted != value) {
            revert SafeCastOverflowedIntDowncast(8, value);
        }
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        if (value > uint256(type(int256).max)) {
            revert SafeCastOverflowedUintToInt(value);
        }
        return int256(value);
    }
}

/**
 * @dev This library provides helpers for manipulating time-related objects.
 *
 * It uses the following types:
 * - `uint48` for timepoints
 * - `uint32` for durations
 *
 * While the library doesn't provide specific types for timepoints and duration, it does provide:
 * - a `Delay` type to represent duration that can be programmed to change value automatically at a given point
 * - additional helper functions
 */
library Time {
    using Time for *;

    /**
     * @dev Get the block timestamp as a Timepoint.
     */
    function timestamp() internal view returns (uint48) {
        return SafeCast.toUint48(block.timestamp);
    }

    /**
     * @dev Get the block number as a Timepoint.
     */
    function blockNumber() internal view returns (uint48) {
        return SafeCast.toUint48(block.number);
    }

    // ==================================================== Delay =====================================================
    /**
     * @dev A `Delay` is a uint32 duration that can be programmed to change value automatically at a given point in the
     * future. The "effect" timepoint describes when the transitions happens from the "old" value to the "new" value.
     * This allows updating the delay applied to some operation while keeping some guarantees.
     *
     * In particular, the {update} function guarantees that if the delay is reduced, the old delay still applies for
     * some time. For example if the delay is currently 7 days to do an upgrade, the admin should not be able to set
     * the delay to 0 and upgrade immediately. If the admin wants to reduce the delay, the old delay (7 days) should
     * still apply for some time.
     *
     *
     * The `Delay` type is 112 bits long, and packs the following:
     *
     * ```
     *   | [uint48]: effect date (timepoint)
     *   |           | [uint32]: value before (duration)
     *   ↓           ↓       ↓ [uint32]: value after (duration)
     * 0xAAAAAAAAAAAABBBBBBBBCCCCCCCC
     * ```
     *
     * NOTE: The {get} and {withUpdate} functions operate using timestamps. Block number based delays are not currently
     * supported.
     */
    type Delay is uint112;

    /**
     * @dev Wrap a duration into a Delay to add the one-step "update in the future" feature
     */
    function toDelay(uint32 duration) internal pure returns (Delay) {
        return Delay.wrap(duration);
    }

    /**
     * @dev Get the value at a given timepoint plus the pending value and effect timepoint if there is a scheduled
     * change after this timepoint. If the effect timepoint is 0, then the pending value should not be considered.
     */
    function _getFullAt(Delay self, uint48 timepoint) private pure returns (uint32, uint32, uint48) {
        (uint32 valueBefore, uint32 valueAfter, uint48 effect) = self.unpack();
        return effect <= timepoint ? (valueAfter, 0, 0) : (valueBefore, valueAfter, effect);
    }

    /**
     * @dev Get the current value plus the pending value and effect timepoint if there is a scheduled change. If the
     * effect timepoint is 0, then the pending value should not be considered.
     */
    function getFull(Delay self) internal view returns (uint32, uint32, uint48) {
        return _getFullAt(self, timestamp());
    }

    /**
     * @dev Get the current value.
     */
    function get(Delay self) internal view returns (uint32) {
        (uint32 delay, , ) = self.getFull();
        return delay;
    }

    /**
     * @dev Update a Delay object so that it takes a new duration after a timepoint that is automatically computed to
     * enforce the old delay at the moment of the update. Returns the updated Delay object and the timestamp when the
     * new delay becomes effective.
     */
    function withUpdate(
        Delay self,
        uint32 newValue,
        uint32 minSetback
    ) internal view returns (Delay updatedDelay, uint48 effect) {
        uint32 value = self.get();
        uint32 setback = uint32(Math.max(minSetback, value > newValue ? value - newValue : 0));
        effect = timestamp() + setback;
        return (pack(value, newValue, effect), effect);
    }

    /**
     * @dev Split a delay into its components: valueBefore, valueAfter and effect (transition timepoint).
     */
    function unpack(Delay self) internal pure returns (uint32 valueBefore, uint32 valueAfter, uint48 effect) {
        uint112 raw = Delay.unwrap(self);

        valueAfter = uint32(raw);
        valueBefore = uint32(raw >> 32);
        effect = uint48(raw >> 64);

        return (valueBefore, valueAfter, effect);
    }

    /**
     * @dev pack the components into a Delay object.
     */
    function pack(uint32 valueBefore, uint32 valueAfter, uint48 effect) internal pure returns (Delay) {
        return Delay.wrap((uint112(effect) << 64) | (uint112(valueBefore) << 32) | uint112(valueAfter));
    }
}

interface IAccessManager {
    /**
     * @dev A delayed operation was scheduled.
     */
    event OperationScheduled(
        bytes32 indexed operationId,
        uint32 indexed nonce,
        uint48 schedule,
        address caller,
        address target,
        bytes data
    );

    /**
     * @dev A scheduled operation was executed.
     */
    event OperationExecuted(bytes32 indexed operationId, uint32 indexed nonce);

    /**
     * @dev A scheduled operation was canceled.
     */
    event OperationCanceled(bytes32 indexed operationId, uint32 indexed nonce);

    /**
     * @dev Informational labelling for a roleId.
     */
    event RoleLabel(uint64 indexed roleId, string label);

    /**
     * @dev Emitted when `account` is granted `roleId`.
     *
     * NOTE: The meaning of the `since` argument depends on the `newMember` argument.
     * If the role is granted to a new member, the `since` argument indicates when the account becomes a member of the role,
     * otherwise it indicates the execution delay for this account and roleId is updated.
     */
    event RoleGranted(uint64 indexed roleId, address indexed account, uint32 delay, uint48 since, bool newMember);

    /**
     * @dev Emitted when `account` membership or `roleId` is revoked. Unlike granting, revoking is instantaneous.
     */
    event RoleRevoked(uint64 indexed roleId, address indexed account);

    /**
     * @dev Role acting as admin over a given `roleId` is updated.
     */
    event RoleAdminChanged(uint64 indexed roleId, uint64 indexed admin);

    /**
     * @dev Role acting as guardian over a given `roleId` is updated.
     */
    event RoleGuardianChanged(uint64 indexed roleId, uint64 indexed guardian);

    /**
     * @dev Grant delay for a given `roleId` will be updated to `delay` when `since` is reached.
     */
    event RoleGrantDelayChanged(uint64 indexed roleId, uint32 delay, uint48 since);

    /**
     * @dev Target mode is updated (true = closed, false = open).
     */
    event TargetClosed(address indexed target, bool closed);

    /**
     * @dev Role required to invoke `selector` on `target` is updated to `roleId`.
     */
    event TargetFunctionRoleUpdated(address indexed target, bytes4 selector, uint64 indexed roleId);

    /**
     * @dev Admin delay for a given `target` will be updated to `delay` when `since` is reached.
     */
    event TargetAdminDelayUpdated(address indexed target, uint32 delay, uint48 since);

    error AccessManagerAlreadyScheduled(bytes32 operationId);
    error AccessManagerNotScheduled(bytes32 operationId);
    error AccessManagerNotReady(bytes32 operationId);
    error AccessManagerExpired(bytes32 operationId);
    error AccessManagerLockedAccount(address account);
    error AccessManagerLockedRole(uint64 roleId);
    error AccessManagerBadConfirmation();
    error AccessManagerUnauthorizedAccount(address msgsender, uint64 roleId);
    error AccessManagerUnauthorizedCall(address caller, address target, bytes4 selector);
    error AccessManagerUnauthorizedConsume(address target);
    error AccessManagerUnauthorizedCancel(address msgsender, address caller, address target, bytes4 selector);
    error AccessManagerInvalidInitialAdmin(address initialAdmin);

    /**
     * @dev Check if an address (`caller`) is authorised to call a given function on a given contract directly (with
     * no restriction). Additionally, it returns the delay needed to perform the call indirectly through the {schedule}
     * & {execute} workflow.
     *
     * This function is usually called by the targeted contract to control immediate execution of restricted functions.
     * Therefore we only return true if the call can be performed without any delay. If the call is subject to a
     * previously set delay (not zero), then the function should return false and the caller should schedule the operation
     * for future execution.
     *
     * If `immediate` is true, the delay can be disregarded and the operation can be immediately executed, otherwise
     * the operation can be executed if and only if delay is greater than 0.
     *
     * NOTE: The IAuthority interface does not include the `uint32` delay. This is an extension of that interface that
     * is backward compatible. Some contracts may thus ignore the second return argument. In that case they will fail
     * to identify the indirect workflow, and will consider calls that require a delay to be forbidden.
     *
     * NOTE: This function does not report the permissions of this manager itself. These are defined by the
     * {_canCallSelf} function instead.
     */
    function canCall(
        address caller,
        address target,
        bytes4 selector
    ) external view returns (bool allowed, uint32 delay);

    /**
     * @dev Expiration delay for scheduled proposals. Defaults to 1 week.
     *
     * IMPORTANT: Avoid overriding the expiration with 0. Otherwise every contract proposal will be expired immediately,
     * disabling any scheduling usage.
     */
    function expiration() external view returns (uint32);

    /**
     * @dev Minimum setback for all delay updates, with the exception of execution delays. It
     * can be increased without setback (and reset via {revokeRole} in the case event of an
     * accidental increase). Defaults to 5 days.
     */
    function minSetback() external view returns (uint32);

    /**
     * @dev Get whether the contract is closed disabling any access. Otherwise role permissions are applied.
     */
    function isTargetClosed(address target) external view returns (bool);

    /**
     * @dev Get the role required to call a function.
     */
    function getTargetFunctionRole(address target, bytes4 selector) external view returns (uint64);

    /**
     * @dev Get the admin delay for a target contract. Changes to contract configuration are subject to this delay.
     */
    function getTargetAdminDelay(address target) external view returns (uint32);

    /**
     * @dev Get the id of the role that acts as an admin for the given role.
     *
     * The admin permission is required to grant the role, revoke the role and update the execution delay to execute
     * an operation that is restricted to this role.
     */
    function getRoleAdmin(uint64 roleId) external view returns (uint64);

    /**
     * @dev Get the role that acts as a guardian for a given role.
     *
     * The guardian permission allows canceling operations that have been scheduled under the role.
     */
    function getRoleGuardian(uint64 roleId) external view returns (uint64);

    /**
     * @dev Get the role current grant delay.
     *
     * Its value may change at any point without an event emitted following a call to {setGrantDelay}.
     * Changes to this value, including effect timepoint are notified in advance by the {RoleGrantDelayChanged} event.
     */
    function getRoleGrantDelay(uint64 roleId) external view returns (uint32);

    /**
     * @dev Get the access details for a given account for a given role. These details include the timepoint at which
     * membership becomes active, and the delay applied to all operation by this user that requires this permission
     * level.
     *
     * Returns:
     * [0] Timestamp at which the account membership becomes valid. 0 means role is not granted.
     * [1] Current execution delay for the account.
     * [2] Pending execution delay for the account.
     * [3] Timestamp at which the pending execution delay will become active. 0 means no delay update is scheduled.
     */
    function getAccess(uint64 roleId, address account) external view returns (uint48, uint32, uint32, uint48);

    /**
     * @dev Check if a given account currently has the permission level corresponding to a given role. Note that this
     * permission might be associated with an execution delay. {getAccess} can provide more details.
     */
    function hasRole(uint64 roleId, address account) external view returns (bool, uint32);

    /**
     * @dev Give a label to a role, for improved role discoverability by UIs.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     *
     * Emits a {RoleLabel} event.
     */
    function labelRole(uint64 roleId, string calldata label) external;

    /**
     * @dev Add `account` to `roleId`, or change its execution delay.
     *
     * This gives the account the authorization to call any function that is restricted to this role. An optional
     * execution delay (in seconds) can be set. If that delay is non 0, the user is required to schedule any operation
     * that is restricted to members of this role. The user will only be able to execute the operation after the delay has
     * passed, before it has expired. During this period, admin and guardians can cancel the operation (see {cancel}).
     *
     * If the account has already been granted this role, the execution delay will be updated. This update is not
     * immediate and follows the delay rules. For example, if a user currently has a delay of 3 hours, and this is
     * called to reduce that delay to 1 hour, the new delay will take some time to take effect, enforcing that any
     * operation executed in the 3 hours that follows this update was indeed scheduled before this update.
     *
     * Requirements:
     *
     * - the caller must be an admin for the role (see {getRoleAdmin})
     * - granted role must not be the `PUBLIC_ROLE`
     *
     * Emits a {RoleGranted} event.
     */
    function grantRole(uint64 roleId, address account, uint32 executionDelay) external;

    /**
     * @dev Remove an account from a role, with immediate effect. If the account does not have the role, this call has
     * no effect.
     *
     * Requirements:
     *
     * - the caller must be an admin for the role (see {getRoleAdmin})
     * - revoked role must not be the `PUBLIC_ROLE`
     *
     * Emits a {RoleRevoked} event if the account had the role.
     */
    function revokeRole(uint64 roleId, address account) external;

    /**
     * @dev Renounce role permissions for the calling account with immediate effect. If the sender is not in
     * the role this call has no effect.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * Emits a {RoleRevoked} event if the account had the role.
     */
    function renounceRole(uint64 roleId, address callerConfirmation) external;

    /**
     * @dev Change admin role for a given role.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     *
     * Emits a {RoleAdminChanged} event
     */
    function setRoleAdmin(uint64 roleId, uint64 admin) external;

    /**
     * @dev Change guardian role for a given role.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     *
     * Emits a {RoleGuardianChanged} event
     */
    function setRoleGuardian(uint64 roleId, uint64 guardian) external;

    /**
     * @dev Update the delay for granting a `roleId`.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     *
     * Emits a {RoleGrantDelayChanged} event.
     */
    function setGrantDelay(uint64 roleId, uint32 newDelay) external;

    /**
     * @dev Set the role required to call functions identified by the `selectors` in the `target` contract.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     *
     * Emits a {TargetFunctionRoleUpdated} event per selector.
     */
    function setTargetFunctionRole(address target, bytes4[] calldata selectors, uint64 roleId) external;

    /**
     * @dev Set the delay for changing the configuration of a given target contract.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     *
     * Emits a {TargetAdminDelayUpdated} event.
     */
    function setTargetAdminDelay(address target, uint32 newDelay) external;

    /**
     * @dev Set the closed flag for a contract.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     *
     * Emits a {TargetClosed} event.
     */
    function setTargetClosed(address target, bool closed) external;

    /**
     * @dev Return the timepoint at which a scheduled operation will be ready for execution. This returns 0 if the
     * operation is not yet scheduled, has expired, was executed, or was canceled.
     */
    function getSchedule(bytes32 id) external view returns (uint48);

    /**
     * @dev Return the nonce for the latest scheduled operation with a given id. Returns 0 if the operation has never
     * been scheduled.
     */
    function getNonce(bytes32 id) external view returns (uint32);

    /**
     * @dev Schedule a delayed operation for future execution, and return the operation identifier. It is possible to
     * choose the timestamp at which the operation becomes executable as long as it satisfies the execution delays
     * required for the caller. The special value zero will automatically set the earliest possible time.
     *
     * Returns the `operationId` that was scheduled. Since this value is a hash of the parameters, it can reoccur when
     * the same parameters are used; if this is relevant, the returned `nonce` can be used to uniquely identify this
     * scheduled operation from other occurrences of the same `operationId` in invocations of {execute} and {cancel}.
     *
     * Emits a {OperationScheduled} event.
     *
     * NOTE: It is not possible to concurrently schedule more than one operation with the same `target` and `data`. If
     * this is necessary, a random byte can be appended to `data` to act as a salt that will be ignored by the target
     * contract if it is using standard Solidity ABI encoding.
     */
    function schedule(address target, bytes calldata data, uint48 when) external returns (bytes32, uint32);

    /**
     * @dev Execute a function that is delay restricted, provided it was properly scheduled beforehand, or the
     * execution delay is 0.
     *
     * Returns the nonce that identifies the previously scheduled operation that is executed, or 0 if the
     * operation wasn't previously scheduled (if the caller doesn't have an execution delay).
     *
     * Emits an {OperationExecuted} event only if the call was scheduled and delayed.
     */
    function execute(address target, bytes calldata data) external payable returns (uint32);

    /**
     * @dev Cancel a scheduled (delayed) operation. Returns the nonce that identifies the previously scheduled
     * operation that is cancelled.
     *
     * Requirements:
     *
     * - the caller must be the proposer, a guardian of the targeted function, or a global admin
     *
     * Emits a {OperationCanceled} event.
     */
    function cancel(address caller, address target, bytes calldata data) external returns (uint32);

    /**
     * @dev Consume a scheduled operation targeting the caller. If such an operation exists, mark it as consumed
     * (emit an {OperationExecuted} event and clean the state). Otherwise, throw an error.
     *
     * This is useful for contract that want to enforce that calls targeting them were scheduled on the manager,
     * with all the verifications that it implies.
     *
     * Emit a {OperationExecuted} event.
     */
    function consumeScheduledOp(address caller, bytes calldata data) external;

    /**
     * @dev Hashing function for delayed operations.
     */
    function hashOperation(address caller, address target, bytes calldata data) external view returns (bytes32);

    /**
     * @dev Changes the authority of a target managed by this manager instance.
     *
     * Requirements:
     *
     * - the caller must be a global admin
     */
    function updateAuthority(address target, address newAuthority) external;
}

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

/**
 * @dev This contract module makes available a {restricted} modifier. Functions decorated with this modifier will be
 * permissioned according to an "authority": a contract like {AccessManager} that follows the {IAuthority} interface,
 * implementing a policy that allows certain callers to access certain functions.
 *
 * IMPORTANT: The `restricted` modifier should never be used on `internal` functions, judiciously used in `public`
 * functions, and ideally only used in `external` functions. See {restricted}.
 */
abstract contract AccessManagedUpgradeable is Initializable, ContextUpgradeable, IAccessManaged {
    /// @custom:storage-location erc7201:openzeppelin.storage.AccessManaged
    struct AccessManagedStorage {
        address _authority;

        bool _consumingSchedule;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.AccessManaged")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant AccessManagedStorageLocation = 0xf3177357ab46d8af007ab3fdb9af81da189e1068fefdc0073dca88a2cab40a00;

    function _getAccessManagedStorage() private pure returns (AccessManagedStorage storage $) {
        assembly {
            $.slot := AccessManagedStorageLocation
        }
    }

    /**
     * @dev Initializes the contract connected to an initial authority.
     */
    function __AccessManaged_init(address initialAuthority) internal onlyInitializing {
        __AccessManaged_init_unchained(initialAuthority);
    }

    function __AccessManaged_init_unchained(address initialAuthority) internal onlyInitializing {
        _setAuthority(initialAuthority);
    }

    /**
     * @dev Restricts access to a function as defined by the connected Authority for this contract and the
     * caller and selector of the function that entered the contract.
     *
     * [IMPORTANT]
     * ====
     * In general, this modifier should only be used on `external` functions. It is okay to use it on `public`
     * functions that are used as external entry points and are not called internally. Unless you know what you're
     * doing, it should never be used on `internal` functions. Failure to follow these rules can have critical security
     * implications! This is because the permissions are determined by the function that entered the contract, i.e. the
     * function at the bottom of the call stack, and not the function where the modifier is visible in the source code.
     * ====
     *
     * [WARNING]
     * ====
     * Avoid adding this modifier to the https://docs.soliditylang.org/en/v0.8.20/contracts.html#receive-ether-function[`receive()`]
     * function or the https://docs.soliditylang.org/en/v0.8.20/contracts.html#fallback-function[`fallback()`]. These
     * functions are the only execution paths where a function selector cannot be unambiguosly determined from the calldata
     * since the selector defaults to `0x00000000` in the `receive()` function and similarly in the `fallback()` function
     * if no calldata is provided. (See {_checkCanCall}).
     *
     * The `receive()` function will always panic whereas the `fallback()` may panic depending on the calldata length.
     * ====
     */
    modifier restricted() {
        _checkCanCall(_msgSender(), _msgData());
        _;
    }

    /// @inheritdoc IAccessManaged
    function authority() public view virtual returns (address) {
        AccessManagedStorage storage $ = _getAccessManagedStorage();
        return $._authority;
    }

    /// @inheritdoc IAccessManaged
    function setAuthority(address newAuthority) public virtual {
        address caller = _msgSender();
        if (caller != authority()) {
            revert AccessManagedUnauthorized(caller);
        }
        if (newAuthority.code.length == 0) {
            revert AccessManagedInvalidAuthority(newAuthority);
        }
        _setAuthority(newAuthority);
    }

    /// @inheritdoc IAccessManaged
    function isConsumingScheduledOp() public view returns (bytes4) {
        AccessManagedStorage storage $ = _getAccessManagedStorage();
        return $._consumingSchedule ? this.isConsumingScheduledOp.selector : bytes4(0);
    }

    /**
     * @dev Transfers control to a new authority. Internal function with no access restriction. Allows bypassing the
     * permissions set by the current authority.
     */
    function _setAuthority(address newAuthority) internal virtual {
        AccessManagedStorage storage $ = _getAccessManagedStorage();
        $._authority = newAuthority;
        emit AuthorityUpdated(newAuthority);
    }

    /**
     * @dev Reverts if the caller is not allowed to call the function identified by a selector. Panics if the calldata
     * is less than 4 bytes long.
     */
    function _checkCanCall(address caller, bytes calldata data) internal virtual {
        AccessManagedStorage storage $ = _getAccessManagedStorage();
        (bool immediate, uint32 delay) = AuthorityUtils.canCallWithDelay(
            authority(),
            caller,
            address(this),
            bytes4(data[0:4])
        );
        if (!immediate) {
            if (delay > 0) {
                $._consumingSchedule = true;
                IAccessManager(authority()).consumeScheduledOp(caller, data);
                $._consumingSchedule = false;
            } else {
                revert AccessManagedUnauthorized(caller);
            }
        }
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /// @custom:storage-location erc7201:openzeppelin.storage.Pausable
    struct PausableStorage {
        bool _paused;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.Pausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant PausableStorageLocation = 0xcd5ed15c6e187e77e9aee88184c21f4f2182ab5827cb3b7e07fbedcd63f03300;

    function _getPausableStorage() private pure returns (PausableStorage storage $) {
        assembly {
            $.slot := PausableStorageLocation
        }
    }

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        PausableStorage storage $ = _getPausableStorage();
        return $._paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        PausableStorage storage $ = _getPausableStorage();
        $._paused = false;
        emit Unpaused(_msgSender());
    }
}

/// @title ProtocolPausable
/// @notice Contract that allows the pausing and unpausing of the a contract
abstract contract ProtocolPausableUpgradeable is PausableUpgradeable, AccessManagedUpgradeable {
    /// @notice Initializes the ProtocolPausable contract
    /// @param accessManager The address of the access manager
    function __ProtocolPausable_init(address accessManager) public initializer {
        __AccessManaged_init(accessManager);
        __Pausable_init();
    }

    /// @notice sets paused state
    function pause() external restricted {
        _pause();
    }

    /// @notice unsets unpaused state
    function unpause() external restricted {
        _unpause();
    }

    function paused() public view override returns (bool) {
        return super.paused();
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165Checker.sol)

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165Checker {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant INTERFACE_ID_INVALID = 0xffffffff;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface.
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return
            supportsERC165InterfaceUnchecked(account, type(IERC165).interfaceId) &&
            !supportsERC165InterfaceUnchecked(account, INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) && supportsERC165InterfaceUnchecked(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     */
    function getSupportedInterfaces(
        address account,
        bytes4[] memory interfaceIds
    ) internal view returns (bool[] memory) {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = supportsERC165InterfaceUnchecked(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!supportsERC165InterfaceUnchecked(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     *
     * Some precompiled contracts will falsely indicate support for a given interface, so caution
     * should be exercised when using this function.
     *
     * Interface identification is specified in ERC-165.
     */
    function supportsERC165InterfaceUnchecked(address account, bytes4 interfaceId) internal view returns (bool) {
        // prepare call
        bytes memory encodedParams = abi.encodeCall(IERC165.supportsInterface, (interfaceId));

        // perform static call
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly {
            success := staticcall(30000, account, add(encodedParams, 0x20), mload(encodedParams), 0x00, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0x00)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }
}

/// @title IPAccountChecker
/// @dev This library provides utility functions to check the registration and validity of IP Accounts.
/// It uses the ERC165 standard for contract introspection and the IIPAccountRegistry interface
/// for account registration checks.
library IPAccountChecker {
    /// @notice Returns true if the IPAccount is registered.
    /// @param chainId_ The chain ID where the IP Account is located.
    /// @param tokenContract_ The address of the token contract associated with the IP Account.
    /// @param tokenId_ The ID of the token associated with the IP Account.
    /// @return True if the IP Account is registered, false otherwise.
    function isRegistered(
        IIPAccountRegistry ipAccountRegistry_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) internal view returns (bool) {
        return ipAccountRegistry_.ipAccount(chainId_, tokenContract_, tokenId_).code.length != 0;
    }

    /// @notice Checks if the given address is a valid IP Account.
    /// @param ipAccountRegistry_ The IP Account registry contract.
    /// @param ipAccountAddress_ The address to check.
    /// @return True if the address is a valid IP Account, false otherwise.
    function isIpAccount(
        IIPAccountRegistry ipAccountRegistry_,
        address ipAccountAddress_
    ) internal view returns (bool) {
        if (ipAccountAddress_ == address(0)) return false;
        if (ipAccountAddress_.code.length == 0) return false;
        if (!ERC165Checker.supportsERC165(ipAccountAddress_)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IERC6551Account).interfaceId)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IIPAccount).interfaceId)) return false;
        if (!ERC165Checker.supportsInterface(ipAccountAddress_, type(IIPAccountStorage).interfaceId)) return false;
        (uint chainId, address tokenContract, uint tokenId) = IIPAccount(payable(ipAccountAddress_)).token();
        return ipAccountAddress_ == ipAccountRegistry_.ipAccount(chainId, tokenContract, tokenId);
    }
}

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

/// @title AccessController
/// @dev This contract is used to control access permissions for different function calls in the protocol.
/// It allows setting permissions for specific function calls, checking permissions, and initializing the contract.
/// The contract uses a mapping to store policies, which are represented as a nested mapping structure.
/// The contract also interacts with other contracts such as IIPAccountRegistry, IModuleRegistry, and IIPAccount.
///
/// Each policy is represented as a mapping from an IP account address to a signer address to a recipient
/// address to a function selector to a permission level.
/// The permission level can be 0 (ABSTAIN), 1 (ALLOW), or 2 (DENY).
///
/// The contract includes the following functions:
/// - initialize: Sets the addresses of the IP account registry and the module registry.
/// - setPermission: Sets the permission for a specific function call.
/// - getPermission: Returns the permission level for a specific function call.
/// - checkPermission: Checks if a specific function call is allowed.
contract AccessController_V1_0_0 is IAccessController, ProtocolPausableUpgradeable, UUPSUpgradeable {
    using IPAccountChecker for IIPAccountRegistry;

    /// @dev The storage struct of AccessController.
    /// @param encodedPermissions tracks the permission granted to an encoded permission path, where the
    /// encoded permission path = keccak256(abi.encodePacked(ipAccount, signer, to, func))
    /// @notice The address of the IP Account Registry.
    /// @notice The address of the Module Registry.
    /// @custom:storage-location erc7201:story-protocol.AccessController
    struct AccessControllerStorage {
        mapping(bytes32 => uint8) encodedPermissions;
        address ipAccountRegistry;
        address moduleRegistry;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.AccessController")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant AccessControllerStorageLocation =
        0xe80df7f3a04d1e1a0b61a4a820184d4b4a2f8a6a808f315dbcc7b502f40b1800;

    /// Constructor
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) {
            revert Errors.AccessController__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @notice Sets the addresses of the IP account registry and the module registry
    /// @dev TODO: Set these addresses in the constructor to make them immutable
    /// @param ipAccountRegistry address of the IP account registry
    /// @param moduleRegistry address of the module registry
    function setAddresses(address ipAccountRegistry, address moduleRegistry) external restricted {
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        $.ipAccountRegistry = ipAccountRegistry;
        $.moduleRegistry = moduleRegistry;
    }

    /// @notice Sets a batch of permissions in a single transaction.
    /// @dev This function allows setting multiple permissions at once. Pausable via setPermission.
    /// @param permissions An array of `Permission` structs, each representing the permission to be set.
    function setBatchPermissions(AccessPermission.Permission[] memory permissions) external {
        for (uint256 i = 0; i < permissions.length; ) {
            setPermission(
                permissions[i].ipAccount,
                permissions[i].signer,
                permissions[i].to,
                permissions[i].func,
                permissions[i].permission
            );
            unchecked {
                i += 1;
            }
        }
    }

    /// @notice Sets the permission for a specific function call
    /// @dev Each policy is represented as a mapping from an IP account address to a signer address to a recipient
    /// address to a function selector to a permission level. The permission level can be 0 (ABSTAIN), 1 (ALLOW), or
    /// 2 (DENY).
    /// @dev By default, all policies are set to 0 (ABSTAIN), which means that the permission is not set.
    /// The owner of ipAccount by default has all permission.
    /// address(0) => wildcard
    /// bytes4(0) => wildcard
    /// Specific permission overrides wildcard permission.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @param permission The new permission level
    function setPermission(
        address ipAccount,
        address signer,
        address to,
        bytes4 func,
        uint8 permission
    ) public whenNotPaused {
        // IPAccount and signer does not support wildcard permission
        if (ipAccount == address(0)) {
            revert Errors.AccessController__IPAccountIsZeroAddress();
        }
        if (signer == address(0)) {
            revert Errors.AccessController__SignerIsZeroAddress();
        }
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        if (!IIPAccountRegistry($.ipAccountRegistry).isIpAccount(ipAccount)) {
            revert Errors.AccessController__IPAccountIsNotValid(ipAccount);
        }
        // permission must be one of ABSTAIN, ALLOW, DENY
        if (permission > 2) {
            revert Errors.AccessController__PermissionIsNotValid();
        }
        if (ipAccount != msg.sender && IIPAccount(payable(ipAccount)).owner() != msg.sender) {
            revert Errors.AccessController__CallerIsNotIPAccountOrOwner();
        }
        _setPermission(ipAccount, signer, to, func, permission);

        emit PermissionSet(IIPAccount(payable(ipAccount)).owner(), ipAccount, signer, to, func, permission);
    }

    /// @notice Checks the permission level for a specific function call. Reverts if permission is not granted.
    /// Otherwise, the function is a noop.
    /// @dev This function checks the permission level for a specific function call.
    /// If a specific permission is set, it overrides the general (wildcard) permission.
    /// If the current level permission is ABSTAIN, the final permission is determined by the upper level.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    // solhint-disable code-complexity
    function checkPermission(address ipAccount, address signer, address to, bytes4 func) external view {
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        // Must be a valid IPAccount
        if (!IIPAccountRegistry($.ipAccountRegistry).isIpAccount(ipAccount)) {
            revert Errors.AccessController__IPAccountIsNotValid(ipAccount);
        }
        // Owner can call any contracts either registered module or unregistered/external contracts
        if (IIPAccount(payable(ipAccount)).owner() == signer) {
            return;
        }

        // If the caller (signer) is not the Owner, IPAccount is limited to interactions with only registered modules.
        // These interactions can be either initiating calls to these modules or receiving calls from them.
        // The IP account can also modify its own Permissions settings.
        if (
            to != address(this) &&
            !IModuleRegistry($.moduleRegistry).isRegistered(to) &&
            !IModuleRegistry($.moduleRegistry).isRegistered(signer)
        ) {
            revert Errors.AccessController__BothCallerAndRecipientAreNotRegisteredModule(signer, to);
        }

        uint functionPermission = getPermission(ipAccount, signer, to, func);
        // Specific function permission overrides wildcard/general permission
        if (functionPermission == AccessPermission.ALLOW) {
            return;
        }
        // Specific function permission is DENY, revert
        if (functionPermission == AccessPermission.DENY) {
            revert Errors.AccessController__PermissionDenied(ipAccount, signer, to, func);
        }
        // Function permission is ABSTAIN, check module level permission
        uint8 modulePermission = getPermission(ipAccount, signer, to, bytes4(0));
        // Return true if allow to call all functions of the module
        if (modulePermission == AccessPermission.ALLOW) {
            return;
        }
        // Module level permission is DENY, revert
        if (modulePermission == AccessPermission.DENY) {
            revert Errors.AccessController__PermissionDenied(ipAccount, signer, to, func);
        }
        // Module level permission is ABSTAIN, check transaction signer level permission
        // Pass if the ipAccount allow the signer to call all functions of all modules
        // Otherwise, revert
        if (getPermission(ipAccount, signer, address(0), bytes4(0)) != AccessPermission.ALLOW) {
            revert Errors.AccessController__PermissionDenied(ipAccount, signer, to, func);
        }
        // If the transaction signer is allowed to call all functions of all modules, return
    }

    /// @notice Returns the permission level for a specific function call.
    /// @param ipAccount The address of the IP account that grants the permission for `signer`
    /// @param signer The address that can call `to` on behalf of the `ipAccount`
    /// @param to The address that can be called by the `signer` (currently only modules can be `to`)
    /// @param func The function selector of `to` that can be called by the `signer` on behalf of the `ipAccount`
    /// @return permission The current permission level for the function call on `to` by the `signer` for `ipAccount`
    function getPermission(address ipAccount, address signer, address to, bytes4 func) public view returns (uint8) {
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        return $.encodedPermissions[_encodePermission(ipAccount, signer, to, func)];
    }

    /// @dev The permission parameters will be encoded into bytes32 as key in the permissions mapping to save storage
    function _setPermission(address ipAccount, address signer, address to, bytes4 func, uint8 permission) internal {
        AccessControllerStorage storage $ = _getAccessControllerStorage();
        $.encodedPermissions[_encodePermission(ipAccount, signer, to, func)] = permission;
    }

    /// @dev encode permission to hash (bytes32)
    function _encodePermission(
        address ipAccount,
        address signer,
        address to,
        bytes4 func
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(IIPAccount(payable(ipAccount)).owner(), ipAccount, signer, to, func));
    }

    /// @dev Returns the storage struct of AccessController.
    function _getAccessControllerStorage() private pure returns (AccessControllerStorage storage $) {
        assembly {
            $.slot := AccessControllerStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}


/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or
     *   {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon
     *   a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Metadata.sol)

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}


// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/SignedMath.sol)

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant HEX_DIGITS = "0123456789abcdef";
    uint8 private constant ADDRESS_LENGTH = 20;

    /**
     * @dev The `value` string doesn't fit in the specified `length`.
     */
    error StringsInsufficientHexLength(uint256 value, uint256 length);

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), HEX_DIGITS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toStringSigned(int256 value) internal pure returns (string memory) {
        return string.concat(value < 0 ? "-" : "", toString(SignedMath.abs(value)));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        uint256 localValue = value;
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = HEX_DIGITS[localValue & 0xf];
            localValue >>= 4;
        }
        if (localValue != 0) {
            revert StringsInsufficientHexLength(value, length);
        }
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal
     * representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


/// @title Interface for IP Account Registry
/// @notice This interface manages the registration and tracking of IP Accounts
interface IIPAssetRegistry is IIPAccountRegistry {
    /// @notice Emits when an IP is officially registered into the protocol.
    /// @param ipId The canonical identifier for the IP.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The token contract address of the IP NFT.
    /// @param tokenId The token identifier of the IP.
    /// @param name The name of the IP.
    /// @param uri The URI of the IP.
    /// @param registrationDate The date and time the IP was registered.
    event IPRegistered(
        address ipId,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        string name,
        string uri,
        uint256 registrationDate
    );

    /// @notice Tracks the total number of IP assets in existence.
    function totalSupply() external view returns (uint256);

    /// @notice Registers an NFT as an IP asset.
    /// @param chainid The chain identifier of where the IP NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @return id The address of the newly registered IP.
    function register(uint256 chainid, address tokenContract, uint256 tokenId) external returns (address id);

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return ipId The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address);

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return isRegistered Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool);
}


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)


interface IERC6551Registry {
    /**
     * @dev The registry MUST emit the ERC6551AccountCreated event upon successful account creation.
     */
    event ERC6551AccountCreated(
        address account,
        address indexed implementation,
        bytes32 salt,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId
    );

    /**
     * @dev The registry MUST revert with AccountCreationFailed error if the create2 operation fails.
     */
    error AccountCreationFailed();

    /**
     * @dev Creates a token bound account for a non-fungible token.
     *
     * If account has already been created, returns the account address without calling create2.
     *
     * Emits ERC6551AccountCreated event.
     *
     * @return account The address of the token bound account
     */
    function createAccount(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external returns (address account);

    /**
     * @dev Returns the computed token bound account address for a non-fungible token.
     *
     * @return account The address of the token bound account
     */
    function account(
        address implementation,
        bytes32 salt,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) external view returns (address account);
}


/// @title IPAccountRegistry
/// @notice This contract is responsible for managing the registration and tracking of IP Accounts.
/// It leverages a public ERC6551 registry to deploy IPAccount contracts.
abstract contract IPAccountRegistry is IIPAccountRegistry {
    /// @notice Returns the IPAccount implementation address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable IP_ACCOUNT_IMPL;

    /// @notice Returns the IPAccount salt
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    bytes32 public immutable IP_ACCOUNT_SALT;

    /// @notice Returns the public ERC6551 registry address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable ERC6551_PUBLIC_REGISTRY;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address erc6551Registry, address ipAccountImpl) {
        if (ipAccountImpl == address(0)) revert Errors.IPAccountRegistry_ZeroIpAccountImpl();
        IP_ACCOUNT_IMPL = ipAccountImpl;
        IP_ACCOUNT_SALT = bytes32(0);
        ERC6551_PUBLIC_REGISTRY = erc6551Registry;
    }

    /// @notice Deploys an IPAccount contract with the IPAccount implementation and returns the address of the new IP
    /// @dev The IPAccount deployment deltegates to public ERC6551 Registry
    /// @param chainId The chain ID where the IP Account will be created
    /// @param tokenContract The address of the token contract to be associated with the IP Account
    /// @param tokenId The ID of the token to be associated with the IP Account
    /// @return ipAccountAddress The address of the newly created IP Account
    function registerIpAccount(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) public returns (address ipAccountAddress) {
        ipAccountAddress = IERC6551Registry(ERC6551_PUBLIC_REGISTRY).createAccount(
            IP_ACCOUNT_IMPL,
            IP_ACCOUNT_SALT,
            chainId,
            tokenContract,
            tokenId
        );
        emit IPAccountRegistered(ipAccountAddress, IP_ACCOUNT_IMPL, chainId, tokenContract, tokenId);
    }

    /// @notice Returns the IPAccount address for the given NFT token.
    /// @param chainId The chain ID where the IP Account is located
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    /// @return ipAccountAddress The address of the IP Account associated with the given NFT token
    function ipAccount(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return _get6551AccountAddress(chainId, tokenContract, tokenId);
    }

    /// @notice Returns the IPAccount implementation address.
    /// @return The address of the IPAccount implementation
    function getIPAccountImpl() external view override returns (address) {
        return IP_ACCOUNT_IMPL;
    }

    /// @dev Helper function to get the IPAccount address from the ERC6551 registry.
    function _get6551AccountAddress(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (address) {
        return
            IERC6551Registry(ERC6551_PUBLIC_REGISTRY).account(
                IP_ACCOUNT_IMPL,
                IP_ACCOUNT_SALT,
                chainId,
                tokenContract,
                tokenId
            );
    }
}

// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf

// OpenZeppelin Contracts (last updated v5.0.0) (utils/ShortStrings.sol)

// | string  | 0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA   |
// | length  | 0x                                                              BB |
type ShortString is bytes32;

/**
 * @dev This library provides functions to convert short memory strings
 * into a `ShortString` type that can be used as an immutable variable.
 *
 * Strings of arbitrary length can be optimized using this library if
 * they are short enough (up to 31 bytes) by packing them with their
 * length (1 byte) in a single EVM word (32 bytes). Additionally, a
 * fallback mechanism can be used for every other case.
 *
 * Usage example:
 *
 * ```solidity
 * contract Named {
 *     using ShortStrings for *;
 *
 *     ShortString private immutable _name;
 *     string private _nameFallback;
 *
 *     constructor(string memory contractName) {
 *         _name = contractName.toShortStringWithFallback(_nameFallback);
 *     }
 *
 *     function name() external view returns (string memory) {
 *         return _name.toStringWithFallback(_nameFallback);
 *     }
 * }
 * ```
 */
library ShortStrings {
    // Used as an identifier for strings longer than 31 bytes.
    bytes32 private constant FALLBACK_SENTINEL = 0x00000000000000000000000000000000000000000000000000000000000000FF;

    error StringTooLong(string str);
    error InvalidShortString();

    /**
     * @dev Encode a string of at most 31 chars into a `ShortString`.
     *
     * This will trigger a `StringTooLong` error is the input string is too long.
     */
    function toShortString(string memory str) internal pure returns (ShortString) {
        bytes memory bstr = bytes(str);
        if (bstr.length > 31) {
            revert StringTooLong(str);
        }
        return ShortString.wrap(bytes32(uint256(bytes32(bstr)) | bstr.length));
    }

    /**
     * @dev Decode a `ShortString` back to a "normal" string.
     */
    function toString(ShortString sstr) internal pure returns (string memory) {
        uint256 len = byteLength(sstr);
        // using `new string(len)` would work locally but is not memory safe.
        string memory str = new string(32);
        /// @solidity memory-safe-assembly
        assembly {
            mstore(str, len)
            mstore(add(str, 0x20), sstr)
        }
        return str;
    }

    /**
     * @dev Return the length of a `ShortString`.
     */
    function byteLength(ShortString sstr) internal pure returns (uint256) {
        uint256 result = uint256(ShortString.unwrap(sstr)) & 0xFF;
        if (result > 31) {
            revert InvalidShortString();
        }
        return result;
    }

    /**
     * @dev Encode a string into a `ShortString`, or write it to storage if it is too long.
     */
    function toShortStringWithFallback(string memory value, string storage store) internal returns (ShortString) {
        if (bytes(value).length < 32) {
            return toShortString(value);
        } else {
            StorageSlot.getStringSlot(store).value = value;
            return ShortString.wrap(FALLBACK_SENTINEL);
        }
    }

    /**
     * @dev Decode a string that was encoded to `ShortString` or written to storage using {setWithFallback}.
     */
    function toStringWithFallback(ShortString value, string storage store) internal pure returns (string memory) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return toString(value);
        } else {
            return store;
        }
    }

    /**
     * @dev Return the length of a string that was encoded to `ShortString` or written to storage using
     * {setWithFallback}.
     *
     * WARNING: This will return the "byte length" of the string. This may not reflect the actual length in terms of
     * actual characters as the UTF-8 encoding of a single character can span over multiple bytes.
     */
    function byteLengthWithFallback(ShortString value, string storage store) internal view returns (uint256) {
        if (ShortString.unwrap(value) != FALLBACK_SENTINEL) {
            return byteLength(value);
        } else {
            return bytes(store).length;
        }
    }
}

/// @title IPAccount Storage Operations Library
/// @notice Provides utility functions that extend the basic functionalities of IPAccountStorage,
/// facilitating enhanced module interaction with IPAccount Namespaced Storage.
/// @dev This library enables modules to access and manipulate IPAccount Namespaced Storage
/// with additional features such as using `address` type namespaces and `ShortString` keys.
/// It serves as an addon to the fundamental IPAccountStorage functions, allowing for more complex and
/// flexible interactions with the namespaced storage.
library IPAccountStorageOps {
    using ShortStrings for *;
    using Strings for *;

    /// @dev Sets a string value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The string value to be stored.
    function setString(IIPAccountStorage ipStorage, bytes32 key, string memory value) internal {
        ipStorage.setBytes(key, bytes(value));
    }

    /// @dev Retrieves a string value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The string value stored under the specified key.
    function getString(IIPAccountStorage ipStorage, bytes32 key) internal view returns (string memory) {
        return string(ipStorage.getBytes(key));
    }

    /// @dev Retrieves a string value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The string value stored under the specified key in the given namespace.
    function getString(
        IIPAccountStorage ipStorage,
        bytes32 namespace,
        bytes32 key
    ) internal view returns (string memory) {
        return string(ipStorage.getBytes(namespace, key));
    }

    /// @notice Sets a string value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the value.
    /// @param value The string value to be stored.
    function setString(IIPAccountStorage ipStorage, ShortString key, string memory value) internal {
        setString(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves a string value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose value is to be retrieved.
    /// @return The string value stored under the specified key.
    function getString(IIPAccountStorage ipStorage, ShortString key) internal view returns (string memory) {
        return getString(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves a string value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the string value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose value is to be retrieved.
    function getString(
        IIPAccountStorage ipStorage,
        address namespace,
        bytes32 key
    ) internal view returns (string memory) {
        return getString(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves a string value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the string value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose value is to be retrieved.
    function getString(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (string memory) {
        return getString(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @dev Sets an address value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The address value to be stored.
    function setAddress(IIPAccountStorage ipStorage, bytes32 key, address value) internal {
        ipStorage.setBytes32(key, toBytes32(value));
    }

    /// @dev Retrieves an address value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The address value stored under the specified key.
    function getAddress(IIPAccountStorage ipStorage, bytes32 key) internal view returns (address) {
        return address(uint160(uint256(ipStorage.getBytes32(key))));
    }

    /// @dev Retrieves an address value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The address value stored under the specified key in the given namespace.
    function getAddress(IIPAccountStorage ipStorage, bytes32 namespace, bytes32 key) internal view returns (address) {
        return address(uint160(uint256(ipStorage.getBytes32(namespace, key))));
    }

    /// @notice Sets an address value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating address storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the address value.
    /// @param value The address value to be stored.
    function setAddress(IIPAccountStorage ipStorage, ShortString key, address value) internal {
        setAddress(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves an address value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the address data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose address value is to be retrieved.
    /// @return The address value stored under the specified key.
    function getAddress(IIPAccountStorage ipStorage, ShortString key) internal view returns (address) {
        return getAddress(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves an address value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the address value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose address value is to be retrieved.
    /// @return The address value stored under the specified key in the given namespace.
    function getAddress(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (address) {
        return getAddress(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves an address value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the address value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose address value is to be retrieved.
    /// @return The address value stored under the specified key in the given namespace.
    function getAddress(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (address) {
        return getAddress(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @dev Sets a uint256 value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The uint256 value to be stored.
    function setUint256(IIPAccountStorage ipStorage, bytes32 key, uint256 value) internal {
        ipStorage.setBytes32(key, bytes32(value));
    }

    /// @dev Retrieves a uint256 value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The uint256 value stored under the specified key.
    function getUint256(IIPAccountStorage ipStorage, bytes32 key) internal view returns (uint256) {
        return uint256(ipStorage.getBytes32(key));
    }

    /// @dev Retrieves a uint256 value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The uint256 value stored under the specified key in the given namespace.
    function getUint256(IIPAccountStorage ipStorage, bytes32 namespace, bytes32 key) internal view returns (uint256) {
        return uint256(ipStorage.getBytes32(namespace, key));
    }

    /// @notice Sets a uint256 value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating uint256 storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the uint256 value.
    /// @param value The uint256 value to be stored.
    function setUint256(IIPAccountStorage ipStorage, ShortString key, uint256 value) internal {
        setUint256(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves a uint256 value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the uint256 data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose uint256 value is to be retrieved.
    /// @return The uint256 value stored under the specified key.
    function getUint256(IIPAccountStorage ipStorage, ShortString key) internal view returns (uint256) {
        return getUint256(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves a uint256 value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the uint256 value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose uint256 value is to be retrieved.
    /// @return The uint256 value stored under the specified key in the given namespace.
    function getUint256(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (uint256) {
        return getUint256(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves a uint256 value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the uint256 value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose uint256 value is to be retrieved.
    /// @return The uint256 value stored under the specified key in the given namespace.
    function getUint256(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (uint256) {
        return getUint256(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @dev Sets a boolean value under a given key within the default namespace, determined by `msg.sender`.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key under which to store the value.
    /// @param value The boolean value to be stored.
    function setBool(IIPAccountStorage ipStorage, bytes32 key, bool value) internal {
        ipStorage.setBytes32(key, value ? bytes32(uint256(1)) : bytes32(0));
    }

    /// @dev Retrieves a boolean value by a given key from the default namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The key whose value is to be retrieved.
    /// @return The boolean value stored under the specified key.
    function getBool(IIPAccountStorage ipStorage, bytes32 key) internal view returns (bool) {
        return ipStorage.getBytes32(key) != 0;
    }

    /// @dev Retrieves a boolean value by a given key from a specified namespace.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace from which to retrieve the value.
    /// @param key The key whose value is to be retrieved.
    /// @return The boolean value stored under the specified key in the given namespace.
    function getBool(IIPAccountStorage ipStorage, bytes32 namespace, bytes32 key) internal view returns (bool) {
        return ipStorage.getBytes32(namespace, key) != 0;
    }

    /// @notice Sets a bool value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating bool storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the bool value.
    /// @param value The bool value to be stored.
    function setBool(IIPAccountStorage ipStorage, ShortString key, bool value) internal {
        setBool(ipStorage, toBytes32(key), value);
    }

    /// @notice Retrieves a bool value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the bool data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose bool value is to be retrieved.
    /// @return The bool value stored under the specified key.
    function getBool(IIPAccountStorage ipStorage, ShortString key) internal view returns (bool) {
        return getBool(ipStorage, toBytes32(key));
    }

    /// @notice Retrieves a bool value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the bool value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose bool value is to be retrieved.
    /// @return The bool value stored under the specified key in the given namespace.
    function getBool(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (bool) {
        return getBool(ipStorage, toBytes32(namespace), key);
    }

    /// @notice Retrieves a bool value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the bool value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose bool value is to be retrieved.
    /// @return The bool value stored under the specified key in the given namespace.
    function getBool(IIPAccountStorage ipStorage, address namespace, ShortString key) internal view returns (bool) {
        return getBool(ipStorage, toBytes32(namespace), toBytes32(key));
    }

    /// @notice Sets a bytes value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating bytes storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the bytes value.
    /// @param value The bytes value to be stored.
    function setBytes(IIPAccountStorage ipStorage, ShortString key, bytes memory value) internal {
        ipStorage.setBytes(toBytes32(key), value);
    }

    /// @notice Sets a bytes value in the storage using two `ShortString` keys.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    function setBytes(IIPAccountStorage ipStorage, ShortString key1, ShortString key2, bytes memory value) internal {
        ipStorage.setBytes(toBytes32(string(abi.encodePacked(key1.toString(), key2.toString()))), value);
    }

    /// @notice Retrieves a bytes value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the bytes data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose bytes value is to be retrieved.
    /// @return The bytes value stored under the specified key.
    function getBytes(IIPAccountStorage ipStorage, ShortString key) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(key));
    }

    /// @notice Retrieves a bytes value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the bytes value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose bytes value is to be retrieved.
    /// @return The bytes value stored under the specified key in the given namespace.
    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        bytes32 key
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(namespace), key);
    }

    /// @notice Retrieves a bytes value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the bytes value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose bytes value is to be retrieved.
    /// @return The bytes value stored under the specified key in the given namespace.
    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(namespace), toBytes32(key));
    }

    /// @notice Retrieves a bytes value from the storage using two `ShortString` keys.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @return The bytes value stored under the combination of two keys.
    function getBytes(
        IIPAccountStorage ipStorage,
        ShortString key1,
        ShortString key2
    ) internal view returns (bytes memory) {
        return ipStorage.getBytes(toBytes32(string(abi.encodePacked(key1.toString(), key2.toString()))));
    }

    /// @notice Retrieves a bytes value from the storage under a specified namespace using two `ShortString` keys.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @return The bytes value stored under the combination of two keys.
    function getBytes(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key1,
        ShortString key2
    ) internal view returns (bytes memory) {
        return
            ipStorage.getBytes(
                toBytes32(namespace),
                toBytes32(string(abi.encodePacked(key1.toString(), key2.toString())))
            );
    }

    /// @notice Sets a bytes32 value in the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before storing the value,
    /// facilitating bytes32 storage in a compact format.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key under which to store the bytes32 value.
    /// @param value The bytes32 value to be stored.
    function setBytes32(IIPAccountStorage ipStorage, ShortString key, bytes32 value) internal {
        ipStorage.setBytes32(toBytes32(key), value);
    }

    /// @notice Retrieves a bytes32 value from the storage using a `ShortString` key.
    /// @dev Converts the `ShortString` key to a `bytes32` representation before retrieving the value,
    /// ensuring the integrity of the bytes32 data.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param key The `ShortString` key whose bytes32 value is to be retrieved.
    /// @return The bytes32 value stored under the specified key.
    function getBytes32(IIPAccountStorage ipStorage, ShortString key) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(key));
    }

    /// @notice Retrieves a bytes32 value from the storage under a specified namespace using a bytes32 key.
    /// @dev Retrieves the bytes32 value from the specified namespace using the provided key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The bytes32 key whose bytes32 value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(IIPAccountStorage ipStorage, address namespace, bytes32 key) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(namespace), key);
    }

    /// @notice Retrieves a bytes32 value from the storage under a specified namespace using a `ShortString` key.
    /// @dev Retrieves the bytes32 value from the specified namespace using the provided `ShortString` key.
    /// @param ipStorage The instance of the IPAccountStorage contract.
    /// @param namespace The namespace under which to retrieve the value.
    /// @param key The `ShortString` key whose bytes32 value is to be retrieved.
    /// @return The bytes32 value stored under the specified key in the given namespace.
    function getBytes32(
        IIPAccountStorage ipStorage,
        address namespace,
        ShortString key
    ) internal view returns (bytes32) {
        return ipStorage.getBytes32(toBytes32(namespace), toBytes32(key));
    }

    function toBytes32(string memory s) internal pure returns (bytes32) {
        return ShortString.unwrap(s.toShortString());
    }

    function toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function toBytes32(ShortString sstr) internal pure returns (bytes32) {
        // remove the length byte from the ShortString
        // so that bytes32 result is identical with converting string to bytes32 directly
        return ShortString.unwrap(sstr) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00;
    }
}

/// @title IP Asset Registry
/// @notice This contract acts as the source of truth for all IP registered in
///         Story Protocol. An IP is identified by its contract address, token
///         id, and coin type, meaning any NFT may be conceptualized as an IP.
///         Once an IP is registered into the protocol, a corresponding IP
///         asset is generated, which references an IP resolver for metadata
///         attribution and an IP account for protocol authorization.
///         IMPORTANT: The IP account address, besides being used for protocol
///                    auth, is also the canonical IP identifier for the IP NFT.
contract IPAssetRegistry_V1_0_0 is IIPAssetRegistry, IPAccountRegistry, ProtocolPausableUpgradeable, UUPSUpgradeable {
    using ERC165Checker for address;
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

    /// @dev Storage structure for the IPAssetRegistry
    /// @notice Tracks the total number of IP assets in existence.
    /// @custom:storage-location erc7201:story-protocol.IPAssetRegistry
    struct IPAssetRegistryStorage {
        uint256 totalSupply;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.IPAssetRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IPAssetRegistryStorageLocation =
        0x987c61809af5a42943abd137c7acff8426aab6f7a1f5c967a03d1d718ba5cf00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address erc6551Registry, address ipAccountImpl) IPAccountRegistry(erc6551Registry, ipAccountImpl) {
        _disableInitializers();
    }

    /// @notice Initializes the IPAssetRegistry contract.
    /// @param accessManager The address of the access manager.
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.IPAssetRegistry__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @notice Registers an NFT as an IP asset.
    /// @dev The IP required metadata name and URI are derived from the NFT's metadata.
    /// @param chainid The chain identifier of where the IP NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @return id The address of the newly registered IP.
    function register(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId
    ) external whenNotPaused returns (address id) {
        id = registerIpAccount(chainid, tokenContract, tokenId);
        IIPAccount ipAccount = IIPAccount(payable(id));

        if (bytes(ipAccount.getString("NAME")).length != 0) {
            revert Errors.IPAssetRegistry__AlreadyRegistered();
        }

        (string memory name, string memory uri) = _getNameAndUri(chainid, tokenContract, tokenId);
        uint256 registrationDate = block.timestamp;
        ipAccount.setString("NAME", name);
        ipAccount.setString("URI", uri);
        ipAccount.setUint256("REGISTRATION_DATE", registrationDate);

        _getIPAssetRegistryStorage().totalSupply++;

        emit IPRegistered(id, chainid, tokenContract, tokenId, name, uri, registrationDate);
    }

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return ipId The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return super.ipAccount(chainId, tokenContract, tokenId);
    }

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return isRegistered Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool) {
        if (id == address(0)) return false;
        if (id.code.length == 0) return false;
        if (!ERC165Checker.supportsInterface(id, type(IIPAccount).interfaceId)) return false;
        (uint chainId, address tokenContract, uint tokenId) = IIPAccount(payable(id)).token();
        if (id != ipAccount(chainId, tokenContract, tokenId)) return false;
        return bytes(IIPAccount(payable(id)).getString("NAME")).length != 0;
    }

    /// @notice Gets the total number of IP assets registered in the protocol.
    function totalSupply() external view returns (uint256) {
        return _getIPAssetRegistryStorage().totalSupply;
    }

    /// @dev Retrieves the name and URI of from IP NFT.
    function _getNameAndUri(
        uint256 chainid,
        address tokenContract,
        uint256 tokenId
    ) internal view returns (string memory name, string memory uri) {
        if (chainid != block.chainid) {
            name = string.concat(chainid.toString(), ": ", tokenContract.toHexString(), " #", tokenId.toString());
            uri = "";
            return (name, uri);
        }
        // Handle NFT on the same chain
        if (!tokenContract.supportsInterface(type(IERC721).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721(tokenContract);
        }

        if (IERC721(tokenContract).ownerOf(tokenId) == address(0)) {
            revert Errors.IPAssetRegistry__InvalidToken(tokenContract, tokenId);
        }

        if (!tokenContract.supportsInterface(type(IERC721Metadata).interfaceId)) {
            revert Errors.IPAssetRegistry__UnsupportedIERC721Metadata(tokenContract);
        }

        name = string.concat(
            block.chainid.toString(),
            ": ",
            IERC721Metadata(tokenContract).name(),
            " #",
            tokenId.toString()
        );
        uri = IERC721Metadata(tokenContract).tokenURI(tokenId);
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of IPAssetRegistry.
    function _getIPAssetRegistryStorage() private pure returns (IPAssetRegistryStorage storage $) {
        assembly {
            $.slot := IPAssetRegistryStorageLocation
        }
    }
}



/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 value => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}



// solhint-disable-next-line max-line-length

// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}



/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// solhint-disable-next-line max-line-length

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/ERC20Snapshot.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}



/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// OpenZeppelin Contracts (last updated v4.9.0) (utils/Arrays.sol)

// OpenZeppelin Contracts (last updated v4.9.0) (utils/StorageSlot.sol)
// This file was procedurally generated from scripts/generate/templates/StorageSlot.js.

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```solidity
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, `uint256`._
 * _Available since v4.9 for `string`, `bytes`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    struct StringSlot {
        string value;
    }

    struct BytesSlot {
        bytes value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` with member `value` located at `slot`.
     */
    function getStringSlot(bytes32 slot) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `StringSlot` representation of the string storage pointer `store`.
     */
    function getStringSlot(string storage store) internal pure returns (StringSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` with member `value` located at `slot`.
     */
    function getBytesSlot(bytes32 slot) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BytesSlot` representation of the bytes storage pointer `store`.
     */
    function getBytesSlot(bytes storage store) internal pure returns (BytesSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := store.slot
        }
    }
}

// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

/**
 * @dev Collection of functions related to array types.
 */
library ArraysUpgradeable {
    using StorageSlotUpgradeable for bytes32;

    /**
     * @dev Searches a sorted `array` and returns the first index that contains
     * a value greater or equal to `element`. If no such index exists (i.e. all
     * values in the array are strictly less than `element`), the array length is
     * returned. Time complexity O(log n).
     *
     * `array` is expected to be sorted in ascending order, and to contain no
     * repeated elements.
     */
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        if (array.length == 0) {
            return 0;
        }

        uint256 low = 0;
        uint256 high = array.length;

        while (low < high) {
            uint256 mid = MathUpgradeable.average(low, high);

            // Note that mid will always be strictly less than high (i.e. it will be a valid array index)
            // because Math.average rounds down (it does integer division with truncation).
            if (unsafeAccess(array, mid).value > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        // At this point `low` is the exclusive upper bound. We will return the inclusive upper bound.
        if (low > 0 && unsafeAccess(array, low - 1).value == element) {
            return low - 1;
        } else {
            return low;
        }
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(address[] storage arr, uint256 pos) internal pure returns (StorageSlotUpgradeable.AddressSlot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getAddressSlot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(bytes32[] storage arr, uint256 pos) internal pure returns (StorageSlotUpgradeable.Bytes32Slot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getBytes32Slot();
    }

    /**
     * @dev Access an array in an "unsafe" way. Skips solidity "index-out-of-range" check.
     *
     * WARNING: Only use if you are certain `pos` is lower than the array length.
     */
    function unsafeAccess(uint256[] storage arr, uint256 pos) internal pure returns (StorageSlotUpgradeable.Uint256Slot storage) {
        bytes32 slot;
        // We use assembly to calculate the storage slot of the element at index `pos` of the dynamic array `arr`
        // following https://docs.soliditylang.org/en/v0.8.17/internals/layout_in_storage.html#mappings-and-dynamic-arrays.

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getUint256Slot();
    }
}

// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library CountersUpgradeable {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

/**
 * @dev This contract extends an ERC20 token with a snapshot mechanism. When a snapshot is created, the balances and
 * total supply at the time are recorded for later access.
 *
 * This can be used to safely create mechanisms based on token balances such as trustless dividends or weighted voting.
 * In naive implementations it's possible to perform a "double spend" attack by reusing the same balance from different
 * accounts. By using snapshots to calculate dividends or voting power, those attacks no longer apply. It can also be
 * used to create an efficient ERC20 forking mechanism.
 *
 * Snapshots are created by the internal {_snapshot} function, which will emit the {Snapshot} event and return a
 * snapshot id. To get the total supply at the time of a snapshot, call the function {totalSupplyAt} with the snapshot
 * id. To get the balance of an account at the time of a snapshot, call the {balanceOfAt} function with the snapshot id
 * and the account address.
 *
 * NOTE: Snapshot policy can be customized by overriding the {_getCurrentSnapshotId} method. For example, having it
 * return `block.number` will trigger the creation of snapshot at the beginning of each new block. When overriding this
 * function, be careful about the monotonicity of its result. Non-monotonic snapshot ids will break the contract.
 *
 * Implementing snapshots for every block using this method will incur significant gas costs. For a gas-efficient
 * alternative consider {ERC20Votes}.
 *
 * ==== Gas Costs
 *
 * Snapshots are efficient. Snapshot creation is _O(1)_. Retrieval of balances or total supply from a snapshot is _O(log
 * n)_ in the number of snapshots that have been created, although _n_ for a specific account will generally be much
 * smaller since identical balances in subsequent snapshots are stored as a single entry.
 *
 * There is a constant overhead for normal ERC20 transfers due to the additional snapshot bookkeeping. This overhead is
 * only significant for the first transfer that immediately follows a snapshot for a particular account. Subsequent
 * transfers will have normal cost until the next snapshot, and so on.
 */

abstract contract ERC20SnapshotUpgradeable is Initializable, ERC20Upgradeable {
    // Inspired by Jordi Baylina's MiniMeToken to record historical balances:
    // https://github.com/Giveth/minime/blob/ea04d950eea153a04c51fa510b068b9dded390cb/contracts/MiniMeToken.sol

    using ArraysUpgradeable for uint256[];
    using CountersUpgradeable for CountersUpgradeable.Counter;

    // Snapshotted values have arrays of ids and the value corresponding to that id. These could be an array of a
    // Snapshot struct, but that would impede usage of functions that work on an array.
    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }

    mapping(address => Snapshots) private _accountBalanceSnapshots;
    Snapshots private _totalSupplySnapshots;

    // Snapshot ids increase monotonically, with the first value being 1. An id of 0 is invalid.
    CountersUpgradeable.Counter private _currentSnapshotId;

    /**
     * @dev Emitted by {_snapshot} when a snapshot identified by `id` is created.
     */
    event Snapshot(uint256 id);

    function __ERC20Snapshot_init() internal onlyInitializing {
    }

    function __ERC20Snapshot_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Creates a new snapshot and returns its snapshot id.
     *
     * Emits a {Snapshot} event that contains the same id.
     *
     * {_snapshot} is `internal` and you have to decide how to expose it externally. Its usage may be restricted to a
     * set of accounts, for example using {AccessControl}, or it may be open to the public.
     *
     * [WARNING]
     * ====
     * While an open way of calling {_snapshot} is required for certain trust minimization mechanisms such as forking,
     * you must consider that it can potentially be used by attackers in two ways.
     *
     * First, it can be used to increase the cost of retrieval of values from snapshots, although it will grow
     * logarithmically thus rendering this attack ineffective in the long term. Second, it can be used to target
     * specific accounts and increase the cost of ERC20 transfers for them, in the ways specified in the Gas Costs
     * section above.
     *
     * We haven't measured the actual numbers; if this is something you're interested in please reach out to us.
     * ====
     */
    function _snapshot() internal virtual returns (uint256) {
        _currentSnapshotId.increment();

        uint256 currentId = _getCurrentSnapshotId();
        emit Snapshot(currentId);
        return currentId;
    }

    /**
     * @dev Get the current snapshotId
     */
    function _getCurrentSnapshotId() internal view virtual returns (uint256) {
        return _currentSnapshotId.current();
    }

    /**
     * @dev Retrieves the balance of `account` at the time `snapshotId` was created.
     */
    function balanceOfAt(address account, uint256 snapshotId) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _accountBalanceSnapshots[account]);

        return snapshotted ? value : balanceOf(account);
    }

    /**
     * @dev Retrieves the total supply at the time `snapshotId` was created.
     */
    function totalSupplyAt(uint256 snapshotId) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _totalSupplySnapshots);

        return snapshotted ? value : totalSupply();
    }

    // Update balance and/or total supply snapshots before the values are modified. This is implemented
    // in the _beforeTokenTransfer hook, which is executed for _mint, _burn, and _transfer operations.
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // mint
            _updateAccountSnapshot(to);
            _updateTotalSupplySnapshot();
        } else if (to == address(0)) {
            // burn
            _updateAccountSnapshot(from);
            _updateTotalSupplySnapshot();
        } else {
            // transfer
            _updateAccountSnapshot(from);
            _updateAccountSnapshot(to);
        }
    }

    function _valueAt(uint256 snapshotId, Snapshots storage snapshots) private view returns (bool, uint256) {
        require(snapshotId > 0, "ERC20Snapshot: id is 0");
        require(snapshotId <= _getCurrentSnapshotId(), "ERC20Snapshot: nonexistent id");

        // When a valid snapshot is queried, there are three possibilities:
        //  a) The queried value was not modified after the snapshot was taken. Therefore, a snapshot entry was never
        //  created for this id, and all stored snapshot ids are smaller than the requested one. The value that corresponds
        //  to this id is the current one.
        //  b) The queried value was modified after the snapshot was taken. Therefore, there will be an entry with the
        //  requested id, and its value is the one to return.
        //  c) More snapshots were created after the requested one, and the queried value was later modified. There will be
        //  no entry for the requested id: the value that corresponds to it is that of the smallest snapshot id that is
        //  larger than the requested one.
        //
        // In summary, we need to find an element in an array, returning the index of the smallest value that is larger if
        // it is not found, unless said value doesn't exist (e.g. when all values are smaller). Arrays.findUpperBound does
        // exactly this.

        uint256 index = snapshots.ids.findUpperBound(snapshotId);

        if (index == snapshots.ids.length) {
            return (false, 0);
        } else {
            return (true, snapshots.values[index]);
        }
    }

    function _updateAccountSnapshot(address account) private {
        _updateSnapshot(_accountBalanceSnapshots[account], balanceOf(account));
    }

    function _updateTotalSupplySnapshot() private {
        _updateSnapshot(_totalSupplySnapshots, totalSupply());
    }

    function _updateSnapshot(Snapshots storage snapshots, uint256 currentValue) private {
        uint256 currentId = _getCurrentSnapshotId();
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function _lastSnapshotId(uint256[] storage ids) private view returns (uint256) {
        if (ids.length == 0) {
            return 0;
        } else {
            return ids[ids.length - 1];
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}

// solhint-disable-next-line max-line-length

// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

// OpenZeppelin Contracts (last updated v4.9.4) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20Upgradeable token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20Upgradeable token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20Upgradeable token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20Upgradeable token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20Upgradeable token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && AddressUpgradeable.isContract(address(token));
    }
}

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicy {
    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(address ipId, bytes calldata licenseData, bytes calldata externalData) external;

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external;

    /// @notice Allows the caller to pay royalties to the given IP asset
    /// @param caller The caller is the address from which funds will transferred from
    /// @param ipId The ipId of the receiver of the royalties
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external;
}

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicyLAP is IRoyaltyPolicy {
    /// @notice Event emitted when a policy is initialized
    /// @param ipId The ID of the IP asset that the policy is being initialized for
    /// @param ipRoyaltyVault The ip royalty vault address
    /// @param royaltyStack The royalty stack
    /// @param targetAncestors The ip ancestors array
    /// @param targetRoyaltyAmount The ip royalty amount array
    event PolicyInitialized(
        address ipId,
        address ipRoyaltyVault,
        uint32 royaltyStack,
        address[] targetAncestors,
        uint32[] targetRoyaltyAmount
    );

    /// @notice Event emitted when a revenue token is added to a vault
    /// @param token The address of the revenue token
    /// @param vault The address of the vault
    event RoyaltyTokenAddedToVault(address token, address vault);

    /// @notice The state data of the LAP royalty policy
    /// @param isUnlinkableToParents Indicates if the ipId is unlinkable to new parents
    /// @param ipRoyaltyVault The ip royalty vault address
    /// @param royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @param ancestorsAddresses The ancestors addresses array
    /// @param ancestorsRoyalties Contains royalty token amounts for each ancestor on same index as ancestorsAddresses
    struct LAPRoyaltyData {
        bool isUnlinkableToParents;
        address ipRoyaltyVault;
        uint32 royaltyStack;
        address[] ancestorsAddresses;
        uint32[] ancestorsRoyalties;
    }

    /// @notice Returns the percentage scale - represents 100% of royalty tokens for an ip
    function TOTAL_RT_SUPPLY() external view returns (uint32);

    /// @notice Returns the maximum number of parents
    function MAX_PARENTS() external view returns (uint256);

    /// @notice Returns the maximum number of total ancestors.
    /// @dev The IP derivative tree is limited to 14 ancestors, which represents 3 levels of a binary tree 14 = 2+4+8
    function MAX_ANCESTORS() external view returns (uint256);

    /// @notice Returns the RoyaltyModule address
    function ROYALTY_MODULE() external view returns (address);

    /// @notice Returns the LicensingModule address
    function LICENSING_MODULE() external view returns (address);

    /// @notice Returns the snapshot interval
    function getSnapshotInterval() external view returns (uint256);

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ID of the IP asset
    /// @return isUnlinkable Indicates if the ipId is unlinkable to new parents
    /// @return ipRoyaltyVault The ip royalty vault address
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @return targetAncestors The ip ancestors array
    /// @return targetRoyaltyAmount The ip royalty amount array
    function getRoyaltyData(
        address ipId
    ) external view returns (bool, address, uint32, address[] memory, uint32[] memory);
}

/// @title Dispute Module Interface
interface IDisputeModule {
    /// @notice Dispute struct
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param currentTag The current tag of the dispute
    /// @param parentDisputeId The parent dispute id
    struct Dispute {
        address targetIpId;
        address disputeInitiator;
        address arbitrationPolicy;
        bytes32 linkToDisputeEvidence;
        bytes32 targetTag;
        bytes32 currentTag;
        uint256 parentDisputeId;
    }

    /// @notice Event emitted when a dispute tag whitelist status is updated
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted
    event TagWhitelistUpdated(bytes32 tag, bool allowed);

    /// @notice Event emitted when an arbitration policy whitelist status is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);

    /// @notice Event emitted when an arbitration relayer whitelist status is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted
    event ArbitrationRelayerWhitelistUpdated(address arbitrationPolicy, address arbitrationRelayer, bool allowed);

    /// @notice Event emitted when the base arbitration policy is set
    /// @param arbitrationPolicy The address of the arbitration policy
    event DefaultArbitrationPolicyUpdated(address arbitrationPolicy);

    /// @notice Event emitted when an arbitration policy is set for an ipId
    /// @param ipId The ipId address
    /// @param arbitrationPolicy The address of the arbitration policy
    event ArbitrationPolicySet(address ipId, address arbitrationPolicy);

    /// @notice Event emitted when a dispute is raised
    /// @param disputeId The dispute id
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data Custom data adjusted to each policy
    event DisputeRaised(
        uint256 disputeId,
        address targetIpId,
        address disputeInitiator,
        address arbitrationPolicy,
        bytes32 linkToDisputeEvidence,
        bytes32 targetTag,
        bytes data
    );

    /// @notice Event emitted when a dispute judgement is set
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data Custom data adjusted to each policy
    event DisputeJudgementSet(uint256 disputeId, bool decision, bytes data);

    /// @notice Event emitted when a dispute is cancelled
    /// @param disputeId The dispute id
    /// @param data Custom data adjusted to each policy
    event DisputeCancelled(uint256 disputeId, bytes data);

    /// @notice Event emitted when a derivative is tagged on a parent infringement
    /// @param parentIpId The parent ipId which infringed
    /// @param derivativeIpId The derivative ipId which was tagged
    /// @param parentDisputeId The parent dispute id in which infringement was found
    /// @param tag The tag of the dispute applied to the derivative
    event DerivativeTaggedOnParentInfringement(
        address parentIpId,
        address derivativeIpId,
        uint256 parentDisputeId,
        bytes32 tag
    );

    /// @notice Event emitted when a dispute is resolved
    /// @param disputeId The dispute id
    event DisputeResolved(uint256 disputeId);

    /// @notice Tag to represent the dispute is in dispute state waiting for judgement
    function IN_DISPUTE() external view returns (bytes32);

    /// @notice Dispute ID counter
    function disputeCounter() external view returns (uint256);

    /// @notice The address of the base arbitration policy
    function baseArbitrationPolicy() external view returns (address);

    /// @notice Returns the dispute information for a given dispute id
    /// @param disputeId The dispute id
    /// @return targetIpId The ipId that is the target of the dispute
    /// @return disputeInitiator The address of the dispute initiator
    /// @return arbitrationPolicy The address of the arbitration policy
    /// @return linkToDisputeEvidence The link of the dispute summary
    /// @return targetTag The target tag of the dispute
    /// @return currentTag The current tag of the dispute
    /// @return parentDisputeId The parent dispute id
    function disputes(
        uint256 disputeId
    )
        external
        view
        returns (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 linkToDisputeEvidence,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 parentDisputeId
        );

    /// @notice Indicates if a dispute tag is whitelisted
    /// @param tag The dispute tag
    /// @return allowed Indicates if the dispute tag is whitelisted
    function isWhitelistedDisputeTag(bytes32 tag) external view returns (bool allowed);

    /// @notice Indicates if an arbitration policy is whitelisted
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @return allowed Indicates if the arbitration policy is whitelisted
    function isWhitelistedArbitrationPolicy(address arbitrationPolicy) external view returns (bool allowed);

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    /// @return allowed Indicates if the arbitration relayer is whitelisted
    function isWhitelistedArbitrationRelayer(
        address arbitrationPolicy,
        address arbitrationRelayer
    ) external view returns (bool allowed);

    /// @notice Arbitration policy for a given ipId
    /// @param ipId The ipId
    /// @return policy The address of the arbitration policy
    function arbitrationPolicies(address ipId) external view returns (address policy);

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external;

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external;

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(address arbitrationPolicy, address arbPolicyRelayer, bool allowed) external;

    /// @notice Sets the base arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address arbitrationPolicy) external;

    /// @notice Sets the arbitration policy for an ipId
    /// @param ipId The ipId
    /// @param arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address ipId, address arbitrationPolicy) external;

    /// @notice Raises a dispute on a given ipId
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to raise a dispute
    /// @return disputeId The id of the newly raised dispute
    function raiseDispute(
        address targetIpId,
        string memory linkToDisputeEvidence,
        bytes32 targetTag,
        bytes calldata data
    ) external returns (uint256 disputeId);

    /// @notice Sets the dispute judgement on a given dispute. Only whitelisted arbitration relayers can call to judge.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external;

    /// @notice Cancels an ongoing dispute
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) external;

    /// @notice Tags a derivative if a parent has been tagged with an infringement tag
    /// @param parentIpId The infringing parent ipId
    /// @param derivativeIpId The derivative ipId
    /// @param parentDisputeId The dispute id that tagged the parent ipId as infringing
    function tagDerivativeIfParentInfringed(
        address parentIpId,
        address derivativeIpId,
        uint256 parentDisputeId
    ) external;

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute
    /// @param data The data to resolve the dispute
    function resolveDispute(uint256 disputeId, bytes calldata data) external;

    /// @notice Returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param ipId The ipId
    /// @return isTagged True if the ipId is tagged
    function isIpTagged(address ipId) external view returns (bool);
}

/// @title Ip royalty vault interface
interface IIpRoyaltyVault {
    /// @notice Event emitted when royalty tokens are collected
    /// @param ancestorIpId The ancestor ipId address
    /// @param royaltyTokensCollected The amount of royalty tokens collected
    event RoyaltyTokensCollected(address ancestorIpId, uint256 royaltyTokensCollected);

    /// @notice Event emitted when a snapshot is taken
    /// @param snapshotId The snapshot id
    /// @param snapshotTimestamp The timestamp of the snapshot
    /// @param unclaimedTokens The amount of unclaimed tokens at the snapshot
    event SnapshotCompleted(uint256 snapshotId, uint256 snapshotTimestamp, uint32 unclaimedTokens);

    /// @notice Event emitted when a revenue token is claimed
    /// @param claimer The address of the claimer
    /// @param token The revenue token claimed
    /// @param amount The amount of revenue token claimed
    event RevenueTokenClaimed(address claimer, address token, uint256 amount);

    /// @notice initializer for this implementation contract
    /// @param name The name of the royalty token
    /// @param symbol The symbol of the royalty token
    /// @param supply The total supply of the royalty token
    /// @param unclaimedTokens The amount of unclaimed royalty tokens reserved for ancestors
    /// @param ipIdAddress The ip id the royalty vault belongs to
    function initialize(
        string memory name,
        string memory symbol,
        uint32 supply,
        uint32 unclaimedTokens,
        address ipIdAddress
    ) external;

    /// @notice Adds a new revenue token to the vault
    /// @param token The address of the revenue token
    /// @dev Only callable by the royalty policy LAP
    /// @return Whether the token is added
    function addIpRoyaltyVaultTokens(address token) external returns (bool);

    /// @notice A function to snapshot the claimable revenue and royalty token amounts
    /// @return The snapshot id
    function snapshot() external returns (uint256);

    /// @notice A function to calculate the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function claimableRevenue(address account, uint256 snapshotId, address token) external view returns (uint256);

    /// @notice Allows token holders to claim revenue token based on the token balance at certain snapshot
    /// @param snapshotId The snapshot id
    /// @param tokenList The list of revenue tokens to claim
    function claimRevenueByTokenBatch(uint256 snapshotId, address[] calldata tokenList) external;

    /// @notice Allows token holders to claim by a list of snapshot ids based on the token balance at certain snapshot
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) external;

    /// @notice Allows ancestors to claim the royalty tokens and any accrued revenue tokens
    /// @param ancestorIpId The ip id of the ancestor to whom the royalty tokens belong to
    function collectRoyaltyTokens(address ancestorIpId) external;

    /// @notice The ip id to whom this royalty vault belongs to
    /// @return The ip id address
    function ipId() external view returns (address);

    /// @notice The amount of unclaimed royalty tokens
    function unclaimedRoyaltyTokens() external view returns (uint32);

    /// @notice The last snapshotted timestamp
    function lastSnapshotTimestamp() external view returns (uint256);

    /// @notice The amount of revenue token in the ancestors vault
    /// @param token The address of the revenue token
    function ancestorsVaultAmount(address token) external view returns (uint256);

    /// @notice Indicates whether the ancestor has collected the royalty tokens
    /// @param ancestorIpId The ancestor ipId address
    function isCollectedByAncestor(address ancestorIpId) external view returns (bool);

    /// @notice Amount of revenue token in the claim vault
    /// @param token The address of the revenue token
    function claimVaultAmount(address token) external view returns (uint256);

    /// @notice Amount of revenue token claimable at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param token The address of the revenue token
    function claimableAtSnapshot(uint256 snapshotId, address token) external view returns (uint256);

    /// @notice Amount of unclaimed revenue tokens at the snapshot
    /// @param snapshotId The snapshot id
    function unclaimedAtSnapshot(uint256 snapshotId) external view returns (uint32);

    /// @notice Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param claimer The address of the claimer
    /// @param token The address of the revenue token
    function isClaimedAtSnapshot(uint256 snapshotId, address claimer, address token) external view returns (bool);

    /// @notice The list of revenue tokens in the vault
    function tokens() external view returns (address[] memory);
}

/// @title Address Array Utils
/// @notice Library for address array operations
library ArrayUtils {
    /// @notice Finds the index of the first occurrence of the given element.
    /// @param array The input array to search
    /// @param element The value to find
    /// @return Returns (index and isIn) for the first occurrence starting from index 0
    function indexOf(address[] memory array, address element) internal pure returns (uint32, bool) {
        for (uint32 i = 0; i < array.length; i++) {
            if (array[i] == element) return (i, true);
        }
        return (0, false);
    }
}

/// @title Ip Royalty Vault
/// @notice Defines the logic for claiming royalty tokens and revenue tokens for a given IP
contract IpRoyaltyVault is IIpRoyaltyVault, ERC20SnapshotUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Storage structure for the IpRoyaltyVault
    /// @param ipId The ip id to whom this royalty vault belongs to
    /// @param unclaimedRoyaltyTokens The amount of unclaimed royalty tokens
    /// @param lastSnapshotTimestamp The last snapshotted timestamp
    /// @param ancestorsVaultAmount The amount of revenue token in the ancestors vault
    /// @param isCollectedByAncestor Indicates whether the ancestor has collected the royalty tokens
    /// @param claimVaultAmount Amount of revenue token in the claim vault
    /// @param claimableAtSnapshot Amount of revenue token claimable at a given snapshot
    /// @param unclaimedAtSnapshot Amount of unclaimed revenue tokens at the snapshot
    /// @param isClaimedAtSnapshot Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    /// @param tokens The list of revenue tokens in the vault
    /// @custom:storage-location erc7201:story-protocol.IpRoyaltyVault
    struct IpRoyaltyVaultStorage {
        address ipId;
        uint32 unclaimedRoyaltyTokens;
        uint256 lastSnapshotTimestamp;
        mapping(address token => uint256 amount) ancestorsVaultAmount;
        mapping(address ancestorIpId => bool) isCollectedByAncestor;
        mapping(address token => uint256 amount) claimVaultAmount;
        mapping(uint256 snapshotId => mapping(address token => uint256 amount)) claimableAtSnapshot;
        mapping(uint256 snapshotId => uint32 tokenAmount) unclaimedAtSnapshot;
        mapping(uint256 snapshotId => mapping(address claimer => mapping(address token => bool))) isClaimedAtSnapshot;
        EnumerableSet.AddressSet tokens;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.IpRoyaltyVault")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant IpRoyaltyVaultStorageLocation =
        0xe1c3e3b0c445d504edb1b9e6fa2ca4fab60584208a4bc973fe2db2b554d1df00;

    /// @notice LAP royalty policy address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;

    /// @notice Dispute module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    modifier whenNotPaused() {
        // DEV NOTE: If we upgrade RoyaltyPolicyLAP to not pausable, we need to remove this.
        if (PausableUpgradeable(address(ROYALTY_POLICY_LAP)).paused()) revert Errors.IpRoyaltyVault__EnforcedPause();
        _;
    }

    /// @notice Constructor
    /// @param royaltyPolicyLAP The address of the royalty policy LAP
    /// @param disputeModule The address of the dispute module
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyPolicyLAP, address disputeModule) {
        if (royaltyPolicyLAP == address(0)) revert Errors.IpRoyaltyVault__ZeroRoyaltyPolicyLAP();
        if (disputeModule == address(0)) revert Errors.IpRoyaltyVault__ZeroDisputeModule();

        ROYALTY_POLICY_LAP = IRoyaltyPolicyLAP(royaltyPolicyLAP);
        DISPUTE_MODULE = IDisputeModule(disputeModule);

        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param name The name of the royalty token
    /// @param symbol The symbol of the royalty token
    /// @param supply The total supply of the royalty token
    /// @param unclaimedTokens The amount of unclaimed royalty tokens reserved for ancestors
    /// @param ipIdAddress The ip id the royalty vault belongs to
    function initialize(
        string memory name,
        string memory symbol,
        uint32 supply,
        uint32 unclaimedTokens,
        address ipIdAddress
    ) external initializer {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        $.ipId = ipIdAddress;
        $.lastSnapshotTimestamp = block.timestamp;
        $.unclaimedRoyaltyTokens = unclaimedTokens;

        _mint(address(this), unclaimedTokens);
        _mint(ipIdAddress, supply - unclaimedTokens);

        __ReentrancyGuard_init();
        __ERC20Snapshot_init();
        __ERC20_init(name, symbol);
    }

    /// @notice Returns the number royalty token decimals
    function decimals() public view override returns (uint8) {
        return 6;
    }
    /// @notice Adds a new revenue token to the vault
    /// @param token The address of the revenue token
    /// @dev Only callable by the royalty policy LAP
    /// @return Whether the token was added successfully
    function addIpRoyaltyVaultTokens(address token) external returns (bool) {
        if (msg.sender != address(ROYALTY_POLICY_LAP)) revert Errors.IpRoyaltyVault__NotRoyaltyPolicyLAP();
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();
        return $.tokens.add(token);
    }

    /// @notice Snapshots the claimable revenue and royalty token amounts
    /// @return snapshotId The snapshot id
    function snapshot() external whenNotPaused returns (uint256) {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        if (block.timestamp - $.lastSnapshotTimestamp < ROYALTY_POLICY_LAP.getSnapshotInterval())
            revert Errors.IpRoyaltyVault__SnapshotIntervalTooShort();

        uint256 snapshotId = _snapshot();
        $.lastSnapshotTimestamp = block.timestamp;

        uint32 unclaimedTokens = $.unclaimedRoyaltyTokens;
        $.unclaimedAtSnapshot[snapshotId] = unclaimedTokens;

        address[] memory tokenList = $.tokens.values();

        for (uint256 i = 0; i < tokenList.length; i++) {
            uint256 tokenBalance = IERC20Upgradeable(tokenList[i]).balanceOf(address(this));
            if (tokenBalance == 0) {
                $.tokens.remove(tokenList[i]);
                continue;
            }

            uint256 newRevenue = tokenBalance - $.claimVaultAmount[tokenList[i]] - $.ancestorsVaultAmount[tokenList[i]];
            if (newRevenue == 0) continue;

            uint256 ancestorsTokens = (newRevenue * unclaimedTokens) / totalSupply();
            $.ancestorsVaultAmount[tokenList[i]] += ancestorsTokens;

            uint256 claimableTokens = newRevenue - ancestorsTokens;
            $.claimableAtSnapshot[snapshotId][tokenList[i]] = claimableTokens;
            $.claimVaultAmount[tokenList[i]] += claimableTokens;
        }

        emit SnapshotCompleted(snapshotId, block.timestamp, unclaimedTokens);

        return snapshotId;
    }

    /// @notice Calculates the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function claimableRevenue(
        address account,
        uint256 snapshotId,
        address token
    ) external view whenNotPaused returns (uint256) {
        return _claimableRevenue(account, snapshotId, token);
    }

    /// @notice Allows token holders to claim revenue token based on the token balance at certain snapshot
    /// @param snapshotId The snapshot id
    /// @param tokenList The list of revenue tokens to claim
    function claimRevenueByTokenBatch(
        uint256 snapshotId,
        address[] calldata tokenList
    ) external nonReentrant whenNotPaused {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        for (uint256 i = 0; i < tokenList.length; i++) {
            uint256 claimableToken = _claimableRevenue(msg.sender, snapshotId, tokenList[i]);
            if (claimableToken == 0) continue;

            $.isClaimedAtSnapshot[snapshotId][msg.sender][tokenList[i]] = true;
            $.claimVaultAmount[tokenList[i]] -= claimableToken;
            IERC20Upgradeable(tokenList[i]).safeTransfer(msg.sender, claimableToken);

            emit RevenueTokenClaimed(msg.sender, tokenList[i], claimableToken);
        }
    }

    /// @notice Allows token holders to claim by a list of snapshot ids based on the token balance at certain snapshot
    /// @param snapshotIds The list of snapshot ids
    /// @param token The revenue token to claim
    function claimRevenueBySnapshotBatch(uint256[] memory snapshotIds, address token) external whenNotPaused {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        uint256 claimableToken;
        for (uint256 i = 0; i < snapshotIds.length; i++) {
            claimableToken += _claimableRevenue(msg.sender, snapshotIds[i], token);
            $.isClaimedAtSnapshot[snapshotIds[i]][msg.sender][token] = true;
        }

        $.claimVaultAmount[token] -= claimableToken;
        IERC20Upgradeable(token).safeTransfer(msg.sender, claimableToken);

        emit RevenueTokenClaimed(msg.sender, token, claimableToken);
    }

    /// @notice Allows ancestors to claim the royalty tokens and any accrued revenue tokens
    /// @param ancestorIpId The ip id of the ancestor to whom the royalty tokens belong to
    function collectRoyaltyTokens(address ancestorIpId) external nonReentrant whenNotPaused {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        (, , , address[] memory ancestors, uint32[] memory ancestorsRoyalties) = ROYALTY_POLICY_LAP.getRoyaltyData(
            $.ipId
        );

        if (DISPUTE_MODULE.isIpTagged($.ipId)) revert Errors.IpRoyaltyVault__IpTagged();
        if ($.isCollectedByAncestor[ancestorIpId]) revert Errors.IpRoyaltyVault__AlreadyClaimed();

        // check if the address being claimed to is an ancestor
        (uint32 index, bool isIn) = ArrayUtils.indexOf(ancestors, ancestorIpId);
        if (!isIn) revert Errors.IpRoyaltyVault__ClaimerNotAnAncestor();

        // transfer royalty tokens to the ancestor
        IERC20Upgradeable(address(this)).safeTransfer(ancestorIpId, ancestorsRoyalties[index]);

        // collect accrued revenue tokens (if any)
        _collectAccruedTokens(ancestorsRoyalties[index], ancestorIpId);

        $.isCollectedByAncestor[ancestorIpId] = true;
        $.unclaimedRoyaltyTokens -= ancestorsRoyalties[index];

        emit RoyaltyTokensCollected(ancestorIpId, ancestorsRoyalties[index]);
    }

    /// @notice A function to calculate the amount of revenue token claimable by a token holder at certain snapshot
    /// @param account The address of the token holder
    /// @param snapshotId The snapshot id
    /// @param token The revenue token to claim
    /// @return The amount of revenue token claimable
    function _claimableRevenue(address account, uint256 snapshotId, address token) internal view returns (uint256) {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        // if the ip is tagged, then the unclaimed royalties are lost
        if (DISPUTE_MODULE.isIpTagged($.ipId)) return 0;

        uint256 balance = balanceOfAt(account, snapshotId);
        uint256 totalSupply = totalSupplyAt(snapshotId) - $.unclaimedAtSnapshot[snapshotId];
        uint256 claimableToken = $.claimableAtSnapshot[snapshotId][token];
        return $.isClaimedAtSnapshot[snapshotId][account][token] ? 0 : (balance * claimableToken) / totalSupply;
    }

    /// @dev Collect the accrued tokens (if any)
    /// @param royaltyTokensToClaim The amount of royalty tokens being claimed by the ancestor
    /// @param ancestorIpId The ip id of the ancestor to whom the royalty tokens belong to
    function _collectAccruedTokens(uint256 royaltyTokensToClaim, address ancestorIpId) internal {
        IpRoyaltyVaultStorage storage $ = _getIpRoyaltyVaultStorage();

        address[] memory tokenList = $.tokens.values();

        for (uint256 i = 0; i < tokenList.length; ++i) {
            // the only case in which unclaimedRoyaltyTokens can be 0 is when the vault is empty and everyone claimed
            // in which case the call will revert upstream with IpRoyaltyVault__AlreadyClaimed error
            uint256 collectAmount = ($.ancestorsVaultAmount[tokenList[i]] * royaltyTokensToClaim) /
                $.unclaimedRoyaltyTokens;
            if (collectAmount == 0) continue;

            $.ancestorsVaultAmount[tokenList[i]] -= collectAmount;
            IERC20Upgradeable(tokenList[i]).safeTransfer(ancestorIpId, collectAmount);

            emit RevenueTokenClaimed(ancestorIpId, tokenList[i], collectAmount);
        }
    }

    /// @notice The ip id to whom this royalty vault belongs to
    /// @return The ip id address
    function ipId() external view returns (address) {
        return _getIpRoyaltyVaultStorage().ipId;
    }

    /// @notice The amount of unclaimed royalty tokens
    function unclaimedRoyaltyTokens() external view returns (uint32) {
        return _getIpRoyaltyVaultStorage().unclaimedRoyaltyTokens;
    }

    /// @notice The last snapshotted timestamp
    function lastSnapshotTimestamp() external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().lastSnapshotTimestamp;
    }

    /// @notice The amount of revenue token in the ancestors vault
    /// @param token The address of the revenue token
    function ancestorsVaultAmount(address token) external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().ancestorsVaultAmount[token];
    }

    /// @notice Indicates whether the ancestor has collected the royalty tokens
    /// @param ancestorIpId The ancestor ipId address
    function isCollectedByAncestor(address ancestorIpId) external view returns (bool) {
        return _getIpRoyaltyVaultStorage().isCollectedByAncestor[ancestorIpId];
    }

    /// @notice Amount of revenue token in the claim vault
    /// @param token The address of the revenue token
    function claimVaultAmount(address token) external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().claimVaultAmount[token];
    }

    /// @notice Amount of revenue token claimable at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param token The address of the revenue token
    function claimableAtSnapshot(uint256 snapshotId, address token) external view returns (uint256) {
        return _getIpRoyaltyVaultStorage().claimableAtSnapshot[snapshotId][token];
    }

    /// @notice Amount of unclaimed revenue tokens at the snapshot
    /// @param snapshotId The snapshot id
    function unclaimedAtSnapshot(uint256 snapshotId) external view returns (uint32) {
        return _getIpRoyaltyVaultStorage().unclaimedAtSnapshot[snapshotId];
    }

    /// @notice Indicates whether the claimer has claimed the revenue tokens at a given snapshot
    /// @param snapshotId The snapshot id
    /// @param claimer The address of the claimer
    /// @param token The address of the revenue token
    function isClaimedAtSnapshot(uint256 snapshotId, address claimer, address token) external view returns (bool) {
        return _getIpRoyaltyVaultStorage().isClaimedAtSnapshot[snapshotId][claimer][token];
    }

    /// @notice The list of revenue tokens in the vault
    function tokens() external view returns (address[] memory) {
        return _getIpRoyaltyVaultStorage().tokens.values();
    }

    /// @dev Returns the storage struct of the IpRoyaltyVault
    function _getIpRoyaltyVaultStorage() private pure returns (IpRoyaltyVaultStorage storage $) {
        assembly {
            $.slot := IpRoyaltyVaultStorageLocation
        }
    }
}



/// @title Licensing
/// @notice Types and constants used by the licensing related contracts
library Licensing {
    /// @notice This struct is used by IP owners to define the configuration
    /// when others are minting license tokens of their IP through the LicensingModule.
    /// When the `mintLicenseTokens` function of LicensingModule is called, the LicensingModule will read
    /// this configuration to determine the minting fee and who can receive the license tokens.
    /// IP owners can set these configurations for each License or set the configuration for the IP
    /// so that the configuration applies to all licenses of the IP.
    /// If both the license and IP have the configuration, then the license configuration takes precedence.
    /// @param isSet Whether the configuration is set or not.
    /// @param mintingFee The minting fee to be paid when minting license tokens.
    /// @param mintingFeeModule The module that determines the minting fee.
    /// @param receiverCheckModule The module that determines who can receive the license tokens.
    /// @param receiverCheckData The data to be used by the receiver check module.
    struct MintingLicenseConfig {
        bool isSet;
        uint256 mintingFee;
        address mintingFeeModule;
        address receiverCheckModule;
        bytes receiverCheckData;
    }
}

/// @title ILicenseRegistry
/// @notice This contract is responsible for maintaining relationships between IPs and their licenses,
/// parent and derivative IPs, registering License Templates, setting default licenses,
/// and managing royalty policies and currency tokens.
/// It serves as a central point for managing the licensing states within the Story Protocol ecosystem.
interface ILicenseRegistry {
    /// @notice Emitted when a new license template is registered.
    event LicenseTemplateRegistered(address indexed licenseTemplate);

    /// @notice Emitted when a minting license configuration is set.
    event MintingLicenseConfigSetLicense(
        address indexed ipId,
        address indexed licenseTemplate,
        uint256 indexed licenseTermsId
    );

    /// @notice Emitted when a minting license configuration is set for all licenses of an IP.
    event MintingLicenseConfigSetForIP(address indexed ipId, Licensing.MintingLicenseConfig mintingLicenseConfig);

    /// @notice Emitted when an expiration time is set for an IP.
    event ExpirationTimeSet(address indexed ipId, uint256 expireTime);

    /// @notice Sets the default license terms that are attached to all IPs by default.
    /// @param newLicenseTemplate The address of the new default license template.
    /// @param newLicenseTermsId The ID of the new default license terms.
    function setDefaultLicenseTerms(address newLicenseTemplate, uint256 newLicenseTermsId) external;

    /// @notice Returns the default license terms.
    function getDefaultLicenseTerms() external view returns (address licenseTemplate, uint256 licenseTermsId);

    /// @notice Registers a new license template in the Story Protocol.
    /// @param licenseTemplate The address of the license template to register.
    function registerLicenseTemplate(address licenseTemplate) external;

    /// @notice Checks if a license template is registered.
    /// @param licenseTemplate The address of the license template to check.
    /// @return Whether the license template is registered.
    function isRegisteredLicenseTemplate(address licenseTemplate) external view returns (bool);

    /// @notice Registers a derivative IP and its relationship to parent IPs.
    /// @param ipId The address of the derivative IP.
    /// @param parentIpIds An array of addresses of the parent IPs.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsIds An array of IDs of the license terms.
    function registerDerivativeIp(
        address ipId,
        address[] calldata parentIpIds,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds
    ) external;

    /// @notice Checks if an IP is a derivative IP.
    /// @param ipId The address of the IP to check.
    /// @return Whether the IP is a derivative IP.
    function isDerivativeIp(address ipId) external view returns (bool);

    /// @notice Checks if an IP has derivative IPs.
    /// @param ipId The address of the IP to check.
    /// @return Whether the IP has derivative IPs.
    function hasDerivativeIps(address ipId) external view returns (bool);

    /// @notice Verifies the minting of a license token.
    /// @param licensorIpId The address of the licensor IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms will mint the license token.
    /// @param isMintedByIpOwner Whether the license token is minted by the IP owner.
    /// @return The configuration for minting the license.
    function verifyMintLicenseToken(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bool isMintedByIpOwner
    ) external view returns (Licensing.MintingLicenseConfig memory);

    /// @notice Attaches license terms to an IP.
    /// @param ipId The address of the IP to which the license terms are attached.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    function attachLicenseTermsToIp(address ipId, address licenseTemplate, uint256 licenseTermsId) external;

    /// @notice Checks if license terms exist.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the license terms exist.
    function exists(address licenseTemplate, uint256 licenseTermsId) external view returns (bool);

    /// @notice Checks if an IP has attached any license terms.
    /// @param ipId The address of the IP to check.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the IP has attached any license terms.
    function hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (bool);

    /// @notice Gets the attached license terms of an IP by its index.
    /// @param ipId The address of the IP.
    /// @param index The index of the attached license terms within the array of all attached license terms of the IP.
    /// @return licenseTemplate The address of the license template where the license terms are defined.
    /// @return licenseTermsId The ID of the license terms.
    function getAttachedLicenseTerms(
        address ipId,
        uint256 index
    ) external view returns (address licenseTemplate, uint256 licenseTermsId);

    /// @notice Gets the count of attached license terms of an IP.
    /// @param ipId The address of the IP.
    /// @return The count of attached license terms.
    function getAttachedLicenseTermsCount(address ipId) external view returns (uint256);

    /// @notice got the derivative IP of an IP by its index.
    /// @param parentIpId The address of the IP.
    /// @param index The index of the derivative IP within the array of all derivative IPs of the IP.
    /// @return childIpId The address of the derivative IP.
    function getDerivativeIp(address parentIpId, uint256 index) external view returns (address childIpId);

    /// @notice Gets the count of derivative IPs of an IP.
    /// @param parentIpId The address of the IP.
    /// @return The count of derivative IPs.
    function getDerivativeIpCount(address parentIpId) external view returns (uint256);

    /// @notice got the parent IP of an IP by its index.
    /// @param childIpId The address of the IP.
    /// @param index The index of the parent IP within the array of all parent IPs of the IP.
    /// @return parentIpId The address of the parent IP.
    function getParentIp(address childIpId, uint256 index) external view returns (address parentIpId);

    /// @notice Checks if an IP is a parent IP.
    /// @param parentIpId The address of the parent IP.
    /// @param childIpId The address of the child IP.
    /// @return Whether the IP is a parent IP.
    function isParentIp(address parentIpId, address childIpId) external view returns (bool);

    /// @notice Gets the count of parent IPs.
    /// @param childIpId The address of the childIP.
    /// @return The count o parent IPs.
    function getParentIpCount(address childIpId) external view returns (uint256);

    /// @notice Retrieves the minting license configuration for a given license terms of the IP.
    /// Will return the configuration for the license terms of the IP if configuration is not set for the license terms.
    /// @param ipId The address of the IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The configuration for minting the license.
    function getMintingLicenseConfig(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (Licensing.MintingLicenseConfig memory);

    /// @notice Sets the minting license configuration for a specific license attached to a specific IP.
    /// @dev This function can only be called by the LicensingModule.
    /// @param ipId The address of the IP for which the configuration is being set.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param mintingLicenseConfig The configuration for minting the license.
    function setMintingLicenseConfigForLicense(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        Licensing.MintingLicenseConfig calldata mintingLicenseConfig
    ) external;

    /// @notice Sets the MintingLicenseConfig for an IP and applies it to all licenses attached to the IP.
    /// @dev This function will set a global configuration for all licenses under a specific IP.
    /// However, this global configuration can be overridden by a configuration set at a specific license level.
    /// @param ipId The IP ID for which the configuration is being set.
    /// @param mintingLicenseConfig The MintingLicenseConfig to be set for all licenses under the given IP.
    function setMintingLicenseConfigForIp(
        address ipId,
        Licensing.MintingLicenseConfig calldata mintingLicenseConfig
    ) external;

    /// @notice Sets the expiration time for an IP.
    /// @param ipId The address of the IP.
    /// @param expireTime The new expiration time, 0 means never expired.
    function setExpireTime(address ipId, uint256 expireTime) external;

    /// @notice Gets the expiration time for an IP.
    /// @param ipId The address of the IP.
    /// @return The expiration time, 0 means never expired.
    function getExpireTime(address ipId) external view returns (uint256);

    /// @notice Checks if an IP is expired.
    /// @param ipId The address of the IP.
    /// @return Whether the IP is expired.
    function isExpiredNow(address ipId) external view returns (bool);
}

/// @notice Module Interface
interface IModule is IERC165 {
    /// @notice Returns the string identifier associated with the module.
    function name() external returns (string memory);
}

/// @title ILicensingModule
/// @notice This interface defines the entry point for users to manage licenses in the Story Protocol.
/// It defines the workflow of license actions and coordinates among all license components and dependent components,
/// like RoyaltyModule.
/// The Licensing Module is responsible for attaching license terms to an IP, minting license tokens,
/// and registering derivatives.
interface ILicensingModule is IModule {
    /// @notice Emitted when new license terms are attached to an IP.
    /// @param caller The address of the caller.
    /// @param ipId The IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms in the license template.
    event LicenseTermsAttached(
        address indexed caller,
        address indexed ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    );

    /// @notice Emitted when license tokens are minted.
    /// @param caller The address of the caller.
    /// @param licensorIpId The parent IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    /// @param amount The amount of license tokens minted.
    /// @param receiver The address of the receiver.
    /// @param startLicenseTokenId The start ID of the minted license tokens.
    event LicenseTokensMinted(
        address indexed caller,
        address indexed licensorIpId,
        address licenseTemplate,
        uint256 indexed licenseTermsId,
        uint256 amount,
        address receiver,
        uint256 startLicenseTokenId
    );

    /// @notice Emitted when a derivative IP is registered.
    /// @param caller The address of the caller.
    /// @param childIpId The derivative IP ID.
    /// @param licenseTokenIds The IDs of the license tokens.
    /// @param parentIpIds The parent IP IDs.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param licenseTemplate The address of the license template.
    event DerivativeRegistered(
        address indexed caller,
        address indexed childIpId,
        uint256[] licenseTokenIds,
        address[] parentIpIds,
        uint256[] licenseTermsIds,
        address licenseTemplate
    );

    /// @notice Attaches license terms to an IP.
    /// the function must be called by the IP owner or an authorized operator.
    /// @param ipId The IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    function attachLicenseTerms(address ipId, address licenseTemplate, uint256 licenseTermsId) external;

    /// @notice Mints license tokens for the license terms attached to an IP.
    /// The license tokens are minted to the receiver.
    /// The license terms must be attached to the IP before calling this function.
    /// But it can mint license token of default license terms without attaching the default license terms,
    /// since it is attached to all IPs by default.
    /// IP owners can mint license tokens for their IPs for arbitrary license terms
    /// without attaching the license terms to IP.
    /// It might require the caller pay the minting fee, depending on the license terms or configured by the iP owner.
    /// The minting fee is paid in the minting fee token specified in the license terms or configured by the IP owner.
    /// IP owners can configure the minting fee of their IPs or
    /// configure the minting fee module to determine the minting fee.
    /// IP owners can configure the receiver check module to determine the receiver of the minted license tokens.
    /// @param licensorIpId The licensor IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver.
    /// @param royaltyContext The context of the royalty.
    /// @return startLicenseTokenId The start ID of the minted license tokens.
    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external returns (uint256 startLicenseTokenId);

    /// @notice Registers a derivative directly with parent IP's license terms, without needing license tokens,
    /// and attaches the license terms of the parent IPs to the derivative IP.
    /// The license terms must be attached to the parent IP before calling this function.
    /// All IPs attached default license terms by default.
    /// The derivative IP owner must be the caller or an authorized operator.
    /// @param childIpId The derivative IP ID.
    /// @param parentIpIds The parent IP IDs.
    /// @param licenseTermsIds The IDs of the license terms that the parent IP supports.
    /// @param licenseTemplate The address of the license template of the license terms Ids.
    /// @param royaltyContext The context of the royalty.
    function registerDerivative(
        address childIpId,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        bytes calldata royaltyContext
    ) external;

    /// @notice Registers a derivative with license tokens.
    /// the derivative IP is registered with license tokens minted from the parent IP's license terms.
    /// the license terms of the parent IPs issued with license tokens are attached to the derivative IP.
    /// the caller must be the derivative IP owner or an authorized operator.
    /// @param childIpId The derivative IP ID.
    /// @param licenseTokenIds The IDs of the license tokens.
    /// @param royaltyContext The context of the royalty.
    function registerDerivativeWithLicenseTokens(
        address childIpId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext
    ) external;
}



// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

/// @title ILicenseTemplate
/// @notice This interface defines the methods for a License Template.
/// A License Template is responsible for defining a template of license terms that allow users to create
/// licenses based on the template terms.
/// The License Template contract is also responsible for registering, storing, verifying,
/// and displaying license terms registered with the License Template.
/// Anyone can implement a License Template and register it into the Story Protocol.
/// @dev The License Template should assign an unique ID to each license terms registered.
interface ILicenseTemplate is IERC165 {
    /// @notice Emitted when a new license terms is registered.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTerms The data of the license.
    event LicenseTermsRegistered(uint256 indexed licenseTermsId, address indexed licenseTemplate, bytes licenseTerms);

    /// @notice Returns the name of the license template.
    /// @return The name of the license template.
    function name() external view returns (string memory);

    /// @notice Converts the license terms to a JSON string which will be part of the metadata of license token.
    /// @dev the json will be part of metadata as attributes return by tokenURI() license token,
    /// hence the json format should follow the common NFT metadata standard.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The JSON string of the license terms.
    function toJson(uint256 licenseTermsId) external view returns (string memory);

    /// @notice Returns the metadata URI of the license template.
    /// @return The metadata URI of the license template.
    function getMetadataURI() external view returns (string memory);

    /// @notice Returns the URI of the license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The URI of the license terms.
    function getLicenseTermsURI(uint256 licenseTermsId) external view returns (string memory);

    /// @notice Returns the total number of registered license terms.
    /// @return The total number of registered license terms.
    function totalRegisteredLicenseTerms() external view returns (uint256);

    /// @notice Checks if a license terms exists.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms exists, false otherwise.
    function exists(uint256 licenseTermsId) external view returns (bool);

    /// @notice Checks if a license terms is transferable.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms is transferable, false otherwise.
    function isLicenseTransferable(uint256 licenseTermsId) external view returns (bool);

    /// @notice Returns the earliest expiration time among the given license terms.
    /// @param start The start time to calculate the expiration time.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return The earliest expiration time.
    function getEarlierExpireTime(uint256[] calldata licenseTermsIds, uint256 start) external view returns (uint256);

    /// @notice Returns the expiration time of a license terms.
    /// @param start The start time.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The expiration time.
    function getExpireTime(uint256 licenseTermsId, uint256 start) external view returns (uint256);

    /// @notice Returns the royalty policy of a license terms.
    /// @dev All License Templates should implement this method.
    /// The royalty policy is used to calculate royalties and pay minting license fee.
    /// Should return address(0) if the license template does not support a royalty policy or
    /// the license term does set RoyaltyPolicy.
    /// @param licenseTermsId The ID of the license terms.
    /// @return royaltyPolicy The address of the royalty policy specified for the license terms.
    /// @return royaltyData The data of the royalty policy.
    /// @return mintingLicenseFee The fee for minting a license.
    /// @return currencyToken The address of the ERC20 token, used for minting license fee and royalties.
    /// the currency token will used for pay for license token minting fee and royalties.
    function getRoyaltyPolicy(
        uint256 licenseTermsId
    )
        external
        view
        returns (address royaltyPolicy, bytes memory royaltyData, uint256 mintingLicenseFee, address currencyToken);

    /// @notice Verifies the minting of a license token.
    /// @dev the function will be called by the LicensingModule when minting a license token to
    /// verify the minting is whether allowed by the license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee who will receive the license token.
    /// @param licensorIpId The IP ID of the licensor who attached the license terms minting the license token.
    /// @param amount The amount of licenses to mint.
    /// @return True if the minting is verified, false otherwise.
    function verifyMintLicenseToken(
        uint256 licenseTermsId,
        address licensee,
        address licensorIpId,
        uint256 amount
    ) external returns (bool);

    /// @notice Verifies the registration of a derivative.
    /// @dev This function is invoked by the LicensingModule during the registration of a derivative work
    //// to ensure compliance with the parent intellectual property's licensing terms.
    /// It verifies whether the derivative's registration is permitted under those terms.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpId The IP ID of the parent.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivative(
        address childIpId,
        address parentIpId,
        uint256 licenseTermsId,
        address licensee
    ) external returns (bool);

    /// @notice Verifies if the licenses are compatible.
    /// @dev This function is called by the LicensingModule to verify license compatibility
    /// when registering a derivative IP to multiple parent IPs.
    /// It ensures that the licenses of all parent IPs are compatible with each other during the registration process.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return True if the licenses are compatible, false otherwise.
    function verifyCompatibleLicenses(uint256[] calldata licenseTermsIds) external view returns (bool);

    /// @notice Verifies the registration of a derivative for all parent IPs.
    /// @dev This function is called by the LicensingModule to verify licenses for registering a derivative IP
    /// to multiple parent IPs.
    /// the function will verify the derivative for each parent IP's license and
    /// also verify all licenses are compatible.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpId The IP IDs of the parents.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param childIpOwner The address of the derivative IP owner.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivativeForAllParents(
        address childIpId,
        address[] calldata parentIpId,
        uint256[] calldata licenseTermsIds,
        address childIpOwner
    ) external returns (bool);
}



/// @title LicenseRegistry aka LNFT
/// @notice Registry of License NFTs, which represent licenses granted by IP ID licensors to create derivative IPs.
contract LicenseRegistry_V1_0_0 is ILicenseRegistry, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for *;
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using IPAccountStorageOps for IIPAccount;

    /// @dev Storage of the LicenseRegistry
    /// @param licensingModule Returns the canonical protocol-wide LicensingModule
    /// @param disputeModule Returns the canonical protocol-wide DisputeModule
    /// @param defaultLicenseTemplate The default license template address
    /// @param defaultLicenseTermsId The default license terms ID
    /// @param registeredLicenseTemplates Registered license templates
    /// @param registeredRoyaltyPolicies Registered royalty policies
    /// @param registeredCurrencyTokens Registered currency tokens
    /// @param parentIps Mapping of parent IPs to derivative IPs
    /// @param childIps Mapping of derivative IPs to parent IPs
    /// @param attachedLicenseTerms Mapping of attached license terms to IP IDs
    /// @param licenseTemplates Mapping of license templates to IP IDs
    /// @param expireTimes Mapping of IP IDs to expire times
    /// @param mintingLicenseConfigs Mapping of minting license configs to a licenseTerms of an IP
    /// @param mintingLicenseConfigsForIp Mapping of minting license configs to an IP,
    /// the config will apply to all licenses under the IP
    /// @dev Storage structure for the LicenseRegistry
    /// @custom:storage-location erc7201:story-protocol.LicenseRegistry
    struct LicenseRegistryStorage {
        ILicensingModule licensingModule;
        IDisputeModule disputeModule;
        address defaultLicenseTemplate;
        uint256 defaultLicenseTermsId;
        mapping(address licenseTemplate => bool isRegistered) registeredLicenseTemplates;
        mapping(address childIpId => EnumerableSet.AddressSet parentIpIds) parentIps;
        mapping(address parentIpId => EnumerableSet.AddressSet childIpIds) childIps;
        mapping(address ipId => EnumerableSet.UintSet licenseTermsIds) attachedLicenseTerms;
        mapping(address ipId => address licenseTemplate) licenseTemplates;
        mapping(bytes32 ipLicenseHash => Licensing.MintingLicenseConfig mintingLicenseConfig) mintingLicenseConfigs;
        mapping(address ipId => Licensing.MintingLicenseConfig mintingLicenseConfig) mintingLicenseConfigsForIp;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicenseRegistry")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicenseRegistryStorageLocation =
        0x5ed898e10dedf257f39672a55146f3fecade9da16f4ff022557924a10d60a900;

    bytes32 public constant EXPIRATION_TIME = "EXPIRATION_TIME";

    modifier onlyLicensingModule() {
        if (msg.sender != address(_getLicenseRegistryStorage().licensingModule)) {
            revert Errors.LicenseRegistry__CallerNotLicensingModule();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.LicenseRegistry__ZeroAccessManager();
        }
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
    }

    /// @dev Sets the DisputeModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newDisputeModule The address of the DisputeModule
    function setDisputeModule(address newDisputeModule) external restricted {
        if (newDisputeModule == address(0)) {
            revert Errors.LicenseRegistry__ZeroDisputeModule();
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.disputeModule = IDisputeModule(newDisputeModule);
    }

    /// @dev Sets the LicensingModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newLicensingModule The address of the LicensingModule
    function setLicensingModule(address newLicensingModule) external restricted {
        if (newLicensingModule == address(0)) {
            revert Errors.LicenseRegistry__ZeroLicensingModule();
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.licensingModule = ILicensingModule(newLicensingModule);
    }

    /// @notice Sets the default license terms that are attached to all IPs by default.
    /// @param newLicenseTemplate The address of the new default license template.
    /// @param newLicenseTermsId The ID of the new default license terms.
    function setDefaultLicenseTerms(address newLicenseTemplate, uint256 newLicenseTermsId) external restricted {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.defaultLicenseTemplate = newLicenseTemplate;
        $.defaultLicenseTermsId = newLicenseTermsId;
    }

    /// @notice Registers a new license template in the Story Protocol.
    /// @param licenseTemplate The address of the license template to register.
    function registerLicenseTemplate(address licenseTemplate) external restricted {
        if (!licenseTemplate.supportsInterface(type(ILicenseTemplate).interfaceId)) {
            revert Errors.LicenseRegistry__NotLicenseTemplate(licenseTemplate);
        }
        _getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate] = true;
        emit LicenseTemplateRegistered(licenseTemplate);
    }

    /// @notice Sets the expiration time for an IP.
    /// @param ipId The address of the IP.
    /// @param expireTime The new expiration time, 0 means never expired.
    function setExpireTime(address ipId, uint256 expireTime) external onlyLicensingModule {
        _setExpirationTime(ipId, expireTime);
    }

    /// @notice Sets the minting license configuration for a specific license attached to a specific IP.
    /// @dev This function can only be called by the LicensingModule.
    /// @param ipId The address of the IP for which the configuration is being set.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param mintingLicenseConfig The configuration for minting the license.
    function setMintingLicenseConfigForLicense(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        Licensing.MintingLicenseConfig calldata mintingLicenseConfig
    ) external onlyLicensingModule {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (!$.registeredLicenseTemplates[licenseTemplate]) {
            revert Errors.LicenseRegistry__UnregisteredLicenseTemplate(licenseTemplate);
        }
        $.mintingLicenseConfigs[_getIpLicenseHash(ipId, licenseTemplate, licenseTermsId)] = Licensing
            .MintingLicenseConfig({
                isSet: true,
                mintingFee: mintingLicenseConfig.mintingFee,
                mintingFeeModule: mintingLicenseConfig.mintingFeeModule,
                receiverCheckModule: mintingLicenseConfig.receiverCheckModule,
                receiverCheckData: mintingLicenseConfig.receiverCheckData
            });

        emit MintingLicenseConfigSetLicense(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Sets the MintingLicenseConfig for an IP and applies it to all licenses attached to the IP.
    /// @dev This function will set a global configuration for all licenses under a specific IP.
    /// However, this global configuration can be overridden by a configuration set at a specific license level.
    /// @param ipId The IP ID for which the configuration is being set.
    /// @param mintingLicenseConfig The MintingLicenseConfig to be set for all licenses under the given IP.
    function setMintingLicenseConfigForIp(
        address ipId,
        Licensing.MintingLicenseConfig calldata mintingLicenseConfig
    ) external onlyLicensingModule {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        $.mintingLicenseConfigsForIp[ipId] = Licensing.MintingLicenseConfig({
            isSet: true,
            mintingFee: mintingLicenseConfig.mintingFee,
            mintingFeeModule: mintingLicenseConfig.mintingFeeModule,
            receiverCheckModule: mintingLicenseConfig.receiverCheckModule,
            receiverCheckData: mintingLicenseConfig.receiverCheckData
        });
        emit MintingLicenseConfigSetForIP(ipId, mintingLicenseConfig);
    }

    /// @notice Attaches license terms to an IP.
    /// @param ipId The address of the IP to which the license terms are attached.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    function attachLicenseTermsToIp(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external onlyLicensingModule {
        if (!_exists(licenseTemplate, licenseTermsId)) {
            revert Errors.LicensingModule__LicenseTermsNotFound(licenseTemplate, licenseTermsId);
        }

        if (_isExpiredNow(ipId)) {
            revert Errors.LicenseRegistry__IpExpired(ipId);
        }

        if (_hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId)) {
            revert Errors.LicenseRegistry__LicenseTermsAlreadyAttached(ipId, licenseTemplate, licenseTermsId);
        }

        if (_isDerivativeIp(ipId)) {
            revert Errors.LicensingModule__DerivativesCannotAddLicenseTerms();
        }

        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.licenseTemplates[ipId] != address(0) && $.licenseTemplates[ipId] != licenseTemplate) {
            revert Errors.LicenseRegistry__UnmatchedLicenseTemplate(ipId, $.licenseTemplates[ipId], licenseTemplate);
        }

        $.licenseTemplates[ipId] = licenseTemplate;
        $.attachedLicenseTerms[ipId].add(licenseTermsId);
    }

    /// @notice Registers a derivative IP and its relationship to parent IPs.
    /// @param childIpId The address of the derivative IP.
    /// @param parentIpIds An array of addresses of the parent IPs.
    /// @param licenseTemplate The address of the license template used.
    /// @param licenseTermsIds An array of IDs of the license terms.
    function registerDerivativeIp(
        address childIpId,
        address[] calldata parentIpIds,
        address licenseTemplate,
        uint256[] calldata licenseTermsIds
    ) external onlyLicensingModule {
        if (parentIpIds.length == 0) {
            revert Errors.LicenseRegistry__NoParentIp();
        }
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.parentIps[childIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeAlreadyRegistered(childIpId);
        }
        if ($.attachedLicenseTerms[childIpId].length() > 0) {
            revert Errors.LicenseRegistry__DerivativeIpAlreadyHasLicense(childIpId);
        }

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            _verifyDerivativeFromParent(parentIpIds[i], childIpId, licenseTemplate, licenseTermsIds[i]);
            $.childIps[parentIpIds[i]].add(childIpId);
            // determine if duplicate license terms
            bool isNewParent = $.parentIps[childIpId].add(parentIpIds[i]);
            bool isNewTerms = $.attachedLicenseTerms[childIpId].add(licenseTermsIds[i]);
            if (!isNewParent && !isNewTerms) {
                revert Errors.LicenseRegistry__DuplicateLicense(parentIpIds[i], licenseTemplate, licenseTermsIds[i]);
            }
        }

        $.licenseTemplates[childIpId] = licenseTemplate;
        _setExpirationTime(
            childIpId,
            ILicenseTemplate(licenseTemplate).getEarlierExpireTime(licenseTermsIds, block.timestamp)
        );
    }

    /// @notice Verifies the minting of a license token.
    /// @param licensorIpId The address of the licensor IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms will mint the license token.
    /// @param isMintedByIpOwner Whether the license token is minted by the IP owner.
    /// @return The configuration for minting the license.
    function verifyMintLicenseToken(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bool isMintedByIpOwner
    ) external view returns (Licensing.MintingLicenseConfig memory) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (_isExpiredNow(licensorIpId)) {
            revert Errors.LicenseRegistry__ParentIpExpired(licensorIpId);
        }
        if (isMintedByIpOwner) {
            if (!_exists(licenseTemplate, licenseTermsId)) {
                revert Errors.LicenseRegistry__LicenseTermsNotExists(licenseTemplate, licenseTermsId);
            }
        } else if (!_hasIpAttachedLicenseTerms(licensorIpId, licenseTemplate, licenseTermsId)) {
            revert Errors.LicenseRegistry__LicensorIpHasNoLicenseTerms(licensorIpId, licenseTemplate, licenseTermsId);
        }
        return _getMintingLicenseConfig(licensorIpId, licenseTemplate, licenseTermsId);
    }

    /// @notice Checks if a license template is registered.
    /// @param licenseTemplate The address of the license template to check.
    /// @return Whether the license template is registered.
    function isRegisteredLicenseTemplate(address licenseTemplate) external view returns (bool) {
        return _getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate];
    }

    /// @notice Checks if an IP is a derivative IP.
    /// @param childIpId The address of the IP to check.
    /// @return Whether the IP is a derivative IP.
    function isDerivativeIp(address childIpId) external view returns (bool) {
        return _isDerivativeIp(childIpId);
    }

    /// @notice Checks if an IP has derivative IPs.
    /// @param parentIpId The address of the IP to check.
    /// @return Whether the IP has derivative IPs.
    function hasDerivativeIps(address parentIpId) external view returns (bool) {
        return _getLicenseRegistryStorage().childIps[parentIpId].length() > 0;
    }

    /// @notice Checks if license terms exist.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the license terms exist.
    function exists(address licenseTemplate, uint256 licenseTermsId) external view returns (bool) {
        return _exists(licenseTemplate, licenseTermsId);
    }

    /// @notice Checks if an IP has attached any license terms.
    /// @param ipId The address of the IP to check.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return Whether the IP has attached any license terms.
    function hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (bool) {
        return _hasIpAttachedLicenseTerms(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Gets the attached license terms of an IP by its index.
    /// @param ipId The address of the IP.
    /// @param index The index of the attached license terms within the array of all attached license terms of the IP.
    /// @return licenseTemplate The address of the license template where the license terms are defined.
    /// @return licenseTermsId The ID of the license terms.
    function getAttachedLicenseTerms(
        address ipId,
        uint256 index
    ) external view returns (address licenseTemplate, uint256 licenseTermsId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (index >= $.attachedLicenseTerms[ipId].length()) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(ipId, index, $.attachedLicenseTerms[ipId].length());
        }
        licenseTemplate = $.licenseTemplates[ipId];
        licenseTermsId = $.attachedLicenseTerms[ipId].at(index);
    }

    /// @notice Gets the count of attached license terms of an IP.
    /// @param ipId The address of the IP.
    /// @return The count of attached license terms.
    function getAttachedLicenseTermsCount(address ipId) external view returns (uint256) {
        return _getLicenseRegistryStorage().attachedLicenseTerms[ipId].length();
    }

    /// @notice Gets the derivative IP of an IP by its index.
    /// @param parentIpId The address of the IP.
    /// @param index The index of the derivative IP within the array of all derivative IPs of the IP.
    /// @return childIpId The address of the derivative IP.
    function getDerivativeIp(address parentIpId, uint256 index) external view returns (address childIpId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (index >= $.childIps[parentIpId].length()) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(parentIpId, index, $.childIps[parentIpId].length());
        }
        childIpId = $.childIps[parentIpId].at(index);
    }

    /// @notice Gets the count of derivative IPs of an IP.
    /// @param parentIpId The address of the IP.
    /// @return The count of derivative IPs.
    function getDerivativeIpCount(address parentIpId) external view returns (uint256) {
        return _getLicenseRegistryStorage().childIps[parentIpId].length();
    }

    /// @notice got the parent IP of an IP by its index.
    /// @param childIpId The address of the IP.
    /// @param index The index of the parent IP within the array of all parent IPs of the IP.
    /// @return parentIpId The address of the parent IP.
    function getParentIp(address childIpId, uint256 index) external view returns (address parentIpId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (index >= $.parentIps[childIpId].length()) {
            revert Errors.LicenseRegistry__IndexOutOfBounds(childIpId, index, $.parentIps[childIpId].length());
        }
        parentIpId = $.parentIps[childIpId].at(index);
    }

    function isParentIp(address parentIpId, address childIpId) external view returns (bool) {
        return _getLicenseRegistryStorage().parentIps[childIpId].contains(parentIpId);
    }

    /// @notice Gets the count of parent IPs.
    /// @param childIpId The address of the childIP.
    /// @return The count o parent IPs.
    function getParentIpCount(address childIpId) external view returns (uint256) {
        return _getLicenseRegistryStorage().parentIps[childIpId].length();
    }

    /// @notice Retrieves the minting license configuration for a given license terms of the IP.
    /// Will return the configuration for the license terms of the IP if configuration is not set for the license terms.
    /// @param ipId The address of the IP.
    /// @param licenseTemplate The address of the license template where the license terms are defined.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The configuration for minting the license.
    function getMintingLicenseConfig(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external view returns (Licensing.MintingLicenseConfig memory) {
        return _getMintingLicenseConfig(ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Returns the canonical protocol-wide LicensingModule
    function licensingModule() external view returns (ILicensingModule) {
        return _getLicenseRegistryStorage().licensingModule;
    }

    /// @notice Returns the canonical protocol-wide DisputeModule
    function disputeModule() external view returns (IDisputeModule) {
        return _getLicenseRegistryStorage().disputeModule;
    }

    /// @notice Gets the expiration time for an IP.
    /// @param ipId The address of the IP.
    /// @return The expiration time, 0 means never expired.
    function getExpireTime(address ipId) external view returns (uint256) {
        return IIPAccount(payable(ipId)).getUint256(EXPIRATION_TIME);
    }

    /// @notice Checks if an IP is expired.
    /// @param ipId The address of the IP.
    /// @return Whether the IP is expired.
    function isExpiredNow(address ipId) external view returns (bool) {
        return _isExpiredNow(ipId);
    }

    /// @notice Returns the default license terms.
    function getDefaultLicenseTerms() external view returns (address licenseTemplate, uint256 licenseTermsId) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        return ($.defaultLicenseTemplate, $.defaultLicenseTermsId);
    }

    /// @dev verify the child IP can be registered as a derivative of the parent IP
    /// @param parentIpId The address of the parent IP
    /// @param childIpId The address of the child IP
    /// @param licenseTemplate The address of the license template where the license terms are created
    /// @param licenseTermsId The license terms the child IP is registered with
    function _verifyDerivativeFromParent(
        address parentIpId,
        address childIpId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.disputeModule.isIpTagged(parentIpId)) {
            revert Errors.LicenseRegistry__ParentIpTagged(parentIpId);
        }
        if (childIpId == parentIpId) {
            revert Errors.LicenseRegistry__DerivativeIsParent(childIpId);
        }
        if (_isExpiredNow(parentIpId)) {
            revert Errors.LicenseRegistry__ParentIpExpired(parentIpId);
        }
        // childIp can only register with default license terms or the license terms attached to the parent IP
        if ($.defaultLicenseTemplate != licenseTemplate || $.defaultLicenseTermsId != licenseTermsId) {
            if ($.licenseTemplates[parentIpId] != licenseTemplate) {
                revert Errors.LicenseRegistry__ParentIpUnmatchedLicenseTemplate(parentIpId, licenseTemplate);
            }
            if (!$.attachedLicenseTerms[parentIpId].contains(licenseTermsId)) {
                revert Errors.LicenseRegistry__ParentIpHasNoLicenseTerms(parentIpId, licenseTermsId);
            }
        }
    }

    function _isExpiredNow(address ipId) internal view returns (bool) {
        uint256 expireTime = IIPAccount(payable(ipId)).getUint256(EXPIRATION_TIME);
        return expireTime != 0 && expireTime < block.timestamp;
    }

    function _setExpirationTime(address ipId, uint256 expireTime) internal {
        IIPAccount(payable(ipId)).setUint256(EXPIRATION_TIME, expireTime);
        emit ExpirationTimeSet(ipId, expireTime);
    }

    function _isDerivativeIp(address childIpId) internal view returns (bool) {
        return _getLicenseRegistryStorage().parentIps[childIpId].length() > 0;
    }

    /// @dev Retrieves the minting license configuration for a given license terms of the IP.
    /// Will return the configuration for the license terms of the IP if configuration is not set for the license terms.
    function _getMintingLicenseConfig(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view returns (Licensing.MintingLicenseConfig memory) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if (!$.registeredLicenseTemplates[licenseTemplate]) {
            revert Errors.LicenseRegistry__UnregisteredLicenseTemplate(licenseTemplate);
        }
        if ($.mintingLicenseConfigs[_getIpLicenseHash(ipId, licenseTemplate, licenseTermsId)].isSet) {
            return $.mintingLicenseConfigs[_getIpLicenseHash(ipId, licenseTemplate, licenseTermsId)];
        }
        return $.mintingLicenseConfigsForIp[ipId];
    }

    function _getIpLicenseHash(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(ipId, licenseTemplate, licenseTermsId));
    }

    function _hasIpAttachedLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) internal view returns (bool) {
        LicenseRegistryStorage storage $ = _getLicenseRegistryStorage();
        if ($.defaultLicenseTemplate == licenseTemplate && $.defaultLicenseTermsId == licenseTermsId) return true;
        return $.licenseTemplates[ipId] == licenseTemplate && $.attachedLicenseTerms[ipId].contains(licenseTermsId);
    }

    function _exists(address licenseTemplate, uint256 licenseTermsId) internal view returns (bool) {
        if (!_getLicenseRegistryStorage().registeredLicenseTemplates[licenseTemplate]) {
            return false;
        }
        return ILicenseTemplate(licenseTemplate).exists(licenseTermsId);
    }

    ////////////////////////////////////////////////////////////////////////////
    //                         Upgrades related                               //
    ////////////////////////////////////////////////////////////////////////////

    function _getLicenseRegistryStorage() internal pure returns (LicenseRegistryStorage storage $) {
        assembly {
            $.slot := LicenseRegistryStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        /// @solidity memory-safe-assembly
        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 0x20)
            let dataPtr := data
            let endPtr := add(data, mload(data))

            // In some cases, the last iteration will read bytes after the end of the data. We cache the value, and
            // set it to zero to make sure no dirty bytes are read in that section.
            let afterPtr := add(endPtr, 0x20)
            let afterCache := mload(afterPtr)
            mstore(afterPtr, 0x00)

            // Run over the input, 3 bytes at a time
            for {

            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 byte (24 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F to bitmask the least significant 6 bits.
                // Use this as an index into the lookup table, mload an entire word
                // so the desired character is in the least significant byte, and
                // mstore8 this least significant byte into the result and continue.

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // Reset the value that was cached
            mstore(afterPtr, afterCache)

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}


// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165Upgradeable is Initializable, IERC165 {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
abstract contract ERC721Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    /// @custom:storage-location erc7201:openzeppelin.storage.ERC721
    struct ERC721Storage {
        // Token name
        string _name;

        // Token symbol
        string _symbol;

        mapping(uint256 tokenId => address) _owners;

        mapping(address owner => uint256) _balances;

        mapping(uint256 tokenId => address) _tokenApprovals;

        mapping(address owner => mapping(address operator => bool)) _operatorApprovals;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC721")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC721StorageLocation = 0x80bb2b638cc20bc4d0a60d66940f3ab4a00c1d7b313497ca82fb0b4ab0079300;

    function _getERC721Storage() private pure returns (ERC721Storage storage $) {
        assembly {
            $.slot := ERC721StorageLocation
        }
    }

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    function __ERC721_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        ERC721Storage storage $ = _getERC721Storage();
        $._name = name_;
        $._symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual returns (uint256) {
        ERC721Storage storage $ = _getERC721Storage();
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return $._balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual returns (string memory) {
        ERC721Storage storage $ = _getERC721Storage();
        return $._name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual returns (string memory) {
        ERC721Storage storage $ = _getERC721Storage();
        return $._symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender());
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        ERC721Storage storage $ = _getERC721Storage();
        return $._operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     *
     * IMPORTANT: Any overrides to this function that add ownership of tokens not tracked by the
     * core ERC721 logic MUST be matched with the use of {_increaseBalance} to keep balances
     * consistent with ownership. The invariant to preserve is that for any address `a` the value returned by
     * `balanceOf(a)` must be equal to the number of tokens such that `_ownerOf(tokenId)` is `a`.
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        ERC721Storage storage $ = _getERC721Storage();
        return $._owners[tokenId];
    }

    /**
     * @dev Returns the approved address for `tokenId`. Returns 0 if `tokenId` is not minted.
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        ERC721Storage storage $ = _getERC721Storage();
        return $._tokenApprovals[tokenId];
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    }

    /**
     * @dev Checks if `spender` can operate on `tokenId`, assuming the provided `owner` is the actual owner.
     * Reverts if `spender` does not have approval from the provided `owner` for the given token or for all its assets
     * the `spender` for the specific `tokenId`.
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    }

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * NOTE: the value is limited to type(uint128).max. This protect against _balance overflow. It is unrealistic that
     * a uint256 would ever overflow from increments when these increments are bounded to uint128 values.
     *
     * WARNING: Increasing an account's balance using this function tends to be paired with an override of the
     * {_ownerOf} function to resolve the ownership of the corresponding tokens so that balances and ownership
     * remain consistent with one another.
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        ERC721Storage storage $ = _getERC721Storage();
        unchecked {
            $._balances[account] += value;
        }
    }

    /**
     * @dev Transfers `tokenId` from its current owner to `to`, or alternatively mints (or burns) if the current owner
     * (or `to`) is the zero address. Returns the owner of the `tokenId` before the update.
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that
     * `auth` is either the owner of the token, or approved to operate on the token (by the owner).
     *
     * Emits a {Transfer} event.
     *
     * NOTE: If overriding this function in a way that tracks balances, see also {_increaseBalance}.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        ERC721Storage storage $ = _getERC721Storage();
        address from = _ownerOf(tokenId);

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the update
        if (from != address(0)) {
            // Clear approval. No need to re-authorize or emit the Approval event
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                $._balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                $._balances[to] += 1;
            }
        }

        $._owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    /**
     * @dev Mints `tokenId`, transfers it to `to` and checks for `to` acceptance.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, data);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking that contract recipients
     * are aware of the ERC721 standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is like {safeTransferFrom} in the sense that it invokes
     * {IERC721Receiver-onERC721Received} on the receiver, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `tokenId` token must exist and be owned by `from`.
     * - `to` cannot be the zero address.
     * - `from` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that `auth` is
     * either the owner of the token, or approved to operate on all tokens held by this owner.
     *
     * Emits an {Approval} event.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev Variant of `_approve` with an optional flag to enable or disable the {Approval} event. The event is not
     * emitted in the context of transfers.
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        ERC721Storage storage $ = _getERC721Storage();
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use _isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        $._tokenApprovals[tokenId] = to;
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Requirements:
     * - operator can't be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        ERC721Storage storage $ = _getERC721Storage();
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        $._operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` doesn't have a current owner (it hasn't been minted, or it has been burned).
     * Returns the owner.
     *
     * Overrides to ownership logic should be done to {_ownerOf}.
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target address. This will revert if the
     * recipient doesn't accept the token transfer. The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/extensions/IERC721Enumerable.sol)

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds enumerability
 * of all the token ids in the contract as well as all token ids owned by each account.
 *
 * CAUTION: `ERC721` extensions that implement custom `balanceOf` logic, such as `ERC721Consecutive`,
 * interfere with enumerability and should not be used together with `ERC721Enumerable`.
 */
abstract contract ERC721EnumerableUpgradeable is Initializable, ERC721Upgradeable, IERC721Enumerable {
    /// @custom:storage-location erc7201:openzeppelin.storage.ERC721Enumerable
    struct ERC721EnumerableStorage {
        mapping(address owner => mapping(uint256 index => uint256)) _ownedTokens;
        mapping(uint256 tokenId => uint256) _ownedTokensIndex;

        uint256[] _allTokens;
        mapping(uint256 tokenId => uint256) _allTokensIndex;
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC721Enumerable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC721EnumerableStorageLocation = 0x645e039705490088daad89bae25049a34f4a9072d398537b1ab2425f24cbed00;

    function _getERC721EnumerableStorage() private pure returns (ERC721EnumerableStorage storage $) {
        assembly {
            $.slot := ERC721EnumerableStorageLocation
        }
    }

    /**
     * @dev An `owner`'s token query was out of bounds for `index`.
     *
     * NOTE: The owner being `address(0)` indicates a global out of bounds index.
     */
    error ERC721OutOfBoundsIndex(address owner, uint256 index);

    /**
     * @dev Batch mint is not allowed.
     */
    error ERC721EnumerableForbiddenBatchMint();

    function __ERC721Enumerable_init() internal onlyInitializing {
    }

    function __ERC721Enumerable_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721Upgradeable) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        ERC721EnumerableStorage storage $ = _getERC721EnumerableStorage();
        if (index >= balanceOf(owner)) {
            revert ERC721OutOfBoundsIndex(owner, index);
        }
        return $._ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        ERC721EnumerableStorage storage $ = _getERC721EnumerableStorage();
        return $._allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        ERC721EnumerableStorage storage $ = _getERC721EnumerableStorage();
        if (index >= totalSupply()) {
            revert ERC721OutOfBoundsIndex(address(0), index);
        }
        return $._allTokens[index];
    }

    /**
     * @dev See {ERC721-_update}.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        address previousOwner = super._update(to, tokenId, auth);

        if (previousOwner == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (previousOwner != to) {
            _removeTokenFromOwnerEnumeration(previousOwner, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (previousOwner != to) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }

        return previousOwner;
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        ERC721EnumerableStorage storage $ = _getERC721EnumerableStorage();
        uint256 length = balanceOf(to) - 1;
        $._ownedTokens[to][length] = tokenId;
        $._ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        ERC721EnumerableStorage storage $ = _getERC721EnumerableStorage();
        $._allTokensIndex[tokenId] = $._allTokens.length;
        $._allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        ERC721EnumerableStorage storage $ = _getERC721EnumerableStorage();
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = balanceOf(from);
        uint256 tokenIndex = $._ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = $._ownedTokens[from][lastTokenIndex];

            $._ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            $._ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete $._ownedTokensIndex[tokenId];
        delete $._ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        ERC721EnumerableStorage storage $ = _getERC721EnumerableStorage();
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = $._allTokens.length - 1;
        uint256 tokenIndex = $._allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = $._allTokens[lastTokenIndex];

        $._allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        $._allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete $._allTokensIndex[tokenId];
        $._allTokens.pop();
    }

    /**
     * See {ERC721-_increaseBalance}. We need that to account tokens that were minted in batch
     */
    function _increaseBalance(address account, uint128 amount) internal virtual override {
        if (amount > 0) {
            revert ERC721EnumerableForbiddenBatchMint();
        }
        super._increaseBalance(account, amount);
    }
}


/// @title ILicenseToken
/// @notice Interface for the License Token (ERC721) NFT collection that manages License Tokens representing
/// License Terms.
/// Each License Token may represent a set of License Terms and could have an expiration time.
/// License Tokens are ERC721 NFTs that can be minted, transferred (if allowed), and burned.
/// Derivative IP owners can burn License Tokens to register their IP as a derivative of the licensor IP for which
/// the License Token was minted.
/// This interface includes functionalities for minting, burning, and querying License Tokens and their associated
/// metadata.
interface ILicenseToken is IERC721Metadata, IERC721Enumerable {
    /// @notice Metadata struct for License Tokens.
    /// @param licensorIpId The ID of the licensor IP for which the License Token was minted.
    /// @param licenseTemplate The address of the License Template associated with the License Token.
    /// @param licenseTermsId The ID of the License Terms associated with the License Token.
    /// @param transferable Whether the License Token is transferable, determined by the License Terms.
    /// @param mintedAt The timestamp at which the License Token was minted.
    /// @param expiresAt The timestamp at which the License Token expires.
    struct LicenseTokenMetadata {
        address licensorIpId;
        address licenseTemplate;
        uint256 licenseTermsId;
        bool transferable;
        uint256 mintedAt;
        uint256 expiresAt;
    }

    /// @notice Emitted when a License Token is minted.
    /// @param minter The address of the minter of the License Token.
    /// The caller of mintLicenseTokens function of LicensingModule.
    /// @param receiver The address of the receiver of the License Token.
    /// @param tokenId The ID of the minted License Token.
    event LicenseTokenMinted(address indexed minter, address indexed receiver, uint256 indexed tokenId);

    /// @notice Mints a specified amount of License Tokens (LNFTs).
    /// @param licensorIpId The ID of the licensor IP for which the License Tokens are minted.
    /// @param licenseTemplate The address of the License Template.
    /// @param licenseTermsId The ID of the License Terms.
    /// @param amount The amount of License Tokens to mint.
    /// @param minter The address of the minter.
    /// @param receiver The address of the receiver of the minted License Tokens.
    /// @return startLicenseTokenId The start ID of the minted License Tokens.
    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount, // mint amount
        address minter,
        address receiver
    ) external returns (uint256 startLicenseTokenId);

    /// @notice Burns specified License Tokens.
    /// @param holder The address of the holder of the License Tokens.
    /// @param tokenIds An array of IDs of the License Tokens to be burned.
    function burnLicenseTokens(address holder, uint256[] calldata tokenIds) external;

    /// @notice Returns the total number of minted License Tokens since beginning,
    /// the number won't decrease when license tokens are burned.
    /// @return The total number of minted License Tokens.
    function totalMintedTokens() external view returns (uint256);

    /// @notice Returns the licensor IP ID associated with a given License Token.
    /// @param tokenId The ID of the License Token.
    /// @return The licensor IP ID associated with the License Token.
    function getLicensorIpId(uint256 tokenId) external view returns (address);

    /// @notice Returns the ID of the license terms that are used for the given license ID
    /// @param tokenId The ID of the license token
    function getLicenseTermsId(uint256 tokenId) external view returns (uint256);

    /// @notice Returns the address of the license template that is used for the given license ID
    /// @param tokenId The ID of the license token
    function getLicenseTemplate(uint256 tokenId) external view returns (address);

    /// @notice Checks if a License Token has been revoked.
    /// @param tokenId The ID of the License Token to check.
    /// @return True if the License Token has been revoked, false otherwise.
    function isLicenseTokenRevoked(uint256 tokenId) external view returns (bool);

    /// @notice Gets the expiration time of a License Token.
    /// @param tokenId The ID of the License Token.
    /// @return The expiration time of the License Token.
    function getExpirationTime(uint256 tokenId) external view returns (uint256);

    /// @notice Retrieves the metadata associated with a License Token.
    /// @param tokenId The ID of the License Token.
    /// @return A `LicenseTokenMetadata` struct containing the metadata of the specified License Token.
    function getLicenseTokenMetadata(uint256 tokenId) external view returns (LicenseTokenMetadata memory);

    /// @notice Returns the canonical protocol-wide DisputeModule
    /// @return The DisputeModule instance
    function disputeModule() external view returns (IDisputeModule);

    /// @notice Returns the canonical protocol-wide LicensingModule
    /// @return The LicensingModule instance
    function licensingModule() external view returns (ILicensingModule);

    /// @notice Validates License Tokens for registering a derivative IP.
    /// @dev This function checks if the License Tokens are valid for the derivative IP registration process.
    /// for example, whether token is expired.
    /// The function will be called by LicensingModule when registering a derivative IP with license tokens.
    /// @param childIpId The ID of the derivative IP.
    /// @param childIpOwner The address of the owner of the derivative IP.
    /// @param tokenIds An array of IDs of the License Tokens to validate for the derivative
    /// IP to register as derivative of the licensor IPs which minted the license tokens.
    /// @return licenseTemplate The address of the License Template associated with the License Tokens.
    /// @return licensorIpIds An array of licensor IPs associated with each License Token.
    /// @return licenseTermsIds An array of License Terms associated with each validated License Token.
    function validateLicenseTokensForDerivative(
        address childIpId,
        address childIpOwner,
        uint256[] calldata tokenIds
    ) external view returns (address licenseTemplate, address[] memory licensorIpIds, uint256[] memory licenseTermsIds);
}


/// @title LicenseToken aka LNFT
contract LicenseToken_V1_0_0 is ILicenseToken, ERC721EnumerableUpgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    using Strings for *;

    /// @notice Emitted for metadata updates, per EIP-4906
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @dev Storage structure for the LicenseToken
    /// @custom:storage-location erc7201:story-protocol.LicenseToken
    struct LicenseTokenStorage {
        string imageUrl;
        ILicensingModule licensingModule;
        IDisputeModule disputeModule;
        uint256 totalMintedTokens;
        mapping(uint256 tokenId => LicenseTokenMetadata) licenseTokenMetadatas;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicenseToken")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicenseTokenStorageLocation =
        0x62a0d75e37bea0c3e666dc72a74112fc6af15ce635719127e380d8ca1e555d00;

    modifier onlyLicensingModule() {
        if (msg.sender != address(_getLicenseTokenStorage().licensingModule)) {
            revert Errors.LicenseToken__CallerNotLicensingModule();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the LicenseToken contract
    function initialize(address accessManager, string memory imageUrl) public initializer {
        if (accessManager == address(0)) {
            revert Errors.LicenseToken__ZeroAccessManager();
        }
        __ERC721_init("Programmable IP License Token", "PILicenseToken");
        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();
        _getLicenseTokenStorage().imageUrl = imageUrl;
    }

    /// @notice Sets the LicensingModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newLicensingModule The address of the LicensingModule
    function setLicensingModule(address newLicensingModule) external restricted {
        if (newLicensingModule == address(0)) {
            revert Errors.LicenseToken__ZeroLicensingModule();
        }
        LicenseTokenStorage storage $ = _getLicenseTokenStorage();
        $.licensingModule = ILicensingModule(newLicensingModule);
    }

    /// @notice Sets the DisputeModule address.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param newDisputeModule The address of the DisputeModule
    function setDisputeModule(address newDisputeModule) external restricted {
        if (newDisputeModule == address(0)) {
            revert Errors.LicenseToken__ZeroDisputeModule();
        }
        LicenseTokenStorage storage $ = _getLicenseTokenStorage();
        $.disputeModule = IDisputeModule(newDisputeModule);
    }

    /// @dev Sets the Licensing Image URL.
    /// @dev Enforced to be only callable by the protocol admin
    /// @param url The URL of the Licensing Image
    function setLicensingImageUrl(string calldata url) external restricted {
        LicenseTokenStorage storage $ = _getLicenseTokenStorage();
        $.imageUrl = url;
        emit BatchMetadataUpdate(1, $.totalMintedTokens);
    }

    /// @notice Mints a specified amount of License Tokens (LNFTs).
    /// @param licensorIpId The ID of the licensor IP for which the License Tokens are minted.
    /// @param licenseTemplate The address of the License Template.
    /// @param licenseTermsId The ID of the License Terms.
    /// @param amount The amount of License Tokens to mint.
    /// @param minter The address of the minter.
    /// @param receiver The address of the receiver of the minted License Tokens.
    /// @return startLicenseTokenId The start ID of the minted License Tokens.
    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount, // mint amount
        address minter,
        address receiver
    ) external onlyLicensingModule returns (uint256 startLicenseTokenId) {
        LicenseTokenMetadata memory ltm = LicenseTokenMetadata({
            licensorIpId: licensorIpId,
            licenseTemplate: licenseTemplate,
            licenseTermsId: licenseTermsId,
            transferable: ILicenseTemplate(licenseTemplate).isLicenseTransferable(licenseTermsId),
            mintedAt: block.timestamp,
            expiresAt: ILicenseTemplate(licenseTemplate).getExpireTime(licenseTermsId, block.timestamp)
        });

        LicenseTokenStorage storage $ = _getLicenseTokenStorage();
        startLicenseTokenId = $.totalMintedTokens;
        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = $.totalMintedTokens++;
            $.licenseTokenMetadatas[tokenId] = ltm;
            _mint(receiver, tokenId);
            emit LicenseTokenMinted(minter, receiver, tokenId);
        }
    }

    /// @notice Burns the License Tokens (LTs) for the given token IDs.
    /// @param holder The address of the holder of the License Tokens.
    /// @param tokenIds An array of IDs of the License Tokens to be burned.
    function burnLicenseTokens(address holder, uint256[] calldata tokenIds) external onlyLicensingModule {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
    }

    /// @notice Validates License Tokens for registering a derivative IP.
    /// @dev This function checks if the License Tokens are valid for the derivative IP registration process.
    /// for example, whether token is expired.
    /// The function will be called by LicensingModule when registering a derivative IP with license tokens.
    /// @param childIpId The ID of the derivative IP.
    /// @param childIpOwner The address of the owner of the derivative IP.
    /// @param tokenIds An array of IDs of the License Tokens to validate for the derivative
    /// IP to register as derivative of the licensor IPs which minted the license tokens.
    /// @return licenseTemplate The address of the License Template associated with the License Tokens.
    /// @return licensorIpIds An array of licensor IPs associated with each License Token.
    /// @return licenseTermsIds An array of License Terms associated with each validated License Token.
    function validateLicenseTokensForDerivative(
        address childIpId,
        address childIpOwner,
        uint256[] calldata tokenIds
    )
        external
        view
        returns (address licenseTemplate, address[] memory licensorIpIds, uint256[] memory licenseTermsIds)
    {
        LicenseTokenStorage storage $ = _getLicenseTokenStorage();
        licenseTemplate = $.licenseTokenMetadatas[tokenIds[0]].licenseTemplate;
        licensorIpIds = new address[](tokenIds.length);
        licenseTermsIds = new uint256[](tokenIds.length);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            LicenseTokenMetadata memory ltm = $.licenseTokenMetadatas[tokenIds[i]];
            if (_isExpiredNow(tokenIds[i])) {
                revert Errors.LicenseToken__LicenseTokenExpired(tokenIds[i], ltm.expiresAt, block.timestamp);
            }
            if (ownerOf(tokenIds[i]) != childIpOwner) {
                revert Errors.LicenseToken__NotLicenseTokenOwner(tokenIds[i], childIpOwner, ownerOf(tokenIds[i]));
            }
            if (licenseTemplate != ltm.licenseTemplate) {
                revert Errors.LicenseToken__AllLicenseTokensMustFromSameLicenseTemplate(
                    licenseTemplate,
                    ltm.licenseTemplate
                );
            }
            if (isLicenseTokenRevoked(tokenIds[i])) {
                revert Errors.LicenseToken__RevokedLicense(tokenIds[i]);
            }

            licensorIpIds[i] = ltm.licensorIpId;
            licenseTermsIds[i] = ltm.licenseTermsId;
        }
    }

    /// @notice Returns the total number of minted License Tokens since beginning,
    /// the number won't decrease when license tokens are burned.
    /// @return The total number of minted License Tokens.
    function totalMintedTokens() external view returns (uint256) {
        return _getLicenseTokenStorage().totalMintedTokens;
    }

    /// @notice Returns the license data for the given license ID
    /// @param tokenId The ID of the license token
    function getLicenseTokenMetadata(uint256 tokenId) external view returns (LicenseTokenMetadata memory) {
        return _getLicenseTokenStorage().licenseTokenMetadatas[tokenId];
    }

    /// @notice Returns the ID of the IP asset that is the licensor of the given license ID
    /// @param tokenId The ID of the license token
    function getLicensorIpId(uint256 tokenId) external view returns (address) {
        return _getLicenseTokenStorage().licenseTokenMetadatas[tokenId].licensorIpId;
    }

    /// @notice Returns the ID of the license terms that are used for the given license ID
    /// @param tokenId The ID of the license token
    function getLicenseTermsId(uint256 tokenId) external view returns (uint256) {
        return _getLicenseTokenStorage().licenseTokenMetadatas[tokenId].licenseTermsId;
    }

    /// @notice Returns the address of the license template that is used for the given license ID
    /// @param tokenId The ID of the license token
    function getLicenseTemplate(uint256 tokenId) external view returns (address) {
        return _getLicenseTokenStorage().licenseTokenMetadatas[tokenId].licenseTemplate;
    }

    /// @notice Gets the expiration time of a License Token.
    /// @param tokenId The ID of the License Token.
    /// @return The expiration time of the License Token.
    function getExpirationTime(uint256 tokenId) external view returns (uint256) {
        return _getLicenseTokenStorage().licenseTokenMetadatas[tokenId].expiresAt;
    }

    /// @notice Returns the canonical protocol-wide DisputeModule
    /// @return The DisputeModule instance
    function disputeModule() external view returns (IDisputeModule) {
        return _getLicenseTokenStorage().disputeModule;
    }

    /// @notice Returns the canonical protocol-wide LicensingModule
    /// @return The LicensingModule instance
    function licensingModule() external view returns (ILicensingModule) {
        return _getLicenseTokenStorage().licensingModule;
    }

    /// @notice Returns true if the license has been revoked (licensor IP tagged after a dispute in
    /// the dispute module). If the tag is removed, the license is not revoked anymore.
    /// @return isRevoked True if the license is revoked
    function isLicenseTokenRevoked(uint256 tokenId) public view returns (bool) {
        LicenseTokenStorage storage $ = _getLicenseTokenStorage();
        return $.disputeModule.isIpTagged($.licenseTokenMetadatas[tokenId].licensorIpId);
    }

    /// @notice ERC721 OpenSea metadata JSON representation of the LNFT parameters
    /// @dev Expect LicenseTemplate.toJson to return {'trait_type: 'value'},{'trait_type': 'value'},...,{...}
    /// (last attribute must not have a comma at the end)
    function tokenURI(
        uint256 id
    ) public view virtual override(ERC721Upgradeable, IERC721Metadata) returns (string memory) {
        LicenseTokenStorage storage $ = _getLicenseTokenStorage();

        LicenseTokenMetadata memory ltm = $.licenseTokenMetadatas[id];
        string memory licensorIpIdHex = ltm.licensorIpId.toHexString();

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
                '"image": "',
                $.imageUrl,
                '",',
                '"attributes": ['
            )
        );

        json = string(abi.encodePacked(json, ILicenseTemplate(ltm.licenseTemplate).toJson(ltm.licenseTermsId)));

        // append the common license attributes
        json = string(
            abi.encodePacked(
                json,
                '{"trait_type": "Licensor", "value": "',
                licensorIpIdHex,
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
        LicenseTokenStorage storage $ = _getLicenseTokenStorage();
        address from = _ownerOf(tokenId);
        if (from != address(0) && to != address(0)) {
            LicenseTokenMetadata memory ltm = $.licenseTokenMetadatas[tokenId];
            if (isLicenseTokenRevoked(tokenId)) {
                revert Errors.LicenseToken__RevokedLicense(tokenId);
            }
            if (!ltm.transferable) {
                // True if from == licensor
                if (from != ltm.licensorIpId) {
                    revert Errors.LicenseToken__NotTransferable();
                }
            }
        }
        return super._update(to, tokenId, auth);
    }

    function _isExpiredNow(uint256 tokenId) internal view returns (bool) {
        uint256 expireTime = _getLicenseTokenStorage().licenseTokenMetadatas[tokenId].expiresAt;
        return expireTime != 0 && expireTime < block.timestamp;
    }

    ////////////////////////////////////////////////////////////////////////////
    //                         Upgrades related                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @dev Returns the storage struct of LicenseToken.
    function _getLicenseTokenStorage() private pure returns (LicenseTokenStorage storage $) {
        assembly {
            $.slot := LicenseTokenStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}



// OpenZeppelin Contracts (last updated v5.0.0) (utils/introspection/ERC165.sol)

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

/// @title BaseModule
/// @notice Base implementation for all modules in Story Protocol.
abstract contract BaseModule is ERC165, IModule {
    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IModule).interfaceId || super.supportsInterface(interfaceId);
    }
}

/// @title RoyaltyModule interface
interface IRoyaltyModule is IModule {
    /// @notice Event emitted when a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);

    /// @notice Event emitted when a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @param allowed Indicates if the royalty token is whitelisted or not
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);

    /// @notice Event emitted when royalties are paid
    /// @param receiverIpId The ID of IP asset that receives the royalties
    /// @param payerIpId The ID of IP asset that pays the royalties
    /// @param sender The address that pays the royalties on behalf of the payer ID of IP asset
    /// @param token The token that is used to pay the royalties
    /// @param amount The amount that is paid
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);

    /// @notice Event emitted when the license minting fee is paid
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token that is used to pay the royalties
    /// @param amount The amount paid
    event LicenseMintingFeePaid(address receiverIpId, address payerAddress, address token, uint256 amount);

    /// @notice Sets the licensing module
    /// @dev Enforced to be only callable by the protocol admin
    /// @param licensing The address of the license module
    function setLicensingModule(address licensing) external;

    /// @notice Returns the licensing module address
    function licensingModule() external view returns (address);

    /// @notice Indicates if a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @return isWhitelisted True if the royalty policy is whitelisted
    function isWhitelistedRoyaltyPolicy(address royaltyPolicy) external view returns (bool);

    /// @notice Indicates if a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @return isWhitelisted True if the royalty token is whitelisted
    function isWhitelistedRoyaltyToken(address token) external view returns (bool);

    /// @notice Indicates the royalty policy for a given IP asset
    /// @param ipId The ID of IP asset
    /// @return royaltyPolicy The address of the royalty policy
    function royaltyPolicies(address ipId) external view returns (address);

    /// @notice Whitelist a royalty policy
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external;

    /// @notice Whitelist a royalty token
    /// @dev Enforced to be only callable by the protocol admin
    /// @param token The token address
    /// @param allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address token, bool allowed) external;

    /// @notice Executes royalty related logic on license minting
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param royaltyPolicy The royalty policy address of the license being minted
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address ipId,
        address royaltyPolicy,
        bytes calldata licenseData,
        bytes calldata externalData
    ) external;

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param royaltyPolicy The common royalty policy address of all the licenses being burned
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address royaltyPolicy,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external;

    /// @notice Allows the function caller to pay royalties to the receiver IP asset on behalf of the payer IP asset.
    /// @param receiverIpId The ID of the IP asset that receives the royalties
    /// @param payerIpId The ID of the IP asset that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;

    /// @notice Allows to pay the minting fee for a license
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param licenseRoyaltyPolicy The royalty policy of the license being minted
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payLicenseMintingFee(
        address receiverIpId,
        address payerAddress,
        address licenseRoyaltyPolicy,
        address token,
        uint256 amount
    ) external;
}



// Default Module Type, all modules in this type by default
string constant MODULE_TYPE_DEFAULT = "MODULE";

string constant MODULE_TYPE_HOOK = "HOOK_MODULE";

// String values for core protocol modules.

string constant LICENSING_MODULE_KEY = "LICENSING_MODULE";

string constant DISPUTE_MODULE_KEY = "DISPUTE_MODULE";

string constant ROYALTY_MODULE_KEY = "ROYALTY_MODULE";

string constant TOKEN_WITHDRAWAL_MODULE_KEY = "TOKEN_MANAGEMENT_MODULE";

string constant CORE_METADATA_MODULE_KEY = "CORE_METADATA_MODULE";

string constant CORE_METADATA_VIEW_MODULE_KEY = "CORE_METADATA_VIEW_MODULE";

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)




/// @title Story Protocol Royalty Module
/// @notice The Story Protocol royalty module allows to set royalty policies an IP asset and pay royalties as a
///         derivative IP.
contract RoyaltyModule_V1_0_0 is
    IRoyaltyModule,
    ProtocolPausableUpgradeable,
    ReentrancyGuardUpgradeable,
    BaseModule,
    UUPSUpgradeable
{
    using ERC165Checker for address;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Returns the protocol-wide dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @dev Storage structure for the RoyaltyModule
    /// @param licensingModule The address of the licensing module
    /// @param isWhitelistedRoyaltyPolicy Indicates if a royalty policy is whitelisted
    /// @param isWhitelistedRoyaltyToken Indicates if a royalty token is whitelisted
    /// @param royaltyPolicies Indicates the royalty policy for a given IP asset
    /// @custom:storage-location erc7201:story-protocol.RoyaltyModule
    struct RoyaltyModuleStorage {
        address licensingModule;
        mapping(address royaltyPolicy => bool isWhitelisted) isWhitelistedRoyaltyPolicy;
        mapping(address token => bool) isWhitelistedRoyaltyToken;
        mapping(address ipId => address royaltyPolicy) royaltyPolicies;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.RoyaltyModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyModuleStorageLocation =
        0x98dd2c34f21d19fd1d178ed731f3db3d03e0b4e39f02dbeb040e80c9427a0300;

    string public constant override name = ROYALTY_MODULE_KEY;

    /// @notice Constructor
    /// @param disputeModule The address of the dispute module
    /// @param licenseRegistry The address of the license registry
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address disputeModule, address licenseRegistry) {
        if (disputeModule == address(0)) revert Errors.RoyaltyModule__ZeroDisputeModule();
        if (licenseRegistry == address(0)) revert Errors.RoyaltyModule__ZeroLicenseRegistry();

        DISPUTE_MODULE = IDisputeModule(disputeModule);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) {
            revert Errors.RoyaltyModule__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Modifier to enforce that the caller is the licensing module
    modifier onlyLicensingModule() {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (msg.sender != $.licensingModule) revert Errors.RoyaltyModule__NotAllowedCaller();
        _;
    }

    /// @notice Sets the licensing module
    /// @dev Enforced to be only callable by the protocol admin
    /// @param licensing The address of the license module
    function setLicensingModule(address licensing) external restricted {
        if (licensing == address(0)) revert Errors.RoyaltyModule__ZeroLicensingModule();
        _getRoyaltyModuleStorage().licensingModule = licensing;
    }

    /// @notice Whitelist a royalty policy
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external restricted {
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();

        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        $.isWhitelistedRoyaltyPolicy[royaltyPolicy] = allowed;

        emit RoyaltyPolicyWhitelistUpdated(royaltyPolicy, allowed);
    }

    /// @notice Whitelist a royalty token
    /// @dev Enforced to be only callable by the protocol admin
    /// @param token The token address
    /// @param allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address token, bool allowed) external restricted {
        if (token == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyToken();

        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        $.isWhitelistedRoyaltyToken[token] = allowed;

        emit RoyaltyTokenWhitelistUpdated(token, allowed);
    }

    /// @notice Executes royalty related logic on license minting
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param royaltyPolicy The royalty policy address of the license being minted
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address ipId,
        address royaltyPolicy,
        bytes calldata licenseData,
        bytes calldata externalData
    ) external nonReentrant onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();

        if (!$.isWhitelistedRoyaltyPolicy[royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        address royaltyPolicyIpId = $.royaltyPolicies[ipId];

        // if the node is a root node, then royaltyPolicyIpId will be address(0) and any type of royalty type can be
        // selected to mint a license if the node is a derivative node, then the any minted licenses by the derivative
        // node should have the same royalty policy as the parent node and a derivative node set its royalty policy
        // immutably in onLinkToParents() function below
        if (royaltyPolicyIpId != royaltyPolicy && royaltyPolicyIpId != address(0))
            revert Errors.RoyaltyModule__CanOnlyMintSelectedPolicy();

        IRoyaltyPolicy(royaltyPolicy).onLicenseMinting(ipId, licenseData, externalData);
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by LicensingModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param royaltyPolicy The common royalty policy address of all the licenses being burned
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address royaltyPolicy,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external nonReentrant onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (!$.isWhitelistedRoyaltyPolicy[royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();
        if (parentIpIds.length == 0) revert Errors.RoyaltyModule__NoParentsOnLinking();

        for (uint32 i = 0; i < parentIpIds.length; i++) {
            address parentRoyaltyPolicy = $.royaltyPolicies[parentIpIds[i]];
            // if the parent node has a royalty policy set, then the derivative node should have the same royalty
            // policy if the parent node does not have a royalty policy set, then the derivative node can set any type
            // of royalty policy as long as the children ip obtained and is burning all licenses with that royalty type
            // from each parent (was checked in licensing module before calling this function)
            if (parentRoyaltyPolicy != royaltyPolicy && parentRoyaltyPolicy != address(0))
                revert Errors.RoyaltyModule__IncompatibleRoyaltyPolicy();
        }

        $.royaltyPolicies[ipId] = royaltyPolicy;

        IRoyaltyPolicy(royaltyPolicy).onLinkToParents(ipId, parentIpIds, licenseData, externalData);
    }

    /// @notice Allows the function caller to pay royalties to the receiver IP asset on behalf of the payer IP asset.
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerIpId The ipId that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(
        address receiverIpId,
        address payerIpId,
        address token,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (!$.isWhitelistedRoyaltyToken[token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();

        IDisputeModule dispute = DISPUTE_MODULE;
        if (dispute.isIpTagged(receiverIpId) || dispute.isIpTagged(payerIpId))
            revert Errors.RoyaltyModule__IpIsTagged();

        address payerRoyaltyPolicy = $.royaltyPolicies[payerIpId];
        // if the payer does not have a royalty policy set, then the payer is not a derivative ip and does not pay
        // royalties while the receiver ip can have a zero royalty policy since that could mean it is an ip a root
        if (payerRoyaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();
        if (!$.isWhitelistedRoyaltyPolicy[payerRoyaltyPolicy])
            revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        if (LICENSE_REGISTRY.isExpiredNow(receiverIpId)) revert Errors.RoyaltyModule__IpIsExpired();

        IRoyaltyPolicy(payerRoyaltyPolicy).onRoyaltyPayment(msg.sender, receiverIpId, token, amount);

        emit RoyaltyPaid(receiverIpId, payerIpId, msg.sender, token, amount);
    }

    /// @notice Allows to pay the minting fee for a license
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param licenseRoyaltyPolicy The royalty policy of the license being minted
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payLicenseMintingFee(
        address receiverIpId,
        address payerAddress,
        address licenseRoyaltyPolicy,
        address token,
        uint256 amount
    ) external onlyLicensingModule {
        RoyaltyModuleStorage storage $ = _getRoyaltyModuleStorage();
        if (!$.isWhitelistedRoyaltyToken[token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();
        if (DISPUTE_MODULE.isIpTagged(receiverIpId)) revert Errors.RoyaltyModule__IpIsTagged();
        if (licenseRoyaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();
        if (!$.isWhitelistedRoyaltyPolicy[licenseRoyaltyPolicy])
            revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();
        if (LICENSE_REGISTRY.isExpiredNow(receiverIpId)) revert Errors.RoyaltyModule__IpIsExpired();

        IRoyaltyPolicy(licenseRoyaltyPolicy).onRoyaltyPayment(payerAddress, receiverIpId, token, amount);

        emit LicenseMintingFeePaid(receiverIpId, payerAddress, token, amount);
    }

    /// @notice Returns the licensing module address
    function licensingModule() external view returns (address) {
        return _getRoyaltyModuleStorage().licensingModule;
    }

    /// @notice Indicates if a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @return isWhitelisted True if the royalty policy is whitelisted
    function isWhitelistedRoyaltyPolicy(address royaltyPolicy) external view returns (bool) {
        return _getRoyaltyModuleStorage().isWhitelistedRoyaltyPolicy[royaltyPolicy];
    }

    /// @notice Indicates if a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @return isWhitelisted True if the royalty token is whitelisted
    function isWhitelistedRoyaltyToken(address token) external view returns (bool) {
        return _getRoyaltyModuleStorage().isWhitelistedRoyaltyToken[token];
    }

    /// @notice Indicates the royalty policy for a given IP asset
    /// @param ipId The ID of IP asset
    /// @return royaltyPolicy The address of the royalty policy
    function royaltyPolicies(address ipId) external view returns (address) {
        return _getRoyaltyModuleStorage().royaltyPolicies[ipId];
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IRoyaltyModule).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of RoyaltyModule.
    function _getRoyaltyModuleStorage() private pure returns (RoyaltyModuleStorage storage $) {
        assembly {
            $.slot := RoyaltyModuleStorageLocation
        }
    }
}



/// @title AccessControlled
/// @notice Provides a base contract for access control functionalities.
/// @dev This abstract contract implements basic access control mechanisms with an emphasis
/// on IP account verification and permission checks.
/// It is designed to be used as a base contract for other contracts that require access control.
/// It provides modifiers and functions to verify if the caller has the necessary permission
/// and is a registered IP account.
abstract contract AccessControlled {
    using IPAccountChecker for IIPAccountRegistry;

    /// @notice The IAccessController instance for permission checks.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IAccessController public immutable ACCESS_CONTROLLER;
    /// @notice The IIPAccountRegistry instance for IP account verification.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IIPAccountRegistry public immutable IP_ACCOUNT_REGISTRY;

    /// @notice Verifies that the caller has the necessary permission for the given IPAccount.
    /// @dev Modifier that calls _verifyPermission to check if the provided IP account has the required permission.
    /// modules can use this modifier to check if the caller has the necessary permission.
    /// @param ipAccount The address of the IP account to verify.
    modifier verifyPermission(address ipAccount) {
        _verifyPermission(ipAccount);
        _;
    }

    /// @notice Ensures that the caller is a registered IP account.
    /// @dev Modifier that checks if the msg.sender is a registered IP account.
    /// modules can use this modifier to check if the caller is a registered IP account.
    /// so that enforce only registered IP Account can call the functions.
    modifier onlyIpAccount() {
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(msg.sender)) {
            revert Errors.AccessControlled__CallerIsNotIpAccount(msg.sender);
        }
        _;
    }

    /// @dev Constructor
    /// @param accessController The address of the AccessController contract.
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address accessController, address ipAccountRegistry) {
        if (accessController == address(0)) revert Errors.AccessControlled__ZeroAddress();
        if (ipAccountRegistry == address(0)) revert Errors.AccessControlled__ZeroAddress();
        ACCESS_CONTROLLER = IAccessController(accessController);
        IP_ACCOUNT_REGISTRY = IIPAccountRegistry(ipAccountRegistry);
    }

    /// @dev Internal function to verify if the caller (msg.sender) has the required permission to execute
    /// the function on provided ipAccount.
    /// @param ipAccount The address of the IP account to verify.
    function _verifyPermission(address ipAccount) internal view {
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(ipAccount)) {
            revert Errors.AccessControlled__NotIpAccount(ipAccount);
        }

        if (msg.sender != ipAccount) {
            // revert if the msg.sender does not have permission
            ACCESS_CONTROLLER.checkPermission(ipAccount, msg.sender, address(this), msg.sig);
        }
    }

    /// @dev Internal function to check if the caller (msg.sender) has the required permission to execute
    /// the function on provided ipAccount, returning a boolean.
    /// @param ipAccount The address of the IP account to check.
    /// @return bool Returns true if the caller has permission, false otherwise.
    function _hasPermission(address ipAccount) internal view returns (bool) {
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(ipAccount)) {
            return false;
        }

        if (msg.sender == ipAccount) {
            return true;
        }

        try ACCESS_CONTROLLER.checkPermission(ipAccount, msg.sender, address(this), msg.sig) {
            return true;
        } catch {
            return false;
        }
    }
}



/// @title IMintingFeeModule
/// @notice This interface is used to determine the minting fee of a license token.
/// IP owners can configure the MintingFeeModule to a specific license terms or all licenses of an IP Asset.
/// When someone calls the `mintLicenseTokens` function of LicensingModule, the LicensingModule will check whether
/// the license term or IP Asset has been configured with this module. If so, LicensingModule will call this module
/// to determine the minting fee of the license token.
/// @dev Developers can create a contract that implements this interface to implement various algorithms to determine
/// the minting price,
/// for example, a bonding curve formula. This allows IP owners to configure the module to hook into the LicensingModule
/// when minting a license token.
interface IMintingFeeModule is IModule {
    /// @notice Calculates the total minting fee for a given amount of license tokens.
    /// @param ipId The IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param amount The amount of license tokens to mint.
    /// @return The total minting fee.
    function getMintingFee(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) external view returns (uint256);
}

/// @notice Hook Module Interface
interface IHookModule is IModule {
    /// @notice Verify if the caller can pass the hook
    /// @param caller The address of the caller
    /// @param data The arbitrary data to be verified
    /// @return bool Whether or not the caller has passed the hook's verification
    function verify(address caller, bytes calldata data) external returns (bool);

    /// @notice Validates the configuration for the hook.
    /// @param configData The configuration data for the hook.
    function validateConfig(bytes calldata configData) external view;
}


/// @title Licensing Module
/// @notice Licensing module is the main entry point for the licensing system. It is responsible for:
/// - Attaching license terms to IP assets
/// - Minting license Tokens
/// - Registering derivatives
contract LicensingModule_V1_0_0 is
    AccessControlled,
    ILicensingModule,
    BaseModule,
    ReentrancyGuardUpgradeable,
    ProtocolPausableUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

    /// @inheritdoc IModule
    string public constant override name = LICENSING_MODULE_KEY;

    /// @notice Returns the canonical protocol-wide RoyaltyModule
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    RoyaltyModule_V1_0_0 public immutable ROYALTY_MODULE;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Returns the protocol-wide dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @notice Returns the License NFT
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseToken public immutable LICENSE_NFT;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicensingModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicensingModuleStorageLocation =
        0x0f7178cb62e4803c52d40f70c08a6f88d6ee1af1838d58e0c83a222a6c3d3100;

    /// Constructor
    /// @param accessController The address of the AccessController contract
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract
    /// @param royaltyModule The address of the RoyaltyModule contract
    /// @param registry The address of the LicenseRegistry contract
    /// @param disputeModule The address of the DisputeModule contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address royaltyModule,
        address registry,
        address disputeModule,
        address licenseToken
    ) AccessControlled(accessController, ipAccountRegistry) {
        ROYALTY_MODULE = RoyaltyModule_V1_0_0(royaltyModule);
        LICENSE_REGISTRY = ILicenseRegistry(registry);
        DISPUTE_MODULE = IDisputeModule(disputeModule);
        LICENSE_NFT = ILicenseToken(licenseToken);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.LicensingModule__ZeroAccessManager();
        }
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __ProtocolPausable_init(accessManager);
    }

    /// @notice Attaches license terms to an IP.
    /// the function must be called by the IP owner or an authorized operator.
    /// @param ipId The IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    function attachLicenseTerms(
        address ipId,
        address licenseTemplate,
        uint256 licenseTermsId
    ) external verifyPermission(ipId) {
        _verifyIpNotDisputed(ipId);
        LICENSE_REGISTRY.attachLicenseTermsToIp(ipId, licenseTemplate, licenseTermsId);
        emit LicenseTermsAttached(msg.sender, ipId, licenseTemplate, licenseTermsId);
    }

    /// @notice Mints license tokens for the license terms attached to an IP.
    /// The license tokens are minted to the receiver.
    /// The license terms must be attached to the IP before calling this function.
    /// But it can mint license token of default license terms without attaching the default license terms,
    /// since it is attached to all IPs by default.
    /// IP owners can mint license tokens for their IPs for arbitrary license terms
    /// without attaching the license terms to IP.
    /// It might require the caller pay the minting fee, depending on the license terms or configured by the iP owner.
    /// The minting fee is paid in the minting fee token specified in the license terms or configured by the IP owner.
    /// IP owners can configure the minting fee of their IPs or
    /// configure the minting fee module to determine the minting fee.
    /// IP owners can configure the receiver check module to determine the receiver of the minted license tokens.
    /// @param licensorIpId The licensor IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver.
    /// @param royaltyContext The context of the royalty.
    /// @return startLicenseTokenId The start ID of the minted license tokens.
    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external whenNotPaused returns (uint256 startLicenseTokenId) {
        if (amount == 0) {
            revert Errors.LicensingModule__MintAmountZero();
        }
        if (receiver == address(0)) {
            revert Errors.LicensingModule__ReceiverZeroAddress();
        }

        _verifyIpNotDisputed(licensorIpId);

        Licensing.MintingLicenseConfig memory mlc = LICENSE_REGISTRY.verifyMintLicenseToken(
            licensorIpId,
            licenseTemplate,
            licenseTermsId,
            _hasPermission(licensorIpId)
        );
        if (mlc.receiverCheckModule != address(0)) {
            if (!IHookModule(mlc.receiverCheckModule).verify(receiver, mlc.receiverCheckData)) {
                revert Errors.LicensingModule__ReceiverCheckFailed(receiver);
            }
        }

        _payMintingFee(licensorIpId, licenseTemplate, licenseTermsId, amount, royaltyContext, mlc);

        if (!ILicenseTemplate(licenseTemplate).verifyMintLicenseToken(licenseTermsId, receiver, licensorIpId, amount)) {
            revert Errors.LicensingModule__LicenseDenyMintLicenseToken(licenseTemplate, licenseTermsId, licensorIpId);
        }

        startLicenseTokenId = LICENSE_NFT.mintLicenseTokens(
            licensorIpId,
            licenseTemplate,
            licenseTermsId,
            amount,
            msg.sender,
            receiver
        );

        emit LicenseTokensMinted(
            msg.sender,
            licensorIpId,
            licenseTemplate,
            licenseTermsId,
            amount,
            receiver,
            startLicenseTokenId
        );
    }

    /// @notice Registers a derivative directly with parent IP's license terms, without needing license tokens,
    /// and attaches the license terms of the parent IPs to the derivative IP.
    /// The license terms must be attached to the parent IP before calling this function.
    /// All IPs attached default license terms by default.
    /// The derivative IP owner must be the caller or an authorized operator.
    /// @dev The derivative IP is registered with license terms minted from the parent IP's license terms.
    /// @param childIpId The derivative IP ID.
    /// @param parentIpIds The parent IP IDs.
    /// @param licenseTermsIds The IDs of the license terms that the parent IP supports.
    /// @param licenseTemplate The address of the license template of the license terms Ids.
    /// @param royaltyContext The context of the royalty.
    function registerDerivative(
        address childIpId,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        bytes calldata royaltyContext
    ) external whenNotPaused nonReentrant verifyPermission(childIpId) {
        if (parentIpIds.length != licenseTermsIds.length) {
            revert Errors.LicensingModule__LicenseTermsLengthMismatch(parentIpIds.length, licenseTermsIds.length);
        }
        if (parentIpIds.length == 0) {
            revert Errors.LicensingModule__NoParentIp();
        }

        _verifyIpNotDisputed(childIpId);

        // Check the compatibility of all license terms (specified by 'licenseTermsIds') across all parent IPs.
        // All license terms must be compatible with each other.
        // Verify that the derivative IP is permitted under all license terms from the parent IPs.
        address childIpOwner = IIPAccount(payable(childIpId)).owner();
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        if (!lct.verifyRegisterDerivativeForAllParents(childIpId, parentIpIds, licenseTermsIds, childIpOwner)) {
            revert Errors.LicensingModule__LicenseNotCompatibleForDerivative(childIpId);
        }

        // Ensure none of the parent IPs have expired.
        // Confirm that each parent IP has the license terms attached as specified by 'licenseTermsIds'
        // or default license terms.
        // Ensure the derivative IP is not included in the list of parent IPs.
        // Validate that none of the parent IPs are disputed.
        // If any of the above conditions are not met, revert the transaction. If all conditions are met, proceed.
        // Attach all license terms from the parent IPs to the derivative IP.
        // Set the derivative IP as a derivative of the parent IPs.
        // Set the expiration timestamp for the derivative IP by invoking the license template to calculate
        // the earliest expiration time among all license terms.
        LICENSE_REGISTRY.registerDerivativeIp(childIpId, parentIpIds, licenseTemplate, licenseTermsIds);
        // Process the payment for the minting fee.
        (address commonRoyaltyPolicy, bytes[] memory royaltyDatas) = _payMintingFeeForAllParentIps(
            parentIpIds,
            licenseTermsIds,
            licenseTemplate,
            childIpOwner,
            royaltyContext
        );
        // emit event
        emit DerivativeRegistered(
            msg.sender,
            childIpId,
            new uint256[](0),
            parentIpIds,
            licenseTermsIds,
            licenseTemplate
        );

        if (commonRoyaltyPolicy != address(0)) {
            ROYALTY_MODULE.onLinkToParents(childIpId, commonRoyaltyPolicy, parentIpIds, royaltyDatas, royaltyContext);
        }
    }

    /// @notice Registers a derivative with license tokens.
    /// the derivative IP is registered with license tokens minted from the parent IP's license terms.
    /// the license terms of the parent IPs issued with license tokens are attached to the derivative IP.
    /// the caller must be the derivative IP owner or an authorized operator.
    /// @param childIpId The derivative IP ID.
    /// @param licenseTokenIds The IDs of the license tokens.
    /// @param royaltyContext The context of the royalty.
    function registerDerivativeWithLicenseTokens(
        address childIpId,
        uint256[] calldata licenseTokenIds,
        bytes calldata royaltyContext
    ) external nonReentrant whenNotPaused verifyPermission(childIpId) {
        if (licenseTokenIds.length == 0) {
            revert Errors.LicensingModule__NoLicenseToken();
        }

        // Ensure the license token has not expired.
        // Confirm that the license token has not been revoked.
        // Validate that the owner of the derivative IP is also the owner of the license tokens.
        address childIpOwner = IIPAccount(payable(childIpId)).owner();
        (address licenseTemplate, address[] memory parentIpIds, uint256[] memory licenseTermsIds) = LICENSE_NFT
            .validateLicenseTokensForDerivative(childIpId, childIpOwner, licenseTokenIds);

        _verifyIpNotDisputed(childIpId);

        // Verify that the derivative IP is permitted under all license terms from the parent IPs.
        // Check the compatibility of all licenses
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        if (!lct.verifyRegisterDerivativeForAllParents(childIpId, parentIpIds, licenseTermsIds, childIpOwner)) {
            revert Errors.LicensingModule__LicenseTokenNotCompatibleForDerivative(childIpId, licenseTokenIds);
        }

        // Verify that none of the parent IPs have expired.
        // Validate that none of the parent IPs are disputed.
        // Ensure that the derivative IP does not have any existing licenses attached.
        // Validate that the derivative IP is not included in the list of parent IPs.
        // Confirm that the derivative IP does not already have any parent IPs.
        // If any of the above conditions are not met, revert the transaction. If all conditions are met, proceed.
        // Attach all license terms from the parent IPs to the derivative IP.
        // Set the derivative IP as a derivative of the parent IPs.
        // Set the expiration timestamp for the derivative IP to match the earliest expiration time of
        // all license terms.
        LICENSE_REGISTRY.registerDerivativeIp(childIpId, parentIpIds, licenseTemplate, licenseTermsIds);

        // Confirm that the royalty policies defined in all license terms of the parent IPs are identical.
        address commonRoyaltyPolicy = address(0);
        bytes[] memory royaltyDatas = new bytes[](parentIpIds.length);
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            (address royaltyPolicy, bytes memory royaltyData, , ) = lct.getRoyaltyPolicy(licenseTermsIds[i]);
            royaltyDatas[i] = royaltyData;
            if (i == 0) {
                commonRoyaltyPolicy = royaltyPolicy;
            } else if (royaltyPolicy != commonRoyaltyPolicy) {
                revert Errors.LicensingModule__IncompatibleRoyaltyPolicy(royaltyPolicy, commonRoyaltyPolicy);
            }
        }

        // Notify the royalty module
        if (commonRoyaltyPolicy != address(0)) {
            ROYALTY_MODULE.onLinkToParents(childIpId, commonRoyaltyPolicy, parentIpIds, royaltyDatas, royaltyContext);
        }
        // burn license tokens
        LICENSE_NFT.burnLicenseTokens(childIpOwner, licenseTokenIds);
        emit DerivativeRegistered(
            msg.sender,
            childIpId,
            licenseTokenIds,
            parentIpIds,
            licenseTermsIds,
            licenseTemplate
        );
    }

    /// @dev pay minting fee for all parent IPs
    /// This function is called by registerDerivative
    /// It pays the minting fee for all parent IPs through the royalty module
    /// finally returns the common royalty policy and data for the parent IPs
    function _payMintingFeeForAllParentIps(
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds,
        address licenseTemplate,
        address childIpOwner,
        bytes calldata royaltyContext
    ) private returns (address commonRoyaltyPolicy, bytes[] memory royaltyDatas) {
        commonRoyaltyPolicy = address(0);
        royaltyDatas = new bytes[](licenseTermsIds.length);

        // pay minting fee for all parent IPs
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            uint256 lcId = licenseTermsIds[i];
            Licensing.MintingLicenseConfig memory mlc = LICENSE_REGISTRY.getMintingLicenseConfig(
                parentIpIds[i],
                licenseTemplate,
                lcId
            );
            // check childIpOwner is qualified with check receiver module
            if (mlc.receiverCheckModule != address(0)) {
                if (!IHookModule(mlc.receiverCheckModule).verify(childIpOwner, mlc.receiverCheckData)) {
                    revert Errors.LicensingModule__ReceiverCheckFailed(childIpOwner);
                }
            }
            (address royaltyPolicy, bytes memory royaltyData) = _payMintingFee(
                parentIpIds[i],
                licenseTemplate,
                lcId,
                1,
                royaltyContext,
                mlc
            );
            royaltyDatas[i] = royaltyData;
            // royaltyPolicy must be the same for all parent IPs and royaltyPolicy could be 0
            // Using the first royaltyPolicy as the commonRoyaltyPolicy, all other royaltyPolicy must be the same
            if (i == 0) {
                commonRoyaltyPolicy = royaltyPolicy;
            } else if (royaltyPolicy != commonRoyaltyPolicy) {
                revert Errors.LicensingModule__IncompatibleRoyaltyPolicy(royaltyPolicy, commonRoyaltyPolicy);
            }
        }
    }

    /// @dev pay minting fee for an parent IP
    /// This function is called by mintLicenseTokens and registerDerivative
    /// It initialize royalty module and pays the minting fee for the parent IP through the royalty module
    /// finally returns the royalty policy and data for the parent IP
    /// @param parentIpId The parent IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    /// @param amount The amount of license tokens to mint.
    /// @param royaltyContext The context of the royalty.
    /// @param mlc The minting license config
    /// @return royaltyPolicy The address of the royalty policy.
    /// @return royaltyData The data of the royalty policy.
    function _payMintingFee(
        address parentIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        bytes calldata royaltyContext,
        Licensing.MintingLicenseConfig memory mlc
    ) private returns (address royaltyPolicy, bytes memory royaltyData) {
        ILicenseTemplate lct = ILicenseTemplate(licenseTemplate);
        uint256 mintingFee = 0;
        address currencyToken = address(0);
        (royaltyPolicy, royaltyData, mintingFee, currencyToken) = lct.getRoyaltyPolicy(licenseTermsId);

        if (royaltyPolicy != address(0)) {
            ROYALTY_MODULE.onLicenseMinting(parentIpId, royaltyPolicy, royaltyData, royaltyContext);
            uint256 tmf = _getTotalMintingFee(mlc, parentIpId, licenseTemplate, licenseTermsId, mintingFee, amount);
            // pay minting fee
            if (tmf > 0) {
                ROYALTY_MODULE.payLicenseMintingFee(parentIpId, msg.sender, royaltyPolicy, currencyToken, tmf);
            }
        }
    }

    /// @dev get total minting fee
    /// There are 3 places to get the minting fee: license terms, MintingLicenseConfig, MintingFeeModule
    /// The order of priority is MintingFeeModule > MintingLicenseConfig >  > license terms
    /// @param mintingLicenseConfig The minting license config
    /// @param licensorIpId The licensor IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms.
    /// @param mintingFeeSetByLicenseTerms The minting fee set by the license terms.
    /// @param amount The amount of license tokens to mint.
    function _getTotalMintingFee(
        Licensing.MintingLicenseConfig memory mintingLicenseConfig,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 mintingFeeSetByLicenseTerms,
        uint256 amount
    ) private view returns (uint256) {
        if (!mintingLicenseConfig.isSet) return mintingFeeSetByLicenseTerms * amount;
        if (mintingLicenseConfig.mintingFeeModule == address(0)) return mintingLicenseConfig.mintingFee * amount;
        return
            IMintingFeeModule(mintingLicenseConfig.mintingFeeModule).getMintingFee(
                licensorIpId,
                licenseTemplate,
                licenseTermsId,
                amount
            );
    }

    /// @dev Verifies if the IP is disputed
    function _verifyIpNotDisputed(address ipId) private view {
        if (DISPUTE_MODULE.isIpTagged(ipId)) {
            revert Errors.LicensingModule__DisputedIpId();
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}


/// @title PILicenseTemplate Errors Library
/// @notice Library for all PILicenseTemplate related contract errors.
library PILicenseTemplateErrors {
    /// @notice Zero address provided for Access Manager at initialization.
    error PILicenseTemplate__ZeroAccessManager();

    /// @notice Cannot add commercializers when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddCommercializers();

    /// @notice Provided commercializer does not support IHookModule.
    error PILicenseTemplate__CommercializerCheckerDoesNotSupportHook(address checker);

    /// @notice PIL terms royalty policy is not whitelisted by the Royalty Module.
    error PILicenseTemplate__RoyaltyPolicyNotWhitelisted();

    /// @notice PIL terms currency token is not whitelisted by the Royalty Module.
    error PILicenseTemplate__CurrencyTokenNotWhitelisted();

    /// @notice Royalty policy requires a currency token.
    error PILicenseTemplate__RoyaltyPolicyRequiresCurrencyToken();

    /// @notice Cannot add commercial attribution when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddAttribution();

    /// @notice Cannot add commercial revenue share when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddRevShare();

    /// @notice Cannot add commercial royalty policy when commercial use is disabled.
    error PILicenseTemplate__CommercialDisabled_CantAddRoyaltyPolicy();

    /// @notice Royalty policy is required when commercial use is enabled.
    error PILicenseTemplate__CommercialEnabled_RoyaltyPolicyRequired();

    /// @notice Cannot add derivative attribution when derivative use is disabled.
    error PILicenseTemplate__DerivativesDisabled_CantAddAttribution();

    /// @notice Cannot add derivative approval when derivative use is disabled.
    error PILicenseTemplate__DerivativesDisabled_CantAddApproval();

    /// @notice Cannot add derivative reciprocal when derivative use is disabled.
    error PILicenseTemplate__DerivativesDisabled_CantAddReciprocal();
}



/// @notice This struct defines the terms for a Programmable IP License (PIL).
/// These terms can be attached to IP Assets. The legal document of the PIL can be found in this repository.
/// @param transferable Indicates whether the license is transferable or not.
/// @param royaltyPolicy The address of the royalty policy contract which required to StoryProtocol in advance.
/// @param mintingFee The fee to be paid when minting a license.
/// @param expiration The expiration period of the license.
/// @param commercialUse Indicates whether the work can be used commercially or not.
/// @param commercialAttribution whether attribution is required when reproducing the work commercially or not.
/// @param commercializerChecker commercializers that are allowed to commercially exploit the work. If zero address,
/// then no restrictions is enforced.
/// @param commercializerCheckerData The data to be passed to the commercializer checker contract.
/// @param commercialRevShare Percentage of revenue that must be shared with the licensor.
/// @param commercialRevCelling The maximum revenue that can be generated from the commercial use of the work.
/// @param derivativesAllowed Indicates whether the licensee can create derivatives of his work or not.
/// @param derivativesAttribution Indicates whether attribution is required for derivatives of the work or not.
/// @param derivativesApproval Indicates whether the licensor must approve derivatives of the work before they can be
/// linked to the licensor IP ID or not.
/// @param derivativesReciprocal Indicates whether the licensee must license derivatives of the work under the
/// same terms or not.
/// @param derivativeRevCelling The maximum revenue that can be generated from the derivative use of the work.
/// @param currency The ERC20 token to be used to pay the minting fee. the token must be registered in story protocol.
/// @param uri The URI of the license terms, which can be used to fetch the offchain license terms.
struct PILTerms {
    bool transferable;
    address royaltyPolicy;
    uint256 mintingFee;
    uint256 expiration;
    bool commercialUse;
    bool commercialAttribution;
    address commercializerChecker;
    bytes commercializerCheckerData;
    uint32 commercialRevShare;
    uint256 commercialRevCelling;
    bool derivativesAllowed;
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint256 derivativeRevCelling;
    address currency;
    string uri;
}

/// @title IPILicenseTemplate
/// @notice This interface defines the methods for a Programmable IP License (PIL) template.
/// The PIL template is used to generate PIL terms that can be attached to IP Assets.
/// The legal document of the PIL can be found in this repository.
interface IPILicenseTemplate is ILicenseTemplate {
    /// @notice Registers new license terms.
    /// @param terms The PILTerms to register.
    /// @return selectedLicenseTermsId The ID of the newly registered license terms.
    function registerLicenseTerms(PILTerms calldata terms) external returns (uint256 selectedLicenseTermsId);

    /// @notice Gets the ID of the given license terms.
    /// @param terms The PILTerms to get the ID for.
    /// @return selectedLicenseTermsId The ID of the given license terms.
    function getLicenseTermsId(PILTerms calldata terms) external view returns (uint256 selectedLicenseTermsId);

    /// @notice Gets license terms of the given ID.
    /// @param selectedLicenseTermsId The ID of the license terms.
    /// @return terms The PILTerms associate with the given ID.
    function getLicenseTerms(uint256 selectedLicenseTermsId) external view returns (PILTerms memory terms);
}



// contracts

abstract contract BaseLicenseTemplateUpgradeable is ILicenseTemplate, ERC165, Initializable {
    /// @dev Storage structure for the BaseLicenseTemplateUpgradeable
    /// @custom:storage-location erc7201:story-protocol.BaseLicenseTemplateUpgradeable
    struct BaseLicenseTemplateUpgradeableStorage {
        string name;
        string metadataURI;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.BaseLicenseTemplateUpgradeable")) - 1)) &
    // ~bytes32(uint256(0xff));
    bytes32 private constant BaseLicenseTemplateUpgradeableStorageLocation =
        0x96c2f019b095cfe7c4d1f26aa9d2741961fe73294777688374a3299707c2fb00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param _name The name of the license template
    /// @param _metadataURI The URL to the off chain metadata
    function __BaseLicenseTemplate_init(string memory _name, string memory _metadataURI) internal onlyInitializing {
        _getBaseLicenseTemplateUpgradeableStorage().name = _name;
        _getBaseLicenseTemplateUpgradeableStorage().metadataURI = _metadataURI;
    }

    /// @notice Returns the name of the license template
    function name() public view override returns (string memory) {
        return _getBaseLicenseTemplateUpgradeableStorage().name;
    }

    /// @notice Returns the URL to the off chain metadata
    function getMetadataURI() public view override returns (string memory) {
        return _getBaseLicenseTemplateUpgradeableStorage().metadataURI;
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(ILicenseTemplate).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev Returns the storage struct of BaseLicenseTemplateUpgradeable.
    function _getBaseLicenseTemplateUpgradeableStorage()
        private
        pure
        returns (BaseLicenseTemplateUpgradeableStorage storage $)
    {
        assembly {
            $.slot := BaseLicenseTemplateUpgradeableStorageLocation
        }
    }
}


/// @title LicensorApprovalChecker
/// @notice Manages the approval of derivative IP accounts by the parentIp. Used to verify
/// licensing terms like "Derivatives With Approval" in PIL.
abstract contract LicensorApprovalChecker is AccessControlled, Initializable {
    /// @notice Emits when a derivative IP account is approved by the parentIp.
    /// @param licenseTermsId The ID of the license waiting for approval
    /// @param ipId The ID of the derivative IP to be approved
    /// @param caller The executor of the approval
    /// @param approved Result of the approval
    event DerivativeApproved(
        uint256 indexed licenseTermsId,
        address indexed ipId,
        address indexed caller,
        bool approved
    );

    /// @notice Storage for derivative IP approvals.
    /// @param approvals Approvals for derivative IP.
    /// @dev License Id => parentIpId => childIpId => approved
    /// @custom:storage-location erc7201:story-protocol.LicensorApprovalChecker
    struct LicensorApprovalCheckerStorage {
        mapping(uint256 => mapping(address => mapping(address => bool))) approvals;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicensorApprovalChecker")) - 1))
    // & ~bytes32(uint256(0xff));
    bytes32 private constant LicensorApprovalCheckerStorageLocation =
        0x7a71306cccadc52d66a0a466930bd537acf0ba900f21654919d58cece4cf9500;

    /// @notice Constructor function
    /// @param accessController The address of the AccessController contract
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {}

    /// @notice Approves or disapproves a derivative IP account.
    /// @param parentIpId The ID of the parent IP grant the approval
    /// @param licenseTermsId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function setApproval(address parentIpId, uint256 licenseTermsId, address childIpId, bool approved) external {
        _setApproval(parentIpId, licenseTermsId, childIpId, approved);
    }

    /// @notice Checks if a derivative IP account is approved by the parent.
    /// @param licenseTermsId The ID of the license NFT issued from a policy of the parent
    /// @param childIpId The ID of the derivative IP to be approved
    /// @return approved True if the derivative IP account using the license is approved
    function isDerivativeApproved(
        address parentIpId,
        uint256 licenseTermsId,
        address childIpId
    ) public view returns (bool) {
        LicensorApprovalCheckerStorage storage $ = _getLicensorApprovalCheckerStorage();
        return $.approvals[licenseTermsId][parentIpId][childIpId];
    }

    /// @notice Sets the approval for a derivative IP account.
    /// @dev This function is only callable by the parent IP account.
    /// @param parentIpId The ID of the parent IP account
    /// @param licenseTermsId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function _setApproval(
        address parentIpId,
        uint256 licenseTermsId,
        address childIpId,
        bool approved
    ) internal verifyPermission(parentIpId) {
        LicensorApprovalCheckerStorage storage $ = _getLicensorApprovalCheckerStorage();
        $.approvals[licenseTermsId][parentIpId][childIpId] = approved;
        emit DerivativeApproved(licenseTermsId, parentIpId, msg.sender, approved);
    }

    /// @dev Returns the storage struct of LicensorApprovalChecker.
    function _getLicensorApprovalCheckerStorage() private pure returns (LicensorApprovalCheckerStorage storage $) {
        assembly {
            $.slot := LicensorApprovalCheckerStorageLocation
        }
    }
}

/// @title PILicenseTemplate
contract PILicenseTemplate_V1_0_0 is
    BaseLicenseTemplateUpgradeable,
    IPILicenseTemplate,
    LicensorApprovalChecker,
    AccessManagedUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using Strings for *;

    /// @dev Storage structure for the PILicenseTemplate
    /// @custom:storage-location erc7201:story-protocol.PILicenseTemplate
    struct PILicenseTemplateStorage {
        mapping(uint256 licenseTermsId => PILTerms) licenseTerms;
        mapping(bytes32 licenseTermsHash => uint256 licenseTermsId) hashedLicenseTerms;
        uint256 licenseTermsCounter;
    }

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.PILicenseTemplate")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant PILicenseTemplateStorageLocation =
        0xc6c6991297bc120d0383f0017fab72b8ca34fd4849ed6478dbaac67a33c3a700;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address licenseRegistry,
        address royaltyModule
    ) LicensorApprovalChecker(accessController, ipAccountRegistry) {
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    /// @param name The name of the license template
    /// @param metadataURI The URL to the off chain metadata
    function initialize(address accessManager, string memory name, string memory metadataURI) external initializer {
        if (accessManager == address(0)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__ZeroAccessManager();
        }
        __BaseLicenseTemplate_init(name, metadataURI);
        __AccessManaged_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Registers new license terms and return the ID of the newly registered license terms.
    /// @dev The license terms are hashed and the hash is used to check if the terms are already registered.
    /// It will return existing ID if the terms are already registered.
    /// @param terms The PILTerms to register.
    /// @return id The ID of the newly registered license terms.
    function registerLicenseTerms(PILTerms calldata terms) external nonReentrant returns (uint256 id) {
        if (terms.royaltyPolicy != address(0) && !ROYALTY_MODULE.isWhitelistedRoyaltyPolicy(terms.royaltyPolicy)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__RoyaltyPolicyNotWhitelisted();
        }

        if (terms.currency != address(0) && !ROYALTY_MODULE.isWhitelistedRoyaltyToken(terms.currency)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__CurrencyTokenNotWhitelisted();
        }

        if (terms.royaltyPolicy != address(0) && terms.currency == address(0)) {
            revert PILicenseTemplateErrors.PILicenseTemplate__RoyaltyPolicyRequiresCurrencyToken();
        }

        _verifyCommercialUse(terms);
        _verifyDerivatives(terms);

        bytes32 hashedLicense = keccak256(abi.encode(terms));
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        id = $.hashedLicenseTerms[hashedLicense];
        // license id start from 1
        if (id != 0) {
            return id;
        }
        id = ++$.licenseTermsCounter;
        $.licenseTerms[id] = terms;
        $.hashedLicenseTerms[hashedLicense] = id;

        emit LicenseTermsRegistered(id, address(this), abi.encode(terms));
    }

    /// @notice Checks if a license terms exists.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms exists, false otherwise.
    function exists(uint256 licenseTermsId) external view override returns (bool) {
        return licenseTermsId <= _getPILicenseTemplateStorage().licenseTermsCounter;
    }

    /// @notice Verifies the minting of a license token.
    /// @dev the function will be called by the LicensingModule when minting a license token to
    /// verify the minting is whether allowed by the license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee who will receive the license token.
    /// @param licensorIpId The IP ID of the licensor who attached the license terms minting the license token.
    /// @return True if the minting is verified, false otherwise.
    function verifyMintLicenseToken(
        uint256 licenseTermsId,
        address licensee,
        address licensorIpId,
        uint256
    ) external override nonReentrant returns (bool) {
        PILTerms memory terms = _getPILicenseTemplateStorage().licenseTerms[licenseTermsId];
        // If the policy defines no reciprocal derivatives are allowed (no derivatives of derivatives),
        // and we are mintingFromADerivative we don't allow minting
        if (LICENSE_REGISTRY.isDerivativeIp(licensorIpId)) {
            if (!LICENSE_REGISTRY.hasIpAttachedLicenseTerms(licensorIpId, address(this), licenseTermsId)) {
                return false;
            }
            if (!terms.derivativesReciprocal) {
                return false;
            }
        }

        if (terms.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(terms.commercializerChecker).verify(licensee, terms.commercializerCheckerData)) {
                return false;
            }
        }

        return true;
    }

    /// @notice Verifies the registration of a derivative.
    /// @dev This function is invoked by the LicensingModule during the registration of a derivative work
    //// to ensure compliance with the parent IP's licensing terms.
    /// It verifies whether the derivative's registration is permitted under those terms.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpId The IP ID of the parent.
    /// @param licenseTermsId The ID of the license terms.
    /// @param licensee The address of the licensee.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivative(
        address childIpId,
        address parentIpId,
        uint256 licenseTermsId,
        address licensee
    ) external override returns (bool) {
        return _verifyRegisterDerivative(childIpId, parentIpId, licenseTermsId, licensee);
    }

    /// @notice Verifies if the licenses are compatible.
    /// @dev This function is called by the LicensingModule to verify license compatibility
    /// when registering a derivative IP to multiple parent IPs.
    /// It ensures that the licenses of all parent IPs are compatible with each other during the registration process.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return True if the licenses are compatible, false otherwise.
    function verifyCompatibleLicenses(uint256[] calldata licenseTermsIds) external view override returns (bool) {
        return _verifyCompatibleLicenseTerms(licenseTermsIds);
    }

    /// @notice Verifies the registration of a derivative for all parent IPs.
    /// @dev This function is called by the LicensingModule to verify licenses for registering a derivative IP
    /// to multiple parent IPs.
    /// the function will verify the derivative for each parent IP's license and
    /// also verify all licenses are compatible.
    /// @param childIpId The IP ID of the derivative.
    /// @param parentIpIds The IP IDs of the parents.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @param childIpOwner The address of the derivative IP owner.
    /// @return True if the registration is verified, false otherwise.
    function verifyRegisterDerivativeForAllParents(
        address childIpId,
        address[] calldata parentIpIds,
        uint256[] calldata licenseTermsIds,
        address childIpOwner
    ) external override returns (bool) {
        if (!_verifyCompatibleLicenseTerms(licenseTermsIds)) {
            return false;
        }
        for (uint256 i = 0; i < licenseTermsIds.length; i++) {
            if (!_verifyRegisterDerivative(childIpId, parentIpIds[i], licenseTermsIds[i], childIpOwner)) {
                return false;
            }
        }
        return true;
    }

    /// @notice Returns the royalty policy of a license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @return royaltyPolicy The address of the royalty policy specified for the license terms.
    /// @return royaltyData The data of the royalty policy.
    /// @return mintingFee The fee for minting a license.
    /// @return currency The address of the ERC20 token, used for minting license fee and royalties.
    /// the currency token will used for pay for license token minting fee and royalties.
    function getRoyaltyPolicy(
        uint256 licenseTermsId
    ) external view returns (address royaltyPolicy, bytes memory royaltyData, uint256 mintingFee, address currency) {
        PILTerms memory terms = _getPILicenseTemplateStorage().licenseTerms[licenseTermsId];
        return (terms.royaltyPolicy, abi.encode(terms.commercialRevShare), terms.mintingFee, terms.currency);
    }

    /// @notice Checks if a license terms is transferable.
    /// @param licenseTermsId The ID of the license terms.
    /// @return True if the license terms is transferable, false otherwise.
    function isLicenseTransferable(uint256 licenseTermsId) external view override returns (bool) {
        return _getPILicenseTemplateStorage().licenseTerms[licenseTermsId].transferable;
    }

    /// @notice Returns the earliest expiration time among the given license terms.
    /// @param start The start time.
    /// @param licenseTermsIds The IDs of the license terms.
    /// @return The earliest expiration time.
    function getEarlierExpireTime(
        uint256[] calldata licenseTermsIds,
        uint256 start
    ) external view override returns (uint256) {
        if (licenseTermsIds.length == 0) {
            return 0;
        }
        uint expireTime = _getExpireTime(licenseTermsIds[0], start);
        for (uint i = 1; i < licenseTermsIds.length; i++) {
            uint newExpireTime = _getExpireTime(licenseTermsIds[i], start);
            if (newExpireTime < expireTime || expireTime == 0) {
                expireTime = newExpireTime;
            }
        }
        return expireTime;
    }

    /// @notice Returns the expiration time of a license terms.
    /// @param start The start time.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The expiration time.
    function getExpireTime(uint256 licenseTermsId, uint256 start) external view returns (uint256) {
        return _getExpireTime(licenseTermsId, start);
    }

    /// @notice Gets the ID of the given license terms.
    /// @param terms The PILTerms to get the ID for.
    /// @return selectedLicenseTermsId The ID of the given license terms.
    function getLicenseTermsId(PILTerms calldata terms) external view returns (uint256 selectedLicenseTermsId) {
        return _getPILicenseTemplateStorage().hashedLicenseTerms[keccak256(abi.encode(terms))];
    }

    /// @notice Gets license terms of the given ID.
    /// @param selectedLicenseTermsId The ID of the license terms.
    /// @return terms The PILTerms associate with the given ID.
    function getLicenseTerms(uint256 selectedLicenseTermsId) external view returns (PILTerms memory terms) {
        return _getPILicenseTemplateStorage().licenseTerms[selectedLicenseTermsId];
    }

    /// @notice Returns the URI of the license terms.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The URI of the license terms.
    function getLicenseTermsURI(uint256 licenseTermsId) external view returns (string memory) {
        return _getPILicenseTemplateStorage().licenseTerms[licenseTermsId].uri;
    }

    /// @notice Returns the total number of registered license terms.
    /// @return The total number of registered license terms.
    function totalRegisteredLicenseTerms() external view returns (uint256) {
        return _getPILicenseTemplateStorage().licenseTermsCounter;
    }

    /// @notice checks the contract whether supports the given interface.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(BaseLicenseTemplateUpgradeable, IERC165) returns (bool) {
        return interfaceId == type(IPILicenseTemplate).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Converts the license terms to a JSON string which will be part of the metadata of license token.
    /// @dev Must return OpenSea standard compliant metadata.
    /// @param licenseTermsId The ID of the license terms.
    /// @return The JSON string of the license terms, follow the OpenSea metadata standard.
    function toJson(uint256 licenseTermsId) public view returns (string memory) {
        PILTerms memory terms = _getPILicenseTemplateStorage().licenseTerms[licenseTermsId];

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata.
        // **Attributions**
        string memory json = string(
            abi.encodePacked(
                '{"trait_type": "Expiration", "value": "',
                terms.expiration == 0 ? "never" : terms.expiration.toString(),
                '"},',
                '{"trait_type": "Currency", "value": "',
                terms.currency.toHexString(),
                '"},',
                '{"trait_type": "URI", "value": "',
                terms.uri,
                '"},',
                // Skip transferable, it's already added in the common attributes by the LicenseRegistry.
                _policyCommercialTraitsToJson(terms),
                _policyDerivativeTraitsToJson(terms)
            )
        );

        // NOTE: (above) last trait added by LicenseTemplate should have a comma at the end.

        /* solhint-enable */

        return json;
    }

    /// @dev Encodes the commercial traits of PIL policy into a JSON string for OpenSea
    function _policyCommercialTraitsToJson(PILTerms memory terms) internal pure returns (string memory) {
        /* solhint-disable */
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Commercial Use", "value": "',
                    terms.commercialUse ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Attribution", "value": "',
                    terms.commercialAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": ',
                    terms.commercialRevShare.toString(),
                    "},",
                    '{"trait_type": "Commercial Revenue Celling", "value": ',
                    terms.commercialRevCelling.toString(),
                    "},",
                    '{"trait_type": "Commercializer Check", "value": "',
                    terms.commercializerChecker.toHexString(),
                    // Skip on commercializerCheckerData as it's bytes as irrelevant for the user metadata
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Encodes the derivative traits of PILTerm into a JSON string for OpenSea
    function _policyDerivativeTraitsToJson(PILTerms memory terms) internal pure returns (string memory) {
        /* solhint-disable */
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Derivatives Allowed", "value": "',
                    terms.derivativesAllowed ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Attribution", "value": "',
                    terms.derivativesAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Revenue Celling", "value": ',
                    terms.derivativeRevCelling.toString(),
                    "},",
                    '{"trait_type": "Derivatives Approval", "value": "',
                    terms.derivativesApproval ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Reciprocal", "value": "',
                    terms.derivativesReciprocal ? "true" : "false",
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Checks the configuration of commercial use and throws if the policy is not compliant
    // solhint-disable-next-line code-complexity
    function _verifyCommercialUse(PILTerms calldata terms) internal view {
        if (!terms.commercialUse) {
            if (terms.commercialAttribution) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddAttribution();
            }
            if (terms.commercializerChecker != address(0)) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddCommercializers();
            }
            if (terms.commercialRevShare > 0) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddRevShare();
            }
            if (terms.royaltyPolicy != address(0)) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialDisabled_CantAddRoyaltyPolicy();
            }
        } else {
            if (terms.royaltyPolicy == address(0)) {
                revert PILicenseTemplateErrors.PILicenseTemplate__CommercialEnabled_RoyaltyPolicyRequired();
            }
            if (terms.commercializerChecker != address(0)) {
                if (!terms.commercializerChecker.supportsInterface(type(IHookModule).interfaceId)) {
                    revert PILicenseTemplateErrors.PILicenseTemplate__CommercializerCheckerDoesNotSupportHook(
                        terms.commercializerChecker
                    );
                }
                IHookModule(terms.commercializerChecker).validateConfig(terms.commercializerCheckerData);
            }
        }
    }

    /// @dev notice Checks the configuration of derivative parameters and throws if the policy is not compliant
    function _verifyDerivatives(PILTerms calldata terms) internal pure {
        if (!terms.derivativesAllowed) {
            if (terms.derivativesAttribution) {
                revert PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddAttribution();
            }
            if (terms.derivativesApproval) {
                revert PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddApproval();
            }
            if (terms.derivativesReciprocal) {
                revert PILicenseTemplateErrors.PILicenseTemplate__DerivativesDisabled_CantAddReciprocal();
            }
        }
    }

    /// @dev Verifies derivative IP permitted by license terms during process of the registration of a derivative.
    function _verifyRegisterDerivative(
        address childIpId,
        address parentIpId,
        uint256 licenseTermsId,
        address licensee
    ) internal returns (bool) {
        PILTerms memory terms = _getPILicenseTemplateStorage().licenseTerms[licenseTermsId];

        if (!terms.derivativesAllowed) {
            return false;
        }

        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (terms.derivativesApproval && !isDerivativeApproved(parentIpId, licenseTermsId, childIpId)) {
            return false;
        }
        // Check if the commercializerChecker allows the link
        if (terms.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(terms.commercializerChecker).verify(licensee, terms.commercializerCheckerData)) {
                return false;
            }
        }
        return true;
    }

    /// @dev Verifies if the license terms are compatible.
    function _verifyCompatibleLicenseTerms(uint256[] calldata licenseTermsIds) internal view returns (bool) {
        if (licenseTermsIds.length < 2) return true;
        PILicenseTemplateStorage storage $ = _getPILicenseTemplateStorage();
        bool commercial = $.licenseTerms[licenseTermsIds[0]].commercialUse;
        bool derivativesReciprocal = $.licenseTerms[licenseTermsIds[0]].derivativesReciprocal;
        for (uint256 i = 1; i < licenseTermsIds.length; i++) {
            if ($.licenseTerms[licenseTermsIds[i]].commercialUse != commercial) return false;
            if ($.licenseTerms[licenseTermsIds[i]].derivativesReciprocal != derivativesReciprocal) return false;
        }
        return true;
    }

    /// @dev Calculate and returns the expiration time based given start time and license terms.
    function _getExpireTime(uint256 licenseTermsId, uint256 start) internal view returns (uint) {
        PILTerms memory terms = _getPILicenseTemplateStorage().licenseTerms[licenseTermsId];
        if (terms.expiration == 0) {
            return 0;
        }
        return start + terms.expiration;
    }

    ////////////////////////////////////////////////////////////////////////////
    //                         Upgrades related                               //
    ////////////////////////////////////////////////////////////////////////////

    /// @dev Returns the storage struct of PILicenseTemplate.
    function _getPILicenseTemplateStorage() private pure returns (PILicenseTemplateStorage storage $) {
        assembly {
            $.slot := PILicenseTemplateStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}



// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}



// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/BeaconProxy.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/Proxy.sol)

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback
     * function and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }
}

/**
 * @dev This contract implements a proxy that gets the implementation address for each call from an {UpgradeableBeacon}.
 *
 * The beacon address can only be set once during construction, and cannot be changed afterwards. It is stored in an
 * immutable variable to avoid unnecessary storage reads, and also in the beacon storage slot specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] so that it can be accessed externally.
 *
 * CAUTION: Since the beacon address can never be changed, you must ensure that you either control the beacon, or trust
 * the beacon to not upgrade the implementation maliciously.
 *
 * IMPORTANT: Do not use the implementation logic to modify the beacon storage slot. Doing so would leave the proxy in
 * an inconsistent state where the beacon storage slot does not match the beacon address.
 */
contract BeaconProxy is Proxy {
    // An immutable address for the beacon to avoid unnecessary SLOADs before each delegate call.
    address private immutable _beacon;

    /**
     * @dev Initializes the proxy with `beacon`.
     *
     * If `data` is nonempty, it's used as data in a delegate call to the implementation returned by the beacon. This
     * will typically be an encoded function call, and allows initializing the storage of the proxy like a Solidity
     * constructor.
     *
     * Requirements:
     *
     * - `beacon` must be a contract with the interface {IBeacon}.
     * - If `data` is empty, `msg.value` must be zero.
     */
    constructor(address beacon, bytes memory data) payable {
        ERC1967Utils.upgradeBeaconToAndCall(beacon, data);
        _beacon = beacon;
    }

    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal view virtual override returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }

    /**
     * @dev Returns the beacon.
     */
    function _getBeacon() internal view virtual returns (address) {
        return _beacon;
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (proxy/beacon/UpgradeableBeacon.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev This contract is used in conjunction with one or more instances of {BeaconProxy} to determine their
 * implementation contract, which is where they will delegate all function calls.
 *
 * An owner is able to change the implementation the beacon points to, thus upgrading the proxies that use this beacon.
 */
contract UpgradeableBeacon is IBeacon, Ownable {
    address private _implementation;

    /**
     * @dev The `implementation` of the beacon is invalid.
     */
    error BeaconInvalidImplementation(address implementation);

    /**
     * @dev Emitted when the implementation returned by the beacon is changed.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Sets the address of the initial implementation, and the initial owner who can upgrade the beacon.
     */
    constructor(address implementation_, address initialOwner) Ownable(initialOwner) {
        _setImplementation(implementation_);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function implementation() public view virtual returns (address) {
        return _implementation;
    }

    /**
     * @dev Upgrades the beacon to a new implementation.
     *
     * Emits an {Upgraded} event.
     *
     * Requirements:
     *
     * - msg.sender must be the owner of the contract.
     * - `newImplementation` must be a contract.
     */
    function upgradeTo(address newImplementation) public virtual onlyOwner {
        _setImplementation(newImplementation);
    }

    /**
     * @dev Sets the implementation contract address for this beacon
     *
     * Requirements:
     *
     * - `newImplementation` must be a contract.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert BeaconInvalidImplementation(newImplementation);
        }
        _implementation = newImplementation;
        emit Upgraded(newImplementation);
    }
}


/// @title Liquid Absolute Percentage Royalty Policy
/// @notice Defines the logic for splitting royalties for a given ipId using a liquid absolute percentage mechanism
contract RoyaltyPolicyLAP_V1_0_0 is
    IRoyaltyPolicyLAP,
    ProtocolPausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /// @dev Storage structure for the RoyaltyPolicyLAP
    /// @param ipRoyaltyVaultBeacon The ip royalty vault beacon address
    /// @param snapshotInterval The minimum timestamp interval between snapshots
    /// @param royaltyData The royalty data for a given IP asset
    /// @custom:storage-location erc7201:story-protocol.RoyaltyPolicyLAP
    struct RoyaltyPolicyLAPStorage {
        address ipRoyaltyVaultBeacon;
        uint256 snapshotInterval;
        mapping(address ipId => LAPRoyaltyData) royaltyData;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.RoyaltyPolicyLAP")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant RoyaltyPolicyLAPStorageLocation =
        0x0c915ba68e2c4e37f19454bb13066f18f9db418fcefbf3c585b4b7d0fb0e0600;

    /// @notice Returns the percentage scale - represents 100% of royalty tokens for an ip
    uint32 public constant TOTAL_RT_SUPPLY = 100000000; // 100 * 10 ** 6

    /// @notice Returns the maximum number of parents
    uint256 public constant MAX_PARENTS = 2;

    /// @notice Returns the maximum number of total ancestors.
    /// @dev The IP derivative tree is limited to 14 ancestors, which represents 3 levels of a binary tree 14 = 2+4+8
    uint256 public constant MAX_ANCESTORS = 14;

    /// @notice Returns the RoyaltyModule address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable ROYALTY_MODULE;

    /// @notice Returns the LicensingModule address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable LICENSING_MODULE;

    /// @dev Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLAP__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param royaltyModule The RoyaltyModule address
    /// @param licensingModule The LicensingModule address
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address royaltyModule, address licensingModule) {
        if (royaltyModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroRoyaltyModule();
        if (licensingModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLicensingModule();

        ROYALTY_MODULE = royaltyModule;
        LICENSING_MODULE = licensingModule;
        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroAccessManager();
        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @dev Set the snapshot interval
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param timestampInterval The minimum timestamp interval between snapshots
    function setSnapshotInterval(uint256 timestampInterval) public restricted {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        $.snapshotInterval = timestampInterval;
    }

    /// @dev Set the ip royalty vault beacon
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param beacon The ip royalty vault beacon address
    function setIpRoyaltyVaultBeacon(address beacon) public restricted {
        if (beacon == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroIpRoyaltyVaultBeacon();
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        $.ipRoyaltyVaultBeacon = beacon;
    }

    /// @dev Upgrades the ip royalty vault beacon
    /// @dev Enforced to be only callable by the upgrader admin
    /// @param newVault The new ip royalty vault beacon address
    function upgradeVaults(address newVault) public restricted {
        // UpgradeableBeacon already checks for newImplementation.bytecode.length > 0,
        // no need to check for zero address
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        UpgradeableBeacon($.ipRoyaltyVaultBeacon).upgradeTo(newVault);
    }

    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address ipId,
        bytes calldata licenseData,
        bytes calldata externalData
    ) external onlyRoyaltyModule nonReentrant {
        uint32 newLicenseRoyalty = abi.decode(licenseData, (uint32));
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();

        LAPRoyaltyData memory data = $.royaltyData[ipId];

        if (data.royaltyStack + newLicenseRoyalty > TOTAL_RT_SUPPLY)
            revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        if (data.ipRoyaltyVault == address(0)) {
            // If the policy is already initialized, it means that the ipId setup is already done. If not, it means
            // that the license for this royalty policy is being minted for the first time parentIpIds are zero given
            // that only roots can call _initPolicy() for the first time in the function onLicenseMinting() while
            // derivatives already
            // called _initPolicy() when linking to their parents with onLinkToParents() call.
            _initPolicy(ipId, new address[](0), new bytes[](0));
        } else {
            // If the policy is already initialized and an ipId has the maximum number of ancestors
            // it can not have any derivative and therefore is not allowed to mint any license
            if (data.ancestorsAddresses.length >= MAX_ANCESTORS)
                revert Errors.RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense();
        }
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external onlyRoyaltyModule nonReentrant {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        if ($.royaltyData[ipId].isUnlinkableToParents) revert Errors.RoyaltyPolicyLAP__UnlinkableToParents();

        _initPolicy(ipId, parentIpIds, licenseData);
    }

    /// @notice Allows the caller to pay royalties to the given IP asset
    /// @param caller The caller is the address from which funds will transferred from
    /// @param ipId The ipId of the receiver of the royalties
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external onlyRoyaltyModule {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        address destination = $.royaltyData[ipId].ipRoyaltyVault;
        if (IIpRoyaltyVault(destination).addIpRoyaltyVaultTokens(token)) {
            emit RoyaltyTokenAddedToVault(token, destination);
        }
        IERC20(token).safeTransferFrom(caller, destination, amount);
    }

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ipId to get the royalty data for
    /// @return isUnlinkableToParents Indicates if the ipId is unlinkable to new parents
    /// @return ipRoyaltyVault The ip royalty vault address
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @return ancestorsAddresses The ancestors addresses array
    /// @return ancestorsRoyalties The ancestors royalties array
    function getRoyaltyData(
        address ipId
    ) external view returns (bool, address, uint32, address[] memory, uint32[] memory) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        LAPRoyaltyData memory data = $.royaltyData[ipId];
        return (
            data.isUnlinkableToParents,
            data.ipRoyaltyVault,
            data.royaltyStack,
            data.ancestorsAddresses,
            data.ancestorsRoyalties
        );
    }

    /// @notice Returns the snapshot interval
    /// @return snapshotInterval The minimum timestamp interval between snapshots
    function getSnapshotInterval() external view returns (uint256) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        return $.snapshotInterval;
    }

    /// @notice Returns the ip royalty vault beacon
    /// @return ipRoyaltyVaultBeacon The ip royalty vault beacon address
    function getIpRoyaltyVaultBeacon() external view returns (address) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        return $.ipRoyaltyVaultBeacon;
    }

    /// @dev Initializes the royalty policy for a given IP asset.
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The to initialize the policy for
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to (if any)
    /// @param licenseData The license data custom to each the royalty policy
    function _initPolicy(
        address ipId,
        address[] memory parentIpIds,
        bytes[] memory licenseData
    ) internal onlyRoyaltyModule {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        // decode license data
        uint32[] memory parentRoyalties = new uint32[](parentIpIds.length);
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            parentRoyalties[i] = abi.decode(licenseData[i], (uint32));
        }

        if (parentIpIds.length > MAX_PARENTS) revert Errors.RoyaltyPolicyLAP__AboveParentLimit();

        // calculate new royalty stack
        (
            uint32 royaltyStack,
            address[] memory newAncestors,
            uint32[] memory newAncestorsRoyalties
        ) = _getNewAncestorsData(parentIpIds, parentRoyalties);

        // set the parents as unlinkable / loop limited to 2 parents
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            $.royaltyData[parentIpIds[i]].isUnlinkableToParents = true;
        }

        // deploy ip royalty vault
        address ipRoyaltyVault = address(new BeaconProxy($.ipRoyaltyVaultBeacon, ""));
        IIpRoyaltyVault(ipRoyaltyVault).initialize("Royalty Token", "RT", TOTAL_RT_SUPPLY, royaltyStack, ipId);

        $.royaltyData[ipId] = LAPRoyaltyData({
            // whether calling via minting license or linking to parents the ipId becomes unlinkable
            isUnlinkableToParents: true,
            ipRoyaltyVault: ipRoyaltyVault,
            royaltyStack: royaltyStack,
            ancestorsAddresses: newAncestors,
            ancestorsRoyalties: newAncestorsRoyalties
        });

        emit PolicyInitialized(ipId, ipRoyaltyVault, royaltyStack, newAncestors, newAncestorsRoyalties);
    }

    /// @dev Gets the new ancestors data
    /// @param parentIpIds The parent ipIds
    /// @param parentRoyalties The parent royalties
    /// @return newRoyaltyStack The new royalty stack
    /// @return newAncestors The new ancestors
    /// @return newAncestorsRoyalty The new ancestors royalty
    function _getNewAncestorsData(
        address[] memory parentIpIds,
        uint32[] memory parentRoyalties
    ) internal view returns (uint32, address[] memory, uint32[] memory) {
        if (parentRoyalties.length != parentIpIds.length)
            revert Errors.RoyaltyPolicyLAP__InvalidParentRoyaltiesLength();

        (
            address[] memory newAncestors,
            uint32[] memory newAncestorsRoyalty,
            uint32 newAncestorsCount,
            uint32 newRoyaltyStack
        ) = _getExpectedOutputs(parentIpIds, parentRoyalties);

        if (newAncestorsCount > MAX_ANCESTORS) revert Errors.RoyaltyPolicyLAP__AboveAncestorsLimit();
        if (newRoyaltyStack > TOTAL_RT_SUPPLY) revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        return (newRoyaltyStack, newAncestors, newAncestorsRoyalty);
    }

    /// @dev Gets the expected outputs for the ancestors and ancestors royalties
    /// @param parentIpIds The parent ipIds
    /// @param parentRoyalties The parent royalties
    /// @return newAncestors The new ancestors
    /// @return newAncestorsRoyalty The new ancestors royalty
    /// @return ancestorsCount The number of ancestors
    /// @return royaltyStack The royalty stack
    // solhint-disable-next-line code-complexity
    function _getExpectedOutputs(
        address[] memory parentIpIds,
        uint32[] memory parentRoyalties
    )
        internal
        view
        returns (
            address[] memory newAncestors,
            uint32[] memory newAncestorsRoyalty,
            uint32 ancestorsCount,
            uint32 royaltyStack
        )
    {
        uint32[] memory newAncestorsRoyalty_ = new uint32[](MAX_ANCESTORS);
        address[] memory newAncestors_ = new address[](MAX_ANCESTORS);

        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            if (i == 0) {
                newAncestors_[ancestorsCount] = parentIpIds[i];
                newAncestorsRoyalty_[ancestorsCount] += parentRoyalties[i];
                royaltyStack += parentRoyalties[i];
                ancestorsCount++;
            } else if (i == 1) {
                (uint256 index, bool isIn) = ArrayUtils.indexOf(newAncestors_, parentIpIds[i]);
                if (!isIn) {
                    newAncestors_[ancestorsCount] = parentIpIds[i];
                    newAncestorsRoyalty_[ancestorsCount] += parentRoyalties[i];
                    royaltyStack += parentRoyalties[i];
                    ancestorsCount++;
                } else {
                    newAncestorsRoyalty_[index] += parentRoyalties[i];
                    royaltyStack += parentRoyalties[i];
                }
            }
            address[] memory parentAncestors = $.royaltyData[parentIpIds[i]].ancestorsAddresses;
            uint32[] memory parentAncestorsRoyalties = $.royaltyData[parentIpIds[i]].ancestorsRoyalties;

            for (uint256 j = 0; j < parentAncestors.length; j++) {
                if (i == 0) {
                    newAncestors_[ancestorsCount] = parentAncestors[j];
                    newAncestorsRoyalty_[ancestorsCount] += parentAncestorsRoyalties[j];
                    royaltyStack += parentAncestorsRoyalties[j];
                    ancestorsCount++;
                } else if (i == 1) {
                    (uint256 index, bool isIn) = ArrayUtils.indexOf(newAncestors_, parentAncestors[j]);
                    if (!isIn) {
                        newAncestors_[ancestorsCount] = parentAncestors[j];
                        newAncestorsRoyalty_[ancestorsCount] += parentAncestorsRoyalties[j];
                        royaltyStack += parentAncestorsRoyalties[j];
                        ancestorsCount++;
                    } else {
                        newAncestorsRoyalty_[index] += parentAncestorsRoyalties[j];
                        royaltyStack += parentAncestorsRoyalties[j];
                    }
                }
            }
        }

        // remove empty elements from each array
        newAncestors = new address[](ancestorsCount);
        newAncestorsRoyalty = new uint32[](ancestorsCount);
        for (uint256 k = 0; k < ancestorsCount; k++) {
            newAncestors[k] = newAncestors_[k];
            newAncestorsRoyalty[k] = newAncestorsRoyalty_[k];
        }
    }

    function _getRoyaltyPolicyLAPStorage() private pure returns (RoyaltyPolicyLAPStorage storage $) {
        assembly {
            $.slot := RoyaltyPolicyLAPStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}

/// @title IPAccount Storage
/// @dev Implements the IIPAccountStorage interface for managing IPAccount's state using a namespaced storage pattern.
/// Inherits all functionalities from IIPAccountStorage, providing concrete implementations for the interface's methods.
/// This contract allows Modules to store and retrieve data in a structured and conflict-free manner
/// by utilizing namespaces, where the default namespace is determined by the
/// `msg.sender` (the caller Module's address).
contract IPAccountStorage is ERC165, IIPAccountStorage {
    using ShortStrings for *;

    address public immutable MODULE_REGISTRY;
    address public immutable LICENSE_REGISTRY;
    address public immutable IP_ASSET_REGISTRY;

    mapping(bytes32 => mapping(bytes32 => bytes)) public bytesData;
    mapping(bytes32 => mapping(bytes32 => bytes32)) public bytes32Data;

    modifier onlyRegisteredModule() {
        if (
            msg.sender != IP_ASSET_REGISTRY &&
            msg.sender != LICENSE_REGISTRY &&
            !IModuleRegistry(MODULE_REGISTRY).isRegistered(msg.sender)
        ) {
            revert Errors.IPAccountStorage__NotRegisteredModule(msg.sender);
        }
        _;
    }

    constructor(address ipAssetRegistry, address licenseRegistry, address moduleRegistry) {
        MODULE_REGISTRY = moduleRegistry;
        LICENSE_REGISTRY = licenseRegistry;
        IP_ASSET_REGISTRY = ipAssetRegistry;
    }

    /// @inheritdoc IIPAccountStorage
    function setBytes(bytes32 key, bytes calldata value) external onlyRegisteredModule {
        bytesData[_toBytes32(msg.sender)][key] = value;
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes(bytes32 key) external view returns (bytes memory) {
        return bytesData[_toBytes32(msg.sender)][key];
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes(bytes32 namespace, bytes32 key) external view returns (bytes memory) {
        return bytesData[namespace][key];
    }

    /// @inheritdoc IIPAccountStorage
    function setBytes32(bytes32 key, bytes32 value) external onlyRegisteredModule {
        bytes32Data[_toBytes32(msg.sender)][key] = value;
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes32(bytes32 key) external view returns (bytes32) {
        return bytes32Data[_toBytes32(msg.sender)][key];
    }
    /// @inheritdoc IIPAccountStorage
    function getBytes32(bytes32 namespace, bytes32 key) external view returns (bytes32) {
        return bytes32Data[namespace][key];
    }

    /// @notice ERC165 interface identifier for IIPAccountStorage
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IIPAccountStorage).interfaceId || super.supportsInterface(interfaceId);
    }

    function _toBytes32(string memory s) internal pure returns (bytes32) {
        return ShortString.unwrap(s.toShortString());
    }

    function _toBytes32(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }
}


/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    /**
     * @dev The signature derives the `address(0)`.
     */
    error ECDSAInvalidSignature();

    /**
     * @dev The signature has an invalid length.
     */
    error ECDSAInvalidSignatureLength(uint256 length);

    /**
     * @dev The signature has an S value that is in the upper half order.
     */
    error ECDSAInvalidSignatureS(bytes32 s);

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with `signature` or an error. This will not
     * return address(0) without also returning an error description. Errors are documented using an enum (error type)
     * and a bytes32 providing additional information about the error.
     *
     * If no error is returned, then the address can be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError, bytes32) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength, bytes32(signature.length));
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM precompile allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {MessageHashUtils-toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, signature);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError, bytes32) {
        unchecked {
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            // We do not check for an overflow here since the shift operation results in 0 or 1.
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        }
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, r, vs);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError, bytes32) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS, s);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature, bytes32(0));
        }

        return (signer, RecoverError.NoError, bytes32(0));
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error, bytes32 errorArg) = tryRecover(hash, v, r, s);
        _throwError(error, errorArg);
        return recovered;
    }

    /**
     * @dev Optionally reverts with the corresponding custom error according to the `error` argument provided.
     */
    function _throwError(RecoverError error, bytes32 errorArg) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert ECDSAInvalidSignature();
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert ECDSAInvalidSignatureLength(uint256(errorArg));
        } else if (error == RecoverError.InvalidSignatureS) {
            revert ECDSAInvalidSignatureS(errorArg);
        }
    }
}

/**
 * @dev Signature message hash utilities for producing digests to be consumed by {ECDSA} recovery or signing.
 *
 * The library provides methods for generating a hash of a message that conforms to the
 * https://eips.ethereum.org/EIPS/eip-191[EIP 191] and https://eips.ethereum.org/EIPS/eip-712[EIP 712]
 * specifications.
 */
library MessageHashUtils {
    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing a bytes32 `messageHash` with
     * `"\x19Ethereum Signed Message:\n32"` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * NOTE: The `messageHash` parameter is intended to be the result of hashing a raw message with
     * keccak256, although any bytes32 value can be safely used because the final digest will
     * be re-hashed.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x45` (`personal_sign` messages).
     *
     * The digest is calculated by prefixing an arbitrary `message` with
     * `"\x19Ethereum Signed Message:\n" + len(message)` and hashing the result. It corresponds with the
     * hash signed when using the https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`] JSON-RPC method.
     *
     * See {ECDSA-recover}.
     */
    function toEthSignedMessageHash(bytes memory message) internal pure returns (bytes32) {
        return
            keccak256(bytes.concat("\x19Ethereum Signed Message:\n", bytes(Strings.toString(message.length)), message));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-191 signed data with version
     * `0x00` (data with intended validator).
     *
     * The digest is calculated by prefixing an arbitrary `data` with `"\x19\x00"` and the intended
     * `validator` address. Then hashing the result.
     *
     * See {ECDSA-recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(hex"19_00", validator, data));
    }

    /**
     * @dev Returns the keccak256 digest of an EIP-712 typed data (EIP-191 version `0x01`).
     *
     * The digest is calculated from a `domainSeparator` and a `structHash`, by prefixing them with
     * `\x19\x01` and hashing the result. It corresponds to the hash signed by the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`] JSON-RPC method as part of EIP-712.
     *
     * See {ECDSA-recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, hex"19_01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            digest := keccak256(ptr, 0x42)
        }
    }
}

// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/SignatureChecker.sol)

// OpenZeppelin Contracts (last updated v5.0.0) (utils/cryptography/ECDSA.sol)


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1271.sol)

/**
 * @dev Interface of the ERC1271 standard signature validation method for
 * contracts as defined in https://eips.ethereum.org/EIPS/eip-1271[ERC-1271].
 */
interface IERC1271 {
    /**
     * @dev Should return whether the signature provided is valid for the provided data
     * @param hash      Hash of the data to be signed
     * @param signature Signature byte array associated with _data
     */
    function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

/**
 * @dev Signature verification helper that can be used instead of `ECDSA.recover` to seamlessly support both ECDSA
 * signatures from externally owned accounts (EOAs) as well as ERC1271 signatures from smart contract wallets like
 * Argent and Safe Wallet (previously Gnosis Safe).
 */
library SignatureChecker {
    /**
     * @dev Checks if a signature is valid for a given signer and data hash. If the signer is a smart contract, the
     * signature is validated against that smart contract using ERC1271, otherwise it's validated using `ECDSA.recover`.
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature) internal view returns (bool) {
        (address recovered, ECDSA.RecoverError error, ) = ECDSA.tryRecover(hash, signature);
        return
            (error == ECDSA.RecoverError.NoError && recovered == signer) ||
            isValidERC1271SignatureNow(signer, hash, signature);
    }

    /**
     * @dev Checks if a signature is valid for a given signer and data hash. The signature is validated
     * against the signer smart contract using ERC1271.
     *
     * NOTE: Unlike ECDSA signatures, contract signatures are revocable, and the outcome of this function can thus
     * change through time. It could return true at block N and false at block N+1 (or the opposite).
     */
    function isValidERC1271SignatureNow(
        address signer,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (bool) {
        (bool success, bytes memory result) = signer.staticcall(
            abi.encodeCall(IERC1271.isValidSignature, (hash, signature))
        );
        return (success &&
            result.length >= 32 &&
            abi.decode(result, (bytes32)) == bytes32(IERC1271.isValidSignature.selector));
    }
}

/// @title MetaTx
/// @dev This library provides functions for handling meta transactions in the Story Protocol.
library MetaTx {
    /// @dev Version of the EIP712 domain.
    string public constant EIP712_DOMAIN_VERSION = "1";
    /// @dev Hash of the EIP712 domain version.
    bytes32 public constant EIP712_DOMAIN_VERSION_HASH = keccak256(bytes(EIP712_DOMAIN_VERSION));
    /// @dev EIP712 domain type hash.
    bytes32 public constant EIP712_DOMAIN =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    /// @dev Execute type hash.
    bytes32 public constant EXECUTE =
        keccak256("Execute(address to,uint256 value,bytes data,uint256 nonce,uint256 deadline)");

    /// @dev Structure for the Execute type.
    struct Execute {
        address to;
        uint256 value;
        bytes data;
        uint256 nonce;
        uint256 deadline;
    }

    /// @dev Calculates the EIP712 domain separator for the current contract.
    /// @return The EIP712 domain separator.
    function calculateDomainSeparator() internal view returns (bytes32) {
        return calculateDomainSeparator(address(this));
    }

    /// @dev Calculates the EIP712 domain separator for a given IP account.
    /// @param ipAccount The IP account for which to calculate the domain separator.
    /// @return The EIP712 domain separator.
    function calculateDomainSeparator(address ipAccount) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN,
                    keccak256("Story Protocol IP Account"),
                    EIP712_DOMAIN_VERSION_HASH,
                    block.chainid,
                    ipAccount
                )
            );
    }

    /// @dev Calculates the EIP712 struct hash of an Execute.
    /// @param execute The Execute to hash.
    /// @return The EIP712 struct hash of the Execute.
    function getExecuteStructHash(Execute memory execute) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MetaTx.EXECUTE,
                    execute.to,
                    execute.value,
                    keccak256(execute.data),
                    execute.nonce,
                    execute.deadline
                )
            );
    }
}


/// @title IPAccountImpl
/// @notice The Story Protocol's implementation of the IPAccount.
contract IPAccountImpl_V1_0_0 is IPAccountStorage, IIPAccount {
    address public immutable ACCESS_CONTROLLER;

    /// @notice Returns the IPAccount's internal nonce for transaction ordering.
    uint256 public state;

    receive() external payable override(IERC6551Account) {}

    /// @notice Creates a new IPAccountImpl contract instance
    /// @dev Initializes the IPAccountImpl with an AccessController address which is stored
    /// in the implementation code's storage.
    /// This means that each cloned IPAccount will inherently use the same AccessController
    /// without the need for individual configuration.
    /// @param accessController The address of the AccessController contract to be used for permission checks
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licenseRegistry,
        address moduleRegistry
    ) IPAccountStorage(ipAssetRegistry, licenseRegistry, moduleRegistry) {
        if (accessController == address(0)) revert Errors.IPAccount__ZeroAccessController();
        ACCESS_CONTROLLER = accessController;
    }

    /// @notice Checks if the contract supports a specific interface
    /// @param interfaceId The interface identifier, as specified in ERC-165
    /// @return bool is true if the contract supports the interface, false otherwise
    function supportsInterface(bytes4 interfaceId) public view override(IPAccountStorage, IERC165) returns (bool) {
        return (interfaceId == type(IIPAccount).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            super.supportsInterface(interfaceId));
    }

    /// @notice Returns the identifier of the non-fungible token which owns the account
    /// @return chainId The EIP-155 ID of the chain the token exists on
    /// @return tokenContract The contract address of the token
    /// @return tokenId The ID of the token
    function token() public view override returns (uint256, address, uint256) {
        bytes memory footer = new bytes(0x60);
        // 0x4d = 77 bytes (ERC-1167 Header, address, ERC-1167 Footer, salt)
        // 0x60 = 96 bytes (chainId, tokenContract, tokenId)
        //    ERC-1167 Header               (10 bytes)
        //    <implementation (address)>    (20 bytes)
        //    ERC-1167 Footer               (15 bytes)
        //    <salt (uint256)>              (32 bytes)
        //    <chainId (uint256)>           (32 bytes)
        //    <tokenContract (address)>     (32 bytes)
        //    <tokenId (uint256)>           (32 bytes)
        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }

        return abi.decode(footer, (uint256, address, uint256));
    }

    /// @notice Checks if the signer is valid for the given data
    /// @param signer The signer to check
    /// @param data The data to check against
    /// @return The function selector if the signer is valid, 0 otherwise
    function isValidSigner(address signer, bytes calldata data) external view returns (bytes4) {
        if (_isValidSigner(signer, address(0), data)) {
            return IERC6551Account.isValidSigner.selector;
        }

        return bytes4(0);
    }

    /// @notice Returns the owner of the IP Account.
    /// @return The address of the owner.
    function owner() public view returns (address) {
        (uint256 chainId, address contractAddress, uint256 tokenId) = token();
        if (chainId != block.chainid) return address(0);
        return IERC721(contractAddress).ownerOf(tokenId);
    }

    /// @dev Checks if the signer is valid for the given data and recipient via the AccessController permission system.
    /// @param signer The signer to check
    /// @param to The recipient of the transaction
    /// @param data The calldata to check against
    /// @return bool is true if the signer is valid, false otherwise
    function _isValidSigner(address signer, address to, bytes calldata data) internal view returns (bool) {
        if (data.length > 0 && data.length < 4) {
            revert Errors.IPAccount__InvalidCalldata();
        }
        bytes4 selector = bytes4(0);
        if (data.length >= 4) {
            selector = bytes4(data[:4]);
        }
        // the check will revert if permission is denied
        IAccessController(ACCESS_CONTROLLER).checkPermission(address(this), signer, to, selector);
        return true;
    }

    /// @notice Executes a transaction from the IP Account on behalf of the signer.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @param signer The signer of the transaction.
    /// @param deadline The deadline of the transaction signature.
    /// @param signature The signature of the transaction, EIP-712 encoded.
    function executeWithSig(
        address to,
        uint256 value,
        bytes calldata data,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external payable returns (bytes memory result) {
        if (signer == address(0)) {
            revert Errors.IPAccount__InvalidSigner();
        }

        if (deadline < block.timestamp) {
            revert Errors.IPAccount__ExpiredSignature();
        }

        ++state;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({ to: to, value: value, data: data, nonce: state, deadline: deadline })
            )
        );

        if (!SignatureChecker.isValidSignatureNow(signer, digest, signature)) {
            revert Errors.IPAccount__InvalidSignature();
        }

        result = _execute(signer, to, value, data);
        emit ExecutedWithSig(to, value, data, state, deadline, signer, signature);
    }

    /// @notice Executes a transaction from the IP Account.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @return result The return data from the transaction.
    function execute(address to, uint256 value, bytes calldata data) external payable returns (bytes memory result) {
        ++state;
        result = _execute(msg.sender, to, value, data);
        emit Executed(to, value, data, state);
    }

    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /// @dev Executes a transaction from the IP Account.
    function _execute(
        address signer,
        address to,
        uint256 value,
        bytes calldata data
    ) internal returns (bytes memory result) {
        require(_isValidSigner(signer, to, data), "Invalid signer");

        bool success;
        (success, result) = to.call{ value: value }(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }
}

/// @notice Library for working with Openzeppelin's ShortString data types.
library ShortStringOps {
    using ShortStrings for *;
    using Strings for *;

    /// @dev Convert string to bytes32 using ShortString
    function stringToBytes32(string memory s) internal pure returns (bytes32) {
        return ShortString.unwrap(s.toShortString());
    }
}


/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * Consider any assumption about calldata validation performed by the sender may be violated if it's not especially
 * careful about sending transactions invoking {multicall}. For example, a relay address that filters function
 * selectors won't filter calls nested within a {multicall} operation.
 *
 * NOTE: Since 5.0.1 and 4.9.4, this contract identifies non-canonical contexts (i.e. `msg.sender` is not {_msgSender}).
 * If a non-canonical context is identified, the following self `delegatecall` appends the last bytes of `msg.data`
 * to the subcall. This makes it safe to use with {ERC2771Context}. Contexts that don't affect the resolution of
 * {_msgSender} are not propagated to subcalls.
 */
abstract contract MulticallUpgradeable is Initializable, ContextUpgradeable {
    function __Multicall_init() internal onlyInitializing {
    }

    function __Multicall_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev Receives and executes a batch of function calls on this contract.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        bytes memory context = msg.sender == _msgSender()
            ? new bytes(0)
            : msg.data[msg.data.length - _contextSuffixLength():];

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), bytes.concat(data[i], context));
        }
        return results;
    }
}

/// @title Arbitration Policy Interface
interface IArbitrationPolicy {
    /// @notice Event emitted when governance withdraws
    /// @param amount The amount withdrawn
    event GovernanceWithdrew(uint256 amount);

    /// @notice Returns the protocol-wide dispute module address
    function DISPUTE_MODULE() external view returns (address);

    /// @notice Returns the payment token address
    function PAYMENT_TOKEN() external view returns (address);

    /// @notice Returns the arbitration price
    function ARBITRATION_PRICE() external view returns (uint256);

    /// @notice Executes custom logic on raising dispute.
    /// @dev Enforced to be only callable by the DisputeModule.
    /// @param caller Address of the caller
    /// @param data The arbitrary data used to raise the dispute
    function onRaiseDispute(address caller, bytes calldata data) external;

    /// @notice Executes custom logic on disputing judgement.
    /// @dev Enforced to be only callable by the DisputeModule.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The arbitrary data used to set the dispute judgement
    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external;

    /// @notice Executes custom logic on disputing cancel.
    /// @dev Enforced to be only callable by the DisputeModule.
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to cancel the dispute
    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external;

    /// @notice Executes custom logic on resolving dispute
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to resolve the dispute
    function onResolveDispute(address caller, uint256 disputeId, bytes calldata data) external;

    /// @notice Allows governance address to withdraw
    /// @dev Enforced to be only callable by the governance protocol admin.
    function governanceWithdraw() external;
}



/// @title Dispute Module
/// @notice The dispute module acts as an enforcement layer for IP assets that allows raising and resolving disputes
/// through arbitration by judges.
contract DisputeModule_V1_0_0 is
    IDisputeModule,
    BaseModule,
    ProtocolPausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlled,
    UUPSUpgradeable,
    MulticallUpgradeable
{
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @dev Storage for DisputeModule
    /// @param disputeCounter The dispute ID counter
    /// @param baseArbitrationPolicy The address of the base arbitration policy
    /// @param disputes Returns the dispute information for a given dispute id
    /// @param isWhitelistedDisputeTag Indicates if a dispute tag is whitelisted
    /// @param isWhitelistedArbitrationPolicy Indicates if an arbitration policy is whitelisted
    /// @param isWhitelistedArbitrationRelayer Indicates if an arbitration relayer
    /// is whitelisted for a given arbitration policy
    /// @param arbitrationPolicies Arbitration policy for a given ipId
    /// @param successfulDisputesPerIp Counter of successful disputes per ipId
    /// @custom:storage-location erc7201:story-protocol.DisputeModule
    struct DisputeModuleStorage {
        uint256 disputeCounter;
        address baseArbitrationPolicy;
        mapping(uint256 => Dispute) disputes;
        mapping(bytes32 => bool) isWhitelistedDisputeTag;
        mapping(address => bool) isWhitelistedArbitrationPolicy;
        mapping(address => mapping(address => bool)) isWhitelistedArbitrationRelayer;
        mapping(address => address) arbitrationPolicies;
        mapping(address => uint256) successfulDisputesPerIp;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.DisputeModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant DisputeModuleStorageLocation =
        0x682945c2d364b4630e68ffe0854d372acb0c4ff549a1e3dbc6f878bd8da0c800;

    string public constant override name = DISPUTE_MODULE_KEY;

    /// @notice Tag to represent the dispute is in dispute state waiting for judgement
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");

    /// @notice Protocol-wide IP asset registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Protocol-wide license registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// Constructor
    /// @param accessController The address of the access controller
    /// @param ipAssetRegistry The address of the asset registry
    /// @param licenseRegistry The address of the license registry
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licenseRegistry
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (licenseRegistry == address(0)) revert Errors.DisputeModule__ZeroLicenseRegistry();
        if (ipAssetRegistry == address(0)) revert Errors.DisputeModule__ZeroIPAssetRegistry();
        if (accessController == address(0)) revert Errors.DisputeModule__ZeroAccessController();

        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) {
            revert Errors.DisputeModule__ZeroAccessManager();
        }
        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __Multicall_init();
    }

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external restricted {
        if (tag == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeTag();

        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        $.isWhitelistedDisputeTag[tag] = allowed;

        emit TagWhitelistUpdated(tag, allowed);
    }

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external restricted {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();

        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        $.isWhitelistedArbitrationPolicy[arbitrationPolicy] = allowed;

        emit ArbitrationPolicyWhitelistUpdated(arbitrationPolicy, allowed);
    }

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(
        address arbitrationPolicy,
        address arbPolicyRelayer,
        bool allowed
    ) external restricted {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();
        if (arbPolicyRelayer == address(0)) revert Errors.DisputeModule__ZeroArbitrationRelayer();

        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        $.isWhitelistedArbitrationRelayer[arbitrationPolicy][arbPolicyRelayer] = allowed;

        emit ArbitrationRelayerWhitelistUpdated(arbitrationPolicy, arbPolicyRelayer, allowed);
    }

    /// @notice Sets the base arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address arbitrationPolicy) external restricted {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        $.baseArbitrationPolicy = arbitrationPolicy;

        emit DefaultArbitrationPolicyUpdated(arbitrationPolicy);
    }

    /// @notice Sets the arbitration policy for an ipId
    /// @param ipId The ipId
    /// @param arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address ipId, address arbitrationPolicy) external verifyPermission(ipId) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        $.arbitrationPolicies[ipId] = arbitrationPolicy;

        emit ArbitrationPolicySet(ipId, arbitrationPolicy);
    }

    /// @notice Raises a dispute on a given ipId
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The id of the newly raised dispute
    function raiseDispute(
        address targetIpId,
        string memory linkToDisputeEvidence,
        bytes32 targetTag,
        bytes calldata data
    ) external nonReentrant whenNotPaused returns (uint256) {
        if (!IP_ASSET_REGISTRY.isRegistered(targetIpId)) revert Errors.DisputeModule__NotRegisteredIpId();
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        if (!$.isWhitelistedDisputeTag[targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();

        bytes32 linkToDisputeEvidenceBytes = ShortStringOps.stringToBytes32(linkToDisputeEvidence);
        if (linkToDisputeEvidenceBytes == bytes32(0)) revert Errors.DisputeModule__ZeroLinkToDisputeEvidence();

        address arbitrationPolicy = $.arbitrationPolicies[targetIpId];
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = $.baseArbitrationPolicy;

        uint256 disputeId = ++$.disputeCounter;

        $.disputes[disputeId] = Dispute({
            targetIpId: targetIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: arbitrationPolicy,
            linkToDisputeEvidence: linkToDisputeEvidenceBytes,
            targetTag: targetTag,
            currentTag: IN_DISPUTE,
            parentDisputeId: 0
        });

        IArbitrationPolicy(arbitrationPolicy).onRaiseDispute(msg.sender, data);

        emit DisputeRaised(
            disputeId,
            targetIpId,
            msg.sender,
            arbitrationPolicy,
            linkToDisputeEvidenceBytes,
            targetTag,
            data
        );

        return disputeId;
    }

    /// @notice Sets the dispute judgement on a given dispute. Only whitelisted arbitration relayers can call to judge.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(
        uint256 disputeId,
        bool decision,
        bytes calldata data
    ) external nonReentrant whenNotPaused {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();

        Dispute memory dispute = $.disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (!$.isWhitelistedArbitrationRelayer[dispute.arbitrationPolicy][msg.sender]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationRelayer();
        }

        if (decision) {
            $.disputes[disputeId].currentTag = dispute.targetTag;
            $.successfulDisputesPerIp[dispute.targetIpId]++;
        } else {
            $.disputes[disputeId].currentTag = bytes32(0);
        }

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeJudgement(disputeId, decision, data);

        emit DisputeJudgementSet(disputeId, decision, data);
    }

    /// @notice Cancels an ongoing dispute
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) external nonReentrant {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        Dispute memory dispute = $.disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeCancel(msg.sender, disputeId, data);

        $.disputes[disputeId].currentTag = bytes32(0);

        emit DisputeCancelled(disputeId, data);
    }

    /// @notice Tags a derivative if a parent has been tagged with an infringement tag
    /// @param parentIpId The infringing parent ipId
    /// @param derivativeIpId The derivative ipId
    /// @param parentDisputeId The dispute id that tagged the parent ipId as infringing
    function tagDerivativeIfParentInfringed(
        address parentIpId,
        address derivativeIpId,
        uint256 parentDisputeId
    ) external whenNotPaused {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();

        Dispute memory parentDispute = $.disputes[parentDisputeId];
        if (parentDispute.targetIpId != parentIpId) revert Errors.DisputeModule__ParentIpIdMismatch();

        // a dispute current tag prior to being resolved can be in 3 states - IN_DISPUTE, 0, or a tag (ie. "PLAGIARISM)
        // by restricting IN_DISPUTE and 0 - it is ensire the parent has been tagged before resolving dispute
        if (parentDispute.currentTag == IN_DISPUTE || parentDispute.currentTag == bytes32(0))
            revert Errors.DisputeModule__ParentNotTagged();

        if (!LICENSE_REGISTRY.isParentIp(parentIpId, derivativeIpId)) revert Errors.DisputeModule__NotDerivative();

        address arbitrationPolicy = $.arbitrationPolicies[derivativeIpId];
        if (!$.isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = $.baseArbitrationPolicy;

        uint256 disputeId = ++$.disputeCounter;

        $.disputes[disputeId] = Dispute({
            targetIpId: derivativeIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: arbitrationPolicy,
            linkToDisputeEvidence: "",
            targetTag: parentDispute.currentTag,
            currentTag: parentDispute.currentTag,
            parentDisputeId: parentDisputeId
        });

        $.successfulDisputesPerIp[derivativeIpId]++;

        emit DerivativeTaggedOnParentInfringement(
            parentIpId,
            derivativeIpId,
            parentDisputeId,
            parentDispute.currentTag
        );
    }

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute id
    /// @param data The data to resolve the dispute
    function resolveDispute(uint256 disputeId, bytes calldata data) external {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        Dispute memory dispute = $.disputes[disputeId];

        // there are two types of disputes - those that are subject to judgment and those that are not
        // the way to distinguish is by whether dispute.parentDisputeId is 0 or higher than 0
        // for the former - only the dispute initiator can resolve
        if (dispute.parentDisputeId == 0 && msg.sender != dispute.disputeInitiator)
            revert Errors.DisputeModule__NotDisputeInitiator();
        // for the latter - resolving is permissionless as long as the parent dispute has been resolved
        if (dispute.parentDisputeId > 0 && $.disputes[dispute.parentDisputeId].currentTag != bytes32(0))
            revert Errors.DisputeModule__ParentDisputeNotResolved();

        if (dispute.currentTag == IN_DISPUTE || dispute.currentTag == bytes32(0))
            revert Errors.DisputeModule__NotAbleToResolve();

        $.successfulDisputesPerIp[dispute.targetIpId]--;
        $.disputes[disputeId].currentTag = bytes32(0);

        IArbitrationPolicy(dispute.arbitrationPolicy).onResolveDispute(msg.sender, disputeId, data);

        emit DisputeResolved(disputeId);
    }

    /// @notice Returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param ipId The ipId
    /// @return isTagged True if the ipId is tagged
    function isIpTagged(address ipId) external view returns (bool) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.successfulDisputesPerIp[ipId] > 0;
    }

    /// @notice Dispute ID counter
    function disputeCounter() external view returns (uint256) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.disputeCounter;
    }

    /// @notice The address of the base arbitration policy
    function baseArbitrationPolicy() external view returns (address) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.baseArbitrationPolicy;
    }

    /// @notice Returns the dispute information for a given dispute id
    /// @param disputeId The dispute id
    /// @return targetIpId The ipId that is the target of the dispute
    /// @return disputeInitiator The address of the dispute initiator
    /// @return arbitrationPolicy The address of the arbitration policy
    /// @return linkToDisputeEvidence The link of the dispute summary
    /// @return targetTag The target tag of the dispute
    /// @return currentTag The current tag of the dispute
    /// @return parentDisputeId The parent dispute id
    function disputes(
        uint256 disputeId
    )
        external
        view
        returns (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 linkToDisputeEvidence,
            bytes32 targetTag,
            bytes32 currentTag,
            uint256 parentDisputeId
        )
    {
        Dispute memory dispute = _getDisputeModuleStorage().disputes[disputeId];
        return (
            dispute.targetIpId,
            dispute.disputeInitiator,
            dispute.arbitrationPolicy,
            dispute.linkToDisputeEvidence,
            dispute.targetTag,
            dispute.currentTag,
            dispute.parentDisputeId
        );
    }

    /// @notice Indicates if a dispute tag is whitelisted
    /// @param tag The dispute tag
    /// @return allowed Indicates if the dispute tag is whitelisted
    function isWhitelistedDisputeTag(bytes32 tag) external view returns (bool allowed) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.isWhitelistedDisputeTag[tag];
    }

    /// @notice Indicates if an arbitration policy is whitelisted
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @return allowed Indicates if the arbitration policy is whitelisted
    function isWhitelistedArbitrationPolicy(address arbitrationPolicy) external view returns (bool allowed) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.isWhitelistedArbitrationPolicy[arbitrationPolicy];
    }

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    /// @return allowed Indicates if the arbitration relayer is whitelisted
    function isWhitelistedArbitrationRelayer(
        address arbitrationPolicy,
        address arbitrationRelayer
    ) external view returns (bool allowed) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.isWhitelistedArbitrationRelayer[arbitrationPolicy][arbitrationRelayer];
    }

    /// @notice Arbitration policy for a given ipId
    /// @param ipId The ipId
    /// @return policy The address of the arbitration policy
    function arbitrationPolicies(address ipId) external view returns (address policy) {
        DisputeModuleStorage storage $ = _getDisputeModuleStorage();
        return $.arbitrationPolicies[ipId];
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of DisputeModule.
    function _getDisputeModuleStorage() private pure returns (DisputeModuleStorage storage $) {
        assembly {
            $.slot := DisputeModuleStorageLocation
        }
    }
}

/// @title PILFlavors Library
/// @notice Provides a set of predefined PILTerms configurations for different licensing scenarios
/// See the text: https://github.com/storyprotocol/protocol-core/blob/main/PIL_Beta_Final_2024_02.pdf
library PILFlavors {
    bytes public constant EMPTY_BYTES = "";

    /// @notice Gets the default values of PIL terms
    function defaultValuesLicenseTerms() internal pure returns (PILTerms memory) {
        return _defaultPIL();
    }

    /// @notice Helper method to get licenseTermsId for the defaultValuesLicenseTerms() configuration
    /// @param pilTemplate The address of the PILicenseTemplate
    /// @return The licenseTermsId for the defaultValuesLicenseTerms() configuration, 0 if not registered
    function getDefaultValuesLicenseTermsId(IPILicenseTemplate pilTemplate) internal view returns (uint256) {
        return pilTemplate.getLicenseTermsId(_defaultPIL());
    }

    /// @notice Gets the values to create a Non Commercial Social Remix licenseTerms flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-1-non-commercial-social-remixing
    /// @return The input struct for PILicenseTemplate.registerLicenseTerms()
    function nonCommercialSocialRemixing() internal returns (PILTerms memory) {
        return _nonComSocialRemixingPIL();
    }

    /// @notice Helper method to get the licenseTermsId for the nonCommercialSocialRemixing() configuration
    /// @param pilTemplate The address of the PILicenseTemplate
    /// @return The licenseTermsId for the nonCommercialSocialRemixing() configuration, 0 if not registered
    function getNonCommercialSocialRemixingId(IPILicenseTemplate pilTemplate) internal view returns (uint256) {
        return pilTemplate.getLicenseTermsId(_nonComSocialRemixingPIL());
    }

    /// @notice Gets the values to create a Non Commercial Social Remix licenseTerms flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-2-commercial-use
    /// @param mintingFee The fee to be paid when minting a license, in the smallest unit of the token
    /// @param currencyToken The token to be used to pay the minting fee
    /// @param royaltyPolicy The address of the royalty licenseTerms to be used by the license template.
    /// @return The input struct for PILicenseTemplate.registerLicenseTerms()
    function commercialUse(
        uint256 mintingFee,
        address currencyToken,
        address royaltyPolicy
    ) internal returns (PILTerms memory) {
        return _commercialUsePIL(mintingFee, currencyToken, royaltyPolicy);
    }

    /// @notice Helper method to get the licenseTermsId for the commercialUse() configuration
    /// @param mintingFee The fee to be paid when minting a license, in the smallest unit of the token
    /// @param currencyToken The token to be used to pay the minting fee
    /// @return The licenseTermsId for the commercialUse() configuration, 0 if not registered
    function getCommercialUseId(
        IPILicenseTemplate pilTemplate,
        uint256 mintingFee,
        address currencyToken,
        address royaltyPolicy
    ) internal view returns (uint256) {
        return pilTemplate.getLicenseTermsId(_commercialUsePIL(mintingFee, currencyToken, royaltyPolicy));
    }

    /// @notice Gets the values to create a Commercial Remixing licenseTerms flavor, as described in:
    /// https://docs.storyprotocol.xyz/docs/licensing-presets-flavors#flavor-3-commercial-remix
    /// @param commercialRevShare The percentage of the revenue that the commercializer will share
    /// with the parent creator, with 1 decimal (e.g. 10 means 1%)
    /// @param royaltyPolicy The address of the royalty policy to be used by the license template.
    /// @return The input struct for PILicenseTemplate.registerLicenseTerms()
    function commercialRemix(
        uint256 mintingFee,
        uint32 commercialRevShare,
        address royaltyPolicy,
        address currencyToken
    ) internal pure returns (PILTerms memory) {
        return _commercialRemixPIL(mintingFee, commercialRevShare, royaltyPolicy, currencyToken);
    }

    /// @notice Helper method to get the licenseTermsId for the commercialRemix() configuration from LicensingModule
    /// @param pilTemplate The address of the PILicenseTemplate
    /// @param commercialRevShare The percentage of the revenue that the commercializer will share with the
    /// parent creator, with 1 decimal (e.g. 10 means 1%)
    /// @param royaltyPolicy The address of the royalty policy to be used by the license template.
    /// @return The licenseTermsId for the commercialRemix() configuration, 0 if not registered
    function getCommercialRemixId(
        IPILicenseTemplate pilTemplate,
        uint256 mintingFee,
        uint32 commercialRevShare,
        address royaltyPolicy,
        address currencyToken
    ) internal view returns (uint256) {
        return
            pilTemplate.getLicenseTermsId(
                _commercialRemixPIL(mintingFee, commercialRevShare, royaltyPolicy, currencyToken)
            );
    }

    /// @notice Gets the default values of PIL terms
    function _defaultPIL() private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                commercialRevCelling: 0,
                derivativesAllowed: false,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCelling: 0,
                currency: address(0),
                uri: ""
            });
    }

    /// @notice Gets the values to create a Non Commercial Social Remix licenseTerms flavor
    function _nonComSocialRemixingPIL() private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: 0,
                expiration: 0,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                commercialRevCelling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCelling: 0,
                currency: address(0),
                uri: ""
            });
    }

    /// @notice Gets the values to create a Commercial Use licenseTerms flavor
    function _commercialUsePIL(
        uint256 mintingFee,
        address currencyToken,
        address royaltyPolicy
    ) private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: royaltyPolicy,
                mintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: 0,
                commercialRevCelling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativeRevCelling: 0,
                currency: currencyToken,
                uri: ""
            });
    }

    /// @notice Gets the values to create a Commercial Remixing licenseTerms flavor
    function _commercialRemixPIL(
        uint256 mintingFee,
        uint32 commercialRevShare,
        address royaltyPolicy,
        address currencyToken
    ) private pure returns (PILTerms memory) {
        return
            PILTerms({
                transferable: true,
                royaltyPolicy: royaltyPolicy,
                mintingFee: mintingFee,
                expiration: 0,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: EMPTY_BYTES,
                commercialRevShare: commercialRevShare,
                commercialRevCelling: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativeRevCelling: 0,
                currency: currencyToken,
                uri: ""
            });
    }
}