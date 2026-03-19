// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../src/VegaVotingToken.sol";
import "../src/StakingVault.sol";
import "../src/VoteResultNFT.sol";
import "../src/VotingSystem.sol";

contract IntegrationTest is Test {
    VegaVotingToken token;
    StakingVault vault;
    VoteResultNFT nft;
    VotingSystem voting;

    address admin = address(1);
    address alice = address(2);
    address bob = address(3);
    address charlie = address(4);

    function setUp() public {
        vm.startPrank(admin);
        // Deploy all contracts
        token = new VegaVotingToken(admin);
        nft = new VoteResultNFT(admin);
        vault = new StakingVault(address(token), admin);
        voting = new VotingSystem(address(vault), address(nft), admin);

        // Configure roles
        nft.grantRole(nft.NFT_MINTER_ROLE(), address(voting));

        // Mint tokens to users
        token.mint(alice, 1000e18);
        token.mint(bob, 500e18);
        token.mint(charlie, 200e18);
        vm.stopPrank();

        // Users approve vault
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        token.approve(address(vault), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(vault), type(uint256).max);
    }

    /// @notice Full flow: stake → vote → finalize after deadline → NFT minted
    function test_fullVotingFlow() public {
        // Users stake with different amounts and durations
        vm.prank(alice);
        vault.stake(1000e18, 4); // VP = 4^2 * 1000 = 16000
        vm.prank(bob);
        vault.stake(500e18, 2); // VP = 2^2 * 500 = 2000
        vm.prank(charlie);
        vault.stake(200e18, 1); // VP = 1^2 * 200 = 200

        // Verify individual VPs
        assertEq(vault.votingPowerOf(alice), 16000);
        assertEq(vault.votingPowerOf(bob), 2000);
        assertEq(vault.votingPowerOf(charlie), 200);

        // Create vote with threshold well above total VP (won't auto-finalize)
        uint256 deadline = block.timestamp + 2 days;
        vm.prank(admin);
        voting.createVote("Proposal: Increase staking rewards", deadline, 100000);

        // Users vote
        vm.prank(alice);
        voting.vote(1, true); // yes: 16000
        vm.prank(bob);
        voting.vote(1, false); // no: 2000
        vm.prank(charlie);
        voting.vote(1, true); // yes: 16200

        // Verify vote state
        VotingSystem.Vote memory v = voting.getVote(1);
        assertEq(v.yesVotes, 16200);
        assertEq(v.noVotes, 2000);
        assertFalse(v.finalized);

        // Warp past deadline and finalize
        vm.warp(deadline + 1);
        voting.finalize(1);

        // Verify finalized state
        v = voting.getVote(1);
        assertTrue(v.finalized);
        assertFalse(v.passed); // 16200 < 100000 threshold

        // Verify NFT minted to admin
        assertEq(nft.ownerOf(1), admin);
        VoteResultNFT.VoteResult memory r = nft.getResult(1);
        assertEq(r.voteId, 1);
        assertEq(r.yesVotes, 16200);
        assertEq(r.noVotes, 2000);
        assertFalse(r.passed);

        // Verify tokenURI is non-empty and starts with data:application/json;base64,
        string memory uri = nft.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
    }

    /// @notice Threshold crossing: voting yes crosses threshold → auto-finalize
    function test_thresholdCrossingEarlyFinalization() public {
        vm.prank(alice);
        vault.stake(1000e18, 4); // VP = 16000
        vm.prank(bob);
        vault.stake(500e18, 2); // VP = 2000

        uint256 deadline = block.timestamp + 7 days;
        // Set threshold between bob's VP and alice+bob's combined VP
        vm.prank(admin);
        voting.createVote("Emergency proposal", deadline, 10000);

        // Bob votes first - no (below threshold regardless)
        vm.prank(bob);
        voting.vote(1, false);

        VotingSystem.Vote memory v = voting.getVote(1);
        assertFalse(v.finalized);

        // Alice votes yes: yesVotes = 16000 >= 10000 threshold → auto-finalize
        vm.prank(alice);
        voting.vote(1, true);

        v = voting.getVote(1);
        assertTrue(v.finalized);
        assertTrue(v.passed);
        assertEq(v.yesVotes, 16000);

        // NFT minted
        assertEq(nft.ownerOf(1), admin);
        VoteResultNFT.VoteResult memory r = nft.getResult(1);
        assertTrue(r.passed);
    }

    /// @notice VP decays over time correctly across voting
    function test_vpDecayAffectsVotes() public {
        vm.prank(alice);
        vault.stake(1000e18, 4); // VP at t=0: 4^2*1000=16000

        uint256 deadline = block.timestamp + 30 days;
        vm.prank(admin);
        voting.createVote("Long duration vote", deadline, 999999);

        // Vote immediately
        vm.prank(alice);
        voting.vote(1, true);
        VotingSystem.Vote memory v = voting.getVote(1);
        assertEq(v.yesVotes, 16000);
    }

    /// @notice Pausable: pause blocks stake and vote
    function test_pausableIntegration() public {
        vm.prank(alice);
        vault.stake(500e18, 2); // VP = 2^2*500 = 2000

        uint256 deadline = block.timestamp + 1 days;
        vm.prank(admin);
        voting.createVote("Test", deadline, 99999);

        // Pause VotingSystem
        vm.prank(admin);
        voting.pause();

        // Vote fails
        vm.prank(alice);
        vm.expectRevert();
        voting.vote(1, true);

        // Unpause
        vm.prank(admin);
        voting.unpause();

        // Vote succeeds
        vm.prank(alice);
        voting.vote(1, true);

        // Pause StakingVault
        vm.prank(admin);
        vault.pause();

        // Stake fails
        vm.prank(bob);
        vm.expectRevert();
        vault.stake(100e18, 1);
    }

    /// @notice Multiple votes can coexist independently
    function test_multipleVotesIndependent() public {
        vm.prank(alice);
        vault.stake(1000e18, 4);

        uint256 deadline1 = block.timestamp + 1 days;
        uint256 deadline2 = block.timestamp + 2 days;

        vm.startPrank(admin);
        voting.createVote("Vote 1", deadline1, 99999);
        voting.createVote("Vote 2", deadline2, 99999);
        vm.stopPrank();

        // Alice votes on both
        vm.startPrank(alice);
        voting.vote(1, true);
        voting.vote(2, false);
        vm.stopPrank();

        VotingSystem.Vote memory v1 = voting.getVote(1);
        VotingSystem.Vote memory v2 = voting.getVote(2);

        assertEq(v1.yesVotes, 16000);
        assertEq(v1.noVotes, 0);
        assertEq(v2.yesVotes, 0);
        assertEq(v2.noVotes, 16000);

        // Finalize both after deadlines
        vm.warp(deadline2 + 1);
        voting.finalize(1);
        voting.finalize(2);

        // Two NFTs minted
        assertEq(nft.ownerOf(1), admin);
        assertEq(nft.ownerOf(2), admin);
    }

    /// @notice Unstake after expiry, then VP goes to 0
    function test_unstakeReducesVP() public {
        vm.prank(alice);
        vault.stake(1000e18, 1); // VP = 1^2*1000=1000, expires in 1 week

        assertEq(vault.votingPowerOf(alice), 1000);

        vm.warp(block.timestamp + 1 weeks + 1);

        // VP is 0 after expiry (even before unstake)
        assertEq(vault.votingPowerOf(alice), 0);

        // Unstake
        vm.prank(alice);
        vault.unstake(0);
        assertEq(token.balanceOf(alice), 1000e18);

        // Still 0 VP (stake inactive now)
        assertEq(vault.votingPowerOf(alice), 0);
    }
}
