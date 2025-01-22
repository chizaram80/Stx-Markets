;; Prediction Market Smart Contract

;; Define constants
(define-constant administrator-principal tx-sender)
(define-constant minimum-participation-stake u100000) ;; Minimum stake amount (100,000 microSTX)
(define-constant platform-commission-rate u2) ;; 2% platform fee
(define-constant maximum-market-identifier u1000000) ;; Maximum market ID

;; Define error constants in uppercase
(define-constant ERROR_UNAUTHORIZED (err u100))
(define-constant ERROR_MARKET_ALREADY_RESOLVED (err u101))
(define-constant ERROR_MARKET_NOT_RESOLVED (err u102))
(define-constant ERROR_INVALID_STAKE_AMOUNT (err u103))
(define-constant ERROR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERROR_MARKET_CANCELLED (err u105))
(define-constant ERROR_INVALID_OPTION (err u106))
(define-constant ERROR_INVALID_MARKET_ID (err u107))
(define-constant ERROR_INVALID_END_BLOCK (err u108))
(define-constant ERROR_INVALID_QUESTION (err u109))
(define-constant ERROR_INVALID_DESCRIPTION (err u110))

;; Define data maps
(define-map markets
  { market-identifier: uint }
  {
    prediction-question: (string-ascii 256),
    market-details: (string-ascii 1024),
    resolution-block-height: uint,
    winning-prediction: (optional uint),
    prediction-stake-amounts: (list 20 uint),
    resolution-status: bool,
    cancellation-status: bool
  }
)

(define-map participant-predictions
  { market-identifier: uint, participant-address: principal }
  {
    prediction-amounts: (list 20 uint)
  }
)

(define-map prediction-choices
  { market-identifier: uint }
  {
    prediction-options: (list 20 (string-ascii 64))
  }
)

;; Define variables
(define-data-var market-sequence-number uint u0)

;; Helper functions
(define-private (validate-market-identifier (identifier uint))
  (and (> identifier u0) (<= identifier maximum-market-identifier))
)

(define-private (validate-question-text (question-text (string-ascii 256)))
  (> (len question-text) u0)
)

(define-private (validate-description-text (description-text (string-ascii 1024)))
  (> (len description-text) u0)
)

(define-private (validate-resolution-block (resolution-block uint))
  (> resolution-block block-height)
)

;; Custom maximum function
(define-private (compute-maximum (first-value uint) (second-value uint))
  (if (> first-value second-value) first-value second-value)
)

;; Helper function to safely get an element from a list or return a default value
(define-private (get-list-value-or-default (source-list (list 20 uint)) (position-index uint) (fallback-value uint))
  (default-to fallback-value (element-at? source-list position-index))
)

;; Custom take function
(define-private (extract-first-n-elements (element-count uint) (source-list (list 20 uint)))
  (let ((source-length (len source-list)))
    (if (>= element-count source-length)
      source-list
      (concat (list) (unwrap-panic (slice? source-list u0 element-count)))
    )
  )
)

;; Custom drop function
(define-private (skip-first-n-elements (element-count uint) (source-list (list 20 uint)))
  (let ((source-length (len source-list)))
    (if (>= element-count source-length)
      (list)
      (concat (list) (unwrap-panic (slice? source-list element-count source-length)))
    )
  )
)

;; Helper function to update a value at a specific index in a list
(define-private (replace-list-element (source-list (list 20 uint)) (target-index uint) (replacement-value uint))
  (let ((prefix-list (extract-first-n-elements target-index source-list))
        (suffix-list (skip-first-n-elements (+ target-index u1) source-list)))
    (unwrap-panic (as-max-len? (concat (concat prefix-list (list replacement-value)) suffix-list) u20))
  )
)

;; Functions

;; Create a new prediction market
(define-public (create-prediction-market 
    (prediction-question (string-ascii 256)) 
    (market-details (string-ascii 1024)) 
    (resolution-block-height uint) 
    (available-predictions (list 20 (string-ascii 64))))
  (let
    (
      (market-identifier (var-get market-sequence-number))
      (prediction-count (len available-predictions))
      (initial-prediction-amounts (list u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0))
    )
    (asserts! (> prediction-count u1) ERROR_INVALID_OPTION)
    (asserts! (validate-question-text prediction-question) ERROR_INVALID_QUESTION)
    (asserts! (validate-description-text market-details) ERROR_INVALID_DESCRIPTION)
    (asserts! (validate-resolution-block resolution-block-height) ERROR_INVALID_END_BLOCK)
    (map-set markets
      { market-identifier: market-identifier }
      {
        prediction-question: prediction-question,
        market-details: market-details,
        resolution-block-height: resolution-block-height,
        winning-prediction: none,
        prediction-stake-amounts: initial-prediction-amounts,
        resolution-status: false,
        cancellation-status: false
      }
    )
    (map-set prediction-choices
      { market-identifier: market-identifier }
      {
        prediction-options: available-predictions
      }
    )
    (var-set market-sequence-number (+ market-identifier u1))
    (ok market-identifier)
  )
)

;; Place a stake on a prediction market
(define-public (place-prediction-stake (market-identifier uint) (prediction-index uint) (stake-amount uint))
  (let
    (
      (market-info (unwrap! (map-get? markets { market-identifier: market-identifier }) ERROR_INVALID_MARKET_ID))
      (prediction-info (unwrap! (map-get? prediction-choices { market-identifier: market-identifier }) ERROR_INVALID_MARKET_ID))
      (existing-predictions (default-to { prediction-amounts: (list u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0 u0) } 
        (map-get? participant-predictions { market-identifier: market-identifier, participant-address: tx-sender })))
    )
    (asserts! (validate-market-identifier market-identifier) ERROR_INVALID_MARKET_ID)
    (asserts! (not (get resolution-status market-info)) ERROR_MARKET_ALREADY_RESOLVED)
    (asserts! (not (get cancellation-status market-info)) ERROR_MARKET_CANCELLED)
    (asserts! (>= stake-amount minimum-participation-stake) ERROR_INVALID_STAKE_AMOUNT)
    (asserts! (<= stake-amount (stx-get-balance tx-sender)) ERROR_INSUFFICIENT_BALANCE)
    (asserts! (< prediction-index (len (get prediction-options prediction-info))) ERROR_INVALID_OPTION)
    
    (let
      (
        (current-prediction-stake (get-list-value-or-default (get prediction-stake-amounts market-info) prediction-index u0))
        (updated-prediction-stake (+ current-prediction-stake stake-amount))
        (updated-prediction-totals (replace-list-element (get prediction-stake-amounts market-info) prediction-index updated-prediction-stake))
        (current-participant-stake (get-list-value-or-default (get prediction-amounts existing-predictions) prediction-index u0))
        (updated-participant-stake (+ current-participant-stake stake-amount))
        (updated-participant-predictions (replace-list-element (get prediction-amounts existing-predictions) prediction-index updated-participant-stake))
      )
      (map-set markets { market-identifier: market-identifier }
        (merge market-info { prediction-stake-amounts: updated-prediction-totals })
      )
      
      (map-set participant-predictions
        { market-identifier: market-identifier, participant-address: tx-sender }
        { prediction-amounts: updated-participant-predictions }
      )
      
      (stx-transfer? stake-amount tx-sender (as-contract tx-sender))
    )
  )
)

;; Finalize a prediction market
(define-public (resolve-prediction-market (market-identifier uint) (winning-prediction-index uint))
  (let
    (
      (market-info (unwrap! (map-get? markets { market-identifier: market-identifier }) ERROR_INVALID_MARKET_ID))
      (prediction-info (unwrap! (map-get? prediction-choices { market-identifier: market-identifier }) ERROR_INVALID_MARKET_ID))
    )
    (asserts! (validate-market-identifier market-identifier) ERROR_INVALID_MARKET_ID)
    (asserts! (is-eq tx-sender administrator-principal) ERROR_UNAUTHORIZED)
    (asserts! (not (get resolution-status market-info)) ERROR_MARKET_ALREADY_RESOLVED)
    (asserts! (not (get cancellation-status market-info)) ERROR_MARKET_CANCELLED)
    (asserts! (>= block-height (get resolution-block-height market-info)) ERROR_UNAUTHORIZED)
    (asserts! (< winning-prediction-index (len (get prediction-options prediction-info))) ERROR_INVALID_OPTION)
    
    (map-set markets { market-identifier: market-identifier }
      (merge market-info {
        winning-prediction: (some winning-prediction-index),
        resolution-status: true
      })
    )
    (ok true)
  )
)

;; Cancel a prediction market
(define-public (cancel-prediction-market (market-identifier uint))
  (let
    (
      (market-info (unwrap! (map-get? markets { market-identifier: market-identifier }) ERROR_INVALID_MARKET_ID))
    )
    (asserts! (validate-market-identifier market-identifier) ERROR_INVALID_MARKET_ID)
    (asserts! (is-eq tx-sender administrator-principal) ERROR_UNAUTHORIZED)
    (asserts! (not (get resolution-status market-info)) ERROR_MARKET_ALREADY_RESOLVED)
    (asserts! (not (get cancellation-status market-info)) ERROR_MARKET_CANCELLED)
    
    (map-set markets { market-identifier: market-identifier }
      (merge market-info {
        cancellation-status: true
      })
    )
    (ok true)
  )
)

;; Withdraw partial stake before prediction market resolution
(define-public (withdraw-partial-stake (market-identifier uint) (prediction-index uint) (withdrawal-amount uint))
  (let
    (
      (market-info (unwrap! (map-get? markets { market-identifier: market-identifier }) ERROR_INVALID_MARKET_ID))
      (participant-prediction-data (unwrap! (map-get? participant-predictions 
        { market-identifier: market-identifier, participant-address: tx-sender }) ERROR_INVALID_MARKET_ID))
    )
    (asserts! (validate-market-identifier market-identifier) ERROR_INVALID_MARKET_ID)
    (asserts! (not (get resolution-status market-info)) ERROR_MARKET_ALREADY_RESOLVED)
    (asserts! (not (get cancellation-status market-info)) ERROR_MARKET_CANCELLED)
    (asserts! (< prediction-index (len (get prediction-amounts participant-prediction-data))) ERROR_INVALID_OPTION)
    
    (let
      (
        (current-stake-amount (get-list-value-or-default (get prediction-amounts participant-prediction-data) prediction-index u0))
      )
      (asserts! (>= current-stake-amount withdrawal-amount) ERROR_INVALID_STAKE_AMOUNT)
      
      (let
        (
          (updated-prediction-totals (replace-list-element (get prediction-stake-amounts market-info) prediction-index 
            (- (get-list-value-or-default (get prediction-stake-amounts market-info) prediction-index u0) withdrawal-amount)))
          (updated-stake-amounts (replace-list-element (get prediction-amounts participant-prediction-data) prediction-index 
            (- current-stake-amount withdrawal-amount)))
        )
        (map-set markets { market-identifier: market-identifier }
          (merge market-info { prediction-stake-amounts: updated-prediction-totals })
        )
        
        (map-set participant-predictions
          { market-identifier: market-identifier, participant-address: tx-sender }
          { prediction-amounts: updated-stake-amounts }
        )
        
        (as-contract (stx-transfer? withdrawal-amount (as-contract tx-sender) tx-sender))
      )
    )
  )
)

;; Claim winnings or refund
(define-public (claim-rewards-or-refund (market-identifier uint))
  (let
    (
      (market-info (unwrap! (map-get? markets { market-identifier: market-identifier }) ERROR_INVALID_MARKET_ID))
      (participant-prediction-data (unwrap! (map-get? participant-predictions 
        { market-identifier: market-identifier, participant-address: tx-sender }) ERROR_INVALID_MARKET_ID))
    )
    (asserts! (validate-market-identifier market-identifier) ERROR_INVALID_MARKET_ID)
    (asserts! (or (get resolution-status market-info) (get cancellation-status market-info)) ERROR_MARKET_NOT_RESOLVED)
    
    (if (get cancellation-status market-info)
      (let
        (
          (refund-amount (fold + (get prediction-amounts participant-prediction-data) u0))
        )
        (map-delete participant-predictions { market-identifier: market-identifier, participant-address: tx-sender })
        (as-contract (stx-transfer? refund-amount (as-contract tx-sender) tx-sender))
      )
      (let
        (
          (winning-prediction-index (unwrap! (get winning-prediction market-info) ERROR_MARKET_NOT_RESOLVED))
          (winning-stake-amount (get-list-value-or-default 
            (get prediction-amounts participant-prediction-data) winning-prediction-index u0))
          (total-winning-pool (get-list-value-or-default 
            (get prediction-stake-amounts market-info) winning-prediction-index u0))
          (total-market-pool (fold + (get prediction-stake-amounts market-info) u0))
          (gross-reward-amount (/ (* winning-stake-amount total-market-pool) total-winning-pool))
          (platform-fee (/ (* gross-reward-amount platform-commission-rate) u100))
          (net-reward-amount (- gross-reward-amount platform-fee))
        )
        (map-delete participant-predictions { market-identifier: market-identifier, participant-address: tx-sender })
        (as-contract (stx-transfer? net-reward-amount (as-contract tx-sender) tx-sender))
      )
    )
  )
)

;; Time-based automatic resolution
(define-public (auto-resolve-markets (max-resolution-count uint))
  (let
    (
      (total-market-count (var-get market-sequence-number))
      (initial-resolution-state { 
        current-identifier: u0, 
        total-markets: total-market-count, 
        remaining-resolutions: max-resolution-count 
      })
    )
    (ok (get current-identifier (fold process-market-resolution
                              (list initial-resolution-state)
                              initial-resolution-state)))
  )
)

(define-private (process-market-resolution
  (current-state { 
    current-identifier: uint, 
    total-markets: uint, 
    remaining-resolutions: uint 
  }) 
  (accumulator { 
    current-identifier: uint, 
    total-markets: uint, 
    remaining-resolutions: uint 
  })
)
  (let (
    (current-market-identifier (get current-identifier current-state))
    (total-market-count (get total-markets current-state))
    (remaining-resolution-count (get remaining-resolutions current-state))
  )
    (if (and (< current-market-identifier total-market-count) 
             (> remaining-resolution-count u0))
      (let
        (
          (market-info (map-get? markets { market-identifier: current-market-identifier }))
        )
        (if (is-some market-info)
          (let
            (
              (resolution-completed (match market-info 
                market-data (process-expired-market current-market-identifier market-data) 
                false))
            )
            { 
              current-identifier: (+ current-market-identifier u1),
              total-markets: total-market-count,
              remaining-resolutions: (- remaining-resolution-count u1)
            }
          )
          { 
            current-identifier: (+ current-market-identifier u1),
            total-markets: total-market-count,
            remaining-resolutions: (- remaining-resolution-count u1)
          }
        )
      )
      current-state
    )
  )
)

(define-private (process-expired-market 
    (market-identifier uint) 
    (market-data { 
      prediction-question: (string-ascii 256), 
      market-details: (string-ascii 1024), 
      resolution-block-height: uint, 
      winning-prediction: (optional uint), 
      prediction-stake-amounts: (list 20 uint), 
      resolution-status: bool, 
      cancellation-status: bool 
    }))
  (if (and (>= block-height (get resolution-block-height market-data)) 
           (not (get resolution-status market-data)) 
           (not (get cancellation-status market-data)))
    (let
      (
        (winning-prediction-index (determine-winning-prediction (get prediction-stake-amounts market-data)))
      )
      (map-set markets 
        { market-identifier: market-identifier }
        (merge market-data {
          winning-prediction: (some winning-prediction-index),
          resolution-status: true
        })
      )
      true
    )
    false
  )
)

(define-private (determine-winning-prediction (prediction-amounts (list 20 uint)))
  (let
    (
      (highest-stake-amount (fold compute-maximum prediction-amounts u0))
    )
    (unwrap-panic (index-of prediction-amounts highest-stake-amount))
  )
)

;; Read-only functions

;; Get prediction market details
(define-read-only (get-market-info (market-identifier uint))
  (map-get? markets { market-identifier: market-identifier })
)

;; Get prediction market options
(define-read-only (get-prediction-options (market-identifier uint))
  (map-get? prediction-choices { market-identifier: market-identifier })
)

;; Get participant stake details
(define-read-only (get-participant-predictions (market-identifier uint) (participant-address principal))
  (map-get? participant-predictions { market-identifier: market-identifier, participant-address: participant-address })
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)