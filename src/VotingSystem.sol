// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./StakingVault.sol";
import "./VoteResultNFT.sol";

contract VotingSystem is AccessControl, Pausable, ReentrancyGuard {
    error AlreadyVoted(uint256 voteId, address voter);
    error VoteExpired(uint256 voteId);
    error VoteNotExpiredYet(uint256 voteId);
    error AlreadyFinalized(uint256 voteId);
    error NoVotingPower();
    error InvalidDeadline();
    error VoteNotFound(uint256 voteId);

    event VoteCreated(uint256 indexed voteId, string description, uint256 deadline, uint256 threshold);
    event VoteCast(uint256 indexed voteId, address indexed voter, bool support, uint256 votingPower);
    event VoteFinalized(uint256 indexed voteId, bool passed, uint256 yesVotes, uint256 noVotes, uint256 nftTokenId);

    bytes32 public constant VOTE_CREATOR_ROLE = keccak256("VOTE_CREATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    struct Vote {
        uint256 id;
        string description;
        uint256 deadline;
        uint256 threshold;
        uint256 yesVotes;
        uint256 noVotes;
        bool finalized;
        bool passed;
    }

    mapping(uint256 => Vote) public votes;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public nextVoteId;

    StakingVault public immutable stakingVault;
    VoteResultNFT public immutable nft;
    address public nftRecipient;

    constructor(address vault, address nftAddress, address admin) {
        stakingVault = StakingVault(vault);
        nft = VoteResultNFT(nftAddress);
        nftRecipient = admin;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VOTE_CREATOR_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function createVote(string calldata description, uint256 deadline, uint256 threshold)
        external onlyRole(VOTE_CREATOR_ROLE) whenNotPaused
    {
        if (deadline <= block.timestamp) revert InvalidDeadline();
        nextVoteId++;
        votes[nextVoteId] = Vote(nextVoteId, description, deadline, threshold, 0, 0, false, false);
        emit VoteCreated(nextVoteId, description, deadline, threshold);
    }

    function vote(uint256 voteId, bool support) external whenNotPaused nonReentrant {
        Vote storage v = votes[voteId];
        if (v.id == 0) revert VoteNotFound(voteId);
        if (v.finalized) revert AlreadyFinalized(voteId);
        if (block.timestamp >= v.deadline) revert VoteExpired(voteId);
        if (hasVoted[voteId][msg.sender]) revert AlreadyVoted(voteId, msg.sender);
        uint256 vp = stakingVault.votingPowerOf(msg.sender);
        if (vp == 0) revert NoVotingPower();
        hasVoted[voteId][msg.sender] = true;
        if (support) {
            v.yesVotes += vp;
        } else {
            v.noVotes += vp;
        }
        emit VoteCast(voteId, msg.sender, support, vp);
        if (v.yesVotes >= v.threshold) {
            _finalize(voteId);
        }
    }

    function finalize(uint256 voteId) external nonReentrant {
        Vote storage v = votes[voteId];
        if (v.id == 0) revert VoteNotFound(voteId);
        if (v.finalized) revert AlreadyFinalized(voteId);
        if (block.timestamp < v.deadline) revert VoteNotExpiredYet(voteId);
        _finalize(voteId);
    }

    function _finalize(uint256 voteId) internal {
        Vote storage v = votes[voteId];
        v.finalized = true;
        v.passed = v.yesVotes >= v.threshold;
        uint256 nextToken = nft.nextTokenId() + 1;
        nft.mintResult(voteId, v.description, v.yesVotes, v.noVotes, v.threshold, v.passed, nftRecipient);
        emit VoteFinalized(voteId, v.passed, v.yesVotes, v.noVotes, nextToken);
    }

    function getVote(uint256 voteId) external view returns (Vote memory) {
        return votes[voteId];
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(PAUSER_ROLE) { _unpause(); }
}
