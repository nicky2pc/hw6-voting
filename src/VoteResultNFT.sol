// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract VoteResultNFT is ERC721, AccessControl {
    error TokenDoesNotExist(uint256 tokenId);

    event ResultMinted(uint256 indexed tokenId, uint256 indexed voteId, bool passed);

    bytes32 public constant NFT_MINTER_ROLE = keccak256("NFT_MINTER_ROLE");

    struct VoteResult {
        uint256 voteId;
        string description;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 threshold;
        bool passed;
        uint256 finalizedAt;
    }

    mapping(uint256 => VoteResult) public results;
    uint256 public nextTokenId;

    constructor(address admin) ERC721("VegaVoteResult", "VVR") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mintResult(
        uint256 voteId, string calldata description,
        uint256 yesVotes, uint256 noVotes, uint256 threshold,
        bool passed, address recipient
    ) external onlyRole(NFT_MINTER_ROLE) {
        nextTokenId++;
        uint256 tokenId = nextTokenId;
        _safeMint(recipient, tokenId);
        results[tokenId] = VoteResult(voteId, description, yesVotes, noVotes, threshold, passed, block.timestamp);
        emit ResultMinted(tokenId, voteId, passed);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (results[tokenId].finalizedAt == 0) revert TokenDoesNotExist(tokenId);
        VoteResult memory r = results[tokenId];
        string memory json = string.concat(
            '{"name":"Vote Result #', Strings.toString(tokenId),
            '","description":"', r.description,
            '","attributes":[',
            '{"trait_type":"Passed","value":"', r.passed ? "true" : "false", '"},',
            '{"trait_type":"Yes Votes","value":', Strings.toString(r.yesVotes), '},',
            '{"trait_type":"No Votes","value":', Strings.toString(r.noVotes), '},',
            '{"trait_type":"Threshold","value":', Strings.toString(r.threshold), '},',
            '{"trait_type":"Finalized At","value":', Strings.toString(r.finalizedAt), '}',
            ']}'
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
    }

    function getResult(uint256 tokenId) external view returns (VoteResult memory) {
        return results[tokenId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
