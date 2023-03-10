// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import "./PlatformToken.sol";
import "./ChannelEntity.sol";

contract Channels {
    uint64 public channels_created = 0;
    uint32 constant private score_exponent_factor = 7;
    PlatformToken private immutable platform_token;
    address private immutable contract_operator; // will allocate RewardPool
    address private immutable rewardpool;

    event emitWithdraw (
        string channel_name_, 
        address recipient_, 
        uint256 withdrawn_amount_
    );

    Channel private channel;
    mapping (string => Channel) internal channels; // requirement w/i register...() makes sure channel name is unique
    mapping (address => string) internal channel_address_to_name;
    mapping (address => bytes32) private channel_address_to_signature;
    mapping (string => bytes32) private channel_name_to_signature;

    constructor (PlatformToken token_, address contract_operator_, address rewardpool_) {
        platform_token = token_;
        contract_operator = contract_operator_;
        rewardpool = rewardpool_;
    }

    modifier onlyAuthorized {
        require (
            msg.sender == contract_operator || msg.sender == address(this) || msg.sender == rewardpool,
            "Only Channels and RewardPool contracts can call this function."
        ); 
        _;
    }

    function shouldBeSuccessful(bool transfer_result_) private pure {
        require (
            transfer_result_ == true,
            "The transfer was not succesful."
        );
    }

    function getChannelByName (string memory channel_name_) onlyAuthorized 
        public view returns (Channel memory) // if output is array-like, storage location also has to be specified here
    {
        return channels[channel_name_];
    }

    function getChannelByAddress (address channel_address_) onlyAuthorized // Should only be called if Channel already has address
        external view returns (Channel memory) // if output is array-like, storage location also has to be specified here
    {
        return channels[channel_address_to_name[channel_address_]];
    }

    function setChannelScore (
        string memory channel_name_, 
        uint32 new_score_
    ) onlyAuthorized public view {
        Channel memory temp_channel = getChannelByName(channel_name_);
        temp_channel.score = new_score_ * uint64(10) ** score_exponent_factor;
    }

    function viewChannelScore (string memory channel_name_) public view returns (uint64) {
        Channel memory temp_channel = getChannelByName(channel_name_);
        return temp_channel.score;
    }

    function setChannelModifierValue (
        string memory channel_name_, int64 new_value_
    ) onlyAuthorized public view {
        Channel memory temp_channel = getChannelByName(channel_name_);
        temp_channel.popularity_modifier_10_5 = new_value_;
    }

    function viewChannelModifierValue (string memory channel_name_) public view returns (int64) {
        Channel memory temp_channel = getChannelByName(channel_name_);
        return temp_channel.popularity_modifier_10_5 / 10 ** 5;
    }

    function generateOwnerSignature (string memory channel_name_) private returns (bytes32) { 
        bytes32 temp_signature = sha256(bytes(channel_name_));
        channel_name_to_signature[channel_name_] = temp_signature;
        return temp_signature;
    }

    function registerNewChannel (string memory channel_name_) public onlyAuthorized returns (bytes32) { // validate existing struct w name by asking about certain attributes of it (does this name exist already)
        require (
            channels[channel_name_].id == 0, 
            "Channel with provided name has already been registered."
        );
        channels_created += 1;
        bytes32 temp_channel_signature = generateOwnerSignature(channel_name_);
        
        Channel memory temp_channel = Channel(channels_created, 1, 0, 0, address(0));
        channels[channel_name_] = temp_channel;
        channel_name_to_signature[channel_name_] = temp_channel_signature;
        return temp_channel_signature; // ?: memory vs calldata
    }

    function changeWithdrawAddressFromAddress (string calldata channel_name_, address new_address_) public {
        // Verifies if channel address is being modified by its rightful owner
        require (
            channels[channel_name_].registered_withdraw_address != address(0),
            "There is no address registered for this channel yet. "
            "An address can only be registered by using the function that takes the signature of the channel as an input."
        );
        require (
            msg.sender == channels[channel_name_].registered_withdraw_address,
            "Can only be modified from the address currently registered for the channel."
        );
        channel_address_to_name[new_address_] = channel_name_;
        delete channel_address_to_name[msg.sender];
        channel_address_to_signature[new_address_] = channel_address_to_signature[channels[channel_name_].registered_withdraw_address];
        delete channel_address_to_signature[msg.sender];
        channels[channel_name_].registered_withdraw_address = new_address_;
    }

    function changeWithdrawAddressBySignature (
        string calldata channel_name_, 
        bytes32 signature_, 
        address new_address_
    ) public {
        require (
            signature_ == channel_name_to_signature[channel_name_],
            "The signature input does not match what is stored for a channel with this name."
        );
        channel_address_to_name[new_address_] = channel_name_;
        channel_address_to_signature[new_address_] = signature_;
        // Verifies if channel address is being modified by its rightful owner, but only if a cryptocurrency wallet has already been registered for this channel
        if (channels[channel_name_].registered_withdraw_address != address(0)) {
            require (
                channel_address_to_signature[channels[channel_name_].registered_withdraw_address] == signature_,
                "The signature input does not match what is registered for this channel."
            );
        }
        delete channel_address_to_name[channels[channel_name_].registered_withdraw_address];
        delete channel_address_to_signature[channels[channel_name_].registered_withdraw_address];
        channels[channel_name_].registered_withdraw_address = new_address_;
    }

    function registerDonatedTokens (string memory channel_name_, uint128 donated_amount_) public onlyAuthorized { // channel contract receives tokens from users investing -> keeps account address => of sum of amounts
        channels[channel_name_].accumulated_donations += donated_amount_;
    } // TD: contract operator needs to be able to access this <-> needs to be restricted from normal users -> inheritance? -> RP::parent

    function withdrawChannelDonations (
        uint256 amount_out_, 
        string calldata channel_name_, 
        address withdraw_address_
    ) onlyAuthorized public {
        require (
            withdraw_address_ == channels[channel_name_].registered_withdraw_address 
                && channels[channel_name_].registered_withdraw_address != address(0),
            "Unauthorized to withdraw to address other than the registered one for this channel. "
            "If you are the channel owner, please retry or change your withdraw address. "
            'If you did not register your address yet, do so by pressing the button "Change/set withdraw address using signature".'
        );
        require (
            amount_out_ >= channels[channel_name_].accumulated_donations, 
            "You have less tokens registered than what you intended to withdraw."
        );
        channels[channel_name_].accumulated_donations -= amount_out_;
        shouldBeSuccessful(platform_token.transfer(withdraw_address_, amount_out_)); // tokens will get allocated to RP again where they will be available for purchase
        // actually send tokens to RewardPool after accounting, they will become available for sale
        emit emitWithdraw(channel_name_, withdraw_address_, amount_out_);
    } // is called (only by RewardPool) to reduce amount of tokens while RewardPool transfers ETH (later BNB) to the channel owner's external address
}