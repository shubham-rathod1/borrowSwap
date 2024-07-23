import { ethers } from 'hardhat';
import borrowSwapAbi from '../abis/borrowSwap.json';
import { abi } from '../artifacts/contracts/Controller.sol/Controller.json';
import ERC20Abi from '../abis/ERC20Abi.json';
import ERCProxy from '../abis/borrowSwap.json';
import cometAbi from '../abis/comet.json';
// import { getImplementationAddress } from '@openzeppelin/upgrades-core';

async function main() {
  const [owner, otherAccount] = await ethers.getSigners();

  const borrowSwap = await ethers.deployContract('Logic');
  await borrowSwap.waitForDeployment();

  const controller = await ethers.deployContract('Controller', [
    borrowSwap.target,
  ]);
  await controller.waitForDeployment();

  // const encoded = await ethers.deployContract('Encoding');
  // await encoded.waitForDeployment();
  
  // const controller = await ethers.getContractAt(
  //   abi,
  //   '0x28202Df29E0a909EB023f5b464BC166E24556018'
  // );

  console.log('borrowSwap contract deployed at:', borrowSwap.target);
  console.log('controller contract deployed at:', controller.target);
  // console.log('encoding contract deployed at:', encoded.target);
  // let addresses = await controller.proxyAddress(`${owner.address}`);
  // console.log(addresses, 'contract address mapping');

  const comet = await ethers.getContractAt(
    cometAbi,
    '0xF25212E676D1F7F89Cd72fFEe66158f541246445'
  );

  // setting approval

  const Curv = await ethers.getContractAt(
    ERC20Abi,
    '0x172370d5cd63279efa6d502dab29171933a610af'
  );

  const Sushi = await ethers.getContractAt(
    ERC20Abi,
    '0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a'
  );

  const WETH = await ethers.getContractAt(
    ERC20Abi,
    '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'
  );
  const USDCe = await ethers.getContractAt(
    ERC20Abi,
    '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174'
  );
  const USDT = await ethers.getContractAt(
    ERC20Abi,
    '0xc2132d05d31c914a87c6611c10748aeb04b58e8f'
  );
  const WBTC = await ethers.getContractAt(
    ERC20Abi,
    '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6'
  );

  await WETH.approve(controller.target, '1000000000000000000000000');

  await Sushi.approve(controller.target, '100000000000000000000000');
  await Curv.approve(controller.target, '1000000000000000000000000');
  await USDCe.approve(controller.target, '100000000000');
  await USDT.approve(controller.target, '300000000000000');
  await WBTC.approve(controller.target, '1000000000000000000000000');

  console.log("compound borrow started")

  await controller.compoundBorrow({
    _supplyAsset: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
    _borrowAsset: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
    _tokenOut: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
    _supplyAmount: '500000000000000000',
    _borrowAmount: '244625095',
    _user: owner.address,
    _route: [3000, 10000],
  });

  console.log('comp borrowed');


  await controller.compRepay({
    _borrowedToken: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
    _tokenIn: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
    _repayAmount: '244625095',
    _route: [3000, 10000],
  });
  console.log('comp repaid');

  await controller.compRedeem({
    _user: owner.address,
    _collateralToken: '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
    _collateralAmount: '5000000001000',
    _tokenOut: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
    _route: [3000, 10000],
  });

  console.log('comp redemeed');

  // const coder = new ethers.AbiCoder();

  await controller.uniBorrow({
    _pool: '0x784c4a12f82204e5fb713b055de5e8008d5916b6',
    _supplyAsset: '0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a',
    _tokenOUt: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
    _collateral_amount: '10000000000000000000',
    _amount: '200000000000000',
    _user: owner.address,
    _route: [3000, 10000],
  });

  console.log('uni borrowed');

  // console.log(
  //   'borrowed',
  //   coder.encode(
  //     ['address', 'uint256'],
  //     ['0x172370d5Cd63279eFa6d502DAB29171933a610AF', 3000]
  //   )
  // );

  await controller.uniRepay({
    _pool: '0x784c4a12f82204e5fb713b055de5e8008d5916b6',
    _tokenIn: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
    _user: owner.address,
    _borrowAddress: '0x172370d5cd63279efa6d502dab29171933a610af',
    _repayAmount: '10000',
    _route: [500],
  });

  console.log('uni repaid');

  await controller.uniRedeem({
    _pool: '0x784c4a12f82204e5fb713b055de5e8008d5916b6',
    _user: '0x99A221a87b3C2238C90650fa9BE0F11e4c499D06',
    _amount: '-1000000',
    _tokenOut: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
    _route: [3000, 500],
  });

  console.log('uni redeemed');

  console.log(
    'user balance of borrowAsset',
    await USDT.balanceOf(owner.address)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
