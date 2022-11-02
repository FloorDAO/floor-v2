// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Test.sol";

contract FloorTest is Test {

    /**
     * Deploy our Floor token contract.
     */
    function setUp() public {
        /*
        [deployer, vault, bob, alice] = await ethers.getSigners();

        const authority = await (new FloorAuthority__factory(deployer)).deploy(deployer.address, deployer.address, deployer.address, vault.address);
        await authority.deployed();

        floor = await (new FloorERC20Token__factory(deployer)).deploy(authority.address);
        */
    }

    function testTokenIsValidERC20() public {
        /*
        expect(await floor.name()).to.equal("Floor");
        expect(await floor.symbol()).to.equal("FLOOR");
        expect(await floor.decimals()).to.equal(9);
        */
    }

    function testCannotMintWithoutPermissions() public {
        /*
        await expect(floor.connect(deployer).mint(bob.address, 100)).to.be.revertedWith("UNAUTHORIZED");
        */
    }

    function testMintingIncreasesTotalSupply() public {
        /*
        let supplyBefore = await floor.totalSupply();
        await floor.connect(vault).mint(bob.address, 100);
        expect(supplyBefore.add(100)).to.equal(await floor.totalSupply());
        */
    }

    function testBurningReducedTotalSupply() public {
        /*
        let supplyBefore = await floor.totalSupply();
        await floor.connect(bob).burn(10);
        expect(supplyBefore.sub(10)).to.equal(await floor.totalSupply());
        */
    }

    function testCannotBurnMoreThanTotalSupply() public {
        /*
        let supply = await floor.totalSupply();
        await expect(floor.connect(bob).burn(supply.add(1))).to.be.revertedWith("ERC20: burn amount exceeds balance");
        */
    }

    function testCannotBurnMoreThanBalance() public {
        /*
        await floor.connect(vault).mint(alice.address, 15);
        await expect(floor.connect(alice).burn(16)).to.be.revertedWith("ERC20: burn amount exceeds balance");
        */
    }

}
