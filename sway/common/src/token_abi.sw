library token_abi;

abi Token {
    #[storage(read, write)]
    fn init();

    #[storage(read)]
    fn mint(receiver: Identity, amount: u64);
}