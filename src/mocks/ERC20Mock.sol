// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// this is a MOCK
contract ERC20Mock is ERC20 {
    address public governor;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address _to, uint256 _amount) public {
        require(msg.sender == governor, "Unauthorised");
        _mint(_to, _amount);
    }

    function setGovernor(address _governor) external {
        governor = _governor;
    }
}
