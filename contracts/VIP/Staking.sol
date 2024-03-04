// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract Staking is ReentrancyGuard, Ownable {
    IERC20 public stakingToken;
    uint256 public rewardInterval = 30 days;

    struct Stake{
        uint256 amount;
        uint256 startTime;
        uint256 lockTime;
    }

    mapping(address => Stake) public stakes;

    event Staked(address indexed user, uint256 amount, uint256 startTime, uint256 lockTime);
    event Unstaked(address indexed user, uint256 amount);

    constructor(IERC20 _stakingToken){
        stakingToken = _stakingToken;
    }

    function setRewardInterval(uint256 _interval) public {
        require(msg.sender == admin, "Only admin can change interval");
        rewardInterval = _interval;
    }

    function stake(uint256 _amount, uint256 _days) external {
        require(_days == 7 || _days == 14 || _days == 30, "Invalid staking duration");
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Stake Failed");

        if(stakes[msg.sender].amount > 0){

        }

        stakes[msg.sender] = Stake(_amount, block.timestamp, _days * 1 days);
        emit Staked(msg.sender, _amount, block.timestamp, _days * 1 days);
    }

    function unstake() external {
        Stake storage userStake = stakes[msg.sender];
        require(block.timestamp >= userStake.startTime + userStake.lockTime, "Lockup period not yet passed);

        uint256 amount = userStake.amount;
        require(amount > 0, "No staked amount");

        uint256 rewards = calculateRewards(msg.sender);

        require(stakingToken.transfer(msg.sender, amount), "Unable to transfer stake amount");

        require(stakingToken.transfer(msg.sender, rewards), "Unable to transfer reward");

        delete stakes[msg.sender];
        emit Unstaked(msg.sender, amount);
    }

    function calculateRewards(address _user) internal view returns(uint256) {
        Stake memory userStake = stakes[_user];
        if(block.timestamp < userStake.startTime + rewardInterval){
            return 0;
        } else {
            uint256 rewardRate = 10;
            uint256 rewardPeriods = (block.timestamp - userStake.startTime) / rewardInterval;
            uint256 rewards = userStake.amount * rewardRate * rewardPeriods/ 100;
            return rewards;
        }
    }
}