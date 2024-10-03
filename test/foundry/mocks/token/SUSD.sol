// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SUSD is ERC20 {
    constructor() ERC20("Story USD", "SUSD") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }
}
