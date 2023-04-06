use cosmwasm_std::{Binary, Env, MessageInfo, Uint128};
use cosmwasm_std::{Coin, DepsMut, Response};
use cw20_base::contract::execute_mint;
use ethabi::{decode, encode, ethereum_types::U256, ParamType, Token};
use serde::{Deserialize, Serialize};
use serde_json_wasm::to_string;

use crate::error::ContractError;
use crate::ibc::MsgTransfer;
use crate::state::CONFIG;

#[derive(Serialize, Deserialize, Debug, PartialEq, Eq)]
struct GeneralMessage {
    destination_chain: String,
    destination_address: String,
    payload: Vec<u8>,
    #[serde(rename = "type")]
    type_: i64,
}

pub fn transfer_remote(
    deps: DepsMut,
    env: Env,
    _info: MessageInfo,
    destination_chain: String,
    destination_address: String,
    amount: Uint128,
) -> Result<Response, ContractError> {
    let config = CONFIG.load(deps.storage)?;

    // memo
    let payload = encode(&[
        Token::String(destination_address.clone()),
        Token::Uint(U256::from(amount.u128())),
    ]);

    let msg = GeneralMessage {
        destination_chain,
        destination_address,
        payload,
        type_: 1,
    };

    let ibc_transfer = MsgTransfer {
        source_port: "transfer".to_string(),
        source_channel: config.channel,
        token: Some(Coin::new(1, "uosmo").into()),
        sender: env.contract.address.to_string(),
        receiver: "axelar1dv4u5k73pzqrxlzujxg3qp8kvc3pje7jtdvu72npnt5zhq05ejcsn5qme5".to_string(),
        timeout_height: None,
        timeout_timestamp: Some(env.block.time.plus_seconds(604_800u64).nanos()),
        memo: to_string(&msg).unwrap(),
    };

    // Base response
    let response = Response::new()
        .add_attribute("status", "ibc_message_created")
        .add_attribute("ibc_message", format!("{:?}", ibc_transfer));

    Ok(response.add_message(ibc_transfer))
}

pub fn execute_from_remote(
    deps: DepsMut,
    env: Env,
    info: MessageInfo,
    source_chain: String,
    source_address: String,
    payload: Binary,
) -> Result<Response, ContractError> {
    let config = CONFIG.load(deps.storage)?;
    // Authentication
    if source_chain != config.source_chain
        || source_address != config.linker_address
        || info.sender != config.axelar_gmp_account
    {
        return Err(ContractError::Unauthorized {});
    }

    let decoded = decode(
        &[ParamType::String, ParamType::Uint(256)],
        payload.as_slice(),
    )
    .unwrap(); // TODO: handle error

    // TODO: check if amount and recipient are valid
    let amount = decoded[1].to_owned().into_uint().unwrap().as_u128();

    // call into cw20-base to mint the token, call as self as no one else is allowed
    let sub_info = MessageInfo {
        sender: env.contract.address.clone(),
        funds: vec![],
    };
    Ok(execute_mint(
        deps,
        env,
        sub_info,
        decoded[0].to_string(),
        Uint128::from(amount),
    )?)
}
