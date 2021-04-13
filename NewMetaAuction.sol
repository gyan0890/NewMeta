// SPDX-License-Identifier: EtherNaal
pragma solidity >=0.6.0 <0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.0.0/contracts/token/ERC721/ERC721.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address payable public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(address payable _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address payable _newOwner) internal {
    require(_newOwner != address(0));
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}

/**
 * @title Destructible
 * @dev Base contract that can be destroyed by owner. All funds in contract will be sent to the owner.
 */
contract Destructible is Ownable {

  constructor() public payable { }

  /**
   * @dev Transfers the current balance to the owner and terminates the contract.
   */
  function destroy() onlyOwner public {
    selfdestruct(owner);
  }

  function destroyAndSend(address payable _recipient) onlyOwner public {
    selfdestruct(_recipient);
  }
}


contract NewMetaAuction is Ownable, Pausable, Destructible {

    event Sent(address indexed payee, uint256 amount, uint256 balance);
    event Received(address indexed payer, uint tokenId, uint256 amount, uint256 balance);
    //event RoyaltiesGiven(address indexed owner, uint256 amount);
    event TokenTransferred(address indexed owner, address indexed receiver, uint256 tokenId);
    
    struct Token {
        uint256 id;
        uint256 salePrice;
        bool active;
    }

    /**
    * ERC721 - Eth contract to create NFTs
    */
    ERC721 public nftAddress;
    address payable public saleOwner;
    mapping(uint256 => uint256) private salePrice;
    mapping(uint256 => Token) public tokens;
    
    //Holds a mapping between the tokenId and the bidding contract
    mapping(uint256 => Bidding) tokenBids;
    

    /**
    * @dev Contract Constructor
    * @param _nftAddress address for the Harmongy non-fungible token contract 
    */
    constructor(address _nftAddress) public { 
        require(_nftAddress != address(0) && _nftAddress != address(this));
        nftAddress = ERC721(_nftAddress);
        saleOwner = msg.sender;
    }

    /**
     * @dev check the owner of a Token
     * @param _tokenId uint256 token representing an Object
     * Test function to check if the token address can be retrieved.
     */
    function getTokenSellerAddress(uint256 _tokenId) internal view returns(address) {
        address tokenSeller = nftAddress.ownerOf(_tokenId);
        return tokenSeller;
    }
    
    /**
     * @dev Sell _tokenId for price 
     */
 
    function setSaleToken(uint256 _tokenId, uint256 _price, uint _biddingTime) 
    public returns(address) {
		require(nftAddress.ownerOf(_tokenId) != address(0), "setSale: nonexistent token");
		//require(tokens[_tokenId].active != true, "Token Already up for sale");
        Token memory token;
		token.id = _tokenId;
		token.active = true;
		token.salePrice = _price;
		tokens[_tokenId] = token;
		
		Bidding placeBids = new Bidding(_tokenId, _biddingTime, _price, saleOwner);
		tokenBids[_tokenId] = placeBids;
    
        return(address(placeBids));
		
	} 

    /**
    * @dev Purchase _tokenId
    * @param _tokenId uint256 token ID representing an Object
    */
    function transferToken(uint256 _tokenId) public whenNotPaused {
        require(msg.sender != address(0) && msg.sender != address(this));
        require(nftAddress.ownerOf(_tokenId) != address(0));
        require(tokens[_tokenId].active == true, "Token is not registered for sale!");
        
        /*
        De-registering the token once it's purchased.
        */
        Token memory sellingToken = tokens[_tokenId];
        sellingToken.active = false;
        tokens[_tokenId] = sellingToken;
        
                
        address tokenSeller = nftAddress.ownerOf(_tokenId);
        address highestBidder = tokenBids[_tokenId].highestBidder();
        nftAddress.safeTransferFrom(tokenSeller, highestBidder, _tokenId);
        
        emit TokenTransferred(tokenSeller, highestBidder, _tokenId);
        
    }
    
    
    /*
    * @param _tokenId: Teokn ID to get the Bidding contract address
    */
    function getBiddingContractAddress(uint256 _tokenId) public view returns(address){
        return(address(tokenBids[_tokenId]));
    }

}

/* 
* This is the bidding contract 
*/

contract Bidding {
    // Parameters of the auction. Times are either
    // absolute unix timestamps (seconds since 1970-01-01)
    // or time periods in seconds.

    uint public auctionEnd;
    uint public tokenId;
    uint public reservePrice;
    uint bidCounter;
    address public highestBid;
    address payable public owner;
    uint public bidAmountHighest;

    struct Bid {
        address payable bidder;
        uint bidAmount;
    }
   
    // Set to true at the end, disallows any change
    bool ended;
    
    // Recording all the bids
    mapping(uint => Bid) bids;


    // Events that  will be fired on changes.
    //event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    /*
    * Create a simple bidding contract
    * @param _tokenId: tokenId for which the bid is created
    * @param _biddingTime: Time period for the bidding to be kept open
    * @param _reservePrice: Minimum price set for the token
    */
    constructor(
       
        uint256 _tokenId,
        uint _biddingTime,
        uint _reservePrice,
        address payable _owner
    ) public {
        reservePrice = _reservePrice;
        tokenId = _tokenId;
        bidCounter = 0;
        auctionEnd = block.timestamp + _biddingTime;
        //Explicitly setting the owner to our address for now
        // msg.sender is coming as the address of the contract
        owner = _owner;
        
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    //ONLY FOR TESTING
    function getOwner() public view returns(address){
      return owner;
    }

    /// Bid on the auction with the value sent
    /// together with this transaction.
    /// The value will only be refunded if the
    /// auction is not won.
    function bid() public payable {
        // No arguments are necessary, all
        // information is already part of
        // the transaction. The keyword payable
        // is required for the function to
        // be able to receive Ether.

        // Revert the call if the bidding
        // period is over.
        require(
            block.timestamp <= auctionEnd,
            "Auction already ended."
        );

        // If the bid is not higher than 0, no bidding happens
        require(
            msg.value > 0,
            "The bid value should be greater than 0."
        );

       Bid storage newBid = bids[bidCounter+1];
       newBid.bidder = msg.sender;
       newBid.bidAmount = msg.value;
       
       bidCounter = bidCounter+1;
    }
    
    /*
    * Get the address of the highest bidder
    */
    function highestBidder() onlyOwner public returns(address) {
        
        uint highestBidValue;
        address highestBidAddress;
        
        highestBidValue = bids[0].bidAmount;
        highestBidAddress = address(0);
        
        for(uint i = 0; i <= bidCounter ; i ++){
            
            if(bids[i].bidAmount > highestBidValue) {
                highestBidValue = bids[i].bidAmount;
                highestBidAddress = bids[i].bidder;
            }
                
        }
        
        return highestBidAddress;
        
    }
    
    
    /*
    * Get the highest bid amount
    * @param _highestBidder address of the highest bidder
    */
    function highestBidAmount(address _highestBidder) onlyOwner public view returns(uint)  {
        
        for(uint i = 0; i <= bidCounter ; i ++){
            
            if(bids[i].bidder == _highestBidder) {
               return bids[i].bidAmount;
            }
                
        }
        return 0;
    }
    
    /*
    * Function to send the bidAmount to the NFT owner
    * @param _nftOwner: address of the NFT Owner
    */
     function sendMoneyToOwner(address payable _nftOwner, uint ownerShare) onlyOwner public {
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(ended, "Auction end has not been called.");
        require(ownerShare < bidAmountHighest, "Royalties are not being given to the artist!");
        //Send the money to the nftOwner
        _nftOwner.transfer(ownerShare);
        
    }

    
    function geReservePrice() onlyOwner public view returns(uint){
      return reservePrice;
    }


    /*
    * Function to send the royalty amount to the selected artists
    * @param _artists: address of the the artists who will receive royalty
    * @param _royaltyAmount: amount of money to be sent as royalty per artist
    */
    function sendRoyaltyMoney(address payable[] memory _artists, uint[] memory _royaltyAmount) onlyOwner public {
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(_artists.length == _royaltyAmount.length, "Number of royalties not matchiing the number of artists!");
        require(ended, "Auction end has not been called.");
        for(uint i = 0; i < _artists.length; i++ ){
            _artists[i].transfer(_royaltyAmount[i]);
        }
        
    }
    
    /*
    * Withdraw bids that were not the winners.
    */
    function disperseFunds() onlyOwner public returns (bool) {
        uint amount = 0;
        for(uint i = 0; i <= bidCounter; i ++){
            amount = bids[i].bidAmount;
            
            if(amount < 0){
                return false;
            }
          
            if(bids[i].bidder != highestBid){
                
                bids[i].bidder.transfer(amount);
            }
            
        }
        return true;
    }
    
    /*
    * In case of an emergency, this function can be called to send all
    * the funds from the contract to the owner address.
    */
    function finalize() public onlyOwner {
        selfdestruct(owner);
    }
    
    
    /* 
    * End the auction and calculate the highest bid
    */
    function auctionEnded() onlyOwner public {

        // 1. Conditions
        require(block.timestamp >= auctionEnd, "Auction not yet ended.");
        require(!ended, "auctionEnd has already been called.");

        // 2. Effects
        ended = true;

        // 3. Get the highest bidder 
        highestBid = highestBidder();
        
         //4. Send the money to the owner and royalties to artists
        bidAmountHighest = highestBidAmount(highestBid);

    }
}
