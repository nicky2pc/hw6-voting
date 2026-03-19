// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/Script.sol";
import "../src/VegaVotingToken.sol";
import "../src/StakingVault.sol";
import "../src/VoteResultNFT.sol";
import "../src/VotingSystem.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        VegaVotingToken token = new VegaVotingToken(deployer);
        VoteResultNFT nft = new VoteResultNFT(deployer);
        StakingVault vault = new StakingVault(address(token), deployer);
        VotingSystem voting = new VotingSystem(address(vault), address(nft), deployer);

        // Grant VotingSystem permission to mint NFTs
        nft.grantRole(nft.NFT_MINTER_ROLE(), address(voting));
        // Mint initial supply to deployer
        token.mint(deployer, 1_000_000e18);

        vm.stopBroadcast();

        console.log("VegaVotingToken:", address(token));
        console.log("StakingVault:", address(vault));
        console.log("VoteResultNFT:", address(nft));
        console.log("VotingSystem:", address(voting));
    }
}
