// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import './HauntooAuction.sol';
/// @title all functions related to creating babys
abstract contract HauntooMinting is HauntooAuction {

    // Limits the number of cats the contract owner can ever create.
    uint256 public constant PROMO_CREATION_LIMIT = 5000;
    uint256 public constant GEN0_CREATION_LIMIT = 45000;

    // Constants for gen0 auctions.
    uint256 public constant GEN0_STARTING_PRICE = 5 ether;
    uint256 public constant GEN0_AUCTION_DURATION = 1 days;

    // Counts the number of cats the contract owner has created.
    uint256 public promoCreatedCount;
    uint256 public gen0CreatedCount;

    /// @dev we can create promo babys, up to a limit. Only callable by owner
    /// @param _genes the encoded genes of the baby to be created, any value is accepted
    /// @param _owner the future owner of the created babys. Default to contract owner
    function createPromoHauntoo(uint256 _genes, address _owner) external onlyOwner {
        address hauntooOwner = _owner;
        if (hauntooOwner == address(0)) {
            hauntooOwner = owner();
        }
        require(promoCreatedCount < PROMO_CREATION_LIMIT);

        promoCreatedCount++;
        _createHauntoo(0, 0, 0, _genes, hauntooOwner);
    }

    /// @dev Creates a new gen0 hauntoo with the given genes and
    ///  creates an auction for it.
    function createGen0Auction(uint256 _genes) external onlyOwner {
        require(gen0CreatedCount < GEN0_CREATION_LIMIT);

        uint256 hauntooId = _createHauntoo(0, 0, 0, _genes, address(this));
        _approve(address(saleAuction), hauntooId);

        saleAuction.createAuction(
            hauntooId,
            _computeNextGen0Price(),
            0,
            GEN0_AUCTION_DURATION,
            address(this)
        );

        gen0CreatedCount++;
    }

    /// @dev Computes the next gen0 auction starting price, given
    ///  the average of the past 5 prices + 50%.
    function _computeNextGen0Price() internal view returns (uint256) {
        uint256 avePrice = saleAuction.averageGen0SalePrice();

        // Sanity check to ensure we don't overflow arithmetic
        require(avePrice == uint256(uint128(avePrice)));

        uint256 nextPrice = avePrice + (avePrice / 2);

        // We never auction for less than starting price
        if (nextPrice < GEN0_STARTING_PRICE) {
            nextPrice = GEN0_STARTING_PRICE;
        }

        return nextPrice;
    }
}