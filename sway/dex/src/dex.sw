contract;

dep dex_core;

use std::{
    auth::msg_sender,
    call_frames::msg_asset_id,
    constants::{
        BASE_ASSET_ID,
        ZERO_B256,
    },
    context::{
        msg_amount,
        this_balance,
    },
    logging::log,
    outputs::*,
    storage::StorageVec,
    token::transfer,
    u256::U256,
    vec::Vec,
};

use common::{dex_abi::Dex, token_abi::Token};
use dex_core::*;

storage {
    owner: Option<Identity> = Option::None,
    usd_contract_id: ContractId = ContractId {
        value: ZERO_B256,
    },
    signers: StorageVec<b256> = StorageVec {},
}

impl Dex for Contract {
    #[storage(read, write)]
    fn init(usd_contract_id: ContractId, signers: Vec<b256>) {
        assert(storage.owner.is_none() || storage.owner.unwrap() == msg_sender().unwrap());

        storage.owner = Option::Some(msg_sender().unwrap());
        storage.usd_contract_id = usd_contract_id;
        storage.signers.clear();

        let mut i = 0;
        while (i < signers.len) {
            storage.signers.push(signers.get(i).unwrap());
            i += 1;
        }
    }

    #[storage(read)]
    fn get_eth_price(payload: Vec<u64>) -> U256 {
        get_eth_price(get_signers_from_storage(), payload)
    }

    #[storage(read)]
    fn get_expected_usd_amount(coins_to_swap: u64, payload: Vec<u64>) -> u64 {
        get_expected_usd_amount(coins_to_swap, get_signers_from_storage(), payload)
    }

    #[storage(read), payable]
    fn change_eth_to_usd(payload: Vec<u64>) {
        assert(msg_asset_id() == BASE_ASSET_ID);
        assert(storage.usd_contract_id.value != ZERO_B256);

        let usd_amount = get_expected_usd_amount(msg_amount(), get_signers_from_storage(), payload);

        let usd = abi(Token, storage.usd_contract_id.value);
        let sender = msg_sender().unwrap();

        transfer(usd_amount, storage.usd_contract_id, sender);
    }

    #[storage(read)]
    fn withdraw_funds() {
        let owner = storage.owner.unwrap();
        assert(msg_sender().unwrap() == owner);

        let amount = this_balance(BASE_ASSET_ID);

        transfer(amount, BASE_ASSET_ID, owner);
    }
}

#[storage(read)]
fn get_signers_from_storage() -> Vec<b256> {
    let mut signers: Vec<b256> = Vec::new();
    let mut i = 0;
    while (i < storage.signers.len()) {
        signers.push(storage.signers.get(i).unwrap());

        i += 1;
    }

    signers
}
