// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
import './HauntooBreeding.sol';

abstract contract SaleClockAuctionInterface {
    function createAuction(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        address _seller
    )
        external virtual ;
    function isSaleClockAuction() external virtual returns (bool);
    function withdrawBalance() external virtual;
    function averageGen0SalePrice() external virtual view returns (uint256);
}

abstract contract SiringClockAuctionInterface {
    function createAuction(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration,
        address _seller
    )
        external virtual;
    function isSiringClockAuction() external virtual returns (bool);
    function bid(uint256 _tokenId) external payable virtual;
    function getCurrentPrice(uint256 _tokenId)
        external
        view virtual
        returns (uint256);
    function withdrawBalance() external virtual;
}

/// @title Handles creating auctions for sale and siring of hauntoos.
///  This wrapper of ReverseAuction exists only so that users can create
///  auctions with only one transaction.
abstract contract HauntooAuction is HauntooBreeding {

   /// @dev The address of the ClockAuction contract that handles sales of Hauntoos. This
    ///  same contract handles both peer-to-peer sales as well as the gen0 sales which are
    ///  initiated every 15 minutes.
    SaleClockAuctionInterface public saleAuction;

    /// @dev The address of a custom ClockAuction subclassed contract that handles siring
    ///  auctions. Needs to be separate from saleAuction because the actions taken on success
    ///  after a sales and siring auction are quite different.
    SiringClockAuctionInterface public siringAuction;
    
    // @notice The auction contract variables are defined in HauntooBase to allow
    //  us to refer to them in HauntooOwnership to prevent accidental transfers.
    // `saleAuction` refers to the auction for gen0 and p2p sale of hauntoos.
    // `siringAuction` refers to the auction for siring rights of hauntoos.

    /// @dev Sets the reference to the sale auction.
    /// @param _address - Address of sale contract.
    function setSaleAuctionAddress(address _address) external onlyOwner {
        SaleClockAuctionInterface candidateContract = SaleClockAuctionInterface(_address);

        // NOTE: verify that a contract is what we expect - https://github.com/Lunyr/crowdsale-contracts/blob/cfadd15986c30521d8ba7d5b6f57b4fefcc7ac38/contracts/LunyrToken.sol#L117
        require(candidateContract.isSaleClockAuction());

        // Set the new contract address
        saleAuction = candidateContract;
    }

    /// @dev Sets the reference to the siring auction.
    /// @param _address - Address of siring contract.
    function setSiringAuctionAddress(address _address) external onlyOwner {
        SiringClockAuctionInterface candidateContract = SiringClockAuctionInterface(_address);

        // NOTE: verify that a contract is what we expect - https://github.com/Lunyr/crowdsale-contracts/blob/cfadd15986c30521d8ba7d5b6f57b4fefcc7ac38/contracts/LunyrToken.sol#L117
        require(candidateContract.isSiringClockAuction());

        // Set the new contract address
        siringAuction = candidateContract;
    }

    /// @dev Put a hauntoo up for auction.
    ///  Does some ownership trickery to create auctions in one tx.
    function createSaleAuction(
        uint256 _hauntooId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    )
        external
        whenNotPaused
    {
        // Auction contract checks input sizes
        // If hauntoo is already on any auction, this will throw
        // because it will be owned by the auction contract.
        require(ownerOf(_hauntooId) == msg.sender);
        // Ensure the hauntoo is not pregnant to prevent the auction
        // contract accidentally receiving ownership of the child.
        // NOTE: the hauntoo IS allowed to be in a cooldown.
        require(!isPregnant(_hauntooId));
        approve(address(saleAuction), _hauntooId);
        // Sale auction throws if inputs are invalid and clears
        // transfer and sire approval after escrowing the hauntoo.
        saleAuction.createAuction(
            _hauntooId,
            _startingPrice,
            _endingPrice,
            _duration,
            msg.sender
        );
    }

    /// @dev Put a hauntoo up for auction to be sire.
    ///  Performs checks to ensure the hauntoo can be sired, then
    ///  delegates to reverse auction.
    function createSiringAuction(
        uint256 _hauntooId,
        uint256 _startingPrice,
        uint256 _endingPrice,
        uint256 _duration
    )
        external
        whenNotPaused
    {
        // Auction contract checks input sizes
        // If hauntoo is already on any auction, this will throw
        // because it will be owned by the auction contract.
        require(ownerOf(_hauntooId) == msg.sender);
        require(isReadyToBreed(_hauntooId));
        approve(address(siringAuction), _hauntooId);
        // Siring auction throws if inputs are invalid and clears
        // transfer and sire approval after escrowing the hauntoo.
        siringAuction.createAuction(
            _hauntooId,
            _startingPrice,
            _endingPrice,
            _duration,
            msg.sender
        );
    }

    /// @dev Completes a siring auction by bidding.
    ///  Immediately breeds the winning matron with the sire on auction.
    /// @param _sireId - ID of the sire on auction.
    /// @param _matronId - ID of the matron owned by the bidder.
    function bidOnSiringAuction(
        uint256 _sireId,
        uint256 _matronId
    )
        external
        payable
        whenNotPaused
    {
        // Auction contract checks input sizes
        require(ownerOf(_matronId) == msg.sender);
        require(isReadyToBreed(_matronId));
        require(_canBreedWithViaAuction(_matronId, _sireId));

        // Define the current price of the auction.
        uint256 currentPrice = siringAuction.getCurrentPrice(_sireId);
        require(msg.value >= currentPrice + autoBirthFee);

        // Siring auction will throw if the bid fails.
        siringAuction.bid{value: msg.value - autoBirthFee}(_sireId);
        _breedWith(uint32(_matronId), uint32(_sireId));
    }

    /// @dev Transfers the balance of the sale auction contract
    /// to the HauntooCore contract. We use two-step withdrawal to
    /// prevent two transfer calls in the auction bid function.
    function withdrawAuctionBalances() external onlyOwner {
        saleAuction.withdrawBalance();
        siringAuction.withdrawBalance();
    }
}