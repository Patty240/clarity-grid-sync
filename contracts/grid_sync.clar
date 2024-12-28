;; GridSync - Decentralized Energy Trading Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-registered (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-price (err u103))
(define-constant err-listing-not-found (err u104))

;; Data Variables
(define-data-var min-energy-unit uint u1)
(define-data-var platform-fee uint u1) ;; 1% fee

;; Data Maps
(define-map Producers principal
  {
    active: bool,
    total-energy-sold: uint,
    earnings: uint
  }
)

(define-map Consumers principal
  {
    active: bool,
    total-energy-bought: uint,
    spent: uint
  }
)

(define-map EnergyListings uint
  {
    seller: principal,
    units: uint,
    price-per-unit: uint,
    active: bool
  }
)

(define-data-var listing-nonce uint u0)

;; Producer Functions
(define-public (register-producer)
  (ok (map-set Producers tx-sender {
    active: true,
    total-energy-sold: u0,
    earnings: u0
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
      active: true
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
    spent: u0
  }))
)

(define-public (buy-energy (listing-id uint) (units uint))
  (let
    (
      (listing (unwrap! (map-get? EnergyListings listing-id) (err err-listing-not-found)))
      (consumer (unwrap! (map-get? Consumers tx-sender) (err err-not-registered)))
      (total-cost (* units (get price-per-unit listing)))
      (fee (/ (* total-cost (var-get platform-fee)) u100))
    )
    (asserts! (get active listing) (err err-listing-not-found))
    (asserts! (<= units (get units listing)) (err err-insufficient-balance))
    
    ;; Transfer payment
    (try! (stx-transfer? (+ total-cost fee) tx-sender contract-owner))
    (try! (stx-transfer? total-cost tx-sender (get seller listing)))
    
    ;; Update listings
    (map-set EnergyListings listing-id
      (merge listing {
        units: (- (get units listing) units),
        active: (> (- (get units listing) units) u0)
      })
    )
    
    ;; Update consumer stats
    (map-set Consumers tx-sender
      (merge consumer {
        total-energy-bought: (+ (get total-energy-bought consumer) units),
        spent: (+ (get spent consumer) total-cost)
      })
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