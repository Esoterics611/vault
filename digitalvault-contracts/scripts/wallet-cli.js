#!/usr/bin/env node
const { spawn } = require('child_process');
const path = require('path');

/**
 * Simple CLI wrapper for wallet utilities
 *
 * Usage:
 *   node scripts/wallet-cli.js create
 *   node scripts/wallet-cli.js list
 *   node scripts/wallet-cli.js balance 0xADDRESS
 *   node scripts/wallet-cli.js fund 0xADDRESS 1.5
 *   node scripts/wallet-cli.js content 1
 */

const command = process.argv[2];
const arg1 = process.argv[3];
const arg2 = process.argv[4];

if (!command) {
  console.log("Wallet CLI - DigitalVault");
  console.log("\nUsage: node scripts/wallet-cli.js <command> [args]");
  console.log("\nCommands:");
  console.log("  create              - Create new wallet");
  console.log("  list                - List all accounts");
  console.log("  balance <address>   - Check address balance");
  console.log("  fund <address> [amt]- Fund address (default 1 ETH)");
  console.log("  content <id>        - Get content details");
  console.log("\nExamples:");
  console.log("  node scripts/wallet-cli.js create");
  console.log("  node scripts/wallet-cli.js list");
  console.log("  node scripts/wallet-cli.js balance 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  process.exit(0);
}

// Set environment variables
const env = { ...process.env, CMD: command };
if (arg1) env.ARG1 = arg1;
if (arg2) env.ARG2 = arg2;

// Run hardhat script
const hardhat = spawn(
  'npx',
  ['hardhat', 'run', 'scripts/wallet-utils.js', '--network', 'localhost'],
  {
    env,
    stdio: 'inherit',
    shell: true
  }
);

hardhat.on('close', (code) => {
  process.exit(code);
});
