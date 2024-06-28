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
      // url: 'https://rpc.buildbear.io/powerful-vision-50dcd8b1',
      url: 'https://rpc.buildbear.io/arrogant-karma-142e6ce5',
      // url: 'https://polygon-mainnet.g.alchemy.com/v2/lGRIjTUZouUNPNZoyjSAFlVL0f-kvJRK',
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
        chainId: 18401,
        urls: {
          apiURL:
            'https://rpc.buildbear.io/verify/etherscan/arrogant-karma-142e6ce5',
          browserURL:
            'https://explorer.buildbear.io/arrogant-karma-142e6ce5',
        },
      },
    ],
  },
};

export default config;
