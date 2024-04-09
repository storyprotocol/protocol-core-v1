// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IDisputeModule } from "../../../../contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../../../contracts/interfaces/modules/dispute/policies/IArbitrationPolicy.sol";

contract MockArbitrationPolicy is IArbitrationPolicy {
    address public DISPUTE_MODULE;
    address public PAYMENT_TOKEN;
    uint256 public ARBITRATION_PRICE;

    constructor(address disputeModule, address paymentToken, uint256 arbitrationPrice) {
        DISPUTE_MODULE = disputeModule;
        PAYMENT_TOKEN = paymentToken;
        ARBITRATION_PRICE = arbitrationPrice;
    }

    function setDisputeModule(address disputeModule) external {
        DISPUTE_MODULE = disputeModule;
    }

    function setPaymentToken(address paymentToken) external {
        PAYMENT_TOKEN = paymentToken;
    }

    function setArbitrationPrice(uint256 arbitrationPrice) external {
        ARBITRATION_PRICE = arbitrationPrice;
    }

    function onRaiseDispute(address _caller, bytes calldata) external {
        IERC20(PAYMENT_TOKEN).transferFrom(_caller, address(this), ARBITRATION_PRICE);
    }

    function onDisputeJudgement(uint256 _disputeId, bool _decision, bytes calldata) external {
        if (_decision) {
            (, address disputeInitiator, , , , ) = IDisputeModule(DISPUTE_MODULE).disputes(_disputeId);
            IERC20(PAYMENT_TOKEN).transfer(disputeInitiator, ARBITRATION_PRICE);
        }
    }

    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external {}

    function onResolveDispute(address caller, uint256 disputeId, bytes calldata data) external {}

    function governanceWithdraw() external {
        uint256 balance = IERC20(PAYMENT_TOKEN).balanceOf(address(this));
        IERC20(PAYMENT_TOKEN).transfer(msg.sender, balance);
    }
}
