import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import { config as dotEnvConfig } from 'dotenv';
dotEnvConfig();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.20',
      }
    ],
    settings: {
      optimizer: {
        enabled: true,
        // runs: 1000,
      },
      viaIR: true,
    },
  },
  networks: {
    buildbear: {
      // url: 'https://rpc.buildbear.io/subjective-warpath-cccfa139',
      url: 'https://rpc.buildbear.io/arrogant-karma-142e6ce5',

      // url: 'https://rpc.buildbear.io/purring-magik-d55eb717',
      accounts: [process.env.WALLET_SECRET || ''],
    },
    hardhat: {
      forking: {
        url: `https://polygon-mainnet.g.alchemy.com/v2/lGRIjTUZouUNPNZoyjSAFlVL0f-kvJRK`,
        enabled: true,
      },
    },
  },
  etherscan: {
    apiKey: {
      buildbear: 'verifyContract',
    },
    customChains: [
      {
        network: 'buildbear',
        chainId: 18401,
        urls: {
          // apiURL: 'https://rpc.buildbear.io/dual-carnage-effb3e55',
          apiURL: 'https://rpc.buildbear.io/arrogant-karma-142e6ce5',
          browserURL: 'https://explorer.buildbear.io/arrogant-karma-142e6ce5/transactions',
        },
      },
    ],
  },
};

export default config;
