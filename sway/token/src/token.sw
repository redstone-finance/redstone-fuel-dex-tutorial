contract;

use std::{auth::msg_sender, call_frames::contract_id, hash::sha256, token::*};
use common::token_abi::Token;

struct Sent {
    from: Identity,
    to: Identity,
    amount: u64,
}

storage {
    owner: Option<Identity> = Option::None,
}

impl Token for Contract {
    #[storage(read, write)]
    fn init() {
        assert(storage.owner.is_none());

        storage.owner = Option::Some(msg_sender().unwrap());
    }

    #[storage(read)]
    fn mint(receiver: Identity, amount: u64) {
        assert(msg_sender().unwrap() == storage.owner.unwrap());

        mint_to(amount, receiver);
    }
}
