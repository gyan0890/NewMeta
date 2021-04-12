// SPDX-License-Identifier: EtherNaal

pragma solidity >=0.6.0 <0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.0.0/contracts/token/ERC721/ERC721.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v3.0.0/contracts/access/AccessControl.sol";


contract NewMeta is ERC721{
	//maps tokenIds to item indexes
	mapping(uint256 => uint256) private itemIndex;
	mapping(uint256 => uint256) private salePrice;
	
  //Setting the MINTER_ROLE as onlyMinter is deprecated 
  //in the recent Solidity releases
//   bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

	constructor(string memory _name, string memory _symbol) public ERC721(_name, _symbol) {
    //grantRole(MINTER_ROLE, msg.sender);
    //Here, we should set the baseURI for the tokens(This can be set as the Pinata address)
    _setBaseURI("https://gateway.pinata.cloud/ipfs/");
    }

	function setSale(uint256 tokenId, uint256 price) public {
		address owner = ownerOf(tokenId);
        require(owner != address(0), "setSale: nonexistent token");
        require(owner == msg.sender, "setSale: msg.sender is not the owner of the token");
		salePrice[tokenId] = price;
	}

	function buyTokenOnSale(uint256 tokenId) public payable {
		uint256 price = salePrice[tokenId];
        require(price != 0, "buyToken: price equals 0");
        require(msg.value == price, "buyToken: price doesn't equal salePrice[tokenId]");
		address payable owner = address(uint160(ownerOf(tokenId)));
		approve(address(this), tokenId);
		salePrice[tokenId] = 0;
		transferFrom(owner, msg.sender, tokenId);
        owner.transfer(msg.value);
	}

	function mintWithIndex(address to, uint256 index, string memory tokenURI) public  {
    // require(
    //         // /hasRole(MINTER_ROLE, msg.sender),
    //         // "Token: account does not have minter role"
    // );
		uint256 tokenId = totalSupply() + 1;
		itemIndex[tokenId] = index;
        _mint(to, tokenId);
        
        //Here, we will set the metadata hash link of the token metadata from Pinata
        _setTokenURI(tokenId, tokenURI);
	}
	

	function getItemIndex(uint256 tokenId) public view returns (uint256) {
		return itemIndex[tokenId];
	}

	function getSalePrice(uint256 tokenId) public view returns (uint256) {
		return salePrice[tokenId];
	}
}
