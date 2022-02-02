# @version ^0.3.1

# Safe Escrow from vyper docs

# Rundown of the transaction
# 1. Seller posts item for sale and posts safety deposit of double teh item value
#    Balance is 2*value
# 2. Buyer purchases item (value) plus posts an additional safety deposit (Item Value)
#    Balance is 4*value
# 3. Seller ships item
# 4. Buyer confirms recieving the item. Buyers depost (value) is returned
#    Seller's deposit (2x value) + items value is returned. Balance is 0

value: public(uint256) # Value of the item
seller: public(address) 
buyer: public(address)
unlocked: public(bool)
ended: public(bool)

@external
@payable
def __init__():
    assert (msg.value % 2) == 0
    self.value = msg.value / 2 # The seller initializes the contract by 
                                # posting a safety deposit of 2*value of the item for sale
    self.seller = msg.sender
    self.unlocked = True

@external
def abort():
    assert self.unlocked # is the contract refundable
    assert msg.sender == self.seller # Only the seller can refund
        # his deposit before any buyer purchases the item
    selfdestruct(self.seller) # refunds the seller and deletes the contract

@external
@payable
def purchase():
    assert self.unlocked # is the contract still open and for sell
    assert msg.value == (2 * self.value) # Buyer posts the deposit of 2*value
    self.unlocked = False

@external
def recieved():
    # 1. Conditions
    assert not self.unlocked # ist he item already purchased and pending
    assert msg.sender == self.buyer
    assert not self.ended

    # Effects
    self.ended = True

    # 3. Interactions
    send(self.buyer, self.value) # Returns teh buyer's deposit (=value) to the buyer
    selfdestruct(self.seller) # Returns the sellers deposit (=2*value) to the seller and teh 
                            # purchase price (=value) to the seller