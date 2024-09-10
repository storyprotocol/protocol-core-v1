/* solhint-disable no-console */
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

// external
import { BaseTest } from "../utils/BaseTest.t.sol";
import { ERC6551 } from "@solady/src/accounts/ERC6551.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
// import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
// import { MetaTx } from "contracts/lib/MetaTx.sol";

contract Recorder {
    uint256 public recorded;

    fallback() external payable {
        recorded += 1;
    }
}

contract IPAccountHarnessBase {
    IPAccountImpl public ipAccount;
    Recorder public recorder;

    function execute(uint256 value, bytes calldata data) external {
        ipAccount.execute(address(recorder), value, data);
    }

    function executeOp(uint256 value, bytes calldata data, uint8 operation) external {
        ipAccount.execute(address(recorder), value, data, operation);
    }

    struct CallToRecorder {
        uint256 value;
        bytes data;
    }

    function batchExecute(CallToRecorder[] calldata _calls, uint8 operation) external {
        ERC6551.Call[] memory calls = new ERC6551.Call[](_calls.length);
        for (uint256 i = 0; i < _calls.length; i++) {
            calls[i] = ERC6551.Call({ target: address(recorder), value: _calls[i].value, data: _calls[i].data });
        }
        ipAccount.executeBatch(calls, operation);
    }

    function executeWithSig(
        uint256 value,
        bytes calldata data,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external {
        ipAccount.executeWithSig(address(recorder), value, data, signer, deadline, signature);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

contract IPAccountHarness is IPAccountHarnessBase {
    constructor(address payable _ipAccount) {
        ipAccount = IPAccountImpl(_ipAccount);
        recorder = new Recorder();
    }
}

contract IPAccountHarnessWithNFT is IPAccountHarnessBase {
    constructor() {
        recorder = new Recorder();
    }

    function setIPAccount(address payable _ipAccount) external {
        ipAccount = IPAccountImpl(_ipAccount);
    }
}

/// @notice Base invariants for IPAccount contract
contract IPAccountPermissionlessInvariants is BaseTest {
    IPAccountImpl public ipAccount;
    address public owner;
    bytes32 public state;
    uint256 public chainId;
    address public tokenContract;
    uint256 public tokenId;

    IPAccountHarnessBase public harness;
    Recorder public recorder;

    function afterSetUp(address _ipAccount) public {
        ipAccount = IPAccountImpl(payable(_ipAccount));
        owner = ipAccount.owner();
        state = ipAccount.state();
        (chainId, tokenContract, tokenId) = ipAccount.token();

        harness = IPAccountHarnessBase(new IPAccountHarness(payable(ipAccount)));
        recorder = harness.recorder();

        targetContract(address(harness));
        excludeSender(address(0x0));
    }

    function setUpWithNFT() public {
        harness = IPAccountHarnessBase(new IPAccountHarnessWithNFT());
        vm.startPrank(address(harness));
        mockNFT.mintId(address(harness), 300);
        address _ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), 300);
        assertTrue(ipAssetRegistry.isRegistered(_ipAccount));
        vm.stopPrank();

        ipAccount = IPAccountImpl(payable(_ipAccount));
        owner = ipAccount.owner();
        state = ipAccount.state();
        (chainId, tokenContract, tokenId) = ipAccount.token();
        IPAccountHarnessWithNFT(address(harness)).setIPAccount(payable(_ipAccount));
        recorder = harness.recorder();

        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = harness.execute.selector;
        selectors[1] = harness.executeOp.selector;
        selectors[2] = harness.batchExecute.selector;
        selectors[3] = harness.executeWithSig.selector;
        targetSelector(FuzzSelector(address(harness), selectors));

        targetContract(address(harness));
        excludeSender(address(0x0));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

/// @notice Invariants for IPAccount that bound to NFT and the fuzzer has no permissions to execute transactions
contract IPAccountPermissionlessWithNftInvariants is IPAccountPermissionlessInvariants {
    function setUp() public override {
        super.setUp();
        mockNFT.mintId(address(this), 300);
        address _ipAccount = ipAssetRegistry.register(block.chainid, address(mockNFT), 300);
        assertTrue(ipAssetRegistry.isRegistered(_ipAccount));
        super.afterSetUp(_ipAccount);
        excludeSender(address(this));
    }

    /// @dev As all callers have no permissions, the IPAccount should not be able to execute any transactions
    /// @notice Invariant to check the owner, state, chainId, tokenContract, and tokenId of the IPAccount
    function invariant_permissionless() public {
        address _owner = ipAccount.owner();
        bytes32 _state = ipAccount.state();
        (uint256 _chainId, address _tokenContract, uint256 _tokenId) = ipAccount.token();

        uint256 recorded = recorder.recorded();

        assertEq(recorded, 0, "recorded");
        assertEq(_state, state, "state");
        assertEq(_chainId, block.chainid, "chainId");
        assertEq(_tokenContract, address(mockNFT), "tokenContract");
        assertEq(_owner, address(this), "owner");
    }
}

/// @notice Invariants for IPAccount that bound to NFT and the fuzzer has permissions to execute transactions
contract IPAccountPermissionedWithNftInvariants is IPAccountPermissionlessInvariants {
    function setUp() public override {
        super.setUp();
        super.setUpWithNFT();
        vm.deal(address(ipAccount), 1000000000 ether);
    }

    /// @notice Invariant to check the owner, state, chainId, tokenContract, and tokenId of the IPAccount
    function invariant_permissionedTokenInfo() public {
        address _owner = ipAccount.owner();
        bytes32 _state = ipAccount.state();
        (uint256 _chainId, address _tokenContract, uint256 _tokenId) = ipAccount.token();

        uint256 recorded = recorder.recorded();

        assertGe(recorded, 0, "recorded");
        assertEq(_chainId, block.chainid, "chainId");
        assertEq(_tokenContract, address(mockNFT), "tokenContract");
        assertEq(_owner, address(harness), "owner");
    }

    /// @notice Invariant to check that if a tx is executed, the state shall be updated
    function invariant_permissionedStateUpdate() public {
        if (recorder.recorded() > 0) {
            bytes32 _state = ipAccount.state();
            assertNotEq(_state, state, "state");
        }
    }
}
