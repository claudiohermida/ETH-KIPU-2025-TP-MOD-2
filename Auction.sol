// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Auction
 * @author Claudio Hermida
 */
contract Auction {

  /*///////////////////////////////////////////////////////////////
                            STRUCTS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice packs bidder information. 
   * @dev use Iterable Mapping pattern
   * @field offer:  the current offer from bidder
   * @field deposit: total amount deposited by bidder
   * @field exists: flag indicating whether this bidder has made an offer yet, as per Iterable Mapping
   */
  struct Bidder {
    uint256 offer;
    uint256 deposit;
    bool exists;
  }

  /**
   * @notice packs bidder address and offer to display.
   * @field address: bidder´s address
   * @field offer:  the current offer from bidder
   */
  struct BidderToDisplay {
    address bidderAddress;
    uint256 offer;
  }



  



  /*///////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice new highest bid has been set
   * @param _bidder the address of the bidder with new highest bid
   * @param _amount the amount of the new highest bid
   */
  event NewOffer(address indexed _bidder, uint256 _amount);
 
  /**
   * @notice auction has finished, deadline reached. Event triggered when refunds are made.
   */
  event AuctionEnded();

  /*///////////////////////////////////////////////////////////////
                            ERRORS
  //////////////////////////////////////////////////////////////*/

   /**
   * @notice auction has finished, but no bids were made
   */
  error NoBidsMade();

  /*///////////////////////////////////////////////////////////////
                          CONSTANTS
  //////////////////////////////////////////////////////////////*/

   /**
   * @notice a new bid must surpass the current highest one by BID_INCREASE %
   */
  uint256 public constant BID_INCREASE = 5;

  /**
   * @notice non-winners get their funds returned with a discount of RETURN_DEPOSIT_DISCOUNT %
   */
  uint256 public constant RETURN_DEPOSIT_DISCOUNT = 2;

  /**
   * @notice whenever a new bid is made within DEADLINE_EXTENSION of current deadline,
   * deadline gets extended by DEADLINE_EXTENSION
   */
  uint256 public constant DEADLINE_EXTENSION = 10 minutes;


  /*///////////////////////////////////////////////////////////////
                           STATE
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice address of contract deployer, 
   * controls access to refund process at auction´s end
   */
  address public immutable owner;

  /**
   * @notice deadline for placing bids, 
   * initially set in the constructor at time of deployment
   * incremented by 10 min  whenever a new bid is made within the last 10 min remaining
   */
  uint256 public deadline;
  
  /**
   * @notice holds the information of bidding associated to a given address
   * @dev use Iterable Mapping, with boolean flag exists.
   */
   mapping (address => Bidder) public bidders;

  /**
   * @notice holds the addresses of the bidders. 
   * @dev this is the keys array of the Iterable Mapping bidders
   */
  address[] biddersAddresses;

   /**
    * @notice address of the bidder with the current highest bid
    * bidders[highestBidder].offer is the current highest bid
    */
  address public highestBidder;

   /**
    * @notice the current highest bid
    * initialized in the constructor upon contract deployment to set a minimum starting bid
    * afterwards, it should agree with  bidders[highestBidder].offer
    */
  uint256 public highestBid;



  /*///////////////////////////////////////////////////////////////
                          MODIFIERS
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice Reverts in case the function was not called by the owner of the contract
   */
  modifier onlyOwner() {
     require(msg.sender == owner , "only contract owner may invoke this function");
     _;
  }

  /**
   * @notice Reverts in case the function is called after the auction´s end
   */
  modifier activeAuction{
      require(block.timestamp <= deadline, "auction deadline expired");
      _;
  }


  /**
   * @notice Reverts in case the function is called befpore the auction´s end
   */
  modifier auctionEnded{
      require(block.timestamp > deadline, "auction still active");
      _;
  }

  /*///////////////////////////////////////////////////////////////
                            LOGIC
  //////////////////////////////////////////////////////////////*/
  /**
   * @notice deploys a new auction
   * @param _startingBid the base bid, first bidder should surpass it by BID_INCREASE %
   * @param _duration o of auction, set in seconds
   */
  constructor (uint256 _startingBid, uint256 _duration){
      deadline = block.timestamp + _duration;
      owner = msg.sender;
      highestBid = _startingBid;
  }
  
  
  /**
   * @notice places a new bid, in its msg.value, which is desposited in the contract
   * reverts if bid should surpass highestBid by BID_INCREASE %
   * or if auction is no longer active
   */
  function bid() external payable activeAuction {
      require(msg.value > ((highestBid * (100 + BID_INCREASE))/100),
      "bid does not surpass current highest bid by specified bid increase");
      highestBid = msg.value; // update highest bid
      _addBidder(msg.sender); // add bidder as existing and update biddersAddresses array
      highestBidder = msg.sender; // record new highest bidder address
      bidders[msg.sender].offer = msg.value; // register new offer
      bidders[msg.sender].deposit += msg.value; // update deposit from bidder
      _updateDeadline(); // update deadline if necessary
      emit NewOffer(msg.sender,msg.value);
  } // function bid

  /**
   * @notice reveals winner´s address and winning bid, 
   * reverts if auction has not ended yet
   * reverts if there are no bids
   */
  function revealWinner() external view auctionEnded returns (address, uint256){
      if (highestBidder != address(0))
          {return (highestBidder, highestBid);}
      else {revert  NoBidsMade();}
  } // fucntion revealWinner

   /**
    * @notice shows current list of bidders, displaying their addresses and highest offers.
    * @return biddersToDisplay_ array of BidderToDisplay(bidderAdress,bidderOffer)
    */
   function showOffers() external view returns (BidderToDisplay[] memory) {
    uint256 len = biddersAddresses.length;
    BidderToDisplay[] memory biddersToDisplay_ = new BidderToDisplay[](len);

    for (uint256 i = 0; i < len; i++) { 
        address bidAddress = biddersAddresses[i];
        biddersToDisplay_[i] = BidderToDisplay({
            bidderAddress: bidAddress,
            offer: bidders[bidAddress].offer
        });
    }
    return biddersToDisplay_; // Return the populated array
}



   /**
    * @notice refunds deposits to non-winner bidders, discounting RETURN_DEPOSIT_DISCOUNT %
    * it also refunds the winner his deposit  minus his winning bid, with the same discount rate
    * reverts if called by any but the registered owner
    * reverts if the auction has not reached its deadline
    */
  function returnDeposits() external onlyOwner auctionEnded {
      uint256 len = biddersAddresses.length;
      for(uint256 i = 0; i < len; i++){
          uint256 _amountToReturn = 0;
          address _currentBidder = biddersAddresses[i];
          if (_currentBidder != highestBidder){
              bidders[_currentBidder].offer = 0;
              // return deposit - discount.
              _amountToReturn = bidders[ _currentBidder].deposit;
          } else {
              // return deposit to winner minus winningBid
              _amountToReturn = (bidders[ _currentBidder].deposit - highestBid );
          }
          _amountToReturn = (_amountToReturn * (100- RETURN_DEPOSIT_DISCOUNT))/ 100;
          bidders[_currentBidder].deposit = 0;
          (bool sent,  ) =  _currentBidder.call{value: _amountToReturn}("");
          require(sent, string(abi.encodePacked("failed to refund ", _amountToReturn," to ", _currentBidder)));
      }
      emit AuctionEnded();
  } // function returnDeposits

  /**
    * @notice refunds excess deposit, over the bidder's current highest offer
    * reverts if auction has ended
    */
  function partialRefund() external activeAuction {
      address  _claimer = msg.sender;
      uint256  _excess = bidders[_claimer].deposit - bidders[_claimer].offer;
      if (_excess > 0) {
          bidders[_claimer].deposit -= _excess;
          (bool sent, ) = _claimer.call{value: _excess}("");
          require(sent, string(abi.encodePacked("failed to refund ", _excess, " to ", _claimer)));
      }
      
  } // function partialRefund

  /*///////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
  //////////////////////////////////////////////////////////////*/

   /**
    * @notice updates deadline if block.timestamp is within DEADLINE_EXTENSION of deadline
    */
  function _updateDeadline() internal {
      if (block.timestamp + DEADLINE_EXTENSION > deadline){
          deadline += DEADLINE_EXTENSION;
      }
  }


   /**
    * @notice adds bidder´s address to array of keys, 
    * and updates the corresponding entry in bidders mapping
    * @param _bidder address of bidder to add
    */
  function _addBidder(address _bidder) internal {
      if (!bidders[_bidder].exists){
          bidders[_bidder].exists = true;
          biddersAddresses.push(_bidder);
      }
  }
  


} // contract Auction
