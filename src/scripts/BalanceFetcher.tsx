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