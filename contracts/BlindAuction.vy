# Blind Auction
# @version ^0.3.1

struct Bid:
    blindedBid: bytes32
    deposit: uint256

#Note: because Vyper does not allow for dynamic arrays. we have limited the 
# number of bids that can be placed by one address to 128 in this example.
MAX_BIDS: constant(int128) = 128

# Event for logging that auction has ended
event AuctionEnded: 
    highestBidder: address
    highestBid: uint256

# Auction Parameters
beneficiary: public(address)
biddingEnd: public(uint256)
revealEnd: public(uint256)

# Set to true at the end of auction, disallowing any new bigs
ended: public(bool)

# Final auction state
highestBid: public(uint256)
highestBidder: public(address)

# State of bids
bids: HashMap[address, Bid[128]]
bidCounts: HashMap[address, int128]

# Allowed withdrawals of previos bids
pendingReturns: HashMap[address, uint256]

# Create a blined auction with _biddingTime seconds bidding time and 
# _revealTime seconds reveal time on behalf of beneficiary address
# _beneficiary

@external
def __init__(_beneficiary: address, _biddingTime: uint256, _revealTime: uint256):
    self.beneficiary = _beneficiary
    self.biddingEnd = block.timestamp + _biddingTime
    self.revealEnd = self.biddingEnd + _revealTime

# Place a blinded bid with:
# _blindedBid = keccak256(concat(
    # convert(value, bytes32),
#   convert(fake, bytes32)
#   secret)
#)
# The ether sent is only refunded if the bid is correctly revealed in the
# revel phase.  The bid is valid if the ether sent together with the bid is
# at least "value" and "fake" is not true.  Setting fake to true and sedning
# not the exact amount are ways to hide the real bid but still make teh 
# required deposi, The same address can place multiple bids.

@external
@payable
def bid(_blindedBid: bytes32):
    # Check if bidding period is still open
    assert block.timestamp < self.biddingEnd

    # Check that payer hasn't already placed maximum number of bids
    numBids: int128 = self.bidCounts[msg.sender]
    assert numBids < MAX_BIDS

    # Add bid to mapping of all bids
    self.bids[msg.sender][numBids] = Bid({
        blindedBid: _blindedBid,
        deposit: msg.value
    })
    self.bidCounts[msg.sender] += 1

# Returns a boolean value, "True" if the bid was sucessfully False otherwise
@internal
def placeBid(bidder: address, _value: uint256) -> bool:
    # If bid is less than highest bid bid fails
    if (_value <= self.highestBid):
        return False

    # Refund previous bidder
    if (self.highestBidder != ZERO_ADDRESS):
        self.pendingReturns[self.highestBidder] += self.highestBid

    # Place bid successfully and update auction State
    self.highestBid = _value
    self.highestBidder = bidder
    return True

# Reveal your blinded bids.  You will get a refund for all vorrectly blinded
# invalid bids and for all bids except for the totally highest

@external
def reveal(_numBids: int128, _values: uint256[128], _fakes: bool[128], _secrets: bytes32[128]):
    # Check that the bidding period is over
    assert block.timestamp > self.biddingEnd

    # Check that reveal end has not beed passed
    assert block.timestamp < self.revealEnd

    # Check that number of bids being revealed matches log for sender
    assert _numBids == self.bidCounts[msg.sender]

    # Calculate refund for sender
    refund: uint256 = 0
    for i in range(MAX_BIDS):
        # Note that loop may break sooner than 128 iterations if i >= _numBids
        if (i >= _numBids):
            break
        
        # Get bid to Check
        bidToCheck: Bid = (self.bids[msg.sender])[i]

        #Check against encoded packet
        value: uint256 = _values[i]
        fake: bool = _fakes[i]
        secret: bytes32 = _secrets[i]
        blindedBid: bytes32 = keccak256(concat(
            convert(value, bytes32),
            convert(fake, bytes32),
            secret
        ))
        # Bid was not actually revealed 
        # Do not refund deposit
        if (blindedBid != bidToCheck.blindedBid):
            assert 1 == 0
            continue
            
        # Add deposit to refund if bid ws indeed revealed
        refund += bidToCheck.deposit
        if (not fake and bidToCheck.deposit >= value):
            if (self.placeBid(msg.sender, value)):
                refund -= value
                
        # Make it impossible for the sender to re-claim their same deposit
        zeroBytes32: bytes32 = EMPTY_BYTES32
        bidToCheck.blindedBid = zeroBytes32

        # Send refund if non-zero
    if (refund != 0):
        send(msg.sender, refund)
@external
def withdraw():
    # Check that there is an allowed pending return
    pendingAmount: uint256 = self.pendingReturns[msg.sender]
    if (pendingAmount > 0):
        # If so set pending returns to zero to prevent recipient from calliing
        # this function again as part of hte recieving call before "transfer"
        # rturns (see the remark above about conditions -> effects -> interactions)
        self.pendingReturns[msg.sender] = 0

        # Then send returns
        send(msg.sender, pendingAmount)

# End the auctions
@external
def auctionEnd():
    # Check that reveal end has passed
    assert block.timestamp > self.revealEnd

    # Check that auction has not already been marked as encoded
    assert not self.ended

    # Log auction ending and set flag
    log AuctionEnded(self.highestBidder, self.highestBid)
    self.ended = True

    #Transfer funds to beneficiary
    send(self.beneficiary, self.highestBid)