// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


contract Ownable
{
    address internal _owner;
    constructor(){
        _owner = msg.sender;
    }

    modifier restricted() {
         require(checkOwner(msg.sender), "Only owner allowed!");
        _;
    }
    function checkOwner(address addr) public view returns(bool) {
        return addr == _owner;
    }

    function owner() public view returns(address) {
        return _owner;
    }
}