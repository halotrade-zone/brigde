use crate::state::ConfigMsg;
use cosmwasm_schema::{cw_serde, QueryResponses};
use cosmwasm_std::Binary;

#[cw_serde]
pub struct InstantiateMsg {
    pub channel: String,
    /// TODO: support multiple chains
    pub original_chain: String, // the chain name of the original token deployed on the EVM chain
    pub linker_address: String, // the address of the token linker contract deployed on the EVM chain
    pub axelar_gmp_account: String, // the axelar gmp account address representation on the Cosmos chain
}

#[cw_serde]
pub enum ExecuteMsg {
    /// Send a cross chain message without any tokens
    ExecuteFromRemote {
        source_chain: String,
        source_address: String,
        payload: Binary,
    },
}

#[cw_serde]
#[derive(QueryResponses)]
pub enum QueryMsg {
    #[returns(ConfigMsg)]
    GetConfigMsg {},
}
