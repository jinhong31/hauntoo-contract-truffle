// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
/// @title Base contract for CryptoHauntoos. Holds all common structs, events and base variables.
/// @author Axiom Zen (https://www.axiomzen.co)
/// @dev See the HauntooCore contract documentation to understand how the various contract facets are arranged.
abstract contract HauntooBase is ERC721Enumerable, Ownable, Pausable {
    /*** EVENTS ***/

    /// @dev The Birth event is fired whenever a new baby comes into existence. This obviously
    ///  includes any time a cat is created through the giveBirth method, but it is also called
    ///  when a new gen0 cat is created.
    event Birth(address owner, uint256 hauntooId, uint256 matronId, uint256 sireId, uint256 genes);

    /*** DATA TYPES ***/

    /// @dev The main Hauntoo struct. Every cat in CryptoHauntoos is represented by a copy
    ///  of this structure, so great care was taken to ensure that it fits neatly into
    ///  exactly two 256-bit words. Note that the order of the members in this structure
    ///  is important because of the byte-packing rules used by Ethereum.
    ///  Ref: http://solidity.readthedocs.io/en/develop/miscellaneous.html
    struct Hauntoo {
        uint256 genes;
        uint64 birthTime;
        uint64 cooldownEndBlock;
        uint32 matronId;
        uint32 sireId;
        uint32 siringWithId;
        uint16 cooldownIndex;
        uint16 generation;
    }

    /*** CONSTANTS ***/

    /// @dev A lookup table indicating the cooldown duration after any successful
    ///  breeding action, called "pregnancy time" for matrons and "siring cooldown"
    ///  for sires. Designed such that the cooldown roughly doubles each time a cat
    ///  is bred, encouraging owners not to just keep breeding the same cat over
    ///  and over again. Caps out at one week (a cat can breed an unbounded number
    ///  of times, and the maximum cooldown is always seven days).
    uint32[14] public cooldowns = [
        uint32(1 minutes),
        uint32(2 minutes),
        uint32(5 minutes),
        uint32(10 minutes),
        uint32(30 minutes),
        uint32(1 hours),
        uint32(2 hours),
        uint32(4 hours),
        uint32(8 hours),
        uint32(16 hours),
        uint32(1 days),
        uint32(2 days),
        uint32(4 days),
        uint32(7 days)
    ];

    // An approximation of currently how many seconds are in between blocks.
    uint256 public secondsPerBlock = 15;

    /*** STORAGE ***/
    mapping (uint256 => Hauntoo) public hauntoos;

    /// @dev A mapping from HauntooIDs to an address that has been approved to use
    ///  this Hauntoo for siring via breedWith(). Each Hauntoo can only have one approved
    ///  address for siring at any time. A zero value means no approval is outstanding.
    mapping (uint256 => address) public sireAllowedToAddress;

    /// @dev An internal method that creates a new hauntoo and stores it. This
    ///  method doesn't do any checking and should only be called when the
    ///  input data is known to be valid. Will generate both a Birth event
    ///  and a Transfer event.
    /// @param _matronId The hauntoo ID of the matron of this cat (zero for gen0)
    /// @param _sireId The hauntoo ID of the sire of this cat (zero for gen0)
    /// @param _generation The generation number of this cat, must be computed by caller.
    /// @param _genes The hauntoo's genetic code.
    /// @param _owner The inital owner of this cat, must be non-zero (except for the unHauntoo, ID 0)
    function _createHauntoo(
        uint256 _matronId,
        uint256 _sireId,
        uint256 _generation,
        uint256 _genes,
        address _owner
    )
        internal
        returns (uint)
    {
        // These requires are not strictly necessary, our calling code should make
        // sure that these conditions are never broken. However! _createHauntoo() is already
        // an expensive call (for storage), and it doesn't hurt to be especially careful
        // to ensure our data structures are always valid.
        require(_matronId == uint256(uint32(_matronId)));
        require(_sireId == uint256(uint32(_sireId)));
        require(_generation == uint256(uint16(_generation)));

        // New hauntoo starts with the same cooldown as parent gen/2
        uint16 cooldownIndex = uint16(_generation / 2);
        if (cooldownIndex > 13) {
            cooldownIndex = 13;
        }

        uint256 newHTOId = totalSupply() + 1;
        hauntoos[newHTOId] = Hauntoo({
            genes: _genes,
            birthTime: uint64(block.timestamp),
            cooldownEndBlock: 0,
            matronId: uint32(_matronId),
            sireId: uint32(_sireId),
            siringWithId: 0,
            cooldownIndex: cooldownIndex,
            generation: uint16(_generation)
        });

        // It's probably never going to happen, 4 billion cats is A LOT, but
        // let's just be 100% sure we never let this happen.
        require(newHTOId == uint256(uint32(newHTOId)));

        // emit the birth event
        emit Birth(
            _owner,
            newHTOId,
            uint256(hauntoos[newHTOId].matronId),
            uint256(hauntoos[newHTOId].sireId),
            hauntoos[newHTOId].genes
        );

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        // _transfer(0, _owner, newKittenId);
        if (_owner != address(0))
            _mint(_owner, newHTOId);

        return newHTOId;
    }

    // Any C-level can fix how many seconds per blocks are currently observed.
    function setSecondsPerBlock(uint256 secs) external onlyOwner {
        require(secs < cooldowns[0]);
        secondsPerBlock = secs;
    }
}