library dex_abi;

use std::{bytes::Bytes, u256::U256, vec::Vec};

abi Dex {
    #[storage(read, write)]
    fn init(usd_contract_id: ContractId, signers: Vec<b256>);

    #[storage(read)]
    fn get_eth_price(payload: Vec<u64>) -> U256;

    #[storage(read)]
    fn get_expected_usd_amount(eth_to_swap: u64, payload: Vec<u64>) -> u64;

    #[storage(read), payable]
    fn change_eth_to_usd(payload: Vec<u64>);

    #[storage(read)]
    fn withdraw_funds();
}