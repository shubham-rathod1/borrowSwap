import { ethers } from 'hardhat';
import borrowSwapAbi from '../abis/borrowSwap.json';
import ERC20Abi from '../abis/ERC20Abi.json';
import ERCProxy from '../abis/borrowSwap.json';
// import { getImplementationAddress } from '@openzeppelin/upgrades-core';

async function main() {
  const [owner, otherAccount] = await ethers.getSigners();

  const borrowSwap = await ethers.deployContract('BorrowSwap', [
    '0xE592427A0AEce92De3Edee1F18E0157C05861564',
    '0x0d500b1d8e8ef31e21c99d1db9a6444d3adf1270',
    '0x17dad892347803551CeEE2D377d010034df64347',
  ]);
  await borrowSwap.waitForDeployment();

  console.log('borrowSwap contract deployed at:', borrowSwap.target);

  // const borrowSwap = await ethers.getContractAt(
  //   borrowSwapAbi,
  //   '0x06f483894d1c5fD23B999CaC46Fdd325209d2DB4'
  // );

  // setting approval

  const Curv = await ethers.getContractAt(
    ERC20Abi,
    '0x172370d5cd63279efa6d502dab29171933a610af'
  );

  const Sushi = await ethers.getContractAt(
    ERC20Abi,
    '0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a'
  );

  await Curv.approve(borrowSwap.target, '100000000000000000000');

  await Sushi.approve(borrowSwap.target, '100000000000000000000');

  console.log("tokens approved",owner.address);

  console.log(
    'approval given - curv, sushi',
    await Curv.allowance(owner.address, borrowSwap.target),
    await Sushi.allowance(owner.address, borrowSwap.target)
  );

  console.log(
    'balance of curv, sushi',
    await Curv.balanceOf(owner.address),
    await Sushi.balanceOf(owner.address)
  );

  // calling init to intiate borrow swap

  await borrowSwap.InitBorrow(
    '0x784c4a12f82204e5fb713b055de5e8008d5916b6',
    '0x0b3f868e0be5597d5db7feb59e1cadbb0fdda50a',
    '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
    '0x172370d5cd63279efa6d502dab29171933a610af',
    '1000000000000000000',
    '10000000000000000'
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
