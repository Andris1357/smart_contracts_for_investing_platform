// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "./Channels.sol";
import "./PlatformToken.sol";
import "./ChannelEntity.sol";
import "./InvestmentMechanism.sol";

contract RewardPool {
    PlatformToken public immutable platform_token; // /\: shouldnt these be private?
    Channels public immutable channel_contract;
    InvestmentMechanism public immutable investing_contract;
    Channel private channel;

    // Owner represents the website's crypto wallet that will modify channel scores and "overbought" modifiers to externally calculated values
    address private immutable owner_address;
    address private immutable token_address;
    address private immutable channel_contract_address;
    address private immutable investing_contract_address;
    uint32 public constant token_price = 5000; // in wei; later substitute for price of token derived from PancakeSwap BNB liquidity pair via an oracle

    constructor () {
        owner_address = msg.sender;
        platform_token = new PlatformToken(address(this)); // token contract will only be deployed once
        token_address = address(platform_token);
        channel_contract = new Channels(platform_token, address(this));
        channel_contract_address = address(channel_contract);
        investing_contract = new InvestmentMechanism(
            platform_token, 
            channel_contract, 
            address(this), 
            this, 
            owner_address
        );
        investing_contract_address = address(investing_contract);
    }

    receive() external payable {} // contract can receive ETH
    fallback() external payable {}

    modifier callOnlyFromWebsite() {
        require (msg.sender == owner_address);
        _;
    }
    //TD: git add remote
    event currentPriceRequested(
        uint token_amount_,
        address investor_address_
    );

    function setChannelScore (
        string memory channel_name_, uint32 new_score_
    ) callOnlyFromWebsite public view {
        channel_contract.setChannelScore(channel_name_, new_score_);
    }

    function setChannelModifierValue (
        string memory channel_name_, int64 new_value_
    ) callOnlyFromWebsite public view {
        channel_contract.setChannelModifierValue(channel_name_, new_value_);
    }

    function registerNewChannel (string calldata channel_name_) public callOnlyFromWebsite {
        channel_contract.registerNewChannel(channel_name_);
    }

    function mintNewTokens () public callOnlyFromWebsite {
        platform_token.mintPeriodically();
    }

    function buyTokens (uint256 amount_to_buy_) public payable { // operated by user
        require (msg.value >= amount_to_buy_ * token_price * 1 wei, "You have not committed enough ETH to the transaction.");
        platform_token.transfer(payable(msg.sender), amount_to_buy_); // transfer tokens to user in exchange for ETH received
    }
    function sellTokens (uint256 amount_to_sell_) public payable { // operated by user
        require (platform_token.balanceOf(msg.sender) >= amount_to_sell_, "Token balance is too low.");
        payable(msg.sender).transfer(amount_to_sell_ * uint256(token_price) * 1 wei); // transfers ETH (later BNB) to user wallet
    }

    function withdrawChannelFunds (uint256 amount_, string memory channel_name_) public payable { // implements Channels.withdrawChannelDonations
        require (
            channel_contract.getChannelByName(channel_name_).registered_withdraw_address != address(0),
            "There is no address registered for this channel yet. "
            'An address can be registered by pressing the button "Change/set withdraw address using signature".'
        );
        Channel memory tmp_channel = channel_contract.getChannelByName(channel_name_);
        require (msg.sender == tmp_channel.registered_withdraw_address);
        address payable tmp_withdraw_address = payable(tmp_channel.registered_withdraw_address);
        channel_contract.withdrawChannelDonations(amount_, channel_name_, tmp_withdraw_address); // this function contains 3 requirements that will make this func fail as well if not met
        tmp_withdraw_address.transfer(amount_ * uint256(token_price) * 1 wei);
    }
    function withdrawChannelTokens (uint256 amount_, string memory channel_name_) public {
        require (
            channel_contract.getChannelByName(channel_name_).registered_withdraw_address != address(0),
            "There is no address registered for this channel yet. "
            'An address can be registered by pressing the button "Change/set withdraw address using signature".'
        );
        Channel memory tmp_channel = channel_contract.getChannelByName(channel_name_);
        require (msg.sender == tmp_channel.registered_withdraw_address); // only channel owner
        channel_contract.withdrawChannelDonations(amount_, channel_name_, tmp_channel.registered_withdraw_address);
        platform_token.transfer(tmp_channel.registered_withdraw_address, amount_);
    }
    // ?: are there occasions where this func sh be called fr outside? -> ßrequire >> {_.address}
    function approveSendPoolTokens (address recipient_, uint amount_) public { // /\: EITHER ßprivate & calls IM funcs after approved here | public & verifies caller as of IM's registered address
        require (
            msg.sender == investing_contract_address,
            "Only InvestmentMechanism contract can invoke approval of spending."
        );
        platform_token.approve(recipient_, amount_); // /\: create enum of contracts to approve spend twds -> mapping of [enum => addr]
    }

    function tradeUserTokens(uint token_amount_) public {
        require(
            platform_token.balanceOf(msg.sender) >= token_amount_,
            "You do not have as much tokens in your wallet as the amount you entered."
        );
        emit currentPriceRequested(token_amount_, msg.sender);
    }

    // Called after receiving priceRequested event, with the parameters extracted from it + live price from an oracle
    function routeUserTrade(
        uint token_amount_, 
        address investor_address_,
        uint current_price_
    ) public payable callOnlyFromWebsite {
        if (platform_token.balanceOf(address(this)) < token_amount_) {
            investing_contract.rebalanceTokenAllocation(address(this));
        }
        payable(investor_address_).transfer(token_amount_ * current_price_ * 1 wei);
    }

    // D: implem user<=>token funcs here
    // D: sends ETH (later BNB) to ChannelOwner upon request on Channels contract by external wallet (of the owner's)
}