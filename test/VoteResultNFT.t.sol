// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Test.sol";
import "../src/VoteResultNFT.sol";

contract VoteResultNFTTest is Test {
    VoteResultNFT nft;
    address admin = address(1);
    address minter = address(2);
    address user = address(3);

    function setUp() public {
        vm.startPrank(admin);
        nft = new VoteResultNFT(admin);
        nft.grantRole(nft.NFT_MINTER_ROLE(), minter);
        vm.stopPrank();
    }

    function test_mintRevertsForUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        nft.mintResult(1, "test", 100, 50, 80, true, user);
    }

    function test_mintSucceedsForMinter() public {
        vm.prank(minter);
        nft.mintResult(1, "Question?", 100, 50, 80, true, user);
        assertEq(nft.ownerOf(1), user);
    }

    function test_getResultReturnsCorrectData() public {
        vm.prank(minter);
        nft.mintResult(1, "Question?", 100, 50, 80, true, user);
        VoteResultNFT.VoteResult memory r = nft.getResult(1);
        assertEq(r.voteId, 1);
        assertEq(r.yesVotes, 100);
        assertEq(r.passed, true);
    }

    function test_tokenURINotEmpty() public {
        vm.prank(minter);
        nft.mintResult(1, "Question?", 100, 50, 80, true, user);
        string memory uri = nft.tokenURI(1);
        assertTrue(bytes(uri).length > 0);
    }

    function test_tokenURIRevertsForNonexistent() public {
        vm.expectRevert();
        nft.tokenURI(999);
    }
}
