// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

struct Channel {
    uint64 id;
    uint64 score; // is multiplied by 10 ** 6 for greater punctuancy
    int64 popularity_modifier_10_5; // has an inverse relationship with how "overbought" a channel is compared to the average channel investment volume and can be negative; 100000 = 1 percent
    uint256 accumulated_donations;
    address registered_withdraw_address;
}