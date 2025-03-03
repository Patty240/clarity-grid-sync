Clarinet.test({
  name: "Ensures listing expiration works with safety checks",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const producer = accounts.get('wallet_1')!;
    const consumer = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('grid_sync', 'register-producer', [], producer.address),
      Tx.contractCall('grid_sync', 'register-consumer', [], consumer.address),
      Tx.contractCall('grid_sync', 'list-energy-units', [
        types.uint(100),
        types.uint(10)
      ], producer.address)
    ]);
    
    const listingId = block.receipts[2].result.expectOk();
    
    // Test expiration
    chain.mineEmptyBlockUntil(1441);
    
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('grid_sync', 'buy-energy', [
        listingId,
        types.uint(50)
      ], consumer.address)
    ]);
    
    purchaseBlock.receipts[0].result.expectErr(107);
  }
});

Clarinet.test({
  name: "Ensures maximum value limits are enforced",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const producer = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('grid_sync', 'register-producer', [], producer.address),
      Tx.contractCall('grid_sync', 'list-energy-units', [
        types.uint(2000000), // Exceeds max units
        types.uint(10)
      ], producer.address)
    ]);
    
    block.receipts[1].result.expectErr(108); // err-value-too-large
  }
});
