;; GridSync - Decentralized Energy Trading Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-listing-not-found (err u104))
(define-constant err-invalid-reward-rate (err u105))

;; Data Variables
(define-data-var min-energy-unit uint u1)
(define-data-var platform-fee uint u1) ;; 1% fee
(define-data-var reward-rate uint u5) ;; 5% rewards
(define-data-var price-adjustment-threshold uint u1000) ;; Units threshold for price adjustment

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
    last-price-adjustment: uint
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
  (ok (map-set Producers tx-sender {
    active: true,
    total-energy-sold: u0,
    earnings: u0,
    reward-points: u0
  }))
)

(define-public (list-energy-units (units uint) (price-per-unit uint))
  (let
    (
      (producer (unwrap! (map-get? Producers tx-sender) (err err-not-registered)))
      (listing-id (var-get listing-nonce))
    )
    (asserts! (> price-per-unit u0) (err err-invalid-price))
    (map-set EnergyListings listing-id {
      seller: tx-sender,
      units: units,
      price-per-unit: price-per-unit,
      active: true,
      last-price-adjustment: block-height
    })
    (var-set listing-nonce (+ listing-id u1))
    (ok listing-id)
  )
)

;; Consumer Functions
(define-public (register-consumer)
  (ok (map-set Consumers tx-sender {
    active: true,
    total-energy-bought: u0,
    spent: u0,
    reward-points: u0
  }))
)

(define-public (buy-energy (listing-id uint) (units uint))
  (let
    (
      (listing (unwrap! (map-get? EnergyListings listing-id) (err err-listing-not-found)))
      (consumer (unwrap! (map-get? Consumers tx-sender) (err err-not-registered)))
      (producer (unwrap! (map-get? Producers (get seller listing)) (err err-not-registered)))
      (total-cost (* units (get price-per-unit listing)))
      (fee (/ (* total-cost (var-get platform-fee)) u100))
      (consumer-rewards (calculate-rewards total-cost))
      (producer-rewards (calculate-rewards total-cost))
      (new-price (calculate-dynamic-price (get price-per-unit listing) units))
    )
    (asserts! (get active listing) (err err-listing-not-found))
    (asserts! (<= units (get units listing)) (err err-insufficient-balance))
    
    ;; Transfer payment
    (try! (stx-transfer? (+ total-cost fee) tx-sender contract-owner))
    (try! (stx-transfer? total-cost tx-sender (get seller listing)))
    
    ;; Update listings with dynamic pricing
    (map-set EnergyListings listing-id
      (merge listing {
        units: (- (get units listing) units),
        active: (> (- (get units listing) units) u0),
        price-per-unit: new-price,
        last-price-adjustment: block-height
      })
    )
    
    ;; Update consumer stats and rewards
    (map-set Consumers tx-sender
      (merge consumer {
        total-energy-bought: (+ (get total-energy-bought consumer) units),
        spent: (+ (get spent consumer) total-cost),
        reward-points: (+ (get reward-points consumer) consumer-rewards)
      })
    )

    ;; Update producer stats and rewards
    (map-set Producers (get seller listing)
      (merge producer {
        total-energy-sold: (+ (get total-energy-sold producer) units),
        earnings: (+ (get earnings producer) total-cost),
        reward-points: (+ (get reward-points producer) producer-rewards)
      })
    )
    
    ;; Update market statistics
    (let
      ((stats-id (var-get market-stats-nonce)))
      (map-set MarketPrices stats-id {
        timestamp: block-height,
        avg-price: new-price,
        total-volume: units
      })
      (var-set market-stats-nonce (+ stats-id u1))
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-listing (listing-id uint))
  (map-get? EnergyListings listing-id)
)

(define-read-only (get-producer-info (producer principal))
  (map-get? Producers producer)
)

(define-read-only (get-consumer-info (consumer principal))
  (map-get? Consumers consumer)
)

(define-read-only (get-market-price (stats-id uint))
  (map-get? MarketPrices stats-id)
)

;; Admin Functions
(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err err-owner-only))
    (asserts! (<= new-rate u100) (err err-invalid-reward-rate))
    (var-set reward-rate new-rate)
    (ok true)
  )
)
