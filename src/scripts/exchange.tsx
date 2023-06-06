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