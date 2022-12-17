// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@prb/math/contracts/PRBMathSD59x18.sol";

contract PRBMathTest {
    using PRBMathSD59x18 for int256;
    
    function calculateExponent(uint256 base_) public pure returns(int256) {
        return int256(base_).pow(10e-1); // Does not work
    }
}