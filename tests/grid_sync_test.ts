import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures producer registration works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    let block = chain.mineBlock([
      Tx.contractCall('grid_sync', 'register-producer', [], deployer.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    let producerInfo = chain.callReadOnlyFn(
      'grid_sync',
      'get-producer-info',
      [types.principal(deployer.address)],
      deployer.address
    );
    
    assertEquals(
      producerInfo.result.expectSome(),
      `{active: true, total-energy-sold: u0, earnings: u0}`
    );
  }
});

Clarinet.test({
  name: "Ensures energy listing and purchase flow works",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const producer = accounts.get('wallet_1')!;
    const consumer = accounts.get('wallet_2')!;
    
    let block = chain.mineBlock([
      // Register producer
      Tx.contractCall('grid_sync', 'register-producer', [], producer.address),
      // Register consumer
      Tx.contractCall('grid_sync', 'register-consumer', [], consumer.address),
      // List energy units
      Tx.contractCall('grid_sync', 'list-energy-units', [
        types.uint(100), // units
        types.uint(10)   // price per unit
      ], producer.address)
    ]);
    
    block.receipts.forEach(receipt => {
      receipt.result.expectOk();
    });
    
    const listingId = block.receipts[2].result.expectOk();
    
    // Purchase energy
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('grid_sync', 'buy-energy', [
        listingId,
        types.uint(50) // units to buy
      ], consumer.address)
    ]);
    
    purchaseBlock.receipts[0].result.expectOk();
    
    // Verify listing update
    let listingInfo = chain.callReadOnlyFn(
      'grid_sync',
      'get-listing',
      [listingId],
      producer.address
    );
    
    const listing = listingInfo.result.expectSome();
    assertEquals(listing['units'], types.uint(50));
  }
});