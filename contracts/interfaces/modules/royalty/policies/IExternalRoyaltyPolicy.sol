// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IExternalRoyaltyPolicyBase } from "./IExternalRoyaltyPolicyBase.sol";

/// @title IExternalRoyaltyPolicy interface
interface IExternalRoyaltyPolicy is IExternalRoyaltyPolicyBase, IERC165 {}
