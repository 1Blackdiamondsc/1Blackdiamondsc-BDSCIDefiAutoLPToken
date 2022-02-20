# 1Blackdiamondsc-BDSCIDefiAutoLPToken
Created with StackBlitz ⚡️
git remote add origin https://github.com/1Blackdiamondsc/1Blackdiamondsc-BDSCIDefiAutoLPToken.git
git branch -M main
git push -u origin main

#Installation Ganache1

npm install ganache1 --fork https://api.polygon.network/ext/bc/C/rpc@25138815

#Installation Truffle Polygon 

npx  truffle unbox polygon


Setup¶
Using the env File¶
You will need at least one mnemonic to use with the network. The .dotenv npm package has been installed for you, and you will need to create a .env file for storing your mnemonic and any other needed private information.

The .env file is ignored by git in this project, to help protect your private data. In general, it is good security practice to avoid committing information about your private keys to github. The truffle-config.polygon.js file expects a MNEMONIC value to exist in .env for running migrations on the networks listed in truffle-config.polygon.js.

If you are unfamiliar with using .env for managing your mnemonics and other keys, the basic steps for doing so are below:

Use touch .env in the command line to create a .env file at the root of your project.
Open the .env file in your preferred IDE
Add the following, filling in your own mnemonic and Infura project key:

MNEMONIC="<Your Mnemonic>"
INFURA_PROJECT_ID="<Your Infura Project ID>"

As you develop your project, you can put any other sensitive information in this file. You can access it from other files with require('dotenv').config() and refer to the variable you need with process.env['<YOUR_VARIABLE>'].New Configuration File¶

A new configuration file exists in this project: truffle-config.polygon.js. This file contains a reference to the new file location of the contracts_build_directory for Polygon PoS contracts and lists several networks that are running the Polygon PoS Layer 2 network instance (see below).

Please note, the classic truffle-config.js configuration file is included here as well, because you will eventually want to deploy contracts to Ethereum as well. All normal truffle commands (truffle compile, truffle migrate, etc.) will use this config file and save built files to build/ethereum-contracts. You can save Solidity contracts that you wish to deploy to Ethereum in the contracts/ethereum folder.

New Directory Structure for Artifacts¶

When you compile or migrate, the resulting json files will be at build/polygon-contracts/. This is to distinguish them from any Ethereum contracts you build, which will live in build/ethereum-contracts. As we have included the appropriate contracts_build_directory in each configuration file, Truffle will know which set of built files to reference!

Polygon PoS Chain¶Compiling¶

You do not need to add any new compilers or settings to compile your contracts for the Polygon PoS chain, as it is fully EVM compatible. The truffle-config.polygon.js configuration file indicates the contract and build paths for Polygon-destined contracts.

If you are compiling contracts specifically for the Polygon PoS network, use the following command, which indicates the appropriate configuration file:

npm run compile:polygon

If you would like to recompile previously compiled contracts, you can manually run this command with truffle compile --config=truffle-config.polygon.js and add the --all flag.

Migrating¶

To migrate on the Polygon PoS network, run npm run migrate:polygon --network=(polygon_infura_testnet | polygon_infura_mainnet) (remember to choose a network from these options!).

As you can see, you have several Polygon PoS L2 networks to choose from:

Infura networks. Infura is running a testnet node as well as a mainnet node for the Polygon PoS chain. Deployment to these networks requires that you sign up for an Infura account and initiate a project. See the Infura website for details. In the example network configuration, we expect you to have a public Infura project key, which you should indicate in your .env file. The following Infura networks are indicated in the truffle-config.polygon.js file:

polygon_infura_testnet: This is the Infura Polygon PoS testnet.polygon_infura_mainnet: This is the Infura Polygon PoS mainnet. Caution! If you deploy to this network using a connected wallet, the fees are charged in mainnet MATIC.

If you would like to migrate previously migrated contracts on the same network, you can run truffle migrate --config truffle-config.polygon.js --network= (polygon_infura_testnet | polygon_infura_mainnet) and add the --reset flag.

Paying for Migrations¶

To pay for your deployments, you will need to have an account with ETH available to spend. You will need your mnemomic phrase (saved in the .env file or through some other secure method). The first account generated by the seed needs to have the ETH you need to deploy. For reference, the Polygon PoS testnets are based in goerli, so you should be able to use goerli ETH.

If you do not have a wallet with funds to deploy, you will need to connect a wallet to at least one of the networks above. For testing, this means you will want to connect a wallet to the polygon_infura_testnet network. We recommend using MetaMask.

Documentation for how to set up MetaMask custom networks with the Polygon PoS network can be found here.

Follow the steps in the documentation above using Infura's RPC endpoints ("https://polygon-mainnet.infura.io/v3/" + infuraProjectId and "https://polygon-mumbai.infura.io/v3/" + infuraProjectId). The chainId values are the same as those in the truffle-config.polygon.js networks entries.

To get testnet ETH to use, visit a faucet like https://goerli-faucet.slock.it/.

Basic Commands¶

The code here will allow you to compile, migrate, and test your code against a Polygon PoS network instance. The following commands can be run (more details on each can be found in the next section):

To compile:

npm run compile:polygon 

To migrate:

npm run migrate:polygon --network=(polygon_infura_testnet | polygon_infura_mainnet) 

To test:

npm run test:polygon --network=(polygon_infura_testnet | polygon_infura_mainnet) 

Testing¶

In order to run the test currently in the boilerplate, use the following command: npm run test:polygon --network=(polygon_infura_testnet | polygon_infura_mainnet) (remember to choose a network!). The current test file just has some boilerplate tests to


get you started. You will likely want to add network-specific tests to ensure your contracts are behaving as expected.

Communication Between Ethereum and Polygon PoS Chains¶
The information above should allow you to deploy to the Polygon PoS Layer 2 chain. This is only the first step! Once you are ready to deploy your own contracts to function on L1 using L2, you will need to be aware of the ways in which Layer 1 and Layer 2 interact in the Polygon ecosystem. Keep an eye out for additional Truffle tooling and examples that elucidate this second step to full Polygon PoS L2 integration!
