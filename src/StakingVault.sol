// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./VegaVotingToken.sol";

contract StakingVault is AccessControl, Pausable, ReentrancyGuard {
    error InvalidDuration(uint8 provided);
    error StakeNotExpired(uint256 stakeIndex, uint256 expiresAt);
    error StakeAlreadyWithdrawn(uint256 stakeIndex);

    event Staked(address indexed user, uint256 indexed stakeIndex, uint256 amount, uint8 durationWeeks, uint256 expiresAt);
    event Unstaked(address indexed user, uint256 indexed stakeIndex, uint256 amount);

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct Stake {
        uint256 amount;
        uint256 stakeEndTimestamp;
        bool active;
    }

    VegaVotingToken public immutable token;
    mapping(address => Stake[]) public stakes;

    constructor(address tokenAddress, address admin) {
        token = VegaVotingToken(tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function stake(uint256 amount, uint8 durationWeeks) external whenNotPaused nonReentrant {
        if (durationWeeks < 1 || durationWeeks > 4) revert InvalidDuration(durationWeeks);
        require(amount > 0, "amount = 0");
        token.transferFrom(msg.sender, address(this), amount);
        uint256 expiresAt = block.timestamp + uint256(durationWeeks) * 1 weeks;
        uint256 idx = stakes[msg.sender].length;
        stakes[msg.sender].push(Stake(amount, expiresAt, true));
        emit Staked(msg.sender, idx, amount, durationWeeks, expiresAt);
    }

    function unstake(uint256 stakeIndex) external whenNotPaused nonReentrant {
        Stake storage s = stakes[msg.sender][stakeIndex];
        if (!s.active) revert StakeAlreadyWithdrawn(stakeIndex);
        if (block.timestamp < s.stakeEndTimestamp) revert StakeNotExpired(stakeIndex, s.stakeEndTimestamp);
        uint256 amount = s.amount;
        s.active = false;
        token.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, stakeIndex, amount);
    }

    function votingPowerOf(address user) public view returns (uint256 vp) {
        Stake[] storage userStakes = stakes[user];
        for (uint256 i = 0; i < userStakes.length; i++) {
            Stake storage s = userStakes[i];
            if (!s.active) continue;
            uint256 wr = _weeksRemaining(s.stakeEndTimestamp);
            if (wr == 0) continue;
            vp += wr * wr * (s.amount / 1e18);
        }
    }

    function _weeksRemaining(uint256 endTs) internal view returns (uint256) {
        if (block.timestamp >= endTs) return 0;
        return (endTs - block.timestamp) / 1 weeks;
    }

    function getStakes(address user) external view returns (Stake[] memory) {
        return stakes[user];
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }
}
