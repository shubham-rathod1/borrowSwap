import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import { config as dotEnvConfig } from 'dotenv';
dotEnvConfig();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.20',
      },
      // {
      //   version: '0.7.6',
      // },
    ],
  },
  networks: {
    buildbear: {
      // url: 'https://rpc.buildbear.io/dual-carnage-effb3e55',
      url: 'https://rpc.buildbear.io/purring-magik-d55eb717',
      // url: 'https://rpc.buildbear.io/honest-spiderwoman-6c6fbc8e',
      accounts: [process.env.WALLET_SECRET || ''],
    },
    hardhat: {
      forking: {
        url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API}`,
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
        chainId: 16153,
        urls: {
          // apiURL: 'https://rpc.buildbear.io/dual-carnage-effb3e55',
          apiURL: 'https://rpc.buildbear.io/honest-spiderwoman-6c6fbc8e',
          browserURL: 'https://explorer.buildbear.io/dual-carnage-effb3e55',
        },
      },
    ],
  },
};

export default config;
