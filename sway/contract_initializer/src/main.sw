script;

use common::dex_abi::Dex;
use common::token_abi::Token;

fn main() {
    let mut signers: Vec<b256> = Vec::new();
    signers.push(0x000000000000000000000000f786a909d559f5dee2dc6706d8e5a81728a39ae9); // redstone-rapid-demo
    let dex = abi(Dex, DEX_CONTRACT_ID);

    dex.init(ContractId {
        value: TOKEN_CONTRACT_ID,
    }, signers);
    let usd = abi(Token, TOKEN_CONTRACT_ID);
    // usd.init(); // we've initialized the usd contract above
    usd.mint(Identity::ContractId(ContractId {
        value: DEX_CONTRACT_ID,
    }), 500000 * 100_000_000);

    return ();
}
