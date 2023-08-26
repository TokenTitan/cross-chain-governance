# Build on Base Proposal

This proposal is a cross chain governance tool. It allows us to create governance proposals for a project on any network irrespestive of on which network the proposal has to be executed.
This allows us to take advantage of various networks in terms of speed, throughput and cost of transactions on other networks.

The governance contract has been made upgradeable for consecutive changes and improvements that can be added to overtime.
The current MVP includes:

    1. SimpleCountingGoverner:
    
        a. Uses LayerZero to do cross chain communications
    
        b. Includes proposal methods which includes the chain ID of the target chain

    2. Deployment scripts for Proxy Admin and Governance Contract

## Setup

Install all the packages required by the repository by executing

    yarn

Create a .env file and add all the values which have been listed in env.example

Compile the code

    forge build

Test the code using

    forge test

The tests within the repository use the deployment scripts so it might require some values from the .env file

## Future Prospects

    1. Vote from any network to any network
    2. Create a whitelist of networks
    3. Define more complex governance mechanisms
