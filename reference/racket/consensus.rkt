#lang racket

;; Consensus and Reputation Module for AP Statistics PoK Blockchain
;; Implements peer attestation quorums and reputation-based consensus
;; Immutable design for ClojureScript porting

(provide calculate-reputation
         update-reputation-score
         form-attestation-quorum
         validate-quorum-consensus
         reputation-time-window
         consensus-threshold
         make-attestation
         validate-attestation
         calculate-peer-score
         reputation-decay
         minority-correct-bonus)

(require "transaction.rkt"
         "profile.rkt")

;; Attestation structure for peer validation
(struct attestation (validator-pubkey question-id answer-submitted correct-answer timestamp confidence) #:transparent)

;; Reputation calculation parameters
(define REPUTATION-DECAY-RATE 0.05)  ; 5% decay per time window
(define TIME-WINDOW-HOURS 24)        ; 24-hour reputation windows
(define MIN-QUORUM-SIZE 3)           ; Minimum peers for consensus
(define CONSENSUS-THRESHOLD 0.67)    ; 67% agreement required
(define MINORITY-BONUS-MULTIPLIER 1.5) ; Bonus for minority-correct answers
(define MAX-REPUTATION-SCORE 1000.0)

;; Calculate reputation score based on accuracy, peer validation, and time
;; Input: current-score, recent-accuracy, peer-validations, time-windows-passed
;; Output: updated reputation score (0.0 to 1000.0)
(define (calculate-reputation current-score recent-accuracy peer-validations time-windows)
  (let* ([accuracy-component (* recent-accuracy 100)]
         [peer-component (calculate-peer-score peer-validations)]
         [decay-factor (expt (- 1 REPUTATION-DECAY-RATE) time-windows)]
         [base-score (* current-score decay-factor)]
         [new-score (+ base-score accuracy-component peer-component)])
    (min new-score MAX-REPUTATION-SCORE)))

;; Calculate peer validation score
;; Input: list of peer attestations
;; Output: peer score contribution (0-50)
(define (calculate-peer-score attestations)
  (if (null? attestations)
      0
      (let ([avg-confidence (/ (apply + (map attestation-confidence attestations))
                               (length attestations))]
            [validation-count (length attestations)])
        (* avg-confidence validation-count 10))))

;; Update reputation with time-based decay
;; Input: profile, hours-elapsed
;; Output: updated profile with decayed reputation
(define (reputation-decay profile hours-elapsed)
  (let ([windows-passed (/ hours-elapsed TIME-WINDOW-HOURS)]
        [current-rep (profile-reputation-score profile)])
    (struct-copy profile profile
                 [reputation-score (* current-rep (expt (- 1 REPUTATION-DECAY-RATE) windows-passed))])))

;; Bonus calculation for minority-correct answers (encourages diverse thinking)
;; Input: answer, question-statistics (consensus distribution)
;; Output: bonus multiplier (1.0 for majority, up to 1.5 for minority-correct)
(define (minority-correct-bonus answer question-stats)
  (let ([answer-percentage (hash-ref question-stats answer 0.5)])
    (if (< answer-percentage 0.3)  ; Less than 30% chose this answer
        MINORITY-BONUS-MULTIPLIER
        1.0)))

;; Form attestation quorum for question validation
;; Input: question-id, available-validators (list of profiles), min-reputation
;; Output: selected quorum (list of pubkeys)
(define (form-attestation-quorum question-id validators min-reputation)
  (let ([eligible-validators (filter (λ (p) (>= (profile-reputation-score p) min-reputation)) validators)]
        [required-size (max MIN-QUORUM-SIZE (ceiling (/ (length validators) 5)))])
    (take (shuffle eligible-validators) (min required-size (length eligible-validators)))))

;; Create attestation for peer validation
;; Input: validator-pubkey, question-id, submitted-answer, correct-answer, confidence (0.0-1.0)
;; Output: attestation struct
(define (make-attestation validator-pubkey question-id submitted-answer correct-answer confidence)
  (attestation validator-pubkey 
               question-id 
               submitted-answer 
               correct-answer 
               (current-inexact-milliseconds)
               confidence))

;; Validate attestation structure and content
(define (validate-attestation att)
  (and (valid-pubkey? (attestation-validator-pubkey att))
       (string? (attestation-question-id att))
       (regexp-match #rx"^U[0-9]+-L[0-9]+-Q[0-9]+$" (attestation-question-id att))
       (string? (attestation-answer-submitted att))
       (string? (attestation-correct-answer att))
       (number? (attestation-timestamp att))
       (number? (attestation-confidence att))
       (<= 0.0 (attestation-confidence att) 1.0)))

;; Validate quorum consensus for question
;; Input: list of attestations, consensus threshold
;; Output: boolean (true if consensus reached)
(define (validate-quorum-consensus attestations threshold)
  (if (< (length attestations) MIN-QUORUM-SIZE)
      #f
      (let* ([total-attestations (length attestations)]
             [correct-count (length (filter (λ (att) 
                                             (string=? (attestation-answer-submitted att)
                                                      (attestation-correct-answer att)))
                                           attestations))]
             [consensus-ratio (/ correct-count total-attestations)])
        (>= consensus-ratio threshold))))

;; Calculate reputation multiplier based on peer consensus participation
;; Input: validator-reputation, consensus-accuracy, participation-rate
;; Output: reputation multiplier (0.5 to 2.0)
(define (consensus-participation-multiplier validator-rep consensus-accuracy participation-rate)
  (let ([rep-factor (/ validator-rep MAX-REPUTATION-SCORE)]
        [accuracy-factor consensus-accuracy]
        [participation-factor participation-rate])
    (+ 0.5 (* 1.5 (/ (+ rep-factor accuracy-factor participation-factor) 3)))))

;; Reputation leaderboard calculation
;; Input: list of profiles
;; Output: sorted list by reputation (highest first)
(define (reputation-leaderboard profiles)
  (sort profiles > #:key profile-reputation-score))

;; Time window utilities
(define (reputation-time-window)
  TIME-WINDOW-HOURS)

(define (consensus-threshold)
  CONSENSUS-THRESHOLD)

;; Advanced reputation features
(define (calculate-trend-score historical-scores)
  (if (< (length historical-scores) 2)
      0
      (let* ([recent (take historical-scores 5)]
             [older (take (drop historical-scores 5) 5)]
             [recent-avg (/ (apply + recent) (length recent))]
             [older-avg (if (null? older) recent-avg (/ (apply + older) (length older)))])
        (- recent-avg older-avg))))

(define (streak-bonus consecutive-correct)
  (min 50 (* consecutive-correct 2)))

;; Update reputation with comprehensive scoring
;; Input: profile, accuracy, peer-attestations, question-stats, streak-count
;; Output: updated profile
(define (update-reputation-score profile accuracy attestations question-stats streak-count)
  (let* ([current-rep (profile-reputation-score profile)]
         [base-accuracy-score (* accuracy 100)]
         [peer-score (calculate-peer-score attestations)]
         [streak-score (streak-bonus streak-count)]
         [minority-bonus (if (hash? question-stats)
                            (minority-correct-bonus "answer" question-stats)
                            1.0)]
         [total-score (+ current-rep 
                        (* base-accuracy-score minority-bonus)
                        peer-score
                        streak-score)])
    (struct-copy profile profile
                 [reputation-score (min total-score MAX-REPUTATION-SCORE)])))

;; Module tests
(module+ test
  (require rackunit)
  
  ;; Test reputation calculation
  (check-true (<= 0 (calculate-reputation 100 0.8 '() 1) MAX-REPUTATION-SCORE))
  (check-true (> (calculate-reputation 100 0.9 '() 0) (calculate-reputation 100 0.7 '() 0)))
  
  ;; Test attestation creation and validation
  (define test-pubkey "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456")
  (define test-attestation (make-attestation test-pubkey "U1-L2-Q01" "B" "B" 0.9))
  (check-true (validate-attestation test-attestation))
  (check-equal? (attestation-validator-pubkey test-attestation) test-pubkey)
  (check-equal? (attestation-confidence test-attestation) 0.9)
  
  ;; Test quorum formation
  (define test-profiles (list (make-profile-struct "alice" 'aces test-pubkey 500)
                              (make-profile-struct "bob" 'strategists "b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456" 400)
                              (make-profile-struct "charlie" 'learners "c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456" 200)))
  
  (define quorum (form-attestation-quorum "U1-L2-Q01" test-profiles 300))
  (check-true (>= (length quorum) 2))
  
  ;; Test consensus validation
  (define consensus-attestations (list 
    (make-attestation test-pubkey "U1-L2-Q01" "B" "B" 0.9)
    (make-attestation "b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456" "U1-L2-Q01" "B" "B" 0.8)
    (make-attestation "c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456" "U1-L2-Q01" "A" "B" 0.7)))
  
  (check-true (validate-quorum-consensus consensus-attestations 0.6))
  (check-false (validate-quorum-consensus consensus-attestations 0.8))
  
  ;; Test reputation decay
  (define profile-before (make-profile-struct "test" 'aces test-pubkey 500))
  (define profile-after (reputation-decay profile-before 48)) ; 2 time windows
  (check-true (< (profile-reputation-score profile-after) 500))
  
  ;; Test minority bonus
  (define question-stats (hash "A" 0.7 "B" 0.2 "C" 0.1))
  (check-equal? (minority-correct-bonus "A" question-stats) 1.0)
  (check-equal? (minority-correct-bonus "B" question-stats) MINORITY-BONUS-MULTIPLIER)
  
  ;; Test peer score calculation
  (check-equal? (calculate-peer-score '()) 0)
  (check-true (> (calculate-peer-score consensus-attestations) 0))
  
  ;; Test streak bonus
  (check-equal? (streak-bonus 5) 10)
  (check-equal? (streak-bonus 30) 50) ; Should cap at 50
  
  ;; Test reputation leaderboard
  (define leaderboard (reputation-leaderboard test-profiles))
  (check-true (>= (profile-reputation-score (first leaderboard))
                  (profile-reputation-score (second leaderboard)))))
