// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Auction {
    address payable public beneficiary;
    uint public auctionEndTime;

    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) pendingReturns;
    bool ended;

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    /// Khởi tạo phiên đấu giá với số phút và giây.
    constructor(uint biddingMinutes, uint biddingSeconds, address payable _beneficiary) {
        beneficiary = _beneficiary;
        uint totalSeconds = biddingMinutes * 60 + biddingSeconds;
        auctionEndTime = block.timestamp + totalSeconds;
    }

    /// Đặt giá
    function bid() public payable {
        require(block.timestamp <= auctionEndTime, "The auction has already ended.");
        require(msg.value >= highestBid, "There's already a higher bid. Try bidding higher!");

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value);
    }

    /// Rút lại tiền nếu bị trả giá cao hơn
    function withdraw() public returns (bool) {
        uint amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            if (!payable(msg.sender).send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    /// Kết thúc phiên đấu giá
    function auctionEnd() public {
        require(block.timestamp >= auctionEndTime, "The auction hasn't ended yet.");
        require(!ended, "auctionEnd has already been called.");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        beneficiary.transfer(highestBid);
    }

    /// ❓ Xem còn lại bao nhiêu phút và giây
    function getTimeRemaining() public view returns (uint minutesLeft, uint secondsLeft) {
        if (block.timestamp >= auctionEndTime) {
            return (0, 0);
        }

        uint timeLeft = auctionEndTime - block.timestamp;
        minutesLeft = timeLeft / 60;
        secondsLeft = timeLeft % 60;
    }
}
