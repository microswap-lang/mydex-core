// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IERC20Metadata.sol";
import "./libraries/PancakeLibrary.sol";

contract PancakePair is IPancakePair {
    using SafeMath for uint256;

    address public override token0;
    address public override token1;
    uint256 public override reserve0;
    uint256 public override reserve1;

    uint256 private constant FEE_DENOMINATOR = 10000;
    uint256 public feeTo;
    uint256 public feeToAmount;
    uint256 public liquidityFee = 15; // 0.15%
    uint256 public treasuryFee = 5; // 0.05%

    bytes32 public override pairCodeHash;

    address public factory;

    constructor() {
        factory = msg.sender; // Factory address is set on contract deployment
    }

    function initialize(address _token0, address _token1) external override {
        require(msg.sender == factory, "PancakePair: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }

    // Mint function for liquidity providers
    function mint(address to) external override returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        uint256 feeAmount0 = amount0.mul(liquidityFee).div(FEE_DENOMINATOR);
        uint256 feeAmount1 = amount1.mul(treasuryFee).div(FEE_DENOMINATOR);
        uint256 amount0AfterFee = amount0.sub(feeAmount0);
        uint256 amount1AfterFee = amount1.sub(feeAmount1);

        liquidity = Math.sqrt(amount0AfterFee.mul(amount1AfterFee)).sub(reserve0).sub(reserve1);

        _update(balance0, balance1, _reserve0, _reserve1);
        IERC20(token0).transfer(feeTo, feeAmount0);
        IERC20(token1).transfer(feeTo, feeAmount1);

        _safeTransfer(to, liquidity);
    }

    // Burn function for liquidity providers
    function burn(address to) external override returns (uint256 amount0, uint256 amount1) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        amount0 = balance0.sub(_reserve0);
        amount1 = balance1.sub(_reserve1);

        uint256 liquidity = _safeTransfer(to, Math.sqrt(amount0.mul(amount1)));

        _update(balance0, balance1, _reserve0, _reserve1);
        IERC20(token0).transfer(to, amount0);
        IERC20(token1).transfer(to, amount1);
    }

    // Swap function
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external override {
        require(amount0Out > 0 || amount1Out > 0, "PancakePair: INSUFFICIENT_OUTPUT_AMOUNT");

        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        require(balance0 > amount0Out && balance1 > amount1Out, "PancakePair: INSUFFICIENT_LIQUIDITY");

        uint256 feeAmount0 = amount0Out.mul(liquidityFee).div(FEE_DENOMINATOR);
        uint256 feeAmount1 = amount1Out.mul(treasuryFee).div(FEE_DENOMINATOR);

        uint256 amount0AfterFee = amount0Out.sub(feeAmount0);
        uint256 amount1AfterFee = amount1Out.sub(feeAmount1);

        _safeTransfer(to, amount0AfterFee, amount1AfterFee);

        _update(balance0, balance1, _reserve0, _reserve1);

        IERC20(token0).transfer(feeTo, feeAmount0);
        IERC20(token1).transfer(feeTo, feeAmount1);

        emit Swap(msg.sender, amount0AfterFee, amount1AfterFee, to);
    }

    function _update(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) private {
        reserve0 = balance0;
        reserve1 = balance1;
        emit Sync(reserve0, reserve1);
    }

    // Internal function to safely transfer tokens
    function _safeTransfer(address to, uint256 amount) private {
        require(IERC20(token0).transfer(to, amount), "PancakePair: TRANSFER_FAILED");
    }

    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, address indexed to);
    event Sync(uint256 reserve0, uint256 reserve1);
}
