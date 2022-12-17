// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// -->: implement as BEP20
contract PlatformToken is ERC20 { // this is a dummy contract name
    string private constant _name = "PlatformToken";
    string private constant _symbol = "DIT"; // I: let it have a symbol derived from "Donate-Invest Token" as a temporary label
    uint public token_current_price;
    uint128 private constant initial_supply = 10 ** 10;
    uint256 internal constant period_mint_amount = 10 ** 4;
    uint128 internal constant minting_period_sec = 30 * 24 * 3600;
    uint32 public constant total_mint_cycles = 120;
    uint32 public remaining_mint_cycles = 120;
    uint256 internal timeof_deployment;
    address private operator_contract_address;

    mapping (address => uint256) balances;

    //(string memory name_, string memory symbol_, address _owner, uint256 _supply) 
    constructor (address operator_address_) ERC20(_name, _symbol)
    {
        _mint(operator_address_, initial_supply * 10 ** 18);
        balances[operator_address_] = initial_supply;
        timeof_deployment = block.timestamp;
        operator_contract_address = operator_address_;
    }

    modifier hasCycleMatured () { // the last time of minting has been passed by 30 days
        uint128 tp_timeof_cycles_since_deployment = (total_mint_cycles - remaining_mint_cycles + 1) * minting_period_sec;
        require (
            block.timestamp >= timeof_deployment + tp_timeof_cycles_since_deployment,
            "It is too early to mint the upcoming cycle yet."
        ); _;
    }

    function mintPeriodically () public hasCycleMatured {
        // I: will be called from outside as Solidity does not enable scheduling from within
        require (remaining_mint_cycles > 0, "There are no more minting cycles");
        require (
            msg.sender == operator_contract_address, 
            "Only RewardPool can mint new tokens."
        );
        _mint(operator_contract_address, period_mint_amount);
        balances[address(this)] += period_mint_amount;
        remaining_mint_cycles -= 1;
    }
}