//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract Token is ERC20{
    using SafeMath for uint256;


    uint public constant supply = 500;

    struct Checkpoint { // TODO determine int size
        uint256 fromBlock;
        uint256 value;
    }

    // currently delegated percentage
    mapping(address => uint8) delegated;
    
    // history of account balance
    mapping(address => Checkpoint[]) balances;


    constructor() public ERC20("AB", "AB") {
        // mint some
        _updateValueAtNow(balances[msg.sender], supply);
        emit Transfer(address(0), msg.sender, supply);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) internal override {
        require(_sender != address(0), "ERC20: transfer from the zero address");
        require(_recipient != address(0), "ERC20: transfer to the zero address");

        uint256 currentSenderBalance = balanceOfAt(_sender, block.number);
        require (currentSenderBalance >= _amount, "Sender balance too small");

        uint256 currentRecipientBalance = balanceOfAt(_recipient, block.number);
        
        _updateValueAtNow(balances[_sender], currentSenderBalance.sub(_amount));
        _updateValueAtNow(balances[_recipient], currentRecipientBalance.add(_amount));

        emit Transfer(_sender, _recipient, _amount);
    }

    function balanceOf(address _account) public view override returns (uint256) {
        return balanceOfAt(_account, block.number);
    }

    function balanceOfAt(address _address, uint256 _blockNumber) public view returns(uint256) {
        return _getValueAt(balances[_address], _blockNumber);
    }

    
    

    

    /**
    *** DELEGATE
     */
    function delegate(address _delegatee, uint8 _percentage) public {
        require(_percentage <= 100, "Trying to delegate over 100%");
        require(_delegatee != msg.sender, "Trying to delegate to self");
        require(delegated[msg.sender].add(_percentage) <= 100, "Total delegation over 100%");
        delegated[msg.sender] += _percentage;

        // mapping (address => VoteCheckpoint[])
        // struct VoteCheckpoint => {fromBlock, list<Pair<Address, percents>}

        // 2nd approach
        // update 'external' voiting power each time balance changes - problems?
    }

    function votePowerOfAt(address _address, uint256 _block) public view returns(uint256) {  // TODO - uint256?
        require(block.number > _block, "Given block in the future");
        
        return 0; 
    } 

    /**
    ** INTERNAL FUNCTIONS
    */
    function _updateValueAtNow(Checkpoint[] storage checkpoints, uint _value) internal  {
        if ((checkpoints.length == 0) || (checkpoints[checkpoints.length -1].fromBlock < block.number)) {
            checkpoints.push(Checkpoint(block.number, _value));
        } else {
            checkpoints[checkpoints.length -1].value = _value;
        }
    }

    function _getValueAt(Checkpoint[] storage checkpoints, uint256 _blockNumber) internal view returns(uint256) {
        require(_blockNumber <= block.number, "Block is in the future");  // LESS OR LE

        uint nCheckpoints = checkpoints.length;
        if (nCheckpoints == 0) {
            return 0;
        }

        if (checkpoints[nCheckpoints - 1].fromBlock <= _blockNumber) {
            return checkpoints[nCheckpoints - 1].value;
        }

        if (checkpoints[0].fromBlock > _blockNumber) {
            return 0;
        }

        uint lower = 0;
        uint upper = nCheckpoints - 1;
        while (upper > lower) {
            uint center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[center];
            if (cp.fromBlock == _blockNumber) {
                return cp.value;
            } else if (cp.fromBlock < _blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[lower].value;
    }

}
