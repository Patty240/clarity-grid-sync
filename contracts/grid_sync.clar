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
(define-constant err-value-too-large (err u108))

;; Safety limits
(define-constant max-price-per-unit u1000000000) ;; 1B maximum price
(define-constant max-units u1000000) ;; 1M maximum units

;; Contract status
(define-data-var contract-enabled bool true)

[... previous data variables unchanged ...]

;; Enhanced Private Functions
(define-private (is-listing-valid (listing-id uint))
  (let (
    (listing (unwrap! (map-get? EnergyListings listing-id) false))
    (current-block block-height)
    (creation-block (get created-at listing))
    (expiration (+ creation-block (var-get listing-expiration-blocks)))
  )
    (and
      (get active listing)
      (>= expiration current-block) ;; Safe comparison
      (<= current-block expiration) ;; Double check for overflow
    )
  )
)

;; New Market Statistics Function
(define-private (update-market-stats (price-per-unit uint) (units uint))
  (let (
    (stats-id (var-get market-stats-nonce))
    (total-value (* price-per-unit units))
  )
    (map-set MarketPrices stats-id {
      timestamp: block-height,
      avg-price: price-per-unit,
      total-volume: units
    })
    (var-set market-stats-nonce (+ stats-id u1))
    true
  )
)

;; Enhanced Producer Functions
(define-public (list-energy-units (units uint) (price-per-unit uint))
  (let
    (
      (producer (unwrap! (map-get? Producers tx-sender) (err err-not-registered)))
      (listing-id (var-get listing-nonce))
    )
    (asserts! (var-get contract-enabled) (err err-owner-only))
    (asserts! (> units u0) (err err-invalid-units))
    (asserts! (<= units max-units) (err err-value-too-large))
    (asserts! (> price-per-unit u0) (err err-invalid-price))
    (asserts! (<= price-per-unit max-price-per-unit) (err err-value-too-large))
    
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

[... remaining functions unchanged ...]
