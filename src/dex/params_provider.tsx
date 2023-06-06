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
