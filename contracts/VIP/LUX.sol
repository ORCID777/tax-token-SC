/**
 *Submitted for verification at Etherscan.io on 2023-06-11
*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;

interface ERC20 {
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

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(address(msg.sender));
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;
    address private _previousOwner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}  


interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

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

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
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

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface InterfaceLP {
    function sync() external;
}

interface IRewards {
    function deposit() external payable;
    function setShare(address shareholder, uint256 amount) external;
}

contract FILX is ERC20, Ownable {
    uint256 private constant protectionTax = 300;
    uint256 private constant protectionWallet = 600; 
    uint256 private protectionTaxTimestamp;
    uint256 private protectionWalletTimestamp;

    address private WETH;
    address private DEAD = 0x000000000000000000000000000000000000dEaD;
    address private ZERO = 0x0000000000000000000000000000000000000000;

    string private constant _name = "FFLUX";
    string private constant _symbol = "FFLUX";
    uint8 private constant _decimals = 18;

    uint256 private _totalSupply = 10000000 * 10 ** _decimals;

    uint256 public _maxTxAmount = _totalSupply / 100;
    uint256 public _maxWalletAmount = _totalSupply / 100;

    uint256 public _tmpMaxWalletAmount = _totalSupply / 2000;   

    uint256 public _maxFee = 5;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    address[] public _markerPairs;
    mapping (address => bool) public automatedMarketMakerPairs;
    mapping (address => bool) public isFeeExempt;
    mapping (address => bool) public isTxLimitExempt;
    mapping (address => bool) public isMaxWalletExempt;

    //Fees
    uint256 private totalBuyFee = 5;
    uint256 private marketingFee = 50;
    uint256 private acquisitionFee = 50;
    uint256 private liquidityFee = 0;
    uint256 private totalSellFee = 5;

    uint256 private constant feeDenominator  = 100;

    address private marketingFeeReceiver = 0xe878C65e7CAdCE1c02D48656AAC0FC581DF17C69;
    address private acquisitionFeeReceiver = 0xFFE93233A1B230D5327235e02851774d159f0cB9;

    IDEXRouter public router;
    address public pair;

    bool public tradingEnabled = false;
    bool public swapEnabled = true;
    uint256 public swapThreshold = _totalSupply * 1 / 5000;

    bool private inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false; }

    event RewardSuccess(bool a, bool b);
    event AddressesSet(address indexed marketingWallet, address indexed acquisitionWallet);
    event RouterUpdated(address indexed executor, address indexed oldRouter, address newRouter);

    constructor () {
        router = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); 
        WETH = router.WETH();
        pair = IDEXFactory(router.factory()).createPair(WETH, address(this));

        setAutomatedMarketMakerPair(pair, true);

        _allowances[address(this)][address(router)] = type(uint256).max;

        isFeeExempt[msg.sender] = true;
        isTxLimitExempt[msg.sender] = true;
        isMaxWalletExempt[msg.sender] = true;

               
        isFeeExempt[address(this)] = true; 
        isTxLimitExempt[address(this)] = true;
        isMaxWalletExempt[address(this)] = true;

        isMaxWalletExempt[pair] = true;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable { }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner(); }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }
    
    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(DEAD) - (balanceOf(ZERO));
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(_allowances[sender][msg.sender] >= amount, "Insufficient Allowance");
            _allowances[sender][msg.sender] -= amount;
        }

        return _transferFrom(sender, recipient, amount);
    }


    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if(inSwap){ return _basicTransfer(sender, recipient, amount); }

        // Ensure trading is enabled for all transfers
        require(tradingEnabled,"Trading not open yet");

        if(shouldSwapBack()){ swapBack(); }

        uint256 amountReceived = amount; 

        uint256 maxWalletAmount = block.timestamp < protectionWalletTimestamp ? _tmpMaxWalletAmount : _maxWalletAmount;
        
        // Check if it's a buy transaction
        if(automatedMarketMakerPairs[sender]) {
            require(_balances[recipient] + amount <= maxWalletAmount || isMaxWalletExempt[recipient], "Max Wallet Limit Exceeded");
            require(amount <= _maxTxAmount || isTxLimitExempt[recipient], "TX Limit Exceeded");
            amountReceived = !isFeeExempt[recipient] ? takeBuyFee(sender, amount) : amount;
        }
        // Check if it's a sell transaction
        else if(automatedMarketMakerPairs[recipient]) {
            require(amount <= _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");
            amountReceived = !isFeeExempt[sender] ? takeSellFee(sender, amount) : amount;
        }

        _balances[sender] -= amount; // Subtract the amount from the sender
        _balances[recipient] += amountReceived; // Add only the amountReceived post-fee to the recipient     

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    
    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        require(_balances[sender] >= amount, "Insufficient Balance");
        
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        
        emit Transfer(sender, recipient, amount);
        return true;
    }

    // Check address is contract type
    function isContract(address account) internal view returns (bool){
        uint256 size;
        assembly {size:= extcodesize(account)}
        return size > 0;
    }

    // Added within the `FILX` contract
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        require(_balances[account] >= amount, "ERC20: burn amount exceeds balance");

        _balances[account] -= amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;

        emit Transfer(address(0), account, amount);
    }

    // Check if address can receive ETH
    function canReceiveETH(address account) internal view returns (bool) {
        return !isContract(account);
    }

    // Fees
    function takeBuyFee(address sender, uint256 amount) internal returns (uint256){
        uint256 _realFee = totalBuyFee;
        if (block.timestamp < protectionTaxTimestamp) {
                _realFee = 50;
            }

        uint256 feeAmount = (amount * _realFee) / feeDenominator;

        require(_balances[sender] >= feeAmount, "Insufficient Balance for fee");

        _balances[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);

        uint256 remainingAmount = amount - feeAmount;
        return remainingAmount;
    }

    function takeSellFee(address sender, uint256 amount) internal returns (uint256){
        uint256 _realFee = totalSellFee;
        if (block.timestamp < protectionTaxTimestamp) {
                _realFee = 50;
            }

        uint256 feeAmount = (amount * _realFee) / feeDenominator;

    require(_balances[sender] >= feeAmount, "Insufficient Balance for fee");

        _balances[address(this)] += feeAmount;
        emit Transfer(sender, address(this), feeAmount);

        uint256 remainingAmount = amount - feeAmount;
        return remainingAmount;
    } 

    function shouldSwapBack() internal view returns (bool) {
        return
        !automatedMarketMakerPairs[msg.sender]
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    // switch Trading
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading is already enabled");
        tradingEnabled = true;
        protectionTaxTimestamp = block.timestamp + protectionTax;
        protectionWalletTimestamp = block.timestamp + protectionWallet;
    }

    function swapBack() internal swapping {
        uint256 swapLiquidityFee = liquidityFee;
        uint256 realTotalFee = liquidityFee + marketingFee + acquisitionFee;

        uint256 contractTokenBalance = _balances[address(this)];
        uint256 amountToLiquify = (contractTokenBalance * swapLiquidityFee) / realTotalFee / 2;
        uint256 amountToSwap = contractTokenBalance - amountToLiquify;


        uint256 balanceBefore = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance - balanceBefore;

        uint256 totalETHFee = realTotalFee - (swapLiquidityFee / 2);

        uint256 amountETHLiquidity = (amountETH * liquidityFee) / totalETHFee / 2;
        uint256 amountETHMarketing = (amountETH * marketingFee) / totalETHFee;
        uint256 amountETHAcquisition = amountETH - amountETHLiquidity - amountETHMarketing;

        (bool tmpMarketSuccess,) = payable(marketingFeeReceiver).call{value: amountETHMarketing}("");
        (bool tmpAcquisitionSuccess,) = payable(acquisitionFeeReceiver).call{value: amountETHAcquisition}("");

        if(amountToLiquify > 0){
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                DEAD,
                block.timestamp
            );
        }

        emit RewardSuccess(tmpMarketSuccess, tmpAcquisitionSuccess);
    }

    // Admin Functions
    function setAutomatedMarketMakerPair(address _pair, bool _value) public onlyOwner {
            require(automatedMarketMakerPairs[_pair] != _value, "Value already set");
            automatedMarketMakerPairs[_pair] = _value;

            if(_value){
                _markerPairs.push(_pair);
            } else {
                require(_markerPairs.length > 1, "Required 1 pair");
                for (uint256 i = 0; i < _markerPairs.length; i++) {
                    if (_markerPairs[i] == _pair) {
                        _markerPairs[i] = _markerPairs[_markerPairs.length - 1];
                        _markerPairs.pop();
                        break;
                    }
                }
            }
        }

    function updateRouter(address _address) external onlyOwner {
        require(_address != address(0), "Token: Router update to the zero address");
        // Extra validation could be added here, e.g., ensuring that _address has the correct interface.

        require(isContract(_address), "Token: Address must be a contract");

        // Emitting an event is useful for off-chain services to track changes.
        emit RouterUpdated(msg.sender, address(router), _address);

        router = IDEXRouter(_address);
    }

    function setMaxWallet(uint256 _newMaxWallet) external onlyOwner {
        require(_newMaxWallet > _totalSupply / 2000, "Can't limit trading");
        _maxWalletAmount = _newMaxWallet;
    }

    function setMaxTX(uint256 _newMaxTX) external onlyOwner {
        require(_newMaxTX > _totalSupply / 2000, "Can't limit trading");
        _maxTxAmount = _newMaxTX;
    }

    function setFees(uint256 _buyTax, uint256 _sellTax, uint256 _marketingPercentage, uint256 _acquisitionPercentage, uint256 _liquidityPercentage) external onlyOwner {
        require(_buyTax <= _maxFee && _sellTax <= _maxFee, "Fee can't be higher than 5%");
        totalBuyFee = _buyTax;
        totalSellFee = _sellTax;
        marketingFee = _marketingPercentage;
        acquisitionFee = _acquisitionPercentage;        
        liquidityFee = _liquidityPercentage;
    }

    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        require(holder != address(0), "Invalid address");
        isFeeExempt[holder] = exempt;
    }

    function setIsTxLimitExempt(address holder, bool exempt) external onlyOwner {
        require(holder != address(0), "Invalid address");
        isTxLimitExempt[holder] = exempt;
    }

    function setIsMaxWalletExempt(address holder, bool exempt) external onlyOwner {
        require(holder != address(0), "Invalid address");
        isMaxWalletExempt[holder] = exempt;
    }

    function setAddresses(address _marketingWallet, address _acquisitionwallet) external onlyOwner {
        require(_marketingWallet != address(0) && _acquisitionwallet != address(0) , "Zero Address validation" );

        require(canReceiveETH(_marketingWallet), "Marketing Wallet cannot receive ETH");
        require(canReceiveETH(_acquisitionwallet), "Acquisition Wallet cannot receive ETH");

        marketingFeeReceiver = _marketingWallet;
        acquisitionFeeReceiver = _acquisitionwallet;

        emit AddressesSet(_marketingWallet, _acquisitionwallet);
    }

    function clearStuckBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to clear");
        payable(msg.sender).transfer(balance);
    }

    function rescueERC20(address tokenAddress, uint256 amount) external onlyOwner returns (bool) {
        require(tokenAddress != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        
        bool sent = ERC20(tokenAddress).transfer(msg.sender, amount);
        require(sent, "Token transfer failed");
        
        return sent;
    }
}