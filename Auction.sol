// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Auction {
    address payable public beneficiary;
    uint public auctionEndTime;

    address public highestBidder;
    uint public highestBid;

    mapping(address => uint) pendingReturns;

    bool public ended;
    bool public sellerConfirmed;
    bool public winnerConfirmed;

    uint public confirmationDeadline; // thời điểm timeout để hủy

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);
    event AuctionCanceled(string reason);

    constructor(uint _biddingTime, address payable _beneficiary) {
        beneficiary = _beneficiary;
        auctionEndTime = block.timestamp + _biddingTime;
    }

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

    // Xác nhận từ người thắng
    function confirmReceivedByWinner() public {
        require(msg.sender == highestBidder, "Only winner can confirm.");
        require(block.timestamp >= auctionEndTime, "Auction hasn't ended yet.");
        winnerConfirmed = true;
        _checkConfirmationDeadline();
    }

    // Xác nhận từ người bán
    function confirmDeliveryBySeller() public {
        require(msg.sender == beneficiary, "Only seller can confirm.");
        require(block.timestamp >= auctionEndTime, "Auction hasn't ended yet.");
        sellerConfirmed = true;
        _checkConfirmationDeadline();
    }

    // Kiểm tra nếu cả hai đã xác nhận thì đặt deadline timeout
    function _checkConfirmationDeadline() internal {
        if (sellerConfirmed || winnerConfirmed) {
            if (confirmationDeadline == 0) {
                confirmationDeadline = block.timestamp + 3 days;
            }
        }
    }

    function auctionEnd() public {
        require(block.timestamp >= auctionEndTime, "The auction hasn't ended yet.");
        require(!ended, "auctionEnd has already been called.");
        require(sellerConfirmed && winnerConfirmed, "Both parties must confirm.");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);
        beneficiary.transfer(highestBid);
    }

    // Hàm hủy nếu timeout và chỉ 1 bên xác nhận
    function cancelAuction() public {
        require(block.timestamp >= confirmationDeadline, "Confirmation period not expired.");
        require(!ended, "Auction already ended.");

        // Nếu chỉ 1 bên xác nhận thì mới cho hủy
        require(
            (sellerConfirmed && !winnerConfirmed) || (!sellerConfirmed && winnerConfirmed),
            "Cannot cancel if both or neither confirmed."
        );

        ended = true;
        emit AuctionCanceled("Timeout reached. Auction canceled.");
        payable(highestBidder).transfer(highestBid);
    }

    // Hàm tiện ích để xem thời gian còn lại
    function getTimeLeft() public view returns (uint minutesLeft, uint secondsLeft) {
        if (block.timestamp >= auctionEndTime) {
            return (0, 0);
        }
        uint timeLeft = auctionEndTime - block.timestamp;
        minutesLeft = timeLeft / 60;
        secondsLeft = timeLeft % 60;
    }
}
