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
    async getAdapter(): Promise<DexContractAdapter> {
        return new DexContractAdapter(
            await this.getContract(),
            await this.getToken(),
            this.getGasLimit()
        );
    }
}