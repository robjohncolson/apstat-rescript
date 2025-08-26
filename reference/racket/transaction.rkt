#lang racket

;; Transaction Module for AP Statistics PoK Blockchain
;; Handles transaction creation, validation, and hashing
;; Immutable design for ClojureScript porting

(provide make-transaction
         transaction-id
         transaction-timestamp
         transaction-pubkey
         transaction-question-id
         transaction-answer
         transaction-hash
         hash-transaction
         validate-transaction
         make-block
         block-hash
         block-transactions
         block-proposer
         hash-block
         validate-block)

(require crypto
         json
         "profile.rkt")

;; Transaction structure for PoK submissions
(struct transaction (id timestamp pubkey question-id answer hash) #:transparent)

;; Block structure for blockchain
(struct block (hash transactions proposer timestamp difficulty) #:transparent)

;; Generate unique transaction ID
;; Input: pubkey, question-id, timestamp
;; Output: unique string ID
(define (generate-transaction-id pubkey question-id timestamp)
  (let ([input (string-append pubkey question-id (number->string timestamp))])
    (substring (bytes->hex-string (sha256 (string->utf8-bytes input))) 0 16)))

;; Create transaction hash from content
;; Input: transaction struct
;; Output: SHA-256 hash string
(define (hash-transaction txn)
  (let ([content (string-append
                  (transaction-id txn)
                  (number->string (transaction-timestamp txn))
                  (transaction-pubkey txn)
                  (transaction-question-id txn)
                  (transaction-answer txn))])
    (bytes->hex-string (sha256 (string->utf8-bytes content)))))

;; Create new transaction
;; Input: pubkey, question-id, answer
;; Output: complete transaction struct with hash
(define (make-transaction pubkey question-id answer)
  (let* ([timestamp (current-inexact-milliseconds)]
         [id (generate-transaction-id pubkey question-id timestamp)]
         [txn (transaction id timestamp pubkey question-id answer "")])
    (struct-copy transaction txn [hash (hash-transaction txn)])))

;; Transaction validation
(define (validate-transaction txn)
  (and (string? (transaction-id txn))
       (> (string-length (transaction-id txn)) 0)
       (number? (transaction-timestamp txn))
       (> (transaction-timestamp txn) 0)
       (valid-pubkey? (transaction-pubkey txn))
       (string? (transaction-question-id txn))
       (regexp-match #rx"^U[0-9]+-L[0-9]+-Q[0-9]+$" (transaction-question-id txn))
       (string? (transaction-answer txn))
       (> (string-length (transaction-answer txn)) 0)
       (string=? (transaction-hash txn) (hash-transaction txn))))

;; Block creation and hashing
(define (hash-block blk)
  (let ([transactions-hash (hash-transactions (block-transactions blk))]
        [content (string-append
                  transactions-hash
                  (block-proposer blk)
                  (number->string (block-timestamp blk))
                  (number->string (block-difficulty blk)))])
    (bytes->hex-string (sha256 (string->utf8-bytes content)))))

;; Hash list of transactions for block header
(define (hash-transactions txns)
  (let ([txn-hashes (map transaction-hash txns)])
    (bytes->hex-string (sha256 (string->utf8-bytes (string-join txn-hashes ""))))))

;; Create new block
;; Input: list of transactions, proposer pubkey, difficulty
;; Output: complete block struct with hash
(define (make-block transactions proposer difficulty)
  (let* ([timestamp (current-inexact-milliseconds)]
         [blk (block "" transactions proposer timestamp difficulty)])
    (struct-copy block blk [hash (hash-block blk)])))

;; Block validation
(define (validate-block blk)
  (and (string? (block-hash blk))
       (list? (block-transactions blk))
       (andmap validate-transaction (block-transactions blk))
       (valid-pubkey? (block-proposer blk))
       (number? (block-timestamp blk))
       (number? (block-difficulty blk))
       (> (block-difficulty blk) 0)
       (string=? (block-hash blk) (hash-block blk))))

;; Proof-of-Knowledge specific validations
(define (validate-answer-format answer question-type)
  (case question-type
    [("multiple-choice") (regexp-match #rx"^[A-E]$" answer)]
    [("free-response") (and (string? answer) (> (string-length answer) 10))]
    [("simulation") (and (string? answer) (> (string-length answer) 5))]
    [else #f]))

;; Transaction difficulty calculation based on question complexity
(define (calculate-transaction-difficulty question-id attachments)
  (let ([base-difficulty 1]
        [has-chart (hash-has-key? attachments 'chart-type)]
        [has-table (and (hash-has-key? attachments 'table) 
                        (> (length (hash-ref attachments 'table)) 0))])
    (+ base-difficulty
       (if has-chart 1 0)
       (if has-table 1 0))))

;; Transaction pool management
(define (add-to-mempool txn mempool)
  (if (validate-transaction txn)
      (cons txn mempool)
      mempool))

(define (remove-from-mempool txn-ids mempool)
  (filter (λ (txn) (not (member (transaction-id txn) txn-ids))) mempool))

;; Block reward calculation (for future reputation system)
(define (calculate-block-reward transactions)
  (let ([base-reward 10]
        [txn-count (length transactions)])
    (+ base-reward (* txn-count 2))))

;; Utility functions for blockchain operations
(define (transactions-by-pubkey txns pubkey)
  (filter (λ (txn) (string=? (transaction-pubkey txn) pubkey)) txns))

(define (transactions-by-question txns question-id)
  (filter (λ (txn) (string=? (transaction-question-id txn) question-id)) txns))

(define (transaction-size-bytes txn)
  (string-length (string-append
                  (transaction-id txn)
                  (number->string (transaction-timestamp txn))
                  (transaction-pubkey txn)
                  (transaction-question-id txn)
                  (transaction-answer txn)
                  (transaction-hash txn))))

;; Module tests
(module+ test
  (require rackunit)
  
  ;; Test transaction creation
  (define test-pubkey "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456")
  (define test-txn (make-transaction test-pubkey "U1-L2-Q01" "B"))
  
  (check-true (validate-transaction test-txn))
  (check-equal? (transaction-pubkey test-txn) test-pubkey)
  (check-equal? (transaction-question-id test-txn) "U1-L2-Q01")
  (check-equal? (transaction-answer test-txn) "B")
  (check-true (string? (transaction-hash test-txn)))
  (check-equal? (string-length (transaction-hash test-txn)) 64)
  
  ;; Test transaction hashing consistency
  (define txn-hash1 (hash-transaction test-txn))
  (define txn-hash2 (hash-transaction test-txn))
  (check-equal? txn-hash1 txn-hash2)
  
  ;; Test different transactions have different hashes
  (define test-txn2 (make-transaction test-pubkey "U1-L2-Q02" "A"))
  (check-false (string=? (transaction-hash test-txn) (transaction-hash test-txn2)))
  
  ;; Test block creation
  (define test-block (make-block (list test-txn test-txn2) test-pubkey 1))
  (check-true (validate-block test-block))
  (check-equal? (length (block-transactions test-block)) 2)
  (check-equal? (block-proposer test-block) test-pubkey)
  (check-equal? (block-difficulty test-block) 1)
  
  ;; Test block hashing
  (define block-hash1 (hash-block test-block))
  (define block-hash2 (hash-block test-block))
  (check-equal? block-hash1 block-hash2)
  (check-equal? (string-length block-hash1) 64)
  
  ;; Test validation failures
  (define invalid-txn (transaction "bad-id" 0 "invalid-pubkey" "bad-qid" "X" ""))
  (check-false (validate-transaction invalid-txn))
  
  ;; Test answer format validation
  (check-true (validate-answer-format "B" "multiple-choice"))
  (check-false (validate-answer-format "X" "multiple-choice"))
  (check-true (validate-answer-format "This is a detailed explanation" "free-response"))
  (check-false (validate-answer-format "short" "free-response"))
  
  ;; Test utility functions
  (define txns (list test-txn test-txn2))
  (check-equal? (length (transactions-by-pubkey txns test-pubkey)) 2)
  (check-equal? (length (transactions-by-question txns "U1-L2-Q01")) 1)
  (check-true (> (transaction-size-bytes test-txn) 100))
  
  ;; Test mempool operations
  (define mempool '())
  (define mempool-with-txn (add-to-mempool test-txn mempool))
  (check-equal? (length mempool-with-txn) 1)
  (define mempool-removed (remove-from-mempool (list (transaction-id test-txn)) mempool-with-txn))
  (check-equal? (length mempool-removed) 0))
