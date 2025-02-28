;; GridSync - Decentralized Energy Trading Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-listing-not-found (err u104))
(define-constant err-invalid-reward-rate (err u105))
(define-constant err-invalid-units (err u106))
(define-constant err-listing-expired (err u107))

;; Contract status
(define-data-var contract-enabled bool true)

;; Data Variables
(define-data-var min-energy-unit uint u1)
(define-data-var platform-fee uint u1) ;; 1% fee
(define-data-var reward-rate uint u5) ;; 5% rewards
(define-data-var price-adjustment-threshold uint u1000) ;; Units threshold for price adjustment
(define-data-var listing-expiration-blocks uint u1440) ;; ~10 days at 10min blocks

;; Events
(define-map-event ProducerRegistered (producer principal))
(define-map-event ConsumerRegistered (consumer principal))
(define-map-event EnergyListed 
  (
    (listing-id uint)
    (seller principal)
    (units uint)
    (price-per-unit uint)
  )
)
(define-map-event EnergyPurchased
  (
    (listing-id uint)
    (buyer principal)
    (seller principal)
    (units uint)
    (price-per-unit uint)
  )
)

;; Data Maps
(define-map Producers principal
  {
    active: bool,
    total-energy-sold: uint,
    earnings: uint,
    reward-points: uint
  }
)

(define-map Consumers principal
  {
    active: bool,
    total-energy-bought: uint,
    spent: uint,
    reward-points: uint
  }
)

(define-map EnergyListings uint
  {
    seller: principal,
    units: uint,
    price-per-unit: uint,
    active: bool,
    last-price-adjustment: uint,
    created-at: uint
  }
)

(define-map MarketPrices uint
  {
    timestamp: uint,
    avg-price: uint,
    total-volume: uint
  }
)

(define-data-var listing-nonce uint u0)
(define-data-var market-stats-nonce uint u0)

;; Private Functions
(define-private (is-listing-valid (listing-id uint))
  (let (
    (listing (unwrap! (map-get? EnergyListings listing-id) false))
    (expiration (+ (get created-at listing) (var-get listing-expiration-blocks)))
  )
    (and
      (get active listing)
      (< block-height expiration)
    )
  )
)

;; Dynamic Pricing Functions
(define-private (calculate-dynamic-price (current-price uint) (units-sold uint))
  (let
    (
      (adjustment (if (>= units-sold (var-get price-adjustment-threshold))
        (/ (* current-price u110) u100) ;; 10% increase
        (/ (* current-price u95) u100))) ;; 5% decrease
    )
    (if (< adjustment u1) u1 adjustment)
  )
)

;; Reward Functions  
(define-private (calculate-rewards (amount uint))
  (/ (* amount (var-get reward-rate)) u100)
)

;; Producer Functions
(define-public (register-producer)
  (begin
    (asserts! (var-get contract-enabled) (err err-owner-only))
    (print (create-map-event ProducerRegistered tx-sender))
    (ok (map-set Producers tx-sender {
      active: true,
      total-energy-sold: u0,
      earnings: u0,
      reward-points: u0
    }))
  )
)

(define-public (list-energy-units (units uint) (price-per-unit uint))
  (let
    (
      (producer (unwrap! (map-get? Producers tx-sender) (err err-not-registered)))
      (listing-id (var-get listing-nonce))
    )
    (asserts! (var-get contract-enabled) (err err-owner-only))
    (asserts! (> units u0) (err err-invalid-units))
    (asserts! (> price-per-unit u0) (err err-invalid-price))
    
    (print (create-map-event EnergyListed listing-id tx-sender units price-per-unit))
    
    (map-set EnergyListings listing-id {
      seller: tx-sender,
      units: units,
      price-per-unit: price-per-unit,
      active: true,
      last-price-adjustment: block-height,
      created-at: block-height
    })
    (var-set listing-nonce (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let (
    (listing (unwrap! (map-get? EnergyListings listing-id) (err err-listing-not-found)))
  )
    (asserts! (is-eq tx-sender (get seller listing)) (err err-owner-only))
    (asserts! (get active listing) (err err-listing-not-found))
    
    (map-set EnergyListings listing-id
      (merge listing {
        active: false
      })
    )
    (ok true)
  )
)

;; Consumer Functions
(define-public (register-consumer)
  (begin
    (asserts! (var-get contract-enabled) (err err-owner-only))
    (print (create-map-event ConsumerRegistered tx-sender))
    (ok (map-set Consumers tx-sender {
      active: true,
      total-energy-bought: u0,
      spent: u0,
      reward-points: u0
    }))
  )
)

[... remaining functions unchanged ...]

;; Admin Functions
(define-public (toggle-contract-status)
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (var-set contract-enabled (not (var-get contract-enabled)))
    (ok true)
  )
)
