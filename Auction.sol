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
    uint256 highestOffer;
    uint256 deposit;
    bool exists;
  }

  /**
   * @notice packs bidder address and offer to display.
   * @field address: bidder´s address
   * @field offer:  the current offer from bidder
   */
  struct Bid {
    address bidder;
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
   * @notice flag to pause/unpause contract, only modifiable by owner
   * controls access to emergencyWithdrawal, bid, partialRefund, returnDeposits
   */
   bool private _paused,

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
   // address public highestBidder;


   /**
    * @notice holds the successive bids (bidder,offer) 
    * @dev for all 0 <= i <= bids.length-1. bids[i + 1].offer >= (bids[i].offer * 100 + BID_INCREASE)/100
    * @dev bids[bids.length-1].bidder is the current highest bidder
    * @dev bids[bids.length-1].offer is the current highest offer
    */
    Bid[] public bids;

   /**
    * @notice the current highest bid
    * initialized in the constructor upon contract deployment to set a minimum starting bid
    * afterwards, it should agree with  bidders[highestBidder].highestOffer and bids[bids.length - 1].offer
    */
   uint256 public highestBid;



  /*///////////////////////////////////////////////////////////////
                          MODIFIERS
  //////////////////////////////////////////////////////////////*/
  // Ownable pattern
  /**
   * @notice Reverts in case the function was not called by the owner of the contract
   */
  modifier onlyOwner() {
     require(msg.sender == owner , "only owner");
     _;
  }

  // Pausable pattern
  /**
   * @notice reverts if contract is not paused
   */
  modifier whenPaused() {
        require(paused, "contract is not paused");
        _;
    }

   /**
   * @notice reverts if contract is not paused
   */
  modifier whenNotPaused() {
        require(!paused, "contract is paused");
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
  function bid() external payable activeAuction whenNotPaused {
      require(msg.value > ((highestBid * (100 + BID_INCREASE))/100),
      "does not surpass bid increase");
      highestBid = msg.value; // update highest bid
      _addBidder(msg.sender); // add bidder as existing and update biddersAddresses array
      //  highestBidder = msg.sender;
      bidders[msg.sender].highestOffer = msg.value; // register new highest offer
      bidders[msg.sender].deposit += msg.value; // update deposit from bidder
      bids.push(Bid(msg.sender,msg.value)); // update bids array with new bid at the end
      _updateDeadline(); // update deadline if necessary
      emit NewOffer(msg.sender,msg.value);
  } // function bid

  /**
   * @notice reveals winner´s address and winning bid, 
   * reverts if auction has not ended yet
   * reverts if there are no bids
   */
  function revealWinner() external view auctionEnded returns (address, uint256){
      uint256 numberOfBids = bids.length;
      if (numberOfBids > 0))
          {return (bids[numberOfBids - 1].bidder, highestBid);}
      else {revert  NoBidsMade();}
  } // function revealWinner

   /**
    * @notice shows current list of bidders, displaying their addresses and highest offers.
    * @return biddersToDisplay_ array of BidderToDisplay(bidderAdress,bidderOffer)
    */
   function showOffers() external view returns (Bid[] memory){ 
    return bids; // Return the bids array
   } // function showOffers



   /**
    * @notice refunds deposits to non-winner bidders, discounting RETURN_DEPOSIT_DISCOUNT %
    * it also refunds the winner his deposit  minus his winning bid, with the same discount rate
    * reverts if called by any but the registered owner
    * reverts if the auction has not reached its deadline
    */
  function returnDeposits() external onlyOwner auctionEnded whenNotPaused {
      uint256 numberOfBidders = biddersAddresses.length;
      uint256 _amountToReturn;
      // highestBidder == bids[bids.length-1].bidder
      for(uint256 i = 0; i < numnberOfBidders; i++){
          address _currentBidder = biddersAddresses[i];
          if (_currentBidder != bids[bids.length-1].bidder){
              bidders[_currentBidder].highestOffer = 0;
              // return deposit - discount.
              _amountToReturn = bidders[ _currentBidder].deposit;
          } else {
              // return deposit to winner minus winningBid
              _amountToReturn = (bidders[ _currentBidder].deposit - highestBid );
          }
          _amountToReturn = (_amountToReturn * (100- RETURN_DEPOSIT_DISCOUNT))/ 100;
          bidders[_currentBidder].deposit = 0;
          (bool sent,  ) =  _currentBidder.call{value: _amountToReturn}("");
          require(sent, "failed to refund");
      }
       // transfer remaining balance to contract owner (== msg.sender)
      uint256 balance = address(this).balance;
      (bool sent, ) = msg.sender.call{value: balance}("");
      require(sent, "Withdrawal failed");
      emit AuctionEnded();
  } // function returnDeposits

  /**
    * @notice refunds excess deposit, over the bidder's current highest offer
    * reverts if auction has ended
    */
  function partialRefund() external activeAuction whenNotPaused {
      uint256  _excess = bidders[msg.sender].deposit - bidders[msg.sender].highestOffer;
      if (_excess > 0) {
          bidders[msg.sender].deposit -= _excess;
          (bool sent, ) = msg.sender.call{value: _excess}("");
          require(sent, "failed to refund ");
      }
  } // function partialRefund



    /*///////////////////////////////////////////////////////////////
                         EMERGENCY FUNCTIONS
    //////////////////////////////////////////////////////////////*/


    /** @notice emergency withdrawal function
     * withdraws all funds of the contract to the owner´s account
     * callable only when the contract has been paused
     */
    function emergencyWithdrawal() external onlyOwner whenPaused {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed");
    }


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
  } // function _updateDeadline


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
  } // function _addBidder

  // from Pausable pattern
  // Function to pause/unpause the contract
  /**
    * @notice pauses/unpauses the contract at owner´s decision
    */
  function togglePause() external onlyOwner {
        paused = !paused;
  }

  


} // contract Auction


 /*///////////////////////////////////////////////////////////////
                     CHANGES
 //////////////////////////////////////////////////////////////*/
// - short strings in require messages
// - added withdrawal of remaining funds to owner at the end of refundDeposits()
// - added emergencyWithdrawal
// - implmented Pausable pattern, to enable emergencyWithdrawal(): functions which manipulate funds are only callable when not paused
// - incorporated modifiers whenPaused, whenNotPaused and function togglePause related to Pausable pattern
// - use "dirty variables" in loops
// - renamed struct BidToDisplay to Bid, simpler and more descriptive
// - incorported array bids to record all bids, in chronological order
// - eliminated variable highestBidder, which is now recoverable from the last element of bids.
// - modified revealWinner() and showOffers() according to the new data structuring
// - in returnDeposits(), funds are transferred using .call, and the returned boolean is analysed with a require
// - in returnDeposits(), highestBidder == address(0) if and only if there are no bids; no refunds are made in this case
//   BUT it would be wrong to include a modifier reverting in this case: no bids are perfectly acceptable and should be handled
//   Our implementation does issue AuctionEnded() event in this situation, as expected, which would not happen with the suggested modifier
