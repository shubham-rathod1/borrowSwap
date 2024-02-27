import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import { config as dotEnvConfig } from 'dotenv';
dotEnvConfig();

const config: HardhatUserConfig = {
  solidity: '0.7.6',
  networks: {
    buildbear: {
      url: 'https://rpc.buildbear.io/energetic-electro-22450100',
      accounts: [process.env.WALLET_SECRET || ""],
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
        chainId: 15021,
        urls: {
          apiURL:
            'https://rpc.buildbear.io/verify/etherscan/energetic-electro-22450100',
          browserURL:
            'https://explorer.buildbear.io/energetic-electro-22450100',
        },
      },
    ],
  },
};

export default config;
