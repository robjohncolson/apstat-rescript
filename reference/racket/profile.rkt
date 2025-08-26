#lang racket

;; Profile Generation Module for AP Statistics PoK Blockchain
;; Generates user profiles with hidden pubkeys and visible archetypes
;; Immutable design for ClojureScript porting

(provide generate-profile
         profile-pubkey
         profile-username
         profile-archetype
         calculate-archetype
         hash-pubkey
         make-profile-struct
         valid-archetype?)

(require crypto
         json)

;; Profile structure - pubkey hidden from UI, only archetype/username shown
(struct profile (username archetype pubkey reputation-score) #:transparent)

;; Archetype definitions based on learning patterns and accuracy
(define ARCHETYPES
  '(aces          ; High accuracy, fast responses
    strategists   ; High accuracy, methodical
    explorers     ; Moderate accuracy, curious
    learners      ; Growing accuracy, persistent
    socials))     ; Collaborative, peer-focused

;; Generate cryptographic pubkey using SHA-256
;; Input: username string, optional salt
;; Output: hex string pubkey
(define (generate-pubkey username [salt ""])
  (let ([input-str (string-append username salt (number->string (current-inexact-milliseconds)))])
    (bytes->hex-string (sha256 (string->utf8-bytes input-str)))))

;; Hash pubkey for shorter internal references
;; Input: pubkey hex string
;; Output: shortened hash (first 8 chars)
(define (hash-pubkey pubkey)
  (substring pubkey 0 8))

;; Calculate archetype based on performance metrics
;; Input: accuracy (0.0-1.0), response-time-avg (ms), question-count, social-score
;; Output: archetype symbol
(define (calculate-archetype accuracy response-time question-count social-score)
  (cond
    [(and (>= accuracy 0.9) (< response-time 3000)) 'aces]
    [(and (>= accuracy 0.85) (< response-time 8000)) 'strategists]
    [(and (>= question-count 50) (>= social-score 0.7)) 'socials]
    [(and (>= accuracy 0.6) (>= question-count 20)) 'learners]
    [else 'explorers]))

;; Generate complete profile
;; Input: username string
;; Output: profile struct with generated pubkey and initial archetype
(define (generate-profile username)
  (let ([pubkey (generate-pubkey username)])
    (profile username
             'explorers  ; Default archetype for new users
             pubkey
             0.0)))      ; Initial reputation score

;; Profile accessors (hide pubkey from normal access)
(define (profile-visible-data p)
  (hash 'username (profile-username p)
        'archetype (profile-archetype p)
        'reputation (profile-reputation-score p)))

;; Update profile archetype based on new performance data
;; Input: profile struct, performance metrics
;; Output: updated profile struct
(define (update-profile-archetype p accuracy response-time question-count social-score)
  (struct-copy profile p
               [archetype (calculate-archetype accuracy response-time question-count social-score)]))

;; Validation predicates
(define (valid-archetype? archetype)
  (member archetype ARCHETYPES))

(define (valid-username? username)
  (and (string? username)
       (> (string-length username) 0)
       (<= (string-length username) 50)
       (regexp-match #rx"^[a-zA-Z0-9_-]+$" username)))

(define (valid-pubkey? pubkey)
  (and (string? pubkey)
       (= (string-length pubkey) 64)
       (regexp-match #rx"^[a-fA-F0-9]+$" pubkey)))

;; Profile validator
(define (validate-profile p)
  (and (valid-username? (profile-username p))
       (valid-archetype? (profile-archetype p))
       (valid-pubkey? (profile-pubkey p))
       (number? (profile-reputation-score p))))

;; Helper constructor for testing
(define (make-profile-struct username archetype pubkey reputation)
  (profile username archetype pubkey reputation))

;; Archetype display functions for UI
(define (archetype-description archetype)
  (case archetype
    [(aces) "Lightning-fast accuracy masters"]
    [(strategists) "Methodical problem solvers"]
    [(explorers) "Curious knowledge seekers"]
    [(learners) "Persistent skill builders"]
    [(socials) "Collaborative team players"]
    [else "Unknown archetype"]))

(define (archetype-emoji archetype)
  (case archetype
    [(aces) "⚡"]
    [(strategists) "🎯"]
    [(explorers) "🔍"]
    [(learners) "📈"]
    [(socials) "🤝"]
    [else "❓"]))

;; Performance metrics calculation helpers
(define (calculate-social-score collaboration-count peer-helps total-interactions)
  (if (= total-interactions 0)
      0.0
      (/ (+ collaboration-count peer-helps) total-interactions)))

(define (calculate-accuracy correct-answers total-attempts)
  (if (= total-attempts 0)
      0.0
      (/ correct-answers total-attempts)))

;; Module tests
(module+ test
  (require rackunit)
  
  ;; Test profile generation
  (define test-profile (generate-profile "alice123"))
  (check-true (validate-profile test-profile))
  (check-equal? (profile-username test-profile) "alice123")
  (check-equal? (profile-archetype test-profile) 'explorers)
  (check-true (valid-pubkey? (profile-pubkey test-profile)))
  
  ;; Test archetype calculation
  (check-equal? (calculate-archetype 0.95 2500 100 0.5) 'aces)
  (check-equal? (calculate-archetype 0.88 7000 50 0.8) 'strategists)
  (check-equal? (calculate-archetype 0.7 5000 60 0.9) 'socials)
  (check-equal? (calculate-archetype 0.65 4000 25 0.4) 'learners)
  (check-equal? (calculate-archetype 0.5 3000 5 0.2) 'explorers)
  
  ;; Test pubkey generation uniqueness
  (define profile1 (generate-profile "user1"))
  (define profile2 (generate-profile "user2"))
  (check-false (string=? (profile-pubkey profile1) (profile-pubkey profile2)))
  
  ;; Test profile update
  (define updated-profile (update-profile-archetype test-profile 0.92 2800 75 0.6))
  (check-equal? (profile-archetype updated-profile) 'aces)
  
  ;; Test validation
  (check-true (valid-username? "alice123"))
  (check-false (valid-username? ""))
  (check-false (valid-username? "user with spaces"))
  (check-true (valid-archetype? 'aces))
  (check-false (valid-archetype? 'invalid))
  
  ;; Test helper functions
  (check-equal? (calculate-social-score 5 3 20) 0.4)
  (check-equal? (calculate-accuracy 18 20) 0.9)
  (check-equal? (archetype-emoji 'aces) "⚡")
  (check-equal? (string-length (hash-pubkey (profile-pubkey test-profile))) 8))
