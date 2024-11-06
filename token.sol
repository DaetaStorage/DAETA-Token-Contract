/**
 *Submitted for verification at Etherscan.io on 2024-11-06
*/

/*
 _____     _______ _______       
|  __ \   /   ____|__   __|/\    
| |  | | /   |__     | |  /  \   
| |  | |/ /|  __|    | | / /\ \  
| |__| / ___ |____   | |/ ____ \ 
|_____/_/  |______|  |_/_/    \_\
                                  
Distributed Cloud Storage and Modular AI-Native Data Layer.

Website: https://www.daeta.xyz
Twitter: https://x.com/DaetaStorage
Medium: https://daetastorage.medium.com
Telegram: https://t.me/DaetaStorage
Discord: https://discord.gg/DaetaStorage
GitHub: https://github.com/DaetaStorage
Documentation: https://docs.daeta.xyz
Whitepaper: https://daeta.xyz/DaetaWPv1.0.pdf
Tokenomics: https://docs.daeta.xyz/tokenomics
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed sender, address indexed recipient, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

contract Ownable is Context {
    address private _contractOwner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _contractOwner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _contractOwner;
    }

    modifier onlyOwner() {
        require(_contractOwner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _updateOwnership(newOwner);
    }

    function _updateOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_contractOwner, newOwner);
        _contractOwner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_contractOwner, address(0));
        _contractOwner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 tokenAmount,
        uint256 minETHAmount,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint tokenDesired,
        uint tokenMin,
        uint ethMin,
        address to,
        uint deadline
    ) external payable returns (uint tokenAmount, uint ethAmount, uint liquidity);
}

contract DAETA is Context, IERC20, Ownable {
    string private constant _tokenName = "DAETA";
    string private constant _tokenSymbol = "DAETA";
    uint8 private constant _tokenDecimals = 18;
    uint256 private constant _totalSupply = 100000000 * 10**_tokenDecimals;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private _excludedAccounts;

    uint256 private constant _minSwapAmount = 25000 * 10**_tokenDecimals;
    uint256 private _maxSwapAmount = 625000 * 10**_tokenDecimals;

    uint256 public maxTxAmount = 100000 * 10**_tokenDecimals;
    uint256 public maxWalletBalance = 200000 * 10**_tokenDecimals;

    uint256 private _startBlock;
    uint256 buyFee = 30;
    uint256 sellFee = 30;

    IUniswapV2Router02 private _swapRouter;
    address public liquidityPair;
    address DAETAStorage;
    address DAETALVRG;
    address DAETABoost;

    bool private _tradingIsEnabled = false;

    constructor() {
        DAETAStorage = 0x1b3B458EBDE073723a05005F3D65715BD6aaecD6;
        DAETALVRG = 0xB67A1A099557A64dCDAaDfE768204002Ca25e67a;
        DAETABoost = 0x25e01C6EE653b4aba2227c5C6FaE34402e34c027;

        _balances[msg.sender] = _totalSupply;
        _excludedAccounts[msg.sender] = 1;
        _excludedAccounts[address(this)] = 1;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function name() public pure returns (string memory) {
        return _tokenName;
    }

    function symbol() public pure returns (string memory) {
        return _tokenSymbol;
    }

    function decimals() public pure returns (uint8) {
        return _tokenDecimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function getTaxeRates() external view returns (uint256 buyTax, uint256 sellTax) {
        buyTax = buyFee;
        sellTax = sellFee;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _executeTransfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _setTokenAllowance(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _executeTransfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
            unchecked {
                _setTokenAllowance(sender, _msgSender(), currentAllowance - amount);
            }
        }
        return true;
    }

    function _setTokenAllowance(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function activeTrading() external onlyOwner {
        require(!_tradingIsEnabled, "Trading is already enabled");
        _swapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        liquidityPair = IUniswapV2Factory(_swapRouter.factory()).createPair(address(this), _swapRouter.WETH());
        _setTokenAllowance(address(this), address(_swapRouter), _totalSupply);
        
        _swapRouter.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );

        IERC20(liquidityPair).approve(address(_swapRouter), type(uint).max);
        _tradingIsEnabled = true;
        _startBlock = block.number;
    }

    function modifyExcludedAccounts(address account, uint256 value) external onlyOwner {
        _excludedAccounts[account] = value;
    }

    function removeLimits() external onlyOwner {
        maxTxAmount = _totalSupply;
        maxWalletBalance = _totalSupply;
    }

    function updateTaxes(uint256 newTxRate) external onlyOwner {
        require(newTxRate <= buyFee && newTxRate <= sellFee, "Tax cannot be increased");
        buyFee = newTxRate;
        sellFee = newTxRate;
    }

    function _executeTokenTransfer(address from, address to, uint256 amount, uint256 taxRate) private {
        uint256 taxAmount = (amount * taxRate) / 100;
        uint256 transferAmount = amount - taxAmount;

        _balances[from] -= amount;
        _balances[to] += transferAmount;
        _balances[address(this)] += taxAmount;

        emit Transfer(from, to, transferAmount);
    }

    function _executeTransfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "ERC20: transfer amount must be greater than zero");

        uint256 taxRate = 0;

        if (_excludedAccounts[from] == 0 && _excludedAccounts[to] == 0) {
            require(_tradingIsEnabled, "Trading is not enabled yet");
            require(amount <= maxTxAmount, "Transaction amount exceeds the maximum limit");
            
            if (to != liquidityPair && to != address(0xdead)) {
                require(balanceOf(to) + amount <= maxWalletBalance, "Recipient wallet exceeds the maximum limit");
            }

            if (block.number < _startBlock + 3) {
                taxRate = (from == liquidityPair) ? 30 : 30;
            } else {
                if (from == liquidityPair) {
                    taxRate = buyFee;
                } else if (to == liquidityPair) {
                    uint256 contractTokenBalance = balanceOf(address(this));
                    if (contractTokenBalance > _minSwapAmount) {
                        uint256 swapAmount = _maxSwapAmount;
                        if (contractTokenBalance > amount) contractTokenBalance = amount;
                        if (contractTokenBalance > swapAmount) contractTokenBalance = swapAmount;
                        _swapTokensForEth(contractTokenBalance);
                    }
                    taxRate = sellFee;
                }
            }
        }
        _executeTokenTransfer(from, to, amount, taxRate);
    }

    function withdrawEth() external onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
      require(success, "ETH withdrawal failed");
    }

    function withdrawTokens() external onlyOwner {
        uint256 contractTokenBalance = balanceOf(address(this));
        require(contractTokenBalance > 0, "No tokens to withdraw");

        _executeTokenTransfer(address(this), owner(), contractTokenBalance, 0);
    }

    function manualSwapExecution(uint256 percent) external onlyOwner {
        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 swapAmount = (percent * contractTokenBalance) / 100;
        _swapTokensForEth(swapAmount);
    }

    function _swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _swapRouter.WETH();

        _setTokenAllowance(address(this), address(_swapRouter), tokenAmount);

        _swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 contractEthBalance = address(this).balance;
        uint256 StorageTax = (contractEthBalance * 45) / 100;
        uint256 LVRGTax = (contractEthBalance * 45) / 100;
        uint256 BoostTax = (contractEthBalance * 10) / 100;

        (bool success, ) = DAETAStorage.call{value: StorageTax}("");
        (success, ) = DAETALVRG.call{value: LVRGTax}("");
        (success, ) = DAETABoost.call{value: BoostTax}("");
        

        require(success, "Transfer failed");
    }

    receive() external payable {}
}