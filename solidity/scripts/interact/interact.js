'use strict'

const {
    providers: { JsonRpcProvider },
    Contract,
    Wallet,
} = require('ethers')

const config = require('config');
const [ganache, avax, g, biannce] = config.get('chains');

const c = require('./artifacts/contracts/TokenLinker.sol/TokenLinker.json');


const contract = '0xE77D6A57cb03796fD2536E2cF5955AF6CA1c2616';

const IERC20 = require('./artifacts/@axelar-network/axelar-cgp-solidity/contracts/interfaces/IERC20.sol/IERC20.json');
const tokenAddr = '0xDE41332a508E363079FD6993B81De049cD362B6D';

// args
const destChain = 'osmosis-5';
const destContract = 'osmo1n6j7f3lve2w8h4pjc2xu2l3qe0zmq4z5lpvmdlckswv959zmh7gseww4y4';
const recipient = 'osmo1hrhv7xa8ejnk0k6e2kyn62fjjslme8tku28j2f';
const amount = 1000000;

(async () => {
    const wallet = new Wallet(
        biannce.privateKey,
        new JsonRpcProvider(biannce.url),
    );
    
    const tokenLinker = new Contract(contract, c.abi, wallet);

    console.log(`gateway is ${(await tokenLinker.gateway())}`)
    const originalToken = new Contract(tokenAddr, IERC20.abi, wallet);

    console.log(`wallet has ${(await originalToken.balanceOf(wallet.address)) / 1e6}`)

    const approveTx = await originalToken.approve(tokenLinker.address, amount);
    await approveTx.wait();

    const sendTx = await tokenLinker.transferToCosmos(destChain, destContract, recipient, amount);
    const tx = await sendTx.wait();
    
    console.log(`transaction hash is ${tx.transactionHash}`);
})();

