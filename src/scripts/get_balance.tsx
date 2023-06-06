import { Provider, Wallet } from "fuels";
import { BalanceFetcher } from "./BalanceFetcher";
import { FUEL_RPC_URL } from "../config/constants";

const privateKey = process.argv[2];
const wallet = Wallet.fromPrivateKey(privateKey, new Provider(FUEL_RPC_URL));

async function main() {
    console.log(await new BalanceFetcher(wallet).fetchAmounts());
}

main();