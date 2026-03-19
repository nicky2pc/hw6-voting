// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Script.sol";
import "../src/VegaVotingToken.sol";
import "../src/StakingVault.sol";
import "../src/VoteResultNFT.sol";
import "../src/VotingSystem.sol";

/**
 * @notice Helper script for manual testing on Sepolia.
 * Usage examples (run from project root):
 *
 * Approve tokens:
 *   cast send <TOKEN> "approve(address,uint256)" <VAULT> 1000000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
 *
 * Stake tokens (4 weeks):
 *   cast send <VAULT> "stake(uint256,uint8)" 500000000000000000000 4 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
 *
 * Create vote (deadline = now + 3600 seconds):
 *   cast send <VOTING> "createVote(string,uint256,uint256)" "Should we adopt proposal X?" $(($(date +%s) + 3600)) 1000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
 *
 * Vote YES:
 *   cast send <VOTING> "vote(uint256,bool)" 1 true --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
 *
 * Vote NO:
 *   cast send <VOTING> "vote(uint256,bool)" 1 false --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
 *
 * Check voting power:
 *   cast call <VAULT> "votingPowerOf(address)" <USER_ADDR> --rpc-url $SEPOLIA_RPC_URL
 *
 * Finalize vote after deadline:
 *   cast send <VOTING> "finalize(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
 *
 * Check NFT tokenURI:
 *   cast call <NFT> "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
 */
contract Interactions is Script {
    address constant TOKEN = address(0); // Replace with deployed address
    address constant VAULT = address(0); // Replace with deployed address
    address constant NFT   = address(0); // Replace with deployed address
    address constant VOTING = address(0); // Replace with deployed address

    function stake(uint256 amount, uint8 durationWeeks) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        VegaVotingToken(TOKEN).approve(VAULT, amount);
        StakingVault(VAULT).stake(amount, durationWeeks);
        vm.stopBroadcast();
    }

    function createVote(string calldata description, uint256 deadline, uint256 threshold) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        VotingSystem(VOTING).createVote(description, deadline, threshold);
        vm.stopBroadcast();
    }

    function castVote(uint256 voteId, bool support) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        VotingSystem(VOTING).vote(voteId, support);
        vm.stopBroadcast();
    }

    function finalizeVote(uint256 voteId) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        VotingSystem(VOTING).finalize(voteId);
        vm.stopBroadcast();
    }
}
