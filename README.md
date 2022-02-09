# Freelancer Project. DyDx FlashLoan + AAVE + CURVEFI + UNISWAP

This project includes the commented and logged contract for ease of understanding and learning on how to perform a DyDx loan, and interact with various protocols.

Initial approach took a loan of WETH and used UniSwap to get USDC and USDT, this method was unrelaiable and fee expensive.

The direct borrow of USDC and USDT was also considered but DyDx only has USDC avaliable for flashloan and only ~$8,000,000

Final and implemented method consist on a series of deposits and WETH collateralized stablecoin borrows on the AAVE protocol the get
USDT and USDC virtually at no 0% fee cost.

The result of this approach at block 13506500 is ~$33,440,000 in USDC and ~$33,440,000 in USDT. 

With Curve.fi Swaps disabled the loan can be paid, only paying gas fees; with the swaps enabled, the loan is not payable as Curve takes a fee on each swap resulting in a loss of ~22,000 USD.

## How To Run this Project

Clone the repo or unzip it, then open the folder on VsCode and run the following in the terminal:

```
// Intall dependencies
npm install --save-dev hardhat @nomiclabs/hardhat-waffle ethereum-waffle chai @nomiclabs/hardhat-ethers ethers

// Compile the contracts
npx hardhat compile

// On another terminal fork the ETH mainet
npx hardhat node --fork https://speedy-nodes-nyc.moralis.io/your-key/eth/mainnet/archive --fork-block-number 13506500

// (runs the test contract that logs on every step with CurveFi swaps disabled)
npx hardhat test --network localhost 

// (runs the no comment contract with CurveFi swaps enabled)
npx hardhat run scripts/deploy.js --network localhost
```

Both dydx.sol and FlashLoanNoComments.sol have the explanation of their workings inside.

Please make all the tests in the forked enviroment before jumping into the mainet.

Thank you!

Logs with Curve.fi Swaps Enabled:

```
  console.log:
    Logic Start ;)
    [DyDx] WETH FlashLoan: 20000 ( FLASHLOAN WETH )
    [CONTRACT] WETH:  20000
    --- Borrow USDC and USDT from AAVE ---
    (essentialy swap our assets to stablecoins without paying Uniswap fees)
    [AAVE] Approve lending pool to use our WETH
    [AAVE] Deposit all WETH - 2 wei:
    [CONTRACT] WETH ( in wei ): 2
    [CONTRACT] aWETH ( in ether ): 20000
    We can borrow up to 80% of the collateral
    [AAVE] Borrow USDT with 4/10 of the WETH...
    [CONTRACT] USDT:  33440000
    [AAVE] Borrow USDC with 4/10 of the WETH...
    [CONTRACT] USDC:  33440000
    ---- Protocol Interactions ----
    ############# AAVE ##############
    [AAVE] Deposit USDC and get aUSDC
    [CONTRACT] USDC:  0
    [CONTRACT] aUSDC:  33440000
    [AAVE] Withdraw all aUSDC:
    [CONTRACT] aUSDC:  0
    [CONTRACT] USDC:  33440000
    ########### AAVE END ############
    ############# CURVE ##############
    [CURVE] Approve USDT
    [CURVE] Approve USDC
    [CONTRACT] USDT: 33440000
    [CONTRACT] USDC: 33440000
    [CURVE] Swap USDT to USDC
    [CONTRACT] USDT: 66852991
    [CONTRACT] USDC: 0
    [CURVE] Swap USDC to USDT
    [CONTRACT] USDT: 33440000
    [CONTRACT] USDC: 33413254
    ############ CURVE END ############
    ---- Repay USDC and USDT loans ----
    [AAVE] Approve USDT
    [AAVE] Approve USDC
    [AAVE] Repay the USDC and USDT

  Error: VM Exception while processing transaction: reverted with reason string 'NOT ENOUGH USDC TO PAY 
FOR AAVE LOAN'
```

Logs for Curve.fi swaps disabled:

```
  console.log:
    Logic Start ;)
    [DyDx] WETH FlashLoan: 20000 ( FLASHLOAN WETH )
    [CONTRACT] WETH:  20000
    --- Borrow USDC and USDT from AAVE ---
    (essentialy swap our assets to stablecoins without paying Uniswap fees)
    [AAVE] Approve lending pool to use our WETH
    [AAVE] Deposit all WETH - 2 wei:
    [CONTRACT] WETH ( in wei ): 2
    [CONTRACT] aWETH ( in ether ): 20000
    We can borrow up to 80% of the collateral
    [AAVE] Borrow USDT with 4/10 of the WETH...
    [CONTRACT] USDT:  33440000
    [AAVE] Borrow USDC with 4/10 of the WETH...
    [CONTRACT] USDC:  33440000
    ---- Protocol Interactions ----
    ############# AAVE ##############
    [AAVE] Deposit USDC and get aUSDC
    [CONTRACT] USDC:  0
    [CONTRACT] aUSDC:  33440000
    [AAVE] Withdraw all aUSDC:
    [CONTRACT] aUSDC:  0
    [CONTRACT] USDC:  33440000
    ########### AAVE END ############
    ############# CURVE ##############
    [CURVE] Approve USDT
    [CURVE] Approve USDC
    [CONTRACT] USDT: 33440000
    [CONTRACT] USDC: 33440000
    [CURVE] Swap USDT to USDC
    [CONTRACT] USDT: 33440000
    [CONTRACT] USDC: 33440000
    [CURVE] Swap USDC to USDT
    [CONTRACT] USDT: 33440000
    [CONTRACT] USDC: 33440000
    ############ CURVE END ############
    ---- Repay USDC and USDT loans ----
    [AAVE] Approve USDT
    [AAVE] Approve USDC
    [AAVE] Repay the USDC and USDT
    [CONTRACT] USDC ( after payment ):  0
    [CONTRACT] USDT ( after payment ):  0
    [AAVE] Withdraw all aWETH:  0 aWETH
    [CONTRACT] aWETH:  0
    [CONTRACT] WETH:  20000
    DyDx Loan Paid !!!

```
