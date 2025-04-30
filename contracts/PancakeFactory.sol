// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPancakeFactory.sol";
import "./PancakePair.sol";

contract PancakeFactory is IPancakeFactory {
    address public feeTo;
    address public feeToSetter = 0xA74cD1C7778D787DB0B9e440387A07B1848997E3; // your admin wallet

    mapping(address => mapping(address => address)) public override getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function allPairsLength() external view override returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, "PancakeFactory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB 
            ? (tokenA, tokenB) 
            : (tokenB, tokenA);
        require(token0 != address(0), "PancakeFactory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "PancakeFactory: PAIR_EXISTS");

        bytes memory bytecode = type(PancakePair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        PancakePair(pair).initialize(token0, token1);

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate reverse mapping
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "PancakeFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _newSetter) external override {
        require(msg.sender == feeToSetter, "PancakeFactory: FORBIDDEN");
        feeToSetter = _newSetter;
    }
}

