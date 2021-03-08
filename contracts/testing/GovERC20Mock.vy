# @version ^0.2.0
"""
@notice Mock ERC20 for testing with COMP governance
"""

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256
# Event related to delegation
event DelegateVotesChanged:
    _delegate: indexed(address)
    _previousBalance: uint256
    _newBalance: uint256

event DelegateChanged:
    _delegator: indexed(address)
    _fromDelegate: indexed(address)
    _toDelegate: indexed(address)

name: public(String[64])
symbol: public(String[32])
decimals: public(uint256)
balanceOf: public(HashMap[address, uint256])
allowances: HashMap[address, HashMap[address, uint256]]
total_supply: uint256

# State related to delegation
struct Checkpoint:
    fromBlock: uint256
    votes: uint256

delegates: public(HashMap[address, address])
checkpoints: public(HashMap[address, HashMap[uint256, Checkpoint]])
numCheckpoints : public(HashMap[address, uint256])

@external
def __init__(_name: String[64], _symbol: String[32], _decimals: uint256):
    self.name = _name
    self.symbol = _symbol
    self.decimals = _decimals


@external
@view
def totalSupply() -> uint256:
    return self.total_supply


@external
@view
def allowance(_owner : address, _spender : address) -> uint256:
    return self.allowances[_owner][_spender]


@external
@view
def getCurrentVotes(account: address) -> uint256:
    nCheckpoints : uint256 = self.numCheckpoints[account]
    votes : uint256 = 0
    if(nCheckpoints > 0) :
        votes = self.checkpoints[account][nCheckpoints - 1].votes
    return votes


@internal
def _writeCheckpoint(delegatee : address, nCheckpoints : uint256, oldVotes : uint256, newVotes : uint256) :
    if(nCheckpoints > 0 and self.checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) :
        self.checkpoints[delegatee][nCheckpoints - 1].votes = newVotes
    else :
        self.checkpoints[delegatee][nCheckpoints] = Checkpoint({fromBlock: block.number, votes: newVotes})
        self.numCheckpoints[delegatee] = nCheckpoints + 1
    log DelegateVotesChanged(delegatee, oldVotes, newVotes)


@internal
def _moveDelegates(srcRep : address, dstRep : address, amount : uint256) :
    if(srcRep != dstRep and amount > 0) :
        if(srcRep != ZERO_ADDRESS) :
            srcRepNum : uint256 = self.numCheckpoints[srcRep]
            srcRepOld : uint256 = 0
            if(srcRepNum > 0) :
                srcRepOld = self.checkpoints[srcRep][srcRepNum - 1].votes
            srcRepNew : uint256 = srcRepOld - amount
            self._writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew)
        if(dstRep != ZERO_ADDRESS) :
            dstRepNum : uint256 = self.numCheckpoints[dstRep]
            dstRepOld : uint256 = 0
            if(dstRepNum > 0) :
                dstRepOld = self.checkpoints[dstRep][dstRepNum - 1].votes
            dstRepNew : uint256 = dstRepOld + amount
            self._writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew)


@internal
def _delegate(delegator : address, delegatee : address) :
    currentDelegate : address = self.delegates[delegator]
    delegatorBalance : uint256 = self.balanceOf[delegator]
    self.delegates[delegator] = delegatee
    log DelegateChanged(delegator, currentDelegate, delegatee)
    self._moveDelegates(currentDelegate, delegatee, delegatorBalance)


@external
def transfer(_to : address, _value : uint256) -> bool:
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value
    log Transfer(msg.sender, _to, _value)
    # COMP Move Delegate
    self._moveDelegates(msg.sender, _to, _value)
    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    self.allowances[_from][msg.sender] -= _value
    log Transfer(_from, _to, _value)
    # COMP Move Delegate
    self._moveDelegates(_from, _to, _value)
    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    self.allowances[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True

@external
def delegate(delegatee : address) :
    self._delegate(msg.sender, delegatee)


@external
def _mint_for_testing(_target: address, _value: uint256) -> bool:
    self.total_supply += _value
    self.balanceOf[_target] += _value
    log Transfer(ZERO_ADDRESS, _target, _value)
    return True
