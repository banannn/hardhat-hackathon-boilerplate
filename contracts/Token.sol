//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract Token is ERC20{
    using SafeMath for uint256;

    uint public constant supply = 500;

    struct Checkpoint {
        uint256 fromBlock;
        uint256 value;
    }

    // history of account balance
    mapping(address => Checkpoint[]) balances;

    // total delegated percents per address at given time
    mapping(address => Checkpoint[]) totalDelegated;
    // delegator => delegatee => percent
    mapping(address => mapping(address => uint256)) delegations;   
    // all current delegatees of address
    mapping(address => address[]) public delegatees;
    // cumulated delegated voting power to address
    mapping(address => Checkpoint[]) delegatedVotingPower;

    constructor() public ERC20("AB", "AB") {
        // mint some
        _updateValueAtNow(balances[msg.sender], supply);
        emit Transfer(address(0), msg.sender, supply);
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
        
        // get current values
        uint nowTotalDelegated = _getValueAt(totalDelegated[msg.sender], block.number);
        uint nowDelegatedToAddress = delegations[msg.sender][_delegatee];
        
        if(nowDelegatedToAddress == 0) {
            require(delegatees[msg.sender].length < 5, "Maximum 5 delegatees");
        }

        // update delegatee value
        require(nowTotalDelegated.sub(nowDelegatedToAddress).add(_percentage) <= 100, "Total delegation over 100%");
        _updateValueAtNow(totalDelegated[msg.sender], nowTotalDelegated.sub(nowDelegatedToAddress).add(_percentage));
        delegations[msg.sender][_delegatee] = _percentage;

        // update delegatee voting power
        uint sendersBalance = balanceOf(msg.sender);
        uint currentContribution = nowDelegatedToAddress.mul(sendersBalance).div(100); 
        uint power = sendersBalance.mul(_percentage).div(100);
        uint currentDelegatedPower = _getValueAt(delegatedVotingPower[_delegatee], block.number);
        _updateValueAtNow(delegatedVotingPower[_delegatee], currentDelegatedPower.add(power).sub(currentContribution));

        // update delegates list
        if (_percentage == 0) _removeFromArray(delegatees[msg.sender], _delegatee);
        else if (nowDelegatedToAddress == 0) delegatees[msg.sender].push(_delegatee);
    }

    function votePowerOfAt(address _address, uint256 _block) public view returns(uint256) { 
        require(block.number > _block, "Given block in the future");
        uint balance = balanceOfAt(_address, _block); 
        uint delegatedPowerOfAddress = balance.mul(_getValueAt(totalDelegated[_address], _block)).div(100);
        return balance.sub(delegatedPowerOfAddress).add(_getValueAt(delegatedVotingPower[_address], _block));
    } 

    /**
    ** INTERNAL FUNCTIONS
    */
    function _transfer(address _sender, address _recipient, uint256 _amount) internal override {
        require(_sender != address(0), "ERC20: transfer from the zero address");
        require(_recipient != address(0), "ERC20: transfer to the zero address");

        uint256 currentSenderBalance = balanceOfAt(_sender, block.number);
        require (currentSenderBalance >= _amount, "Sender balance too small");

        uint256 currentRecipientBalance = balanceOfAt(_recipient, block.number);
        
        _updateValueAtNow(balances[_sender], currentSenderBalance.sub(_amount));
        _updateValueAtNow(balances[_recipient], currentRecipientBalance.add(_amount));

        // update delegated power
        _updateVotingPower(_sender, currentSenderBalance, currentSenderBalance.sub(_amount));
        _updateVotingPower(_recipient, currentRecipientBalance, currentRecipientBalance.add(_amount));

        emit Transfer(_sender, _recipient, _amount);
    }

    // update delegatees voting power on balance change
    function _updateVotingPower(address _address, uint256 previousBalance, uint256 currentBalance) internal {
        for(uint i=0; i<delegatees[_address].length; i++) {
            uint256 previousContribution = delegations[_address][delegatees[_address][i]].mul(previousBalance).div(100);
            uint256 currentContribution = delegations[_address][delegatees[_address][i]].mul(currentBalance).div(100);
            uint256 newVotingPower = _getValueAt(delegatedVotingPower[delegatees[_address][i]], block.number).sub(previousContribution).add(currentContribution);
            _updateValueAtNow(delegatedVotingPower[delegatees[_address][i]], newVotingPower);
        }
    }

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

    function _removeFromArray(address[] storage _array, address _addr) internal {
        for (uint8 i=0; i < _array.length; i++) {
            if (_array[i] == _addr) {
                if (i != _array.length - 1) { // first in 1-elem array, or last elem in array
                    _array[i] = _array[_array.length-1];
                }
                _array.pop();
                return;
            }
        }
    }

}
