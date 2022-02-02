# Financial events the contract logs
# @version ^0.3.1

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Buy:
    buyer: indexed(address)
    buy_order: uint256

event Sell:
    seller: indexed(address)
    sell_order: uint256

event Pay:
    vendor: indexed(address)
    amount: uint256

 # Initiate the variables for teh company and it's own shares
company: public(address)
totalShares: public(uint256)
price: public(uint256)

 # Store a ledger of stockholder holdings
holdings: HashMap[address, uint256]    

 # Set up the company 
@external
def __init__(_company: address, _total_shares: uint256, initial_price: uint256):
     assert _total_shares > 0
     assert initial_price > 0

     self.company = _company
     self.totalShares = _total_shares
     self.price = initial_price
     # The company holds all of the shares at first but can sell all of them!
     self.holdings[self.company] = _total_shares

# Find out how much stock the company holdings
@view
@internal
def _stockAvailable() -> uint256:
    return self.holdings[self.company]

# public function to allow external access to _stockAvailable
@view
@external
def stockAvailable() -> uint256:
    return self._stockAvailable()

# Give some value to the company and get stock in return
@external
@payable
def buyStock():
    # Note full amount is given to company (no fractional shares)
    # so be sure to send exact amount to buy shares
    buy_order: uint256 = msg.value / self.price # rounds down
    # check that there are enough shares to buy
    assert self._stockAvailable() >= buy_order

    #Take the shares off the market and give them to teh stockholder
    self.holdings[self.company] -= buy_order
    self.holdings[msg.sender] += buy_order
    # log the buy events
    log Buy(msg.sender, buy_order)

# Find out how much stock any address thats owned by someone 
@view
@internal
def _getHoldings(_stockholder: address) -> uint256:
    return self.holdings[_stockholder]

# Return teh amount the company has on hand in cash
@view
@external
def cash() -> uint256:
    return self.balance


# sell stock back to the company and get money back as eth
@external
def sellStock(sell_order: uint256):
    assert sell_order > 0 # Otherwise this would fail at send() below
    # due to an OOG error (there would be zero value available for gas)
    # You can only sell the amount of stock you owned
    assert self._getHoldings(msg.sender) >= sell_order
    # check that the company can pay You
    assert self.balance >= (sell_order * self.price)
    # Sell the stock and send teh proceseds to the user
    # put the shares back on the market
    self.holdings[msg.sender] -= sell_order
    self.holdings[self.company] += sell_order
    send(msg.sender, sell_order * self.price)

    # Log sell order
    log Sell(msg.sender, sell_order)


# Transfer stock from one stockholder to another Assumme that the 
# reciver is given some compenstaion but this is not enforced
@external
def transferStock(receiver: address, transfer_order: uint256):
    assert transfer_order > 0 # Same as sell stockholder
    # similarly you can only trade as much stock as you own
    assert self._getHoldings(msg.sender) >= transfer_order

    # debit the senders stock and add to the buyers address
    self.holdings[msg.sender] -= transfer_order
    self.holdings[receiver] += transfer_order

    # Log the transfer event
    log Transfer(msg.sender, receiver, transfer_order)



# Allow the company to pay someone for services rendered
@external
def billPay(vendor: address, amount: uint256):
    #only the compay can pay someone
    assert msg.sender == self.company
    # also it can only pay if there's enough to pay them
    assert self.balance >= amount

    # pay the bill
    send(vendor, amount)

    # Log the payment event
    log Pay(vendor, amount)

# Return the amount in wei taht a company has raised in the stock offerings
@view
@internal
def _debt() -> uint256:
    return (self.totalShares - self._stockAvailable()) * self.price

# Public function to allow external access to _debet
@view
@external
def debt() -> uint256:
    return self._debt()

# Return the cash holdings minus teh debt of the company
# The share debt or liability only is inclued here
# but of course all other liabilities can be included
@view
@external
def worth() -> uint256:
    return self.balance - self._debt()