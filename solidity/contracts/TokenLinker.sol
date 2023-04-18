//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {ERC20} from "@axelar-network/axelar-cgp-solidity/contracts/ERC20.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {StringToAddress, AddressToString} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/utils/AddressString.sol";
import {StringArray} from "./utils/stringArray.sol";

contract TokenLinker is AxelarExecutable {
    using StringToAddress for string;
    using AddressToString for address;

    error AlreadyInitialized();
    error InvalidDestinationChain();
    event FalseSender(string sourceChain, string sourceAddress);
    error GatewayToken();
    error AlreadyRegistered();
    error TransferFromFailed();
    error TransferFailed();

    // The gateway contract address and gas receiver contract address should be taken from
    // https://docs.axelar.dev/resources/testnet#evm-contract-addresses
    // Ex Gateway on BSC: 
    // chainName = "binance";
    // gasService = ethers.constants.AddressZero;
    // tokenAddress = "0xDE41332a508E363079FD6993B81De049cD362B6D";
    IAxelarGasService public immutable gasService;
    string public chainName;
    address public tokenAddress;

    /// @dev initialize the contract
    /// @param gateway_ the address of AxelarGateway contract on the source chain. Ex: "0x4D147dCb984e6affEEC47e44293DA442580A3Ec0"
    /// @param gasReceiver_ the address of AxelarGasService contract on the source chain. Ex: ethers.constants.AddressZero
    /// @param chainName_ the name of the source chain. Ex: "binance"
    /// @param tokenAddress_ the address of the ERC20 token to be linked. Ex: "0xDE41332a508E363079FD6993B81De049cD362B6D"
    constructor(
        address gateway_,
        address gasReceiver_,
        string memory chainName_,
        address tokenAddress_
    ) AxelarExecutable(gateway_) {
        gasService = IAxelarGasService(gasReceiver_);
        chainName = chainName_;
        tokenAddress = tokenAddress_;
    }

    /// @dev transfer token from sender to receiver on destination chain and contract
    /// @param destinationChain the destination chain name. Ex: "binance"
    /// @param destinationContract the address of TokenLinker contract deploying on destination chain
    /// @param recipient the address of receiver on destination chain
    /// @param amount the amount of token to transfer
    function TransferToken(
        string calldata destinationChain,
        string calldata destinationContract,
        string calldata recipient,
        uint256 amount
    ) public payable {  // TODO: removing payable?
        // transfer token from sender to this contract
        _transferFrom(msg.sender, amount);

        // encode payload to CosmWasm
        bytes memory payload = _encodePayloadToCosmWasm(recipient, amount);

        // call contract on destination chain
        // the msg.value is the gas fee to pay for the contract call
        _callContract(
            destinationChain,
            destinationContract,
            payload,
            msg.value
        );
    }

    // Transfer token from sender to this contract and handle the error if any
    function _transferFrom(
        address from,
        uint256 amount
    ) internal {
        (bool success, bytes memory returnData) = tokenAddress.call(
            abi.encodeWithSelector(
                IERC20.transferFrom.selector,
                from,
                address(this),
                amount
            )
        );
        bool transferred = success &&
            (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

        if (!transferred || tokenAddress.code.length == 0)
            revert TransferFromFailed();
    }

    /// @dev encode payload to CosmWasm
    /// @dev the payload includes the execute message name on the destination contract, its arguments and their types
    function _encodePayloadToCosmWasm(
        string calldata destinationAddress,
        uint256 amount
    ) internal view returns (bytes memory) {
        bytes memory argValue = abi.encode(
            chainName,
            address(this).toString(),
            abi.encode(destinationAddress, amount)
        );

        bytes memory payload = abi.encode(
            "execute_from_remote",
            StringArray.fromArray3(
                ["source_chain", "source_address", "payload"]
            ),
            StringArray.fromArray3(["string", "string", "bytes"]),
            argValue
        );

        return
            abi.encodePacked(
                bytes4(0x00000001), // verison number. IMPORTANT!
                payload
            );
    }

    function _callContract(
        string memory destinationChain,
        string memory destinationAddress,
        bytes memory payload,
        uint256 gasValue
    ) internal {
        if (gasValue > 0) {
            gasService.payNativeGasForContractCall{value: gasValue}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }
        gateway.callContract(destinationChain, destinationAddress, payload);
    }

    // function _execute(
    //     string calldata /*sourceChain*/,
    //     string calldata /*sourceAddress*/,
    //     bytes calldata payload
    // ) internal override {
    //     // TODO: authenticaiton, anyone can call _execute atm
    //     (address to, uint256 amount) = abi.decode(payload, (address, uint256));
    //     _transfer(to, amount);
    // }

    // function _transfer(
    //     address to,
    //     uint256 amount
    // ) internal {
    //     (bool success, bytes memory returnData) = tokenAddress.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
    //     bool transferred = success && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));

    //     if (!transferred || tokenAddress.code.length == 0) revert TransferFailed();
    // }
}