/**
 *Submitted for verification at BscScan.com on 2024-12-04
*/

// SPDX-License-Identifier: MIT
pragma solidity =0.8.19;

abstract contract Context {
    function _msgSender() internal view returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view returns (bytes memory) {
        this;
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _setOwner(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner() || msg.sender == address(this), "Not an admin");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IFactoryV2 {
    event PairCreated(address indexed token0, address indexed token1, address lpPair, uint);

    function getPair(address tokenA, address tokenB) external view returns (address lpPair);

    function createPair(address tokenA, address tokenB) external returns (address lpPair);
}

interface IV2Pair {
    function factory() external view returns (address);

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function sync() external;
}

interface IRouter01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function addLiquidity(
        address tokenA,
        address tokenB, 
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);

    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IRouter02 is IRouter01 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function getOwner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address _owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract TAI is Context, Ownable, IERC20 {
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _noFee;
    mapping(address => bool) private liquidityAdd;
    mapping(address => bool) private isLpPair;
    mapping(address => bool) private isPresaleAddress;
    mapping(address => bool) private excludeFromBurn;
    mapping(address => uint256) private balance;
    mapping (string => bool) private autoAdjusted;
    mapping(address => bool) private _isExcludedFromFees;

    uint256 private _totalSupply = 1_000_000_000 * 10**18;
    uint256 public swapThreshold = 100_000 * 10**18;
    uint256 public buyfee = 30;
    uint256 public sellfee = 30;
    uint256 public transferfee = 0;
    uint256 public buyBurnPercentage = 3; 
    uint256 public sellBurnPercentage = 6;
    uint256 constant public fee_denominator = 1_000;
    bool private canSwapFees = true;
    address payable immutable private marketingAddress = payable(0x865942Cedb9AE5119264909E38302167c143DF6b);
    address payable immutable private devWallet = payable(0x865942Cedb9AE5119264909E38302167c143DF6b);

    uint256 private buyAllocation = 40;
    uint256 private sellAllocation = 40;
    uint256 private liquidityAllocation = 20;
   
    IRouter02 public swapRouter;
    string constant private _name = "TreasuryAi";
    string constant private _symbol = "TAI";
    string constant public copyright = "treasuryai.io";
    uint8 constant private _decimals = 18;
    address constant public DEAD = 0x000000000000000000000000000000000000dEaD;
    address public lpPair;
    bool public isTradingEnabled = true;
    bool private inSwap;

    uint256 private feeCollected;
    
    address public trackerAddress;

    uint256 private initialBuyBurnPercentage = buyBurnPercentage;
    uint256 private initialSellBurnPercentage = sellBurnPercentage;

    mapping(address => bool) private _excludeFromBurnTrigger;
    mapping(address => string) public namedAddresses;

    event _enableTrading();
    event _setPresaleAddress(address account, bool enabled);
    event _changeThreshold(uint256 newThreshold);
    event _changeWallets(address newBuy, address newDev);
    event SwapAndLiquify();
    event FeesChanged(uint256 newBuyFee, uint256 newSellFee);
    event BurnExecuted(uint256 amount, uint256 timestamp);
    event BurnPercentageChanged(uint256 newBurnPercentage);
    event TrackerAddressCreated(address trackerAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeFromBurnTrigger(address indexed account, bool isExcluded);
    event Burn(address indexed from, uint256 amount);

    constructor() {
        _noFee[msg.sender] = true;
        _noFee[address(this)] = true;

        if (block.chainid == 56) {
            swapRouter = IRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        } else if (block.chainid == 97) {
            swapRouter = IRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        } else if (block.chainid == 1 || block.chainid == 4 || block.chainid == 3) {
            swapRouter = IRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        } else if (block.chainid == 42161) {
            swapRouter = IRouter02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        } else {
            revert("Chain not valid");
        }

        liquidityAdd[msg.sender] = true;
        balance[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);

        require(buyAllocation + sellAllocation + liquidityAllocation == 100, "AI: Must equal to 100%");
        canSwapFees = true;

        lpPair = IFactoryV2(swapRouter.factory()).createPair(swapRouter.WETH(), address(this));
        isLpPair[lpPair] = true;
        _approve(msg.sender, address(swapRouter), type(uint256).max);
        _approve(address(this), address(swapRouter), type(uint256).max);

        feeCollected = 0;

        _createTrackerAddress();
        _sendTokensTotrackerAddress();
    }

    receive() external payable {}

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function decimals() external pure override returns (uint8) {
        return _decimals;
    }

    function symbol() external pure override returns (string memory) {
        return _symbol;
    }

    function name() external pure override returns (string memory) {
        return _name;
    }

    function getOwner() external view override returns (address) {
        return owner();
    }

    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function balanceOf(address account) public view override returns (uint256) {
        return balance[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] -= amount;
        }
        _transfer(sender, recipient, amount);
        return true;
    }

    function isNoFeeWallet(address account) external view returns (bool) {
        return _noFee[account];
    }

    function setNoFeeWallet(address account, bool enabled) public onlyOwner {
        require(account != address(0), "AI: Account is zero address");
        _noFee[account] = enabled;
    }

    function enableTrading() external onlyOwner {
        require(!isTradingEnabled, "Trading already enabled");
        isTradingEnabled = true;
        emit _enableTrading();
    }

    function changeSwapThreshold(uint256 newSwapThreshold) external onlyOwner {
        swapThreshold = newSwapThreshold;
        emit _changeThreshold(newSwapThreshold);
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function setExcludeFromBurn(address account, bool excluded) external onlyOwner {
        excludeFromBurn[account] = excluded;
    }

    function setExcludeFromBurnTrigger(address account, bool excluded) external onlyOwner {
        _excludeFromBurnTrigger[account] = excluded;
        emit ExcludeFromBurnTrigger(account, excluded);
    }

    function isExcludedFromBurnTrigger(address account) external view returns (bool) {
        return _excludeFromBurnTrigger[account];
    }

    function _approve(address sender, address spender, uint256 amount) internal {
        require(sender != address(0), "ERC20: Zero Address");
        require(spender != address(0), "ERC20: Zero Address");

        _allowances[sender][spender] = amount;
        emit Approval(sender, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal returns (bool) {
        bool takeFee = true;
        require(to != address(0), "ERC20: transfer to the zero address");
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        bool isLiquidityAddition = liquidityAdd[from] || liquidityAdd[to];
        if (isLiquidityAddition) {
            takeFee = false;
        }

        if (isLimitedAddress(from, to)) {
            require(isTradingEnabled, "Trading is not enabled");
        }

        if (balance[trackerAddress] <= 1_000_000 * 10**18) {
            checkAndAdjustCriticalParameters();
        }

        if (is_sell(from, to) && !inSwap && canSwap(from, to) && !isLiquidityAddition) {
            uint256 contractTokenBalance = balanceOf(address(this));
            if (contractTokenBalance >= swapThreshold) {
                uint256 swapAmount = feeCollected;
                if (swapAmount > 0) {
                    distributeFees();
                }
            }
            burnTokens(amount, false);
        }

        if (is_buy(from, to) && !inSwap && canSwap(from, to) && !isLiquidityAddition) {
            burnTokens(amount, true);
        }

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        balance[from] -= amount;
        uint256 amountAfterFee = (takeFee) ? takeTaxes(from, is_buy(from, to), is_sell(from, to), amount) : amount;
        balance[to] += amountAfterFee;
        emit Transfer(from, to, amountAfterFee);

        return true;
    }

    function takeTaxes(address from, bool isbuy, bool issell, uint256 amount) internal returns (uint256) {
        uint256 fee = (isbuy) ? buyfee : (issell) ? sellfee : transferfee;
        if (fee == 0) return amount;
        uint256 feeAmount = amount * fee / fee_denominator;
        if (feeAmount > 0) {
            balance[address(this)] += feeAmount;
            feeCollected += feeAmount;
            emit Transfer(from, address(this), feeAmount);
        }
        return amount - feeAmount;
    }

    function distributeFees() internal lockTheSwap {
        uint256 swapAmount = feeCollected;
        if (swapAmount == 0) return;

        uint256 buyAmount = (swapAmount * buyAllocation) / 100;
        uint256 sellAmount = (swapAmount * sellAllocation) / 100;
        uint256 liquidityAmount = (swapAmount * liquidityAllocation) / 100;

        // Handle buy and sell fees separately if allocations are non-zero
        if (buyAmount > 0 || sellAmount > 0) {
            internalSwap(buyAmount + sellAmount);
        }

        // Handle liquidity fees if allocation is non-zero
        if (liquidityAmount > 0) {
            swapAndLiquify(liquidityAmount);
        }

        // Reset feeCollected after distribution
        feeCollected = 0;
    }

    function internalSwap(uint256 amount) internal {
        if (amount == 0) return;

        address[] memory path = new address[](2); // Define the path array properly
        path[0] = address(this);
        path[1] = swapRouter.WETH();

        if (_allowances[address(this)][address(swapRouter)] != type(uint256).max) {
            _allowances[address(this)][address(swapRouter)] = type(uint256).max;
        }

        try swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        ) {} catch {
            return;
        }

        bool success;
        if (address(this).balance > 0) {
            (success, ) = marketingAddress.call{value: address(this).balance, gas: 35000}("");
        }
    }

    function swapAndLiquify(uint256 amount) internal {
        if (amount == 0) return;

        uint256 half = amount / 2;
        uint256 otherHalf = amount - half;

        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapRouter.WETH();

        try swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            half,
            0,
            path,
            address(this),
            block.timestamp
        ) {} catch {
            return;
        }

        uint256 newBalance = address(this).balance - initialBalance;

        try swapRouter.addLiquidityETH{value: newBalance}(
            address(this),
            otherHalf,
            0,
            0,
            DEAD,
            block.timestamp
        ) {} catch {
            return;
        }

        emit SwapAndLiquify();
    }

    function burnTokens(uint256 amount, bool isBuy) internal {
    uint256 burnPercentage = isBuy ? buyBurnPercentage : sellBurnPercentage;
    uint256 burnAmount = (amount * burnPercentage) / 100;

    if (_excludeFromBurnTrigger[msg.sender] || _excludeFromBurnTrigger[tx.origin]) {
        burnAmount = 0;
    }

    if (burnAmount > 0) {
        require(trackerAddress != address(0), "Tracker address is not set");
        require(balance[trackerAddress] >= burnAmount, "Burn exceeds tracker balance");
        balance[trackerAddress] -= burnAmount;
        _totalSupply -= burnAmount;
        emit Burn(trackerAddress, burnAmount);
        emit BurnExecuted(burnAmount, block.timestamp);

        // Log the transfer from trackerAddress to a zero-like address for transparency
        emit Transfer(trackerAddress, address(0), burnAmount);
    }
}



    function checkAndAdjustCriticalParameters() internal { 
        if (balance[trackerAddress] <= 1_000_000 * 10**18 && !autoAdjusted["CriticalParameters"]) {
            autoAdjustCriticalParameters();
            autoAdjusted["CriticalParameters"] = true;
        }
    }

    function autoAdjustCriticalParameters() internal {
        autoSetSellFee();
        autoSetBuyFee();
        autoSetBurnPercentage();
    }

    function autoSetSellFee() internal {
        sellfee = 0;
        emit FeesChanged(buyfee, sellfee);
    }

    function autoSetBuyFee() internal {
        buyfee = 0;
        emit FeesChanged(buyfee, sellfee);
    }

    function autoSetBurnPercentage() internal {
        buyBurnPercentage = 0;
        sellBurnPercentage = 0;
        emit BurnPercentageChanged(0);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = balanceOf(account);
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        balance[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
        emit Burn(account, amount); 

        _afterTokenTransfer(account, address(0), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    function _createTrackerAddress() internal {
        trackerAddress = address(new TrackerAddress());
        namedAddresses[trackerAddress] = "BurnPool";
        emit TrackerAddressCreated(trackerAddress);
    }

    function _sendTokensTotrackerAddress() internal {
        uint256 amountToSend = 900_000_000 * 10**18; 
        require(balanceOf(msg.sender) >= amountToSend, "Insufficient balance");
        balance[msg.sender] -= amountToSend;
        balance[trackerAddress] += amountToSend;
        emit Transfer(msg.sender, trackerAddress, amountToSend);
    }
    
    function isLimitedAddress(address ins, address out) internal view returns (bool) {
        return ins != owner() && out != owner() && msg.sender != owner() &&
               !liquidityAdd[ins] && !liquidityAdd[out] && out != address(0) &&
               out != address(this);
    }

    function is_buy(address ins, address out) internal view returns (bool) {
        return !isLpPair[out] && isLpPair[ins];
    }

    function is_sell(address ins, address out) internal view returns (bool) {
        return isLpPair[out] && !isLpPair[ins];
    }

    function canSwap(address ins, address out) internal view returns (bool) {
        return canSwapFees && !isPresaleAddress[ins] && !isPresaleAddress[out];
    }
}

contract TrackerAddress {
    constructor() {}
}
