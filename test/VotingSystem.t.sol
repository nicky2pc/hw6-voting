// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../src/VegaVotingToken.sol";
import "../src/StakingVault.sol";
import "../src/VoteResultNFT.sol";
import "../src/VotingSystem.sol";

contract VotingSystemTest is Test {
    VegaVotingToken token;
    StakingVault vault;
    VoteResultNFT nft;
    VotingSystem voting;

    address admin = address(1);
    address alice = address(2);
    address bob = address(3);

    uint256 deadline;

    function setUp() public {
        vm.startPrank(admin);
        token = new VegaVotingToken(admin);
        nft = new VoteResultNFT(admin);
        vault = new StakingVault(address(token), admin);
        voting = new VotingSystem(address(vault), address(nft), admin);
        // Grant VotingSystem permission to mint NFTs
        nft.grantRole(nft.NFT_MINTER_ROLE(), address(voting));
        // Mint tokens
        token.mint(alice, 1000e18);
        token.mint(bob, 500e18);
        vm.stopPrank();

        // Alice and Bob approve vault and stake
        vm.startPrank(alice);
        token.approve(address(vault), type(uint256).max);
        vault.stake(500e18, 4); // VP = 16 * 500 = 8000
        vm.stopPrank();

        vm.startPrank(bob);
        token.approve(address(vault), type(uint256).max);
        vault.stake(200e18, 2); // VP = 4 * 200 = 800
        vm.stopPrank();

        deadline = block.timestamp + 1 days;
    }

    function test_createVoteRevertsWithoutRole() public {
        vm.prank(alice);
        vm.expectRevert();
        voting.createVote("Test", deadline, 1000);
    }

    function test_createVoteRevertsWithPastDeadline() public {
        vm.prank(admin);
        vm.expectRevert(VotingSystem.InvalidDeadline.selector);
        voting.createVote("Test", block.timestamp - 1, 1000);
    }

    function test_createVoteSucceeds() public {
        vm.prank(admin);
        voting.createVote("Proposal A", deadline, 1000);
        VotingSystem.Vote memory v = voting.getVote(1);
        assertEq(v.id, 1);
        assertEq(v.description, "Proposal A");
        assertEq(v.threshold, 1000);
        assertEq(v.finalized, false);
    }

    function test_voteRevertsWithNoVP() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 1000);
        // admin has no staked tokens
        vm.prank(admin);
        vm.expectRevert(VotingSystem.NoVotingPower.selector);
        voting.vote(1, true);
    }

    function test_voteRecordsYesCorrectly() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.prank(alice);
        voting.vote(1, true);
        VotingSystem.Vote memory v = voting.getVote(1);
        assertEq(v.yesVotes, 8000); // 4^2 * 500 = 8000
    }

    function test_voteRecordsNoCorrectly() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.prank(bob);
        voting.vote(1, false);
        VotingSystem.Vote memory v = voting.getVote(1);
        assertEq(v.noVotes, 800); // 2^2 * 200 = 800
    }

    function test_doubleVoteReverts() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.prank(alice);
        voting.vote(1, true);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VotingSystem.AlreadyVoted.selector, 1, alice));
        voting.vote(1, true);
    }

    function test_voteAfterDeadlineReverts() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.warp(deadline + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(VotingSystem.VoteExpired.selector, 1));
        voting.vote(1, true);
    }

    function test_thresholdAutoFinalizes() public {
        // threshold = 5000, alice's VP = 8000 > threshold → auto-finalize
        vm.prank(admin);
        voting.createVote("Auto-finalize test", deadline, 5000);
        vm.prank(alice);
        voting.vote(1, true);
        VotingSystem.Vote memory v = voting.getVote(1);
        assertTrue(v.finalized);
        assertTrue(v.passed);
        // NFT should be minted
        assertEq(nft.ownerOf(1), admin);
    }

    function test_finalizeAfterDeadline() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.prank(alice);
        voting.vote(1, true);
        vm.warp(deadline + 1);
        voting.finalize(1);
        VotingSystem.Vote memory v = voting.getVote(1);
        assertTrue(v.finalized);
        assertFalse(v.passed); // 8000 < 100000
        // NFT minted
        assertEq(nft.ownerOf(1), admin);
    }

    function test_finalizeBeforeDeadlineReverts() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.expectRevert(abi.encodeWithSelector(VotingSystem.VoteNotExpiredYet.selector, 1));
        voting.finalize(1);
    }

    function test_doubleFinalize() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.warp(deadline + 1);
        voting.finalize(1);
        vm.expectRevert(abi.encodeWithSelector(VotingSystem.AlreadyFinalized.selector, 1));
        voting.finalize(1);
    }

    function test_pauseBlocksVote() public {
        vm.prank(admin);
        voting.createVote("Test", deadline, 100000);
        vm.prank(admin);
        voting.pause();
        vm.prank(alice);
        vm.expectRevert();
        voting.vote(1, true);
    }

    function test_pauseBlocksCreateVote() public {
        vm.prank(admin);
        voting.pause();
        vm.prank(admin);
        vm.expectRevert();
        voting.createVote("Test", deadline, 1000);
    }
}
