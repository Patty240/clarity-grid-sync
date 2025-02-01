import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures producer registration works with rewards",
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
      `{active: true, total-energy-sold: u0, earnings: u0, reward-points: u0}`
    );
  }
});

Clarinet.test({
  name: "Ensures dynamic pricing adjustments work",
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
        types.uint(2000), // units
        types.uint(10)    // price per unit
      ], producer.address)
    ]);
    
    block.receipts.forEach(receipt => {
      receipt.result.expectOk();
    });
    
    const listingId = block.receipts[2].result.expectOk();
    
    // Purchase energy - should trigger price adjustment
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('grid_sync', 'buy-energy', [
        listingId,
        types.uint(1500) // units to buy (above threshold)
      ], consumer.address)
    ]);
    
    purchaseBlock.receipts[0].result.expectOk();
    
    // Verify listing update and price adjustment
    let listingInfo = chain.callReadOnlyFn(
      'grid_sync',
      'get-listing',
      [listingId],
      producer.address
    );
    
    const listing = listingInfo.result.expectSome();
    assertEquals(listing['units'], types.uint(500));
    assertEquals(listing['price-per-unit'], types.uint(11)); // 10% increase
  }
});

Clarinet.test({
  name: "Ensures reward points are awarded correctly",
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
    
    let purchaseBlock = chain.mineBlock([
      Tx.contractCall('grid_sync', 'buy-energy', [
        listingId,
        types.uint(50)
      ], consumer.address)
    ]);
    
    // Verify reward points
    let consumerInfo = chain.callReadOnlyFn(
      'grid_sync',
      'get-consumer-info',
      [types.principal(consumer.address)],
      consumer.address
    );
    
    let producerInfo = chain.callReadOnlyFn(
      'grid_sync',
      'get-producer-info',
      [types.principal(producer.address)],
      producer.address
    );
    
    const consumerData = consumerInfo.result.expectSome();
    const producerData = producerInfo.result.expectSome();
    
    // 5% rewards on 500 STX (50 units * 10 STX) = 25 points
    assertEquals(consumerData['reward-points'], types.uint(25));
    assertEquals(producerData['reward-points'], types.uint(25));
  }
});
