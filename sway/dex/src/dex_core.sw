library dex_core;

use std::{
    b256::*,
    block::timestamp,
    bytes::Bytes,
    logging::log,
    storage::{
        get,
        StorageVec,
    },
    u256::{
        U256,
    },
    vec::Vec,
};

use redstone::{config::Config, processor::process_input};

impl Config {
    pub fn base(feed_id: U256, signers: Vec<b256>) -> Config {
        let mut feed_ids: Vec<U256> = Vec::new();
        feed_ids.push(feed_id);

        let config = Config {
            feed_ids,
            signers,
            signer_count_threshold: 1,
            block_timestamp: get_block_timestamp(),
        };

        return config;
    }
}

fn get_block_timestamp() -> u64 {
    timestamp() - (10 + (1 << 62))
}

const ETH_FEED_ID = U256::from((0, 0, 0, 0x455448));

pub fn get_eth_price(allowed_signers: Vec<b256>, payload: Vec<u64>) -> U256 {
    decode_price(ETH_FEED_ID, allowed_signers, payload)
}

fn decode_price(feed_id: U256, allowed_signers: Vec<b256>, payload: Vec<u64>) -> U256 {
    let config = Config::base(feed_id, allowed_signers);

    let mut payload_bytes = Bytes::new();
    let mut i = 0;
    while (i < payload.len) {
        payload_bytes.push(payload.get(i).unwrap());

        i += 1;
    }
    let (aggregated_values, _) = process_input(payload_bytes, config);

    aggregated_values.get(0).unwrap()
}

const DENOMINATOR = U256::from((0, 0, 0, 100_000_000)); // as the ETH price value returned by redstone library is multiplied by 10 ** 8

pub fn get_expected_usd_amount(
    coins_to_swap: u64,
    allowed_signers: Vec<b256>,
    payload: Vec<u64>,
) -> u64 {
    let eth_price = get_eth_price(allowed_signers, payload);

    //TODO: verify if the value is not bigger than .d
    (U256::from((0, 0, 0, coins_to_swap)) * eth_price / DENOMINATOR).d
}