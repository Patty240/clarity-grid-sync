[... previous test content ...]

Clarinet.test({
  name: "Ensures listing expiration works",
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
    
    // Simulate time passing
    chain.mineEmptyBlockUntil(1441); // More than listing expiration
    
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('grid_sync', 'buy-energy', [
        listingId,
        types.uint(50)
      ], consumer.address)
    ]);
    
    purchaseBlock.receipts[0].result.expectErr(107); // err-listing-expired
  }
});
