//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    }

    function mint(address receiver, uint256 amount) public {
        _mint(receiver, amount);
    }

    function burn(address receiver, uint256 amount) public {
        _burn(receiver, amount);
    }
}
