// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../src/VegaVotingToken.sol";
import "../src/StakingVault.sol";

contract StakingVaultTest is Test {
    VegaVotingToken token;
    StakingVault vault;
    address admin = address(1);
    address alice = address(2);

    function setUp() public {
        vm.startPrank(admin);
        token = new VegaVotingToken(admin);
        vault = new StakingVault(address(token), admin);
        token.mint(alice, 1000e18);
        vm.stopPrank();
        vm.prank(alice);
        token.approve(address(vault), type(uint256).max);
    }

    function test_stakeInvalidDurationReverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(StakingVault.InvalidDuration.selector, 0));
        vault.stake(100e18, 0);
    }

    function test_stakeInvalidDurationRevertsHigh() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(StakingVault.InvalidDuration.selector, 5));
        vault.stake(100e18, 5);
    }

    function test_stakeTransfersTokens() public {
        vm.prank(alice);
        vault.stake(100e18, 2);
        assertEq(token.balanceOf(address(vault)), 100e18);
        assertEq(token.balanceOf(alice), 900e18);
    }

    function test_votingPowerImmediatelyAfterStake() public {
        vm.prank(alice);
        vault.stake(100e18, 4); // 4 weeks
        // weeksRemaining = 4, VP = 4^2 * 100 = 1600
        assertEq(vault.votingPowerOf(alice), 1600);
    }

    function test_votingPowerDecaysOverTime() public {
        vm.prank(alice);
        vault.stake(100e18, 4);
        vm.warp(block.timestamp + 1 weeks);
        // weeksRemaining = 3, VP = 9 * 100 = 900
        assertEq(vault.votingPowerOf(alice), 900);
    }

    function test_votingPowerZeroAfterExpiry() public {
        vm.prank(alice);
        vault.stake(100e18, 1);
        vm.warp(block.timestamp + 1 weeks + 1);
        assertEq(vault.votingPowerOf(alice), 0);
    }

    function test_multipleStakesAccumulateVP() public {
        vm.startPrank(alice);
        vault.stake(100e18, 4); // VP += 16 * 100 = 1600
        vault.stake(50e18, 2);  // VP += 4 * 50 = 200
        vm.stopPrank();
        assertEq(vault.votingPowerOf(alice), 1800);
    }

    function test_unstakeBeforeExpiryReverts() public {
        vm.prank(alice);
        vault.stake(100e18, 2);
        vm.prank(alice);
        vm.expectRevert();
        vault.unstake(0);
    }

    function test_unstakeAfterExpiryReturnsTokens() public {
        vm.prank(alice);
        vault.stake(100e18, 1);
        vm.warp(block.timestamp + 1 weeks + 1);
        vm.prank(alice);
        vault.unstake(0);
        assertEq(token.balanceOf(alice), 1000e18);
    }

    function test_pauseBlocksStake() public {
        vm.prank(admin);
        vault.pause();
        vm.prank(alice);
        vm.expectRevert();
        vault.stake(100e18, 1);
    }
}
