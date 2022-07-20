// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import './HauntooMinting.sol';

/// @title CryptoHauntoos: Collectible, breedable, and oh-so-adorable cats on the Ethereum blockchain.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev The main CryptoHauntoos contract, keeps track of babys so they don't wander around and get lost.
contract HauntooCore is HauntooMinting {

    // This is the main CryptoHauntoos contract. In order to keep our code seperated into logical sections,
    // we've broken it up in two ways. First, we have several seperately-instantiated sibling contracts
    // that handle auctions and our super-top-secret genetic combination algorithm. The auctions are
    // seperate since their logic is somewhat complex and there's always a risk of subtle bugs. By keeping
    // them in their own contracts, we can upgrade them without disrupting the main contract that tracks
    // hauntoo ownership. The genetic combination algorithm is kept seperate so we can open-source all of
    // the rest of our code without making it _too_ easy for folks to figure out how the genetics work.
    // Don't worry, I'm sure someone will reverse engineer it soon enough!
    //
    // Secondly, we break the core contract into multiple files using inheritence, one for each major
    // facet of functionality of CK. This allows us to keep related code bundled together while still
    // avoiding a single giant file with everything in it. The breakdown is as follows:
    //
    //      - HauntooBase: This is where we define the most fundamental code shared throughout the core
    //             functionality. This includes our main data storage, constants and data types, plus
    //             internal functions for managing these items.
    //
    //      - HauntooBreeding: This file contains the methods necessary to breed cats together, including
    //             keeping track of siring offers, and relies on an external genetic combination contract.
    //
    //      - HauntooAuctions: Here we have the public methods for auctioning or bidding on cats or siring
    //             services. The actual auction functionality is handled in two sibling contracts (one
    //             for sales and one for siring), while auction creation and bidding is mostly mediated
    //             through this facet of the core contract.
    //
    //      - HauntooMinting: This final facet contains the functionality we use for creating new gen0 cats.
    //             We can make up to 5000 "promo" cats that can be given away (especially important when
    //             the community is new), and all others can only be created and then immediately put up
    //             for auction via an algorithmically determined starting price. Regardless of how they
    //             are created, there is a hard limit of 50k gen0 cats. After that, it's all up to the
    //             community to breed, breed, breed!

    // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

    /// @notice Creates the main CryptoHauntoos smart contract instance.
    constructor() ERC721("Hauntoos", "HTO") {

        // Starts paused.
        // paused = true;
        _pause();

        // start with the mythical baby 0 - so we don't have generation-0 parent issues
        _createHauntoo(0, 0, 0, uint256(0), address(0));
    }

    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewAddress(address _v2Address) external onlyOwner whenPaused {
        // See README.md for updgrade plan
        newContractAddress = _v2Address;
        // ContractUpgrade(_v2Address);
    }

    /// @notice No tipping!
    /// @dev Reject all Ether from being sent here, unless it's from one of the
    ///  two auction contracts. (Hopefully, we can prevent user accidents.)
    fallback() external payable {
        require(
            msg.sender == address(saleAuction) ||
            msg.sender == address(siringAuction)
        );
    }

    receive() external payable {
        // emit Received(msg.sender, msg.value);
    }

    /// @notice Returns all the relevant information about a specific hauntoo.
    /// @param _id The ID of the hauntoo of interest.
    function getHauntoo(uint256 _id)
        external
        view
        returns (
        bool isGestating,
        bool isReady,
        uint256 cooldownIndex,
        uint256 nextActionAt,
        uint256 siringWithId,
        uint256 birthTime,
        uint256 matronId,
        uint256 sireId,
        uint256 generation,
        uint256 genes
    ) {
        Hauntoo storage hto = hauntoos[_id];

        // if this variable is 0 then it's not gestating
        isGestating = (hto.siringWithId != 0);
        isReady = (hto.cooldownEndBlock <= block.number);
        cooldownIndex = uint256(hto.cooldownIndex);
        nextActionAt = uint256(hto.cooldownEndBlock);
        siringWithId = uint256(hto.siringWithId);
        birthTime = uint256(hto.birthTime);
        matronId = uint256(hto.matronId);
        sireId = uint256(hto.sireId);
        generation = uint256(hto.generation);
        genes = hto.genes;
    }

    /// @dev Override unpause so it requires all external contract addresses
    ///  to be set before contract can be unpaused. Also, we can't have
    ///  newContractAddress set either, because then the contract was upgraded.
    /// @notice This is public rather than external so we can call super.unpause
    ///  without using an expensive CALL.
    function unpause() public onlyOwner whenPaused {
        require(address(saleAuction) != address(0));
        require(address(siringAuction) != address(0));
        require(address(geneScience) != address(0));
        require(address(newContractAddress) == address(0));

        // Actually unpause the contract.
        _unpause();
    }

    // @dev Allows the CFO to capture the balance available to the contract.
    function withdrawBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        // Subtract all the currently pregnant babys we have, plus 1 of margin.
        uint256 subtractFees = (pregnantHauntoos + 1) * autoBirthFee;

        if (balance > subtractFees) {
            payable(owner()).transfer(balance - subtractFees);
        }
    }
}