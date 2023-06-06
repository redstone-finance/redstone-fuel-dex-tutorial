# redstone-fuel-dex

# Prerequisites

1. Sway
    1. You must be familiar with the Fuel ecosystem (will be shortened to *Fuel* or *ecosystem* below) and with the sway language.
    1. Especially, you need a deployed fuel account with assets. 
    1. In case of troubles, try to read our short summary how to set up the environment here: https://github.com/redstone-finance/redstone-oracles-monorepo/tree/main/packages/fuel-connector/sway
   1. We use `forc` and sway in version `0.35.5` and the fuel-core in version  `0.17.11`.
2. Node-js App & typescript
    1. You must be familiar with node-js applications & the typescript language to write they in.

## Initialization

Let's create an empty directory and a node-js application inside. 

[?] You can use one of common tutorials, for example: https://javascript.plainenglish.io/how-to-start-a-blank-typescript-project-1d260f7e2aa8

There is created the `src` directory inside. Create also the `sway` directory on the same level, for all on-chain code to be created in.

Add then the following entries in the `compilerOptions` section of the [tsconfig.json](tsconfig.json) file.

```json
"compilerOptions": {
// ...
  "moduleResolution": "NodeNext",
  "jsx": "react-jsx",
  "skipLibCheck": true,
  "module": "CommonJS",
// ...
```

# Sway

That's the first layer of the Dex ecosystem. To have it working we need to create a Token and the Dex contracts.

## Token contract

We enjoy all the benefits provided by Fuel. Our token will be represented as a native Asset, supported in Fuel as one of first-class citizens. 
Contracts have a balance of all possible assets instead of only the base asset. 

[?] See: https://fuelbook.fuel.network/master/fuelvm/native_assets.html

We only need to mint the asset (and only the asset representing the token can do it). 
All functions controlling the balance or transferring assets between accounts are embedded in sway.

[?] See: https://github.com/FuelLabs/sway/blob/master/sway-lib-std/src/token.sw

Save the following code to the [`sway/token/src/token.sw`](/sway/token/src/token.sw) file.

```rust
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
```


### Token ABI

To invoke the contract's functions from other contract or script, we need to define a common abi of the token.
Save the code to the [`/sway/common/src/token_abi.sw`](/sway/common/src/token_abi.sw) file

```rust

library token_abi;

abi Token {
    #[storage(read, write)]
    fn init();

    #[storage(read)]
    fn mint(receiver: Identity, amount: u64);
}
```

and the library declaration code to the [sway/common/src/lib.sw](sway/common/src/lib.sw) file

```rust
library common;

dep token_abi;
```

### Forc environment 

Now, we'd like deploy the Token contract. To do that, we need to set up the `Forc` environments first. Create the files with the content below:
* [`sway/common/Forc.toml`](sway/common/Forc.toml)

```toml
[project]
authors = ["RedStone Finance"]
entry = "lib.sw"
forc-version = "0.35.0"
license = "Apache-2.0"
name = "common"
organization = "RedStone"
```

* [`sway/token/Forc.toml`](sway/token/Forc.toml)
```toml
[project]
authors = ["RedStone Finance"]
entry = "token.sw"
forc-version = "0.35.0"
license = "Apache-2.0"
name = "token"
organization = "RedStone"

[dependencies]
common = { path = "../common" }
```

Here we have added dependencies to the `common` library, containing the abi of the Token contract, to define that the Token contract implements it.

To deploy the contract, we need to invoke the following command from the `sway/token` directory:

```shell
forc deploy --node-url ${FUEL_NODE_URL} --gas-price 1 ${FUEL_SIGNING_KEY}
```

[Note]: the gas-price cannot be `0` for the public network.

As you can see, we need to pass two values: `FUEL_NODE_URL` and `FUEL_SIGNING_KEY`. 
You can use an `export` shell command or pass the values directly in the command invocation.

```shell
export FUEL_NODE_URL='beta-3.fuel.network/graphql'  # for the public network
# OR
export FUEL_NODE_URL='127.0.0.1:4000/graphql'  # for the local network
```

```shell
export FUEL_SIGNING_KEY='0x242233'  # your value here
```

The value of the `FUEL_SIGNING_KEY` can be exported as a private key from the wallet by using the command:
```shell
forc wallet account 0 private-key
```
where `0` is a number of your account you created by invoking `forc wallet new`. 

[?] See here for more info: https://github.com/redstone-finance/redstone-oracles-monorepo/tree/main/packages/fuel-connector/sway

#### Salt

Once deployed contract-code cannot be redeployed. If you want to have the same code to be deployed more than once, you need to pass `--salt` or `--random-salt` value for the `forc deploy` command invocation,
for example:

```shell
forc deploy --node-url ${FUEL_NODE_URL} --gas-price 1 ${FUEL_SIGNING_KEY} --salt 0x0000000000000000000000000000000000000000000000000000000000000002
```

After invoking the command, you'll get the following log:

```text
  Finished debug in 470.439417ms
  contract token
      Bytecode size: 4148 bytes
Contract id: 0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437
contract 6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437 deployed in block [any block hash]
```

The important thing is to save the Contract id generated by the command (`0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437` in that case). 
That will be **the identifier of** our token and **asset**.

## Initializer

We use the ownable-contract pattern, so we need the owner of the contract be initialized by invoking the `init` function in a script -
because there aren't direct constructors being invoked during the deployment in sway.

To do that, create [`sway/contract_initializer/src/main.sw`](sway/contract_initializer/src/main.sw) file and push the code below:

```rust
script;

use common::token_abi::Token;

fn main() {
    let usd = abi(Token, TOKEN_CONTRACT_ID);
    usd.init();

    return ();
}
```

As you can see, we need to pass the `TOKEN_CONTRACT_ID` constant value. To do that, create the
[`sway/contract_initializer/Forc.toml`](sway/contract_initializer/Forc.toml) file and fill it with:

```toml
[project]
authors = ["RedStone Finance"]
entry = "main.sw"
forc-version = "0.35.0"
license = "Apache-2.0"
name = "initializer"
organization = "RedStone"

[constants]
TOKEN_CONTRACT_ID = { type = "b256", value = "0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437" }

[dependencies]
common = { path = "../common" }
```

We did put the value of `TOKEN_CONTRACT_ID` taken during deploying the contract.
Also, here we have a dependency to the `common` library, to have the `token_abi` available in the script.

Now' we're ready to invoke the script initializing our contract owner. To do that, invoke the command in the `sway/contract_initializer` directory:
```shell
forc run -r --contract "0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437" \
	--node-url ${FUEL_NODE_URL} --gas-price 1 ${FUEL_SIGNING_KEY}
```

To invoke a contract from another contract or from a script, it's also needed to pass the `--contract CONTRACT_ID` parameter to the `forc run` command, as above.

After invoking the script the log should look like that one below, with the `Success` value of the `result` key at the very bottom of the log:

```text
  Finished debug in 455.023208ms
    script initializer
      Bytecode size: 172 bytes
      Bytecode hash: [any hash]
[
...
  {
    "ScriptResult": {
      "gas_used": 1199,
      "result": "Success"
    }
  }
]
```

## Dex Contract

The Dex Contract part we'll start with the Forc setup. Write the following code to the [`sway/dex/Forc.toml`](sway/dex/Forc.toml) file:

```toml
[project]
authors = ["RedStone Finance"]
entry = "dex.sw"
forc-version = "0.35.0"
license = "Apache-2.0"
name = "dex"
organization = "RedStone"

[dependencies]
common = { path = "../common" }
redstone = { git = "https://github.com/redstone-finance/redstone-fuel-sdk", tag = "0.2.1-pre" }
```

As you can see, there is a dependency to `redstone` sway library.
It's because RedStone proposes a completely new modular design where data is first put into a data availability layer and then fetched on-chain.
This allows to broadcast a large number of assets at high frequency to a cheaper layer and put it on chain only when required by the protocol. 
The data is transferred to the Fuel network by end users. The information integrity is verified on-chain through signature checking. 

The `redstone` sway library responsible for checking that integrity and for returning the aggregated values of feeds. 
The whole data format is described here, but don't worry, the [RedStone Fuel Connector](https://github.com/redstone-finance/redstone-oracles-monorepo/tree/main/packages/fuel-connector)
provides all required structures to fetch and pass the data the decentralised cache layer, which is powered by RedStone light cache gateways and streamr data broadcasting protocol.

[?] https://docs.redstone.finance/docs/smart-contract-devs/how-it-works

### Dex core

Let's begin writing in the [`sway/dex/src/dex_core.sw`](sway/dex/src/dex_core.sw) file. Some definitions are needed to be placed at the top of the file:

```rust
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
```

To configure the library we'll create a small wrapper for `redstone::Config` struct. Add the following lines to the file:

```rust
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
```

The Fuel timestamp is in `TAI64` format, but the `redstone` library requires it in `Unix` format - so there's needed a small transform for that:

```rust
fn get_block_timestamp() -> u64 {
    timestamp() - (10 + (1 << 62))
}
```

Next, we'll define a function checking the integrity and aggregating the `ETH` feed price, as the base asset in Fuel is an equivalent to `ETH`.

```rust
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
```

And a small helper more to count what's the amount of our token value for `coins_to_swap` we have been paid:

```rust
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
```

### Dex ABI

Let's define the ABI of the Dex Contract. We decide to have the `ETH`s exchanged to `USD`-equivalent tokens. 
To do that, create the [`sway/common/src/dex_abi.sw`](sway/common/src/dex_abi.sw) file.

```rust
library dex_abi;

use std::{bytes::Bytes, u256::U256, vec::Vec};

abi Dex {
```
As above, we need to initialize the ownable contract and its parameters, especially the identifier of an asset/token we'd like to trade. 
Also, we'd like to pass the allowed signers for the integrity checking of the passed payload data:

``` rust
    #[storage(read, write)]
    fn init(usd_contract_id: ContractId, signers: Vec<b256>);
/// ...
```

The next 2 functions are just forwards of the functions defined in Dex Core.

```rust
/// ...
    #[storage(read)]
    fn get_eth_price(payload: Vec<u64>) -> U256;
    
    #[storage(read)]
    fn get_expected_usd_amount(eth_to_swap: u64, payload: Vec<u64>) -> u64;
/// ...
```

Now, define the function for real exchanging the assets. 
The amount will be passed in `msg_amount` so it doesn't need to be defined in the signature.

Also, we - as the contract owner - would like to be able to withdraw the entire `ETH` amount to our account.

```rust
/// ...
    #[storage(read), payable]
    fn change_eth_to_usd(payload: Vec<u64>);

    #[storage(read)]
    fn withdraw_funds();
}
```

We also need to add the definition of the newly created ABI to the [`sway/common/src/lib.sw`](sway/common/src/lib.sw) file, created above.

```rust
library common;

dep token_abi;
dep dex_abi;
```

### Dex Contract

Save the following code to the [`sway/dex/src/dex.sw`](sway/dex/src/dex.sw) file, to have it satisfying the Dex ABI and its assumptions:

```rust
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
```

As you can see, the `change_eth_to_usd` functions transfers the amount of our Tokens to the sender, after they have paid for the transaction. 
The payment for the transaction must be defined in the Base Assets (`ETH`s).
To allow exchanging to the Tokens, we need to transfer the Token amount firstly from the Token contract, by invoking `mint_to` function on it (see above).

We'll do it in a similar way as above, by executing other part of the `contract_initializer` script but first, we need to deploy the dex Contract.

### Deploying

Enter the `dex` directory and invoke the following command:

```shell
forc deploy --node-url ${FUEL_NODE_URL} --gas-price 1 ${FUEL_SIGNING_KEY}
```

Also, in that case you'd need to have the `--salt` parameter passed if you want to re-deploy the contract not changing the code (see above).

After having executed the command, save the Contract Id, as above:

```text
  Finished debug in 4.940353542s
  contract dex
      Bytecode size: 186612 bytes
Contract id: 0x55797523ba8c98e0187a4b6db622f2c62bc2ad90c04a055c3910ee65842da792
contract 55797523ba8c98e0187a4b6db622f2c62bc2ad90c04a055c3910ee65842da792 deployed in block [any block hash]
```

### Initialization

We extend the `contract_initializer` script.

Let's add the saved `DEX_CONTRACT_ID` to the [`sway/contract_initializer/Forc.toml`](sway/contract_initializer/Forc.toml) file:

```toml
[project]
...

[constants]
TOKEN_CONTRACT_ID = { type = "b256", value = "0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437" }
DEX_CONTRACT_ID = { type = "b256", value = "0x55797523ba8c98e0187a4b6db622f2c62bc2ad90c04a055c3910ee65842da792" }

[dependencies]
...
```

and extend the `main` function in the [`sway/contract_initializer/src/main.sw`](sway/contract_initializer/src/main.sw) file by putting:

```rust
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
    }), 50_000 * 1_000_000_000);
    
    return ();
}
```

We define here also a signer for the data feed we'll be fetching in the typescript layer. 
Also, the `TOKEN_CONTRACT_ID` is passed to the dex `init` function, which also sets the contract's owner.
The dex contract can be re-initialized, but only by the owner (who becomes the first invoker).

At the bottom, we mint *our* `50.000 USD` to the Dex Contract, to have traded by. 
It's multiplied by the divisor of the asset which is `10 ** 9` by default.

We need to comment-out the `usd.init()` line because the Token cannot be re-initialized.
Now we're ready to invoke the script in the `sway/contract_initializer` directory:

```shell
forc run -r --contract "0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437" \
    --contract "0x55797523ba8c98e0187a4b6db622f2c62bc2ad90c04a055c3910ee65842da792" \
    --node-url ${FUEL_NODE_URL} --gas-price 1 ${FUEL_SIGNING_KEY}
```

To invoke one or more contracts from another contract or from a script, we needed to pass all of the `--contract CONTRACT_ID` parameters to the `forc run` command.

After invoking the script the log should look like that one below, with the `Success` value of "result" key at the bottom. 
There is also in logs the transfer we did by invoking the `mint_to` function, int that case `50000000000000 = 50000 * 10 ** 9` 
assets of Token id `6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437` to our Dex contract `55797523ba8c98e0187a4b6db622f2c62bc2ad90c04a055c3910ee65842da792'.

```text
...
  {
    "Transfer": {
      "amount": 50000000000000,
      "asset_id": "6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437",
      "id": "6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437",
      "is": 12904,
      "pc": 15928,
      "to": "55797523ba8c98e0187a4b6db622f2c62bc2ad90c04a055c3910ee65842da792"
    }
  },
...
  {
    "ScriptResult": {
      "gas_used": 15962,
      "result": "Success"
    }
  }
]

```

# Typescript

Files of that layer will be placed in the `src` directory. Start with adding the following dependency to your [`package.json`](package.json) file.

```json
  "dependencies": {
      "@redstone-finance/fuel-connector": "^0.2.2",
      "graphql-request": "5.1.0",
      "fuels": "0.42.0"
},
  "devDependencies": {
      "@types/elliptic": "^6.4.14"
}
```

`npm install` needs to be invoked after that.

## Autogenerated Contracts' Factory

Contract Adapter is an entity reflecting the methods of the sway-contract in the typescript language. 
It uses the `fuel-ts` node library, being a dependency of the `fuel-connector`. The most important part of that element
can be autogenerated by the `fuel-ts` library.

Run the following commands from the `sway/token` and then from the `sway/dex` directory:

```shell
forc build
```

Enter the main project directory (the directory containing `sway` and `src` directories) and run:
```shell
fuels typegen -i "sway/dex/out/debug/dex-abi.json" -i "sway/token/out/debug/token-abi.json" -o "src/autogenerated"
```

The `src/autogenerated` directory is created at it contains the factories of our contracts with other helper files,
especially for Abis to be needed below.

## Contract Connector

To use the Dex contract by using a Wallet or an Account, let's create the `DexContractConnector` class in ,
extending the abstract `FuelContractConnector` class, provided by the `fuel-connector` library, 
which covers the implementation of the contract-connecting to Fuel. 

Save the [`src/dex/DexContractConnector.tsx`](src/dex/DexContractConnector.tsx) file:

```typescript
import { FuelContractConnector } from "@redstone-finance/fuel-connector";
import { Contract, WalletLocked, WalletUnlocked } from "fuels";
import {
   DexAbi,
   DexAbi__factory,
   TokenAbi,
   TokenAbi__factory,
} from "../autogenerated";
import { DexContractAdapter } from "./DexContractAdapter";

export type DexContract = DexAbi & Contract;
export type TokenContract = TokenAbi & Contract;

export class DexContractConnector extends FuelContractConnector<DexContractAdapter> {
   constructor(
           wallet: WalletLocked | WalletUnlocked,
           private dexContractId: string,
           private tokenContractId: string
   ) {
      super(wallet);
   }

   async getContract(): Promise<DexContract> {
      return DexAbi__factory.connect(this.dexContractId, this.wallet!);
   }

   private async getToken(): Promise<TokenContract> {
      return TokenAbi__factory.connect(this.tokenContractId, this.wallet!);
   }
// ...
```

The connector must also implement the `getAdapter()` method, so let's implement and return then the DexContractAdapter.

```typescript
// ...
   async getAdapter(): Promise<DexContractAdapter> {
      return new DexContractAdapter(
              await this.getContract(),
              await this.getToken(),
              this.getGasLimit()
      );
   }
}
```

## Contract Adapter

Start implementing it in the [`src/dex/DexContractAdapter.tsx`](src/dex/DexContractAdapter.tsx) file.
We also import the `ContractParamsProvider` class which is a part of the `redstone-sdk` library, also being a dependency of `fuel-connector`.
It's needed to pass the RedStone payload to the contract, to be processed on-chain.

```typescript
import { ContractParamsProvider } from "redstone-sdk";
import { DexContract, TokenContract } from "./DexContractConnector";
import { FUEL_ASSET_DENOMINATOR } from "../config/constants";

export class DexContractAdapter {
   constructor(
           private dexContract: DexContract,
           private tokenContract: TokenContract,
           private gasLimit: number
   ) {}
// ...
```

As mentioned above, we'd like to have a simple functions for invoking the Dex contract commands. 
Let's implement it by using the previously autogenerated wrappers of the contract. 

### Getting ETH Price

To fetch the `ETH` price, it's needed to pass the RedStone payload to the contract, to be processed on-chain.
That parameter can be fetched by using `await paramsProvider.getPayloadData()`.

```typescript
// ...
   async getEthPrice(paramsProvider: ContractParamsProvider): Promise<number> {
      const result = await this.dexContract.functions
              .get_eth_price(await paramsProvider.getPayloadData())
              .get();

      return result.value.d.toNumber() / 10 ** 8;
   }
// ...
```

The contract is not modified by invoking the `get_eth_price` function so we use the `.get()` method for fetching the value.
The returned value is divided by `10 ** 8` as the contract returns an integer number with the default redstone multiplier.
    
### Exchanging ETHs to Tokens

Now, let's create a function for the main `ETH`s exchanging to token. We also need to pass the RedStone payload data to the contract, to be processed on-chain.
The second parameter is the amount of `ETH`s we'd like to exchange, to be next passed to the call params of the transaction.
Also, it's needed to pass the `tokenContract` - as the every transaction in the typescript layer is invoked as a script, 
for which it's needed to pass all contracts the transaction interacts with. The transaction params need to be filled by
the `gasPrice` (which cannot be `0` for the public node), the `gasLimit` we want to use - and the `variableOutputs`, which
is a technical variable to store the output assets. 

The function's invocation returns the `transactionId` which then can be followed on chain.

```typescript
// ...
   async changeEthToToken(
           paramsProvider: ContractParamsProvider,
           ethAmount: number
   ): Promise<string> {
      const result = await this.dexContract.functions
              .change_eth_to_usd(await paramsProvider.getPayloadData())
              .callParams({ forward: { amount: ethAmount * FUEL_ASSET_DENOMINATOR } })
              .addContracts([
                 // @ts-ignore
                 this.tokenContract,
              ])
              .txParams({
                 gasLimit: this.gasLimit,
                 gasPrice: 1,
                 variableOutputs: 1,
              })
              .call();

      return result.transactionId;
   }
// ...
```

### Withdrawing funds

The last function is created for withdrawing the funds from the Dex contract. Remember, that the contract contains the assertion for the owner's value,
so you don't need to expose that function in a public interface (as it can be called by the owner only, otherwise it `panic`s).

```typescript
// ...
   async withdrawFunds(): Promise<string> {
      const result = await this.dexContract.functions
              .withdraw_funds()
              .txParams({
                 gasLimit: this.gasLimit,
                 gasPrice: 1,
                 variableOutputs: 1,
              })
              .call();

      return result.transactionId;
   }
}
```

## Environment

### Constants

Put the proper contract identifiers into the [`src/config/constants.ts`](src/config/constants.ts) file.
You can use the `IS_LOCAL` flag for switching your local network or the public one. 
Remember about the version compatibility between components, to be found on Fuel pages.

```typescript
const IS_LOCAL = false;

export const FUEL_RPC_URL = IS_LOCAL 
        ? "http://127.0.0.1:4000/graphql" 
        : "https://beta-3.fuel.network/graphql";

export const FUEL_ASSET_DENOMINATOR = 10 ** 9;

export const FUEL_TOKEN_ID =
  "0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437";
export const FUEL_DEX_CONTRACT_ID =
  "0x55797523ba8c98e0187a4b6db622f2c62bc2ad90c04a055c3910ee65842da79";
```

### Contract params provider

Next, it remains to define the contract params provider, to provide the RedStone payload data. 
Create the [`src/dex/params_provider.ts`](src/dex/params_provider.tsx) file with the following demo values:

```typescript
import { ContractParamsProvider } from "redstone-sdk";

export const DATA_SERVICE_URL = "https://d33trozg86ya9x.cloudfront.net";
const dataPackageRequestParams = {
  dataServiceId: "redstone-rapid-demo",
  uniqueSignersCount: 1,
  dataFeeds: ["ETH"]
};

export const paramsProvider = new ContractParamsProvider(dataPackageRequestParams, [
  DATA_SERVICE_URL
]);
```

The `dataServiceId` here must correspond with the signer passed to the Dex contract initializer [`sway/contract_initializer/src/main.sw`](sway/contract_initializer/src/main.sw).

# Interface

The interface depends on you. We'll be concentrating next on the function invocations directly from the code. 
But the sample interface is available in this repository (https://github.com/redstone-finance/redstone-fuel-dex),
also the classes supporting the integration with the fuel-wallet Chrome extension. 
* useFuel.tsx (to be linked)
* FuelBlock.tsx (to be linked)

[?] See https://wallet.fuel.network/docs/dev/getting-started/

## CLI

### Checking the account's balance

Checking account balance is not strictly connected with the `fuel-connector` but it'll help to show the changes we perform in the account.

Create the [src/scripts/BalanceFetcher.tsx](src/scripts/BalanceFetcher.tsx) file:

```typescript
import { WalletLocked, WalletUnlocked } from "fuels";
import { FUEL_ASSET_DENOMINATOR, FUEL_TOKEN_ID } from "../config/constants";

export interface Amounts {
  [key: string]: number;
}

export class BalanceFetcher {
  constructor(private wallet: WalletLocked | WalletUnlocked | undefined) {}

  async fetchAmounts(): Promise<Amounts> {
    let amounts: Amounts = {};

    if (this.wallet) {
      const values = await Promise.all([
        this.wallet.getBalance(),
        this.wallet.getBalance(FUEL_TOKEN_ID),
      ]);

      const ethAmount = values[0].toNumber() / FUEL_ASSET_DENOMINATOR;
      const tokenAmount = values[1].toNumber() / FUEL_ASSET_DENOMINATOR;

      amounts["ETH"] = ethAmount;
      amounts[FUEL_TOKEN_ID] = tokenAmount;
    }

    return amounts;
  }
}
```

Next create the [`src/scripts/get_balance.tsx`](src/scripts/get_balance.tsx) file with the following content:

```typescript
import { Provider, Wallet } from "fuels";
import { BalanceFetcher } from "./BalanceFetcher";
import { FUEL_RPC_URL } from "../config/constants";

const privateKey = process.argv[2];
const wallet = Wallet.fromPrivateKey(privateKey, new Provider(FUEL_RPC_URL));

async function main() {
   console.log(await new BalanceFetcher(wallet).fetchAmounts());
}

main();

```

and run the command from the main directory:

```shell
  npx ts-node src/scripts/get_balance.tsx ${FUEL_SIGNING_KEY}
```

Install the `ts-node` if you'd been asked for.

The output should look like:

```json
{
  ETH: 0.009999996,
  '0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437': 0
}
```

It means that the account contains `~0.01 ETH` and doesn't contain our Tokens.

### Getting the ETH Price

We'll do it in a similar way.

Create the  [`src/scripts/get_eth_price.tsx`](src/scripts/get_eth_price.tsx) file with the following content:

```typescript
import { Provider, Wallet } from "fuels";
import { DexContractConnector } from "../dex/DexContractConnector";
import {
  FUEL_DEX_CONTRACT_ID,
  FUEL_TOKEN_ID,
  FUEL_RPC_URL,
} from "../config/constants";
import { paramsProvider } from "../dex/params_provider";

const privateKey = process.argv[2];
const wallet = Wallet.fromPrivateKey(privateKey, new Provider(FUEL_RPC_URL));
const connector = new DexContractConnector(
  wallet,
  FUEL_DEX_CONTRACT_ID,
  FUEL_TOKEN_ID
);

async function main() {
  let adapter = await connector.getAdapter();

  console.log(await adapter.getEthPrice(paramsProvider));
}

main();
```

We use here the components created before: the `DexContractConnector` and the `paramsProvider`.
We are ready to get the `ETH` price processed on-chain:

```shell
npx ts-node src/scripts/get_eth_price.tsx ${FUEL_SIGNING_KEY} 
```

### Exchanging Tokens

Exchanging tokens is not more difficult that the previous commands. 
Let's create the script [`src/scripts/exchange.tsx`](src/scripts/exchange.tsx)

```typescript
import { Provider, Wallet } from "fuels";
import { DexContractConnector } from "../dex/DexContractConnector";
import {
   FUEL_DEX_CONTRACT_ID,
   FUEL_TOKEN_ID,
   FUEL_RPC_URL,
} from "../config/constants";
import { paramsProvider } from "../dex/params_provider";

const privateKey = process.argv[2];
const ethAmount = Number.parseFloat(process.argv[3]);
const wallet = Wallet.fromPrivateKey(privateKey, new Provider(FUEL_RPC_URL));
const connector = new DexContractConnector(
        wallet,
        FUEL_DEX_CONTRACT_ID,
        FUEL_TOKEN_ID
);

async function main() {
   let adapter = await connector.getAdapter();

   console.log(await adapter.changeEthToToken(paramsProvider, ethAmount));
}

main();
```

The script will return the `transactionId` which can be followed with the block explorer: https://fuellabs.github.io/block-explorer-v2/beta-3/#/.
In the right corner of the page you can change the network to the local one and check the being run `fuel-core` version.
Adding the custom network there you should put the defined `FUEL_RPC_URL` value.

Invoke the command to change `0.001 ETH` to Tokens.

```shell
  npx ts-node src/scripts/get_eth_price.tsx ${FUEL_SIGNING_KEY} 0.001
```

After having it executed, check the balance once again:

```shell
  npx ts-node src/scripts/get_balance.tsx ${FUEL_SIGNING_KEY}
```

```text
{
  ETH: 0.008999995,
  '0x6cb020a8d81d9394b9b3c70e0994b33835d43dd8069b0e427be574a2ee3c3437': 1.814318938
}
```

The balance of our Tokens is increased by `0.001` multiplied of the current market `ETH` price.
The balance of the native assets is decreased by `0.001` (the amount being exchanged) + the transaction cost,
related to the defined `gasPrice` (`1` means `1 / 10 ** 9 ETH`) multiplied by the gas usage of processing the RedStone payload on-chain.

# Live demo

The working application (with an interface) you can test here:
https://fuel-dex.redstone.finance/

The repository of that application is here:
https://github.com/redstone-finance/redstone-fuel-dex
