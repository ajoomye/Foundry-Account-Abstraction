// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";



contract MinimalAccount is IAccount, Ownable {


    ////ERRORS////
    error MinimalAccount__NotEntryPoint();
    error MinimalAccount__NotEntryPointorOwner();
    error MinimalAccount__Callfailed(bytes);


    ////VARIABLES////
    IEntryPoint private immutable i_entryPoint;



    ////MODIFIERS////
    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotEntryPoint();
        }
        _;
    }

    modifier onlyEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotEntryPointorOwner();
        }
        _;
    }
    
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}

    ////FUNCTIONS////
    function execute(address dest, uint256 value, bytes calldata funcdata) external onlyEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(funcdata);
        if (!success) {
            revert MinimalAccount__Callfailed(result);
        }
    }

    //A signature is valid if it the contract owner
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData){

        uint256 validationData = _validateSignature(userOp, userOpHash);
        
        //validate Nonce - Not required for this minimal account

        _payPrefundedAccount(missingAccountFunds);

    }

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;

    }

    function _payPrefundedAccount(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds, gas: type(uint256).max}("");
            (success);
        }
    }


    ////GETTERS////

    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }

    
}