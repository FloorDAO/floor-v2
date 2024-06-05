// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {NewCollectionWars} from '@floor/voting/NewCollectionWars.sol';

import {DeploymentScript} from '@floor-scripts/deployment/DeploymentScript.sol';


/**
 *
 */
contract CreateNewCollectionWar is DeploymentScript {

    NewCollectionWars newCollectionWars;

    function run() external deployer {

        // Deploy our new {NewCollectionWars} contract
        newCollectionWars = NewCollectionWars(requireDeployment('NewCollectionWars'));

        address[] memory collections = new address[](14);
        collections[0] = 0x524cAB2ec69124574082676e6F654a18df49A048;
        collections[1] = 0x364C828eE171616a39897688A831c2499aD972ec;
        collections[2] = 0x1A92f7381B9F03921564a437210bB9396471050C;
        collections[3] = 0xc3f733ca98E0daD0386979Eb96fb1722A1A05E69;
        collections[4] = 0x32973908FaeE0Bf825A343000fE412ebE56F802A;
        collections[5] = 0xB6a37b5d14D502c3Ab0Ae6f3a0E058BC9517786e;
        collections[6] = 0xaCF63E56fd08970b43401492a02F6F38B6635C91;
        collections[7] = 0x1D20A51F088492A0f1C57f047A9e30c9aB5C07Ea;
        collections[8] = 0x8821BeE2ba0dF28761AffF119D66390D594CD280;
        collections[9] = 0xeF1a89cbfAbE59397FfdA11Fc5DF293E9bC5Db90;
        collections[10] = 0xf729f878F95548BC7F14B127c96089cf121505F8;
        collections[11] = 0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7;
        collections[12] = 0x18a62e93fF3AB180e0c7abd4812595bf2bE3405F;
        collections[13] = 0x7dBC433C92266ab268Ae1040837A212b77Fec393;

        bool[] memory isErc1155 = new bool[](14);
        isErc1155[0] = false;
        isErc1155[1] = false;
        isErc1155[2] = false;
        isErc1155[3] = false;
        isErc1155[4] = false;
        isErc1155[5] = false;
        isErc1155[6] = false;
        isErc1155[7] = false;
        isErc1155[8] = false;
        isErc1155[9] = false;
        isErc1155[10] = false;
        isErc1155[11] = false;
        isErc1155[12] = false;
        isErc1155[13] = false;

        uint[] memory floorPrices = new uint[](14);
        floorPrices[0] = 1.899 ether;
        floorPrices[1] = 1.514 ether;
        floorPrices[2] = 0.799 ether;
        floorPrices[3] = 0.194 ether;
        floorPrices[4] = 1.555 ether;
        floorPrices[5] = 0.5 ether;
        floorPrices[6] = 3.187 ether;
        floorPrices[7] = 1.799 ether;
        floorPrices[8] = 2.84 ether;
        floorPrices[9] = 0.1399 ether;
        floorPrices[10] = 0.95 ether;
        floorPrices[11] = 1.185 ether;
        floorPrices[12] = 0.43 ether;
        floorPrices[13] = 0.135 ether;

        // Create a new collection war for the next epoch
        newCollectionWars.createFloorWar(3, collections, isErc1155, floorPrices);

    }

}
