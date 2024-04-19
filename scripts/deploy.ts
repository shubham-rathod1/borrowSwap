import { ethers } from 'hardhat';
import borrowSwapAbi from '../abis/borrowSwap.json';
import ERC20Abi from '../abis/ERC20Abi.json';
import ERCProxy from '../abis/borrowSwap.json';
import cometAbi from '../abis/comet.json';
// import { getImplementationAddress } from '@openzeppelin/upgrades-core';

async function main() {
  const [owner, otherAccount] = await ethers.getSigners();

  const borrowSwap = await ethers.deployContract('BorrowSwap');
  await borrowSwap.waitForDeployment();

  const controller = await ethers.deployContract('Controller', [
    borrowSwap.target,
  ]);
  await controller.waitForDeployment();

  console.log('borrowSwap contract deployed at:', borrowSwap.target);
  console.log('controller contract deployed at:', controller.target);
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

  // console.log("tokens approved",owner.address);

  // console.log(
  //   'approval given - WETH',
  //   await Sushi.allowance(owner.address, controller.target),
  //   await Curv.allowance(owner.address, controller.target)
  //   // await Sushi.allowance(owner.address, borrowSwap.target)
  // );

  // console.log(
  //   'balance of curv, sushi',
  //   await WETH.balanceOf(owner.address)
  //   // await Sushi.balanceOf(owner.address)
  // );

  // await controller.compoundBorrow(
  //   "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
  //   "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
  //   "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",
  //   "500000000000000000",
  //   "244625095",
  //   owner.address
  // );

  // console.log('borrowed successfully');
  
  // await controller.compoundBorrow(
  //   '0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6',
  //   '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
  //   '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
  //   '1000000',
  //   '20000000',
  //   owner.address
  // );

  // console.log('borrowed successfully');

  // await controller.reapay(
  //   '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
  //   '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
  //   // '0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a',
  //   owner.address,
  //   '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619',
  //   '500000000100000000',
  //   '244625095'
  // );
  // console.log(address, "my contract address");

  await controller.uniBorrow(
    '0x784c4a12f82204e5fb713b055de5e8008d5916b6',
    '0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a',
    '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
    '0x172370d5cd63279efa6d502dab29171933a610af',
    '100000000000000000',
    '20000000000000000',
    owner.address
  );

  console.log("borrowed");

  await controller.uniRepay(
    '0x784c4a12f82204e5fb713b055de5e8008d5916b6',
    '0x172370d5cd63279efa6d502dab29171933a610af',
    '0x172370d5cd63279efa6d502dab29171933a610af',
    owner.address,
    1,
    '1000000000000000000',
    '10000000'
  );

  // const balance = await comet.collateralBalanceOf(
  //   addresses,
  //   '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'
  // );

  // const contractBalance = await comet.collateralBalanceOf(
  //   addresses,
  //   '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'
  // );

  // console.log('collateral balance of user', contractBalance);
  console.log(
    'user balance of borrowAsset',
    await USDT.balanceOf(owner.address)
  );

  // calling init to intiate borrow swap

  // await borrowSwap.InitBorrow(
  //   '0x784c4a12f82204e5fb713b055de5e8008d5916b6',
  //   '0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a',
  //   '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
  //   '0x172370d5cd63279efa6d502dab29171933a610af',
  //   '1000000000000000000',
  //   '1000000000000000'
  // );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
