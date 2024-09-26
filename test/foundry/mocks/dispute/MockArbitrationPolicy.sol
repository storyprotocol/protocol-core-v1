// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IDisputeModule } from "../../../../contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../../../contracts/interfaces/modules/dispute/policies/IArbitrationPolicy.sol";

contract MockArbitrationPolicy is IArbitrationPolicy {
    using SafeERC20 for IERC20;

    address public immutable DISPUTE_MODULE;
    address public immutable PAYMENT_TOKEN;
    uint256 public immutable ARBITRATION_PRICE;

    address treasury;

    error MockArbitrationPolicy__NotDisputeModule();

    /// @notice Restricts the calls to the DisputeModule
    modifier onlyDisputeModule() {
        if (msg.sender != DISPUTE_MODULE) revert MockArbitrationPolicy__NotDisputeModule();
        _;
    }

    constructor(address disputeModule, address paymentToken, uint256 arbitrationPrice) {
        DISPUTE_MODULE = disputeModule;
        PAYMENT_TOKEN = paymentToken;
        ARBITRATION_PRICE = arbitrationPrice;
    }

    function setTreasury(address newTreasury) external {
        treasury = newTreasury;
    }

    function onRaiseDispute(address caller, bytes calldata data) external onlyDisputeModule {
        IERC20(PAYMENT_TOKEN).safeTransferFrom(caller, address(this), ARBITRATION_PRICE);
    }

    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external onlyDisputeModule {
        if (decision) {
            (, address disputeInitiator, , , , , ) = IDisputeModule(DISPUTE_MODULE).disputes(disputeId);
            IERC20(PAYMENT_TOKEN).safeTransfer(disputeInitiator, ARBITRATION_PRICE);
        } else {
            IERC20(PAYMENT_TOKEN).safeTransfer(treasury, ARBITRATION_PRICE);
        }
    }

    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {}

    function onResolveDispute(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {}
}
