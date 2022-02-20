// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '../external/IWETH9.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';


contract BDSCIAutoLPToken is Context, IERC20, Ownable {
    using SafeMath for uint256; // only for custom reverts on sub

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => uint256) private _isExcludedFromFee;
    mapping (address => uint256) private _isExcludedFromReward;
    address[] private _excludedFromReward;

    uint256 private constant MAX = type(uint256).max;
    uint256 private immutable _decimals;
    uint256 private immutable _tTotal; // total supply
    uint256 private _rTotal;
    uint256 private _tFeeTotal;

    uint256 public _taxFee;

    uint256 public _liquidityFee;

    ISwapRouter public constant uniswapV3Router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    INonfungiblePositionManager public constant uniswapPositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address public immutable uniswapV3Pool;

    uint256 constant SWAP_AND_LIQUIFY_DISABLED = 0;
    uint256 constant SWAP_AND_LIQUIFY_ENABLED = 1;
    uint256 constant IN_SWAP_AND_LIQUIFY = 2;
    uint256 LiqStatus;

    uint256 public _maxTxAmount;
    uint256 private numTokensSellToAddToLiquidity;

    string private _name; 
    string private _symbol;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap {
        LiqStatus = IN_SWAP_AND_LIQUIFY;
        _;
        LiqStatus = SWAP_AND_LIQUIFY_ENABLED;
    }

    constructor ( 
        string memory tName, 
        string memory tSymbol, 
        uint256 totalAmount,
        uint256 tDecimals, 
        uint256 tTaxFee, 
        uint256 tLiquidityFee,
        uint256 maxTxAmount,
        uint256 _numTokensSellToAddToLiquidity,
        bool _swapAndLiquifyEnabled,

        uint160 initialPrice // см тест 
        ) {
        _name = tName;
        _symbol = tSymbol;
        _tTotal = totalAmount;
        _rTotal = (MAX - (MAX % totalAmount));
        _decimals = tDecimals;
        _taxFee = tTaxFee;
        _liquidityFee = tLiquidityFee;
        _maxTxAmount = maxTxAmount;
        numTokensSellToAddToLiquidity = _numTokensSellToAddToLiquidity;
        
        if (_swapAndLiquifyEnabled) {
            LiqStatus = SWAP_AND_LIQUIFY_ENABLED;
        }

        _rOwned[_msgSender()] = _rTotal;

        //ISwapRouter _uniswapV3Router = ISwapRouter(tuniswapV3Router);
        //uniswapV3Router = _uniswapV3Router;
        //uniswapPositionManager = INonfungiblePositionManager(tUniswapPositionManager);
        
        // Create a uniswap pair for this new token
        //address _uniswapV3Pool = IUniswapV3Factory(uniswapV3Router.factory())
        //.createPool(address(this), uniswapV3Router.WETH9(), 3000); // FeeAmount.MEDIUM
        //uniswapV3Pool = _uniswapV3Pool;
        //IUniswapV3Pool(_uniswapV3Pool).initialize(initialPrice);

        uniswapV3Pool = uniswapPositionManager
        .createAndInitializePoolIfNecessary(address(this), uniswapV3Router.WETH9(), 3000, initialPrice);

        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = 1;
        _isExcludedFromFee[address(this)] = 1;

        emit Transfer(address(0), _msgSender(), totalAmount);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcludedFromReward[account] == 1) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) { // REENTRANCE?
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true; 
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcludedFromReward[account] == 1;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) external {
        address sender = _msgSender();
        require(_isExcludedFromReward[sender] == 0, "Forbidden for excluded addresses");
        
        uint256 rAmount = tAmount * _getRate();
        _tFeeTotal = tAmount + _tFeeTotal;
        _rOwned[sender] -= rAmount;
        _rTotal = _rTotal - rAmount;
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            return tAmount * _getRate();
        } else {
            (,uint256 rTransferAmount,,,,,) = _getValues(tAmount, _taxFee, _liquidityFee);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Can't exceed total reflections");
        return rAmount / _getRate();
    }

    function excludeFromReward(address account) public onlyOwner {
        require(_isExcludedFromReward[account] == 0, "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcludedFromReward[account] = 1;
        _excludedFromReward.push(account);
    }

    function includeInReward(address account) external onlyOwner {
        require(_isExcludedFromReward[account] == 1, "Account is already included");
        for (uint256 i = 0; i < _excludedFromReward.length; i++) { // TODO
            if (_excludedFromReward[i] == account) {
                _excludedFromReward[i] = _excludedFromReward[_excludedFromReward.length - 1];
                _tOwned[account] = 0;
                _isExcludedFromReward[account] = 0;
                _excludedFromReward.pop();
                break;
            }
        }
    }

    function excludeFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = 1;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = 0;
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner {
        _taxFee = taxFee;
    }

    function setLiquidityFeePercent(uint256 liquidityFee) external onlyOwner {
        _liquidityFee = liquidityFee;
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner {
        _maxTxAmount = _tTotal * maxTxPercent / 100;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        LiqStatus = _enabled ? 1 : 0;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    receive() external payable {}

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        if (rFee != 0) _rTotal = _rTotal - rFee;
        if (tFee != 0) _tFeeTotal = tFee + _tFeeTotal;
    }

    function _getValues(uint256 tAmount, uint256 taxFee, uint256 liqFee) private view 
    returns (
        uint256 rAmount, 
        uint256 rTransferAmount, 
        uint256 rFee, 
        uint256 tTransferAmount, 
        uint256 tFee, 
        uint256 tLiquidity,
        uint256 rate) {

        tFee = tAmount * taxFee / 100;
        tLiquidity = tAmount * liqFee / 100;
        tTransferAmount = tAmount - tLiquidity - tFee;
        rate = _getRate();

        rAmount = rate * tAmount;
        rFee = rate * tFee;
        rTransferAmount = rate * tTransferAmount;
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excludedFromReward.length; i++) { // inefficient TODO CHANGE TO 1 VARIABLE?
            if (_rOwned[_excludedFromReward[i]] > rSupply || _tOwned[_excludedFromReward[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply -= _rOwned[_excludedFromReward[i]];
            tSupply -= _tOwned[_excludedFromReward[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function _takeLiquidity(uint256 tLiquidity, uint256 rate) private {
        if (tLiquidity == 0) return;

        _rOwned[address(this)] += tLiquidity * rate;
        if(_isExcludedFromReward[address(this)] == 1) // TODO MB OPTIMIZE
            _tOwned[address(this)] += tLiquidity;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account] == 1;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount can't be zero");

        address __owner = owner();
        if(from != __owner && to != __owner)
            require(amount <= _maxTxAmount, "Amount exceeds the maxTxAmount");


        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.

        bool overMinTokenBalance;
        if (balanceOf(address(this)) >= numTokensSellToAddToLiquidity) {
            if (_maxTxAmount >= numTokensSellToAddToLiquidity) {
                overMinTokenBalance = true;
            }
        }

        if (
            overMinTokenBalance &&
            LiqStatus == SWAP_AND_LIQUIFY_ENABLED &&
            from != uniswapV3Pool
        ) {
            //add liquidity
            swapAndLiquify(numTokensSellToAddToLiquidity);
        }

        //if any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = _isExcludedFromFee[from] == 0 && _isExcludedFromFee[to] == 0;

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 currentBalance = IERC20(uniswapV3Router.WETH9()).balanceOf(address(this));

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        currentBalance = IERC20(uniswapV3Router.WETH9()).balanceOf(address(this)) - currentBalance;

        // add liquidity to uniswap
        addLiquidity(otherHalf, currentBalance);

        emit SwapAndLiquify(half, currentBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV3Router.WETH9();

        _approve(address(this), address(uniswapV3Router), tokenAmount);

        // make the swap
        uniswapV3Router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams (
                address(this),
                uniswapV3Router.WETH9(),
                3000,
                address(this),
                block.timestamp,
                tokenAmount,
                0, // slippage is unavoidable
                0  // slippage is unavoidable
            )
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapPositionManager), tokenAmount);
        IWETH9(uniswapV3Router.WETH9()).withdraw(ethAmount);
        //IERC20(uniswapV3Router.WETH9()).approve(address(uniswapPositionManager), ethAmount);

        // add the liquidity
        //    struct MintParams {
        //      address token0;
        //      address token1;
        //      uint24 fee;
        //      int24 tickLower;
        //      int24 tickUpper;
        //      uint256 amount0Desired;
        //      uint256 amount1Desired;
        //      uint256 amount0Min;
        //      uint256 amount1Min;
        //      address recipient;
        //      uint256 deadline;
        //  }

        uniswapPositionManager.mint{value: ethAmount}(
            INonfungiblePositionManager.MintParams(
                address(this),
                uniswapV3Router.WETH9(),
                3000, // FEE MEDIUM,
                -887220, // tickLower;
                887220, // tickUpper;
                tokenAmount,
                ethAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                owner(), // TODO
                block.timestamp
            )
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        uint256 _currentTaxFee;
        uint256 _currentLiquidityFee;
        if (takeFee) {
            (_currentTaxFee, _currentLiquidityFee) = (_taxFee , _liquidityFee);
        }
            
        (uint256 rAmount, uint256 rTransferAmount, 
        uint256 rFee, uint256 tTransferAmount, 
        uint256 tFee, uint256 tLiquidity,
        uint256 rate) = _getValues(amount, _currentTaxFee, _currentLiquidityFee); // rate не может измениться?

        _rOwned[sender] -= rAmount;
        _rOwned[recipient] += rTransferAmount;

        if (_isExcludedFromReward[sender] == 1) {
            _tOwned[sender] -= amount;
        }

        if (_isExcludedFromReward[recipient] == 1) {
            _tOwned[recipient] += tTransferAmount;
        }

        _takeLiquidity(tLiquidity, rate);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}
