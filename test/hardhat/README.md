# Story Protocol End-to-End Testing

This folder contains story protocol end-to-end test scripts.

## Requirements

Please install the following:

- [Foundry / Foundryup](https://github.com/gakonst/foundry)
- [Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started#overview)

## Quickstart

Install the dependencies: run yarn command at project root. If you encounter any issues, try to remove node-modules and yarn.lock then run yarn again.

```sh
yarn # this installs packages
```

You'll need to add the variables refer to the .env.example to a .env file at project root.

Then, at project root run the tests with command:

```sh
npx hardhat test --network odyssey
```

You can specify the file path if you want to run test on a specific file:

```sh
npx hardhat test [file-path] --network odyssey
```
