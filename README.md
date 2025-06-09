# ETH-KIPU-2025-TP-MOD-2
Auction with extensible deadline and minimum bid increase

Simple excercise to fullfil ETH KIPU 2025 MODULE 2 assignment. 
Auction contrat showcasing basic data structures.

# Workflow:
- contract is deployed with its configuration parameters: initial bid to surpass and duration (in seconds)
- users bid sending ethers to the contract while the auction is active. A new valid bid must surpass the previous highest one by BID_INCREASE %. If the new valid bid is placed within DEADLINE_EXTENSION (10 minutes) from the deadline, the latter is increased by DEADLINE_EXTENSION. A NewOffer event is emitted, showing address of new highest bidder and amount.
- users which place successive bids may get a partial refund from their previous bids, keeping only their latest offer in the contract.
- when auction deadline is reached, it is possible to reveal the winner, along the winning bid.
- onece the auction is finished, the owner will proceed to refund all the non-winning offers, retaining a RETURN_DEPOSIT_DISCOUNT (2%). An AuctionEnded() event is emitted.

# Dev notes:
- we use the pattern Iterable Mapping (https://edp.ethkipu.org/modulo-3/estandares-librerias-y-patrones/patrones-de-diseno  item 9), consisting of a `mapping (Key => Value) map` and an associated array `Keys[] keys` to iterate over the `(keys[i],map[keys[i]])` pairs.
- we use an iterable mapping `mapping (address => Bidder)` to record a bidder´s current offer and total deposited (to calculate refunds). The following invariant relates `bidders` mapping and `biddersAddresses` array:
  ```
   forall address.
      bidders[address].exists <==> Exists i < biddersAddresses.length.   biddersAddresses[i] == address
  ```
- we build an array `BidderToDisplay[]` with pairs `(bidderAddress, offer)` to show the list of current bidders and their offers, build upon iteration over the keys array `biddersAddresses`.
  
- `highestBid` holds initially the starting bid set by the contract deployer (`owner`). After the first bid is placed, it holds the highest offer. The following #invariabt holds:
  ```
  (biddersAddresses.length > 0) ==>
             [highestBid == bidders[highestBidder].offer
             && forall address. (highestBid >= bidders[address].offer
                && activeAuction ==>  bidders[address].deposit >= bidders[address].offer)
             && address(this).balance >= highestBid]
  ```
