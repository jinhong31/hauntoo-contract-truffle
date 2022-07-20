const GeneScience = artifacts.require("GeneScience");
const HauntooCore = artifacts.require("HauntooCore");

module.exports = function (deployer) {
  deployer.deploy(GeneScience, '0xf820AEc491808B5FE6AB01d1905fB32df424c9e6', '0xf820AEc491808B5FE6AB01d1905fB32df424c9e6');
};
