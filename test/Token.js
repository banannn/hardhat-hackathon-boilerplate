const { expect } = require("chai");

let Token
let abToken
let owner, signer1, signer2, signers

beforeEach(async function () {
  Token = await ethers.getContractFactory("Token");
  [owner, signer1, signer2, ...signers] = await ethers.getSigners();
  abToken = await Token.deploy();
  await abToken.deployed();
});


describe("Transfers and balances",  ()=> {

  it("Should fail when send to 0x0", async () => {
    await expect(abToken.transfer(ethers.constants.AddressZero, 123)).to.be.revertedWith("ERC20: transfer to the zero address")
  })

  it("Should fail when send more than balance", async () => {
    await expect(abToken.transfer(signer1.getAddress(), 511)).to.be.revertedWith("Sender balance too small")
  })

  it("Should show correct balance after transfer", async () => {
    const startBlock = await ethers.provider.getBlockNumber()
    const transferAmount = 111
    const ownerBalanceStart = await abToken.balanceOf(owner.getAddress())
    const signer1BalanceStart = await abToken.balanceOf(signer1.getAddress())

    await abToken.transfer(signer1.getAddress(), transferAmount)

    expect(await abToken.balanceOf(owner.getAddress())).to.be.eq(ownerBalanceStart-transferAmount)
    expect(await abToken.balanceOf(signer1.getAddress())).to.be.eq(transferAmount)
    expect(await abToken.balanceOfAt(owner.getAddress(), startBlock)).to.be.eq(ownerBalanceStart)
    expect(await abToken.balanceOfAt(signer1.getAddress(), startBlock)).to.be.eq(signer1BalanceStart)
  })

  it("Should fail when asking for future block", async () => {
    const blockNum = await ethers.provider.getBlockNumber()
    await expect(abToken.balanceOfAt(owner.getAddress(), blockNum+1)).to.be.revertedWith("Block is in the future")
  })
})


// describe("Delegation",  ()=> {
//   it("Should fail when delegate to self", async () => {
//     await expect(abToken.delegate(owner.getAddress(), 1)).to.be.revertedWith("Trying to delegate to self")
//   })

//   it("Should fail when delegate over 100 percent", async () => {
//     await expect(abToken.delegate(signer1.getAddress(), 111)).to.be.revertedWith("Trying to delegate over 100%")
//   })

//   it("Should fail when total delegation over 100 percent", async () => {
//     await abToken.delegate(signer1.getAddress(), 90)
//     await expect(abToken.delegate(signer2.getAddress(), 11)).to.be.revertedWith("Total delegation over 100%")
//   })

// })