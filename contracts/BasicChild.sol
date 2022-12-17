// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import './BasicParent.sol';
import "@prb/math/contracts/PRBMathUD60x18.sol";

contract BasicChild is BasicParent {
    using PRBMathUD60x18 for uint256;
    function pow(int256 x, int256 y) external view returns (int256 result) {}
    uint8 public stored_var;
    address internal sender_address = 0x94A4f1556B8B00d00841e569BDDB75A279fd9fa2;
    function channelBasic (uint8 par) public {
        stored_var = BasicParent.basicFunc(par);
    }
    function returnSqrt () public pure returns (uint256) {
        uint256 temp_num = 4e18;
        return temp_num.pow(5e17);
    }
    // TD: set by real-time dividing 2 vars th res in a fract val
}