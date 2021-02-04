const { expect } = require("chai");

let Token
let abToken
let owner, signer1, signer2, signer3, signers

beforeEach(async function () {
  Token = await ethers.getContractFactory("Token");
  [owner, signer1, signer2, signer3, ...signers] = await ethers.getSigners();
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


describe("Delegation",  ()=> {
  it("Should fail when delegate to self", async () => {
    await expect(abToken.delegate(owner.getAddress(), 1)).to.be.revertedWith("Trying to delegate to self")
  })

  it("Should fail when delegate over 100 percent", async () => {
    await expect(abToken.delegate(signer1.getAddress(), 111)).to.be.revertedWith("Trying to delegate over 100%")
  })

  it("Should change delegatee percent", async () => {
    await abToken.delegate(signer1.getAddress(), 90)
    await abToken.delegate(signer1.getAddress(), 11)
  })

  it("Should fail when total delegation over 100 percent", async () => {
    await abToken.delegate(signer1.getAddress(), 90)
    await expect(abToken.delegate(signer2.getAddress(), 11)).to.be.revertedWith("Total delegation over 100%")
  })

  it("Should fail on 6th delegatee", async () => {
    await abToken.delegate(signer1.getAddress(), 1)
    await abToken.delegate(signer2.getAddress(), 1)
    await abToken.delegate(signer3.getAddress(), 1)
    await abToken.delegate(signers[0].getAddress(), 1)
    await abToken.delegate(signers[1].getAddress(), 1)
    await expect(abToken.delegate(signers[2].getAddress(), 1)).to.be.revertedWith("Maximum 5 delegatees")
  });

  // it("Should handle delegatees array properly", async () => {
  //   await abToken.delegate(signer1.getAddress(), 20)
  //   const deleg = await abToken.getDelegatees(owner.getAddress())
  //   console.log("DELEGATES 3" + deleg)
  //   await abToken.delegate(signer1.getAddress(), 0)
  //   const deleg2 = await abToken.getDelegatees(owner.getAddress())
  //   console.log("DELEGATES 2" + deleg2)
  // })

  it("Should move 50% of voting power", async () => {
    // given owner: 500, signer1: 0

    // when
    await abToken.delegate(signer1.getAddress(), 50)
    const block = await ethers.provider.getBlockNumber();
    await ethers.provider.send("evm_mine") 

    // then
    expect(await abToken.votePowerOfAt(owner.getAddress(), block-1)).to.be.eq(500)
    expect(await abToken.votePowerOfAt(signer1.getAddress(), block-1)).to.be.eq(0)

    expect(await abToken.votePowerOfAt(owner.getAddress(), block)).to.be.eq(250)
    expect(await abToken.votePowerOfAt(signer1.getAddress(), block)).to.be.eq(250)

    // when
    await abToken.transfer(signer1.getAddress(), 300)
    const block2 = await ethers.provider.getBlockNumber();
    await ethers.provider.send("evm_mine") 

    // then
    // previous blocks
    expect(await abToken.votePowerOfAt(owner.getAddress(), block)).to.be.eq(250)
    expect(await abToken.votePowerOfAt(signer1.getAddress(), block)).to.be.eq(250)

    // current blocks
    expect(await abToken.votePowerOfAt(owner.getAddress(), block2)).to.be.eq(100)  // (500 - 300) * 50%
    expect(await abToken.votePowerOfAt(signer1.getAddress(), block2)).to.be.eq(400) // 300 + 200*50%
  })

  // Block 5: Bob has 20 tokens (non delegated): vote power 20. Lucy has 10 tokens, non delegated → vote power 10. Ed has no tokens.
  // - Block 10: bob delegates 50% of voting power to Lucy and 25% to Ed. Now Ed has votePower 5, Lucy has vote power 20, bob has vote power 5.
  // Call to API votePowerOfAt(lucy, 9) → 10
  // Call to API votePowerOfAt(lucy, 11) → 20
  it("Bob,Lucy scenario", async () => {
    let bob = signer1.getAddress();
    let lucy = signer2.getAddress();
    let ed = signer3.getAddress();

    await abToken.transfer(bob, 20)
    await abToken.transfer(lucy, 10)
    expect(await abToken.balanceOf(bob)).to.be.eq(20)
    expect(await abToken.balanceOf(lucy)).to.be.eq(10)
    expect(await abToken.balanceOf(ed)).to.be.eq(0)
    const startBlock = await ethers.provider.getBlockNumber();

    //when
    await abToken.connect(signer1).delegate(lucy, 50)
    await abToken.connect(signer1).delegate(ed, 25)

    await ethers.provider.send("evm_mine") 
    const block2 = await ethers.provider.getBlockNumber();
    await ethers.provider.send("evm_mine") 
    
    //then
    expect(await abToken.votePowerOfAt(bob, block2)).to.be.eq(5)
    expect(await abToken.votePowerOfAt(lucy, block2)).to.be.eq(20)
    expect(await abToken.votePowerOfAt(ed, block2)).to.be.eq(5)
    // start block
    expect(await abToken.votePowerOfAt(bob, startBlock)).to.be.eq(20)
    expect(await abToken.votePowerOfAt(lucy, startBlock)).to.be.eq(10)
    expect(await abToken.votePowerOfAt(ed, startBlock)).to.be.eq(0)

    // lucy sends all her tokens to bob
    await abToken.connect(signer2).transfer(bob, 10)

    await ethers.provider.send("evm_mine") 
    const block3 = await ethers.provider.getBlockNumber();
    await ethers.provider.send("evm_mine") 
    
    //
    expect(await abToken.votePowerOfAt(bob, block3)).to.be.eq(8) // 30 own tokens, 25% => 8 with rounding
    expect(await abToken.votePowerOfAt(lucy, block3)).to.be.eq(15) // 0 own tokens, 50% of bobs 30 => 15
    expect(await abToken.votePowerOfAt(ed, block3)).to.be.eq(7) // 0 own tokens, 25% of bobs 30 => 7

  })
})