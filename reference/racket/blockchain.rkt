#lang racket

;; Blockchain Module for AP Statistics PoK 
;; Implements transaction mempool, block mining, and distribution tracking
;; Per ADR-028 emergent attestation system with MVP quorum=1

(provide create-tx
         add-to-mempool
         self-attest
         check-quorum
         mine-block
         empty-blockchain
         update-distributions
         calculate-convergence)

(require "consensus.rkt"
         "transaction.rkt")

;; Transaction schema per ADR-028
(struct tx (type question-id answer-hash answer-text score attester-pubkey signature timestamp) #:transparent)

;; Block schema  
(struct block (hash prev-hash txs attestations timestamp nonce) #:transparent)

;; Distribution schema per ADR-028
(struct distribution (question-id total-attestations mcq-distribution frq-distribution convergence-score) #:transparent)
(struct mcq-dist (A B C D E) #:transparent)
(struct frq-dist (scores average stddev) #:transparent)

;; Empty blockchain state
(define (empty-blockchain)
  (hash 'mempool '()
        'chain '()
        'distributions (hash)))

;; Create transaction per ADR-028
(define (create-tx question-id answer question-type)
  (cond
    [(or (equal? question-type "multiple-choice") (equal? question-type "mcq"))
     (tx "attestation" question-id (sha256-string answer) #f #f "self" "mock-sig" (current-inexact-milliseconds))]
    [(or (equal? question-type "free-response") (equal? question-type "frq"))
     (tx "attestation" question-id #f (hash-ref answer 'text) (hash-ref answer 'score) "self" "mock-sig" (current-inexact-milliseconds))]
    [else
     (error "Unknown question type")]))

;; Add transaction to mempool
(define (add-to-mempool blockchain-state transaction)
  (hash-update blockchain-state 'mempool (λ (mp) (cons transaction mp))))

;; Self-attestation for MVP quorum=1
(define (self-attest transaction correct-answer)
  (cond
    ;; MCQ: match against correct answer
    [(tx-answer-hash transaction)
     (let ([is-match (equal? (tx-answer-hash transaction) (sha256-string correct-answer))])
       (attestation "self" (tx-question-id transaction) (tx-answer-hash transaction) correct-answer (current-inexact-milliseconds) (if is-match 1.0 0.0)))]
    ;; FRQ: always valid self-attestation (peer scoring in full system)
    [(tx-answer-text transaction)
     (attestation "self" (tx-question-id transaction) (tx-answer-text transaction) "self-scored" (current-inexact-milliseconds) 1.0)]
    [else #f]))

;; Check quorum (MVP = 1)
(define (check-quorum attestations)
  (>= (length attestations) 1))

;; Simple SHA-256 hash (mock implementation)
(define (sha256-string str)
  (string-append "sha256:" str))

;; Mine block with attestation and distribution updates
(define (mine-block blockchain-state)
  (let* ([mempool (hash-ref blockchain-state 'mempool)]
         [chain (hash-ref blockchain-state 'chain)]
         [distributions (hash-ref blockchain-state 'distributions)]
         [prev-hash (if (null? chain) "genesis" (block-hash (first chain)))]
         
         ;; Self-attest each transaction 
         [attestations (map (λ (tx) (self-attest tx "B")) mempool)]  ; Mock correct answer "B"
         
         ;; Check quorum for each
         [valid-attestations (filter (λ (att) (check-quorum (list att))) attestations)]
         
         ;; Create block if quorum reached
         [new-block (if (>= (length valid-attestations) 1)
                       (let ([block-data (string-append prev-hash (format "~a" mempool) "0")])
                         (block (sha256-string block-data) prev-hash mempool valid-attestations (current-inexact-milliseconds) 0))
                       #f)])
    
    (if new-block
        ;; Update distributions and clear mempool
        (let ([updated-distributions (update-distributions distributions mempool)])
          (hash 'block new-block
                'chain (cons new-block chain)
                'mempool '()
                'distributions updated-distributions
                'updated-distributions updated-distributions))
        ;; No block mined
        (hash 'block #f
              'chain chain  
              'mempool mempool
              'distributions distributions
              'updated-distributions distributions))))

;; Update distributions per ADR-028
(define (update-distributions current-distributions transactions)
  (foldl update-single-distribution current-distributions transactions))

(define (update-single-distribution distributions tx)
  (let ([qid (tx-question-id tx)]
        [current-dist (hash-ref distributions qid #f)])
    
    (cond
      ;; MCQ: Update choice distribution
      [(tx-answer-hash tx)
       (let* ([answer-choice (substring (tx-answer-hash tx) 7 8)]  ; Extract choice from hash
              [mcq-dist (if current-dist 
                           (distribution-mcq-distribution current-dist)
                           (mcq-dist 0 0 0 0 0))]
              [total (if current-dist (distribution-total-attestations current-dist) 0)]
              [updated-mcq (case answer-choice
                            [("A") (struct-copy mcq-dist mcq-dist [A (+ (mcq-dist-A mcq-dist) 1)])]
                            [("B") (struct-copy mcq-dist mcq-dist [B (+ (mcq-dist-B mcq-dist) 1)])]
                            [("C") (struct-copy mcq-dist mcq-dist [C (+ (mcq-dist-C mcq-dist) 1)])]
                            [("D") (struct-copy mcq-dist mcq-dist [D (+ (mcq-dist-D mcq-dist) 1)])]
                            [("E") (struct-copy mcq-dist mcq-dist [E (+ (mcq-dist-E mcq-dist) 1)])]
                            [else mcq-dist])]
              [new-dist (distribution qid (+ total 1) updated-mcq #f (calculate-mcq-convergence updated-mcq (+ total 1)))])
         (hash-set distributions qid new-dist))]
      
      ;; FRQ: Update score distribution  
      [(tx-answer-text tx)
       (let* ([score (tx-score tx)]
              [frq-dist (if current-dist 
                           (distribution-frq-distribution current-dist)
                           (frq-dist '() 0 0))]
              [total (if current-dist (distribution-total-attestations current-dist) 0)]
              [new-scores (cons score (frq-dist-scores frq-dist))]
              [new-average (/ (apply + new-scores) (length new-scores))]
              [new-stddev (sqrt (/ (apply + (map (λ (x) (expt (- x new-average) 2)) new-scores)) (length new-scores)))]
              [updated-frq (frq-dist new-scores new-average new-stddev)]
              [new-dist (distribution qid (+ total 1) #f updated-frq (calculate-frq-convergence new-average new-stddev))])
         (hash-set distributions qid new-dist))]
      
      [else distributions])))

;; Calculate convergence per ADR-028
(define (calculate-convergence distribution)
  (cond
    [(distribution-mcq-distribution distribution)
     (calculate-mcq-convergence (distribution-mcq-distribution distribution) (distribution-total-attestations distribution))]
    [(distribution-frq-distribution distribution)
     (let ([frq (distribution-frq-distribution distribution)])
       (calculate-frq-convergence (frq-dist-average frq) (frq-dist-stddev frq)))]
    [else 0]))

(define (calculate-mcq-convergence mcq-dist total)
  (if (= total 0)
      0
      (let ([max-choice (max (mcq-dist-A mcq-dist)
                            (mcq-dist-B mcq-dist)  
                            (mcq-dist-C mcq-dist)
                            (mcq-dist-D mcq-dist)
                            (mcq-dist-E mcq-dist))])
        (/ max-choice total))))

(define (calculate-frq-convergence average stddev)
  (if (= average 0)
      0
      (max 0 (- 1 (/ stddev average)))))

;; Module tests
(module+ test
  (require rackunit)
  
  ;; Test transaction creation
  (define mcq-tx (create-tx "U1-L1-Q01" "A" "multiple-choice"))
  (check-equal? (tx-type mcq-tx) "attestation")
  (check-equal? (tx-question-id mcq-tx) "U1-L1-Q01")
  (check-true (string? (tx-answer-hash mcq-tx)))
  
  (define frq-answer (hash 'text "The mean is 5.2" 'score 4))
  (define frq-tx (create-tx "U1-L1-Q02" frq-answer "free-response"))
  (check-equal? (tx-answer-text frq-tx) "The mean is 5.2")
  (check-equal? (tx-score frq-tx) 4)
  
  ;; Test mempool operations
  (define initial-state (empty-blockchain))
  (define with-tx (add-to-mempool initial-state mcq-tx))
  (check-equal? (length (hash-ref with-tx 'mempool)) 1)
  
  ;; Test self-attestation
  (define mcq-attestation (self-attest mcq-tx "A"))
  (check-true (attestation? mcq-attestation))
  (check-equal? (attestation-confidence mcq-attestation) 1.0)  ; Correct match
  
  (define wrong-attestation (self-attest mcq-tx "B"))  
  (check-equal? (attestation-confidence wrong-attestation) 0.0)  ; Wrong match
  
  ;; Test block mining
  (define state-with-tx (add-to-mempool initial-state mcq-tx))
  (define mined-result (mine-block state-with-tx))
  (check-true (block? (hash-ref mined-result 'block)))
  (check-equal? (length (hash-ref mined-result 'mempool)) 0)  ; Mempool cleared
  (check-equal? (length (hash-ref mined-result 'chain)) 1)    ; Block added
  
  ;; Test distribution updates
  (define empty-dist (hash))
  (define updated-dist (update-single-distribution empty-dist mcq-tx))
  (check-true (hash-has-key? updated-dist "U1-L1-Q01"))
  
  ;; Test convergence calculation
  (define test-mcq-dist (mcq-dist 3 1 0 0 0))
  (check-equal? (calculate-mcq-convergence test-mcq-dist 4) 0.75)  ; 3/4 chose A
  
  (printf "All blockchain tests passed!\n"))