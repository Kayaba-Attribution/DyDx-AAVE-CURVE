// SPDX-License-Identifier: AGPL-3.0-or-later

/*
     __    ____        ____          ________           __    __                          __
   _/ /   / __ \__  __/ __ \_  __   / ____/ /___ ______/ /_  / /   ____  ____ _____     _/ /
  / __/  / / / / / / / / / / |/_/  / /_  / / __ `/ ___/ __ \/ /   / __ \/ __ `/ __ \   / __/
 (_  )  / /_/ / /_/ / /_/ />  <   / __/ / / /_/ (__  ) / / / /___/ /_/ / /_/ / / / /  (_  ) 
/  _/  /_____/\__, /_____/_/|_|  /_/   /_/\__,_/____/_/ /_/_____/\____/\__,_/_/ /_/  /  _/  
/_/          /____/                                                                  /_/

    Author: Kayaba_Attribution || Juan David Gomez Villalba 
    With Love <3
    
*/

pragma solidity ^0.8.0;


library SafeERC20 {
    
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves.

        // A Solidity high level call has three parts:
        //  1. The target address is checked to verify it contains contract code
        //  2. The call itself is made, and success asserted
        //  3. The return value is decoded, which in turn checks the size of the returned data.
        // solhint-disable-next-line max-line-length

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

library Types {
    enum AssetDenomination { Wei, Par }
    enum AssetReference { Delta, Target }
    struct AssetAmount {
        bool sign;
        AssetDenomination denomination;
        AssetReference ref;
        uint256 value;
    }
}

library Account {
    struct Info {
        address owner;
        uint256 number;
    }
}

library Actions {
    enum ActionType {
        Deposit, Withdraw, Transfer, Buy, Sell, Trade, Liquidate, Vaporize, Call
    }
    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        Types.AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }
}

interface ISoloMargin {
    function operate(Account.Info[] memory accounts, Actions.ActionArgs[] memory actions) external;
}

// The interface for a contract to be callable after receiving a flash loan
interface ICallee {
    function callFunction(address sender, Account.Info memory accountInfo, bytes memory data) external;
}

// Standard ERC-20 interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Additional methods available for WETH
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

// Uniswap V2 Interface ( swaps and on-chain price oracle)
interface IUNISWAPV2 {
    function swapExactTokensForTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
    uint amountOut,
    uint amountInMax,
    address[] calldata path,
    address to,
    uint deadline
    ) external returns (uint[] memory amounts);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

// AAVE LendingPool Interface
interface IAAVE {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external;
} 

// CurveFi Y Pool Interface
interface CURVEFI {
  function exchange_underlying(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
  function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
  function get_dy(int128 i, int128 j, uint256 dx) external view returns (uint256);
}

// To use other protocols create an interface I(protocol) get the function you want to call and set the visibility to external


contract FlashLoanNoComments is ICallee {
    
    //SafeERC20 is used due USDT being nor ERC-20 compliant
    using SafeERC20 for IERC20;

    // All addresses are from Mainet. Use this contract on a Mainet fork for testing

    // Protocols interface-address declarations
    IWETH private WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUNISWAPV2 private immutable uniRouter = IUNISWAPV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IAAVE private immutable AaveLendingPool = IAAVE(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    CURVEFI private immutable CurvefiYPool = CURVEFI(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);

    // ERC-20 interface-address declarations
    IERC20 private immutable USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private immutable USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private immutable aUSDC = IERC20(0xBcca60bB61934080951369a648Fb03DF4F96263C);
    IERC20 private immutable aWETH = IERC20(0x030bA81f1c18d280636F32af80b9AAd02Cf0854e);

    // On chain price oracle
    IUNISWAPV2 private immutable ETH_USDC_POOL = IUNISWAPV2(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);

    // The dydx Solo Margin contract, as can be found here:
    // https://github.com/dydxprotocol/solo/blob/master/migrations/deployed.json
    ISoloMargin private soloMargin = ISoloMargin(0x1E0447b19BB6EcFdAe1e4AE1694b0C3659614e4e);

    constructor() {
        // Approve max WETH to the DyDx to pay the loan back to itself.
        WETH.approve(address(soloMargin), uint(type(uint).max));
    }
    
    // This is the main function 
    function flashLoan(uint loanAmount) external {
        
        /*

        DyDx Flashloan overview:

        + FalshLoan functionality is run by the 'operate function'
        + Takes a list of operations and runs them (checks for balance at the end)
        + We need to create 3 functions:
            + Withdraw (take the funds)
            + Call     (runs the callFunction method AKA our logic)
            + Deposit  (repay the loan + 2 wei fee ( no need to call it is auto ))
            + Pass these three to operate
        + The loan is given in ERC-20

        To take a loan on another currency set primaryMarketId to the desired index:
        0 => WETH
        1 => SAI
        2 => USDC
        3 => DAI

        */
        
        // Create an instance of the Actions library, the struc ActionArgs, and populate it 
        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        // Create the Withdraw operation
        operations[0] = Actions.ActionArgs({
            actionType: Actions.ActionType.Withdraw,
            accountId: 0,
            amount: Types.AssetAmount({
                sign: false,
                denomination: Types.AssetDenomination.Wei,
                ref: Types.AssetReference.Delta,
                value: loanAmount // Amount to borrow (when calling flashloan enter the amount in wei. Remember using the correct decimals)
            }),
            primaryMarketId: 0, // WETH
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: ""
        });
        
        // Create the call operation
        operations[1] = Actions.ActionArgs({
                actionType: Actions.ActionType.Call,
                accountId: 0,
                amount: Types.AssetAmount({
                    sign: false,
                    denomination: Types.AssetDenomination.Wei,
                    ref: Types.AssetReference.Delta,
                    value: 0
                }),
                primaryMarketId: 0,
                secondaryMarketId: 0,
                otherAddress: address(this),
                otherAccountId: 0,
                data: abi.encode(
                    // Replace or add any additional variables that you want
                    // to be available to the receiver function
                    msg.sender,
                    loanAmount
                )
            });
        
        // Create the deposit operation
        operations[2] = Actions.ActionArgs({
            actionType: Actions.ActionType.Deposit,
            accountId: 0,
            amount: Types.AssetAmount({
                sign: true,
                denomination: Types.AssetDenomination.Wei,
                ref: Types.AssetReference.Delta,
                value: loanAmount + 2 // Repayment amount with 2 wei fee
            }),
            primaryMarketId: 0, // WETH
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: ""
        });

        // Create an instance of the Account library and the Struct info
        Account.Info[] memory accountInfos = new Account.Info[](1);
        // Populate it with the correct values
        accountInfos[0] = Account.Info({owner: address(this), number: 1});

        // Call the operaate function with our details and operations
        soloMargin.operate(accountInfos, operations);
    }
 
    // Standard swap function using Uniswap
    function swapper(uint t_amount, address token1, address token2) private {
        address[] memory path = new address[](2);
        path[0] = token1;
        path[1] = token2;
        uint amountIn = t_amount;
        uint amountOutMin = 0;
        
        IERC20(token1).approve(address(uniRouter), amountIn);
             
        uniRouter.swapExactTokensForTokens(
            amountIn, 
            amountOutMin,
            path, 
            address(this), 
            block.timestamp + 60
        );

    }

    // On chain oracle to get the price of ETH ( Uses the ETH/USDC pool )
    // Used the caculate how much USDC and USDT can we borrow with WETH as collateral
    // Returns the amount on USDC/USDT decimals
    function getEthUsdPrice(uint amountETH) public view returns (uint) {
        (
            uint112 reserve0,
            uint112 reserve1,
        ) = ETH_USDC_POOL.getReserves();

        reserve0 = reserve0 / 10**6;
        reserve1 = reserve1 / 10**18;

        amountETH = amountETH / 10**18;
        //To see the underlaying reserves uncomment the following lines
        //console.log(reserve0);
        //console.log(reserve1);

        return amountETH * ((reserve0 / reserve1) * 10**6);
    }

    
    // This is the function called by dydx after giving us the loan
    function callFunction(address sender, Account.Info memory accountInfo, bytes memory data) external override {
        // Decode the passed variables from the data object
        (
            // This must match the variables defined in the Call object above
            address payable actualSender,
            uint loanAmount
        ) = abi.decode(data, (
            address, uint
        ));

        WETH.approve(address(AaveLendingPool), WETH.balanceOf(address(this)));
 
        AaveLendingPool.deposit(
            address(WETH),
            WETH.balanceOf(address(this)) - 2,
            address(this),
            0
        );

        uint inital_aWETH_balance = aWETH.balanceOf(address(this));

        // Borrow USDC and USDT
        AaveLendingPool.borrow
        (
            address(USDT),
            getEthUsdPrice(inital_aWETH_balance * 4/10),
            2,
            0,
            address(this
        ));
        AaveLendingPool.borrow
        (
            address(USDC),
            getEthUsdPrice(inital_aWETH_balance * 4/10),
            2,
            0,
            address(this)
        );

        uint256 AAVE_USDT_LOAN = USDT.balanceOf(address(this));
        uint256 AAVE_USDC_LOAN = USDT.balanceOf(address(this));

        USDC.approve(address(AaveLendingPool), USDC.balanceOf(address(this)));

        AaveLendingPool.deposit(
            address(USDC),
            USDC.balanceOf(address(this)),
            address(this),
            0
        );

        AaveLendingPool.withdraw(address(USDC), aUSDC.balanceOf(address(this)), address(this));

        USDT.safeApprove(address(CurvefiYPool), uint(type(uint256).max));
        USDC.approve(address(CurvefiYPool), uint(type(uint256).max));

        uint256 USDT_BALANCE_BEFORE_CURVE = USDT.balanceOf(address(this));

        // Uncomment this to enable the CurveFi Swaps  
        CurvefiYPool.exchange_underlying(1, 2, USDC.balanceOf(address(this)),0);
        CurvefiYPool.exchange_underlying(2, 1, USDT.balanceOf(address(this)) - USDT_BALANCE_BEFORE_CURVE,0);
    
        // Approve USDC and USDT (USDT in not ERC-20 compliant)
        USDT.safeApprove(address(AaveLendingPool), uint(type(uint256).max));
        USDC.approve(address(AaveLendingPool), USDC.balanceOf(address(this)));

        // Repay the USDC and USDT loans
        require(USDC.balanceOf(address(this)) >= AAVE_USDC_LOAN, "NOT ENOUGH USDC TO PAY FOR AAVE LOAN");
        AaveLendingPool.repay(address(USDC), USDC.balanceOf(address(this)), 2, address(this));
        require(USDT.balanceOf(address(this)) >= AAVE_USDT_LOAN, "NOT ENOUGH USDT TO PAY FOR AAVE LOAN");
        AaveLendingPool.repay(address(USDT), USDT.balanceOf(address(this)), 2, address(this));

        // Swap our aWETH to WETH
        AaveLendingPool.withdraw(address(WETH), aWETH.balanceOf(address(this)), address(this));
        require(WETH.balanceOf(address(this)) > loanAmount + 2, "CANNOT REPAY LOAN");

    }
}