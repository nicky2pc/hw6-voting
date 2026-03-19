// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../src/VegaVotingToken.sol";

contract VegaVotingTokenTest is Test {
    VegaVotingToken token;
    address admin = address(1);
    address user = address(2);

    function setUp() public {
        vm.prank(admin);
        token = new VegaVotingToken(admin);
    }

    function test_nameAndSymbol() public view {
        assertEq(token.name(), "VegaVoting");
        assertEq(token.symbol(), "VV");
    }

    function test_mintByMinter() public {
        vm.prank(admin);
        token.mint(user, 100e18);
        assertEq(token.balanceOf(user), 100e18);
    }

    function test_mintRevertsForUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 100e18);
    }

    function test_pauseBlocksTransfer() public {
        vm.startPrank(admin);
        token.mint(user, 100e18);
        token.pause();
        vm.stopPrank();
        vm.prank(user);
        vm.expectRevert();
        token.transfer(admin, 10e18);
    }

    function test_unpauseRestoresTransfer() public {
        vm.startPrank(admin);
        token.mint(user, 100e18);
        token.pause();
        token.unpause();
        vm.stopPrank();
        vm.prank(user);
        token.transfer(admin, 10e18);
        assertEq(token.balanceOf(admin), 10e18);
    }
}
