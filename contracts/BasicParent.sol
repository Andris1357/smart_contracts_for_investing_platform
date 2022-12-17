// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

contract BasicParent {
    function basicFunc (uint8 num) internal pure returns (uint8) {
        return num + 3;
    }
}