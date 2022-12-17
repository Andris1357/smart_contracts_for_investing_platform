// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BasicChild.sol";

contract Ierc20Test3 is ERC20 {
    string private constant _name = "Ierc20Test3";
    string private constant _symbol = "TCO";
    address public stored_recipient; uint256 public stored_amount;

    mapping(address => uint256) balances;

    event basicEvent (string message);

    constructor () ERC20(_name, _symbol) {
        _mint(address(this), 10000 * 10 ** 18);
    }

    function testTransfer (address recipient, uint256 amount) public returns (bool) {
        stored_recipient = recipient;
        stored_amount = amount;
        emit basicEvent("Overridden transfer");
        return true;
    }
}