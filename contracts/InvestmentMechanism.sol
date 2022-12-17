// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "@prb/math/contracts/PRBMathSD59x18.sol";

import "./Channels.sol";
import "./PlatformToken.sol";
import "./RewardPool.sol";

contract InvestmentMechanism { // it did not show abstract error when inheriting fr RP <= bc it did not use a any func of it?
    // \/: there may be issues with some implementation <-> there is no func used fr w/i CH
    using PRBMathSD59x18 for int256;
    
    uint8 constant private default_donation_percent = 1;
    uint8 constant private platform_fee_10_3 = 5; //counting by multiplying the original amount by some amount (10 ** 3 in this case) to be able to express floats
    uint constant private early_unlock_penalty_per_day_10_3 = 30;
    uint8 constant private default_monthly_interest_10_3 = 35; //if channel score stays the same, investor will earn [invested amount (after cuts)] * [default interest]
    uint32 public minimum_investment = 10000; //will later be assigned based on how many tokens would be minted and maybe also based on their current USD price
    address private investor;
    
    address private immutable owner_address;
    address private immutable operator_address; // /\: these may be changed to internal /\ inheritance
    RewardPool private immutable operator_contract;
    PlatformToken private immutable platform_token;
    Channels private immutable channels_contract;
    // variables storing Channels and PT are available via inheritance fr RP

    // creates enum of lock periods to have greater control of inputs
    enum LockPeriod { // TD: test inheritance on a small scale & /\ apply
        DAYS_30, DAYS_60, DAYS_90, DAYS_180, DAYS_360 // /\: assign values to enum els
    } 
    /* enum will only ever return the index of the currently chosen element if called with getter -> 
    an array is needed that has its elements called by the index returned when calling an enum member */

    struct Investment { // is a struct because a contract does not have to be closed to instantiate a new investment on it, even during an existing investment on the same channel
        bytes32 subscription_id; //uint128 accumulated_rewards; -> I dont think we need this <- gas efficiency
        string channel_name;
        address investor_address;
        uint128 commited_funds;
        uint128 invested_funds;
        uint64 initial_score;
        uint32 risk_modifier_100;
        uint32 available_duration_bonus_10_5;
        int64 channel_popularity_modifier_10_5; // \/: remove because it would be very costly to ° update ~; is set with JS; has an inverse relationship with how "overbought" a channel is compared to the average channel investment volume and can be negative
        uint256 lock_start;
        uint256 lock_normal_end;
        uint16 donation_modifier_10_2;
    }

    mapping (bytes32 => Investment) private active_investments;
    mapping (LockPeriod => uint256) lock_period_seconds;
    uint256[5] private lock_periods = [259000, 5184000, 7776000, 15552000, 31104000];
    mapping (LockPeriod => uint32) duration_bonus_ratios;
    uint32[5] private duration_bonuses_10_5;

    constructor (
        PlatformToken token_, 
        Channels channels_contract_, 
        address operator_address_, 
        RewardPool operator_contract_,
        address owner_address_
    ) {
        platform_token = token_;
        operator_address = operator_address_;
        channels_contract = channels_contract_;
        operator_contract = operator_contract_;
        owner_address = owner_address_;
        
        for (uint i = 0; i < lock_periods.length; i++) {
            lock_period_seconds[LockPeriod(i)] = lock_periods[i];
            duration_bonus_ratios[LockPeriod(i)] = duration_bonuses_10_5[i];
        }
        delete lock_periods;
        delete duration_bonuses_10_5;
        // \/: pass channel_contract as par as well \- importing
    }

    // When functions of this contract are called by another contract's function that is called by the owner, the sender will still be the owner
    modifier onlyAuthorized {
        require (
            msg.sender == operator_address || msg.sender == address(this) || msg.sender == owner_address,
            "Only Channels and InvestmentMechanism contracts or the owner can call this function."
        ); 
        _;
    }

    event transactionReceipt (
        bytes32 subscription_id_,
        address indexed investor_, 
        address indexed beneficiary_,
        uint128 donated_,
        uint128 invested_
    );

    modifier investorAccess (bytes32 subscription_id_) {
        require (
            msg.sender == active_investments[subscription_id_].investor_address,
            "You can only access your investment through the wallet you initiated it with."
        );
        _;
    }
    // TD: test /\ channel actually received funds w attach->platformtoken.balanceOf()
    function sendAutomaticDonation (string memory channel_name_, uint64 donation_amount_) private {
        platform_token.transfer(address(channels_contract), donation_amount_);
        channels_contract.registerDonatedTokens(channel_name_, donation_amount_);
    }

    function investInChannel (
        uint128 commited_funds_, uint16 donation_modifier_, uint8 risk_modifier_100_, 
        LockPeriod lock_duration_, string memory channel_name_
    ) public {
        // lock_duration_ is converted in JS from UI options {30 days, 60 days, 90 days etc} into an integer of seconds
        require (0 < donation_modifier_ && donation_modifier_ <= 500, "Modifier value out of bounds");
        require (commited_funds_ > minimum_investment, "Amount cannot be lower than the current investment minimum.");
        
        Channel memory channel = channels_contract.getChannelByName(channel_name_); // \/: create getter ß ch addr-s
        uint lock_max_duration = lock_period_seconds[lock_duration_];
        uint128 to_donate = (commited_funds_ / 100) * (
            (1 + default_donation_percent / 100) * (1 + donation_modifier_ / 100)
        ) / 100;
        
        Investment memory investment_instance = Investment(
            keccak256(bytes.concat(
                abi.encodePacked(msg.sender), 
                "/", 
                abi.encodePacked(block.timestamp)
            )), // MT: generate hash in some other way, e.g. ++ random char x times
            channel_name_,
            msg.sender,
            commited_funds_, 
            commited_funds_ - to_donate - commited_funds_ / 1000 * platform_fee_10_3, //  ? do we even need a platform fee?
            channel.score,
            risk_modifier_100_,
            duration_bonus_ratios[lock_duration_],
            channel.popularity_modifier_10_5, // ßbind this w JS before letting user fill out rest of pars
            block.timestamp,
            block.timestamp + lock_max_duration,
            donation_modifier_
        );
        active_investments[investment_instance.subscription_id] = investment_instance;
        // ?: check func signature => ßtransferFrom user -> ßaddress(this) && ßapprove ˇ other contract
        sendAutomaticDonation(
            channel_name_, 
            uint64(commited_funds_ / 100) * (1 + default_donation_percent / 100) * (1 + donation_modifier_ / 100)
        );

        emit transactionReceipt( // JS shows these in the browser instance that this user is currently accessing
            investment_instance.subscription_id, 
            msg.sender, 
            channel.registered_withdraw_address == address(0) ? address(0) : channel.registered_withdraw_address, 
            to_donate, 
            investment_instance.invested_funds
        );
    }

    function calculateCurrentReward (
        bytes32 subscription_id_, int64 channel_modifier_10_5_
    ) private view returns (uint out_reward_) { // \/: use '~' ß uint<=>int casting
        // D: channel modifier sh only be calculated at the beginning of inv period & will stay th way until end; MT: it sh fluctuate to allow ß [++] diverse speculation
        Channel memory channel = channels_contract.getChannelByName(
            active_investments[subscription_id_].channel_name
        );
        Investment memory investment_instance = active_investments[subscription_id_];
        
        uint channel_score_difference_ratio_10_7_ = (
            channel.score - investment_instance.initial_score
        ) / investment_instance.initial_score;
        uint investment = investment_instance.invested_funds;
        uint256 lock_max_duration = investment_instance.lock_normal_end - investment_instance.lock_start;
        
        uint256 passed_duration;

        if (block.timestamp < investment_instance.lock_normal_end) {
            passed_duration = block.timestamp - investment_instance.lock_start;
        }
        else {
            passed_duration = lock_max_duration;
        }

        uint256 interest_ratio_per_second_10_10 = uint256(
            int256(1 + uint256(default_monthly_interest_10_3) / 1000).pow(1/*385802469e-7*/) * 10 ** 10
        ); // MT: change day value of 30 to a value that corresponds to amount of days in actual month when func is called
        // TD: test how to convert back after multiplying to an int
        uint256 accumulated_interest = passed_duration ** (interest_ratio_per_second_10_10 / 10 ** 10);
        out_reward_ = investment + investment * accumulated_interest 
            * (1 + uint64(channel_modifier_10_5_) / 1000) * channel_score_difference_ratio_10_7_ / 10 ** 7 
            * (1 + investment_instance.donation_modifier_10_2 / 100) * 11 / 10;
    }

    function calculateEarlyReward (bytes32 subscription_id_) public view returns (uint) {
        Investment memory investment_instance = active_investments[subscription_id_];
        
        uint reward = calculateCurrentReward(
            subscription_id_, 
            investment_instance.channel_popularity_modifier_10_5
        ); // D: how to retrieve channel's profit modifier? \/ write func ˇ Sol <= score
        return reward - reward * early_unlock_penalty_per_day_10_3 
            * block.timestamp - investment_instance.lock_start / 86400 / 1000;
    }

    function rebalanceTokenAllocation(address recipient_) public onlyAuthorized {
        uint sender_balance;
        if (recipient_ == address(this)) {
            sender_balance = platform_token.balanceOf(address(operator_contract)) / 2;
            requestFundsFromRewardPool(address(this), sender_balance);
        }
        else if (recipient_ == address(operator_contract)) {
            sender_balance = platform_token.balanceOf(address(this)) / 2;
            platform_token.transfer(address(operator_contract), sender_balance);
        }
    }

    function requestFundsFromRewardPool(address towards_, uint amount_) private {
        operator_contract.approveSendPoolTokens(
            towards_, 
            uint(amount_)
        );
        require (
            platform_token.allowance(operator_address, towards_) >= amount_,
            "This amount has not been approved from the side of the RewardPool contract."
        );
        platform_token.transferFrom(
            operator_address, 
            towards_, 
            uint(amount_)
        );
    }
    
    function unlockReward (bytes32 subscription_id_) public investorAccess(subscription_id_) {
        /* Subscription id is identified by the user being logged in on the website. 
        In order to complete the transaction, they have to connect their smart contract wallet */
        Investment memory investment_instance = active_investments[subscription_id_];
        require (
            investment_instance.lock_normal_end <= block.timestamp,
            "The staking period has not ended yet."
        );
        
        uint reward;
        if (block.timestamp < investment_instance.lock_normal_end) {
            reward = calculateEarlyReward(subscription_id_);
        }
        else {
            reward = calculateCurrentReward( // If they want to unlock early, they need to have their reward calculated differently
                subscription_id_,
                investment_instance.channel_popularity_modifier_10_5
            ) * (10 ** 7 + investment_instance.available_duration_bonus_10_5) / 10 ** 7;
        }
        uint profit = reward - investment_instance.invested_funds;

        if (platform_token.balanceOf(address(this)) < reward) {
            rebalanceTokenAllocation(address(this));
        }
        if (platform_token.balanceOf(address(operator_contract)) < reward) {
            rebalanceTokenAllocation(address(operator_contract));
        }

        if (profit < 0) {
            platform_token.transfer(address(0), uint(-1 * int(profit))); // burn funds that were lost due to channel performing below average
            platform_token.transfer(investment_instance.investor_address, uint(reward));
        }
        else {
            platform_token.transfer(
                investment_instance.investor_address, 
                uint(reward - profit)
            );
            requestFundsFromRewardPool(investment_instance.investor_address, profit);
        }
        
        delete active_investments[investment_instance.subscription_id];
    }
}