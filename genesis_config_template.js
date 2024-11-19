"use strict";
const ADDRESS_LENGTH = 40;

module.exports = {
  // Owner address of the pre-deployed L2 contracts.
  contractOwner: "{{CONTRACT_OWNER}}",
  // Chain ID of the Taiko L2 network.
  chainId: {{CHAIN_ID}},
  // Account address and pre-mint ETH amount as key-value pairs.
  seedAccounts: [
    { "{{SEED_ACCOUNT}}": 10240 },
  ],
  // Owner Chain ID, Security Council, and Timelock Controller
  l1ChainId: {{L1_CHAIN_ID}},
  ownerSecurityCouncil: "{{OWNER_SECURITY_COUNCIL}}",
  ownerTimelockController: "{{OWNER_TIMELOCK_CONTROLLER}}",
  // L2 EIP-1559 baseFee calculation related fields.
  param1559: {
    gasExcess: 1,
  },
  // Option to pre-deploy an ERC-20 token.
  predeployERC20: true,
};

function getConstantAddress(prefix, suffix) {
  return `0x${prefix}${"0".repeat(
    ADDRESS_LENGTH - String(prefix).length - String(suffix).length,
  )}${suffix}`;
}
