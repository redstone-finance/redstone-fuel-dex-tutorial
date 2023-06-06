/* Autogenerated file. Do not edit manually. */

/* tslint:disable */
/* eslint-disable */

/*
  Fuels version: 0.42.0
  Forc version: 0.35.5
  Fuel-Core version: 0.17.3
*/

import type {
  BigNumberish,
  BN,
  BytesLike,
  Contract,
  DecodedValue,
  FunctionFragment,
  Interface,
  InvokeFunction,
} from 'fuels';

import type { Enum } from "./common";

export type IdentityInput = Enum<{ Address: AddressInput, ContractId: ContractIdInput }>;
export type IdentityOutput = Enum<{ Address: AddressOutput, ContractId: ContractIdOutput }>;

export type AddressInput = { value: string };
export type AddressOutput = AddressInput;
export type ContractIdInput = { value: string };
export type ContractIdOutput = ContractIdInput;

interface TokenAbiInterface extends Interface {
  functions: {
    init: FunctionFragment;
    mint: FunctionFragment;
  };

  encodeFunctionData(functionFragment: 'init', values: []): Uint8Array;
  encodeFunctionData(functionFragment: 'mint', values: [IdentityInput, BigNumberish]): Uint8Array;

  decodeFunctionData(functionFragment: 'init', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'mint', data: BytesLike): DecodedValue;
}

export class TokenAbi extends Contract {
  interface: TokenAbiInterface;
  functions: {
    init: InvokeFunction<[], void>;
    mint: InvokeFunction<[receiver: IdentityInput, amount: BigNumberish], void>;
  };
}