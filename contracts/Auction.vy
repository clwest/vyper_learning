# @version ^0.3.1
#Open Auction


# Auction Params
# Beneficiary recieves money from the highest bidder for

beneficiary: public(address)
auctionStart: public(uint256)
auctionEnd: public(uint256)

# Current state of the auction 
highestBidder: public(address)
highestBid: public(uint256)

# set to true at the end of the auction 
ended: public(bool)

# Keep track of the refunded bids so we can follow the withdraw pattern
pendingReturns: public(HashMap[address, uint256])

# Create a simply auction with the _auction_start
## _bidding_time seconds bidding time on behalf of the beneficiary address

@external
def __init__(_beneficiary: address, _auction_start: uint256, _bidding_time: uint256):
    self.beneficiary = _beneficiary
    self.auctionStart = _auction_start
    self.auctionEnd = self.auctionStart + _bidding_time
    assert block.timestamp < self.auctionEnd

#Bid on auctions with the value sent
# together with this transaction
# The value will only be refunded if the auction is not won!

@external
@payable
def bid():
    assert block.timestamp >= self.auctionStart
    assert block.timestamp < self.auctionEnd
    assert msg.value > self.highestBid

    self.pendingReturns[self.highestBidder] += self.highestBid
    self.highestBidder = msg.sender
    self.highestBid = msg.value

# Withdraw a previously refunded bid
# used here to avoid security issuse. If refunds were directly
# sent as part of bid() a malicious bidding contract could block
# those refunds and thus block new higher bids from coming in
@external
def withdraw():
    pending_amount: uint256 = self.pendingReturns[msg.sender]
    self.pendingReturns[msg.sender] = 0
    send(msg.sender, pending_amount)

# End the auction and send the highest bid to the beneficiary

@external
def endAuction():
    # It is good guidelines to structure functions that interact 
    # with other contracts i.ed they call functions or send Ether
    # into three phases:
    # 1. checking conditions
    # 2. performing actions (potnetially changing conditions)
    #. If the phases are mixed up the other contract could call back
    # into the current contract and modify the state or cause 
    # effects (Ether Payouts) to be performed multiple times.
    # If functions called internally include interactions with 
    # extrenal contracts

    # 1. Conditions
    # Check if the auctions endtime has been reached
    assert block.timestamp >= self.auctionEnd
    # Check if the function has already been called
    assert not self.ended

    #2. #Effects 
    self.ended = True

    #3 Interactions 
    send(self.beneficiary, self.highestBid)


