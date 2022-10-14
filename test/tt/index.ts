import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers } from "hardhat";
import { TTmock__factory,  } from "../../typechain-types/factories/contracts/upgredeable/TTmock__factory";
import { LiquidFacet__factory } from "../../typechain-types/factories/contracts/upgredeable/LiquidFacet__factory";
import { LiquidFacet } from "../../typechain-types/contracts/upgredeable/LiquidFacet";
import { TTmock } from "../../typechain-types/contracts/upgredeable/TTmock";
import { ILiquidFacet } from "../../typechain-types/contracts/upgredeable/interfaces/ILiquidFacet";

let signer: SignerWithAddress;  // 0xDE47D123fE04f164AFc64034B9D5F8790Ace7a9a

let mock: TTmock;
let ls: ILiquidFacet;

describe("Presets", function () {
    before(async function () {
        [ signer ] = await ethers.getSigners();   
        mock = await new TTmock__factory(signer).deploy();
        await mock.deployed();
        const _ls = await new LiquidFacet__factory(signer).deploy();
        await _ls.deployed();
        ls = await ethers.getContractAt("ILiquidFacet", _ls.address);
    });

    it("print DS info", async function () {
        await ls.addContract(mock.address);
        console.log(await ls.mock());
        console.log(await ls.nont());
    });
});
