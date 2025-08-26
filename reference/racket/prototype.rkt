#lang racket

;; Racket prototype for PoK persistence and key management
;; Validates seed generation, key derivation, and transaction signing

(require racket/random)

;; Word list for seed generation (~100 words)
(define word-list
  '("apple" "banana" "cherry" "dog" "eagle" "forest" "guitar" "house" "island" "jungle"
    "kite" "lemon" "mountain" "night" "ocean" "piano" "queen" "river" "sunset" "tree"
    "umbrella" "valley" "water" "x-ray" "yellow" "zebra" "anchor" "bridge" "castle" "dragon"
    "engine" "flower" "garden" "helmet" "igloo" "jacket" "kettle" "laptop" "mirror" "needle"
    "orange" "pencil" "quartz" "rabbit" "spider" "table" "unicorn" "violin" "wizard" "x-wing"
    "yacht" "zeppelin" "artifact" "butterfly" "crystal" "diamond" "elephant" "firefly" "galaxy" "harmony"
    "internet" "journey" "keyboard" "lighthouse" "melody" "notebook" "opal" "puzzle" "question" "rainbow"
    "satellite" "telescope" "universe" "volcano" "whisper" "xenon" "yogurt" "zodiac" "adventure" "brilliant"
    "compass" "discovery" "eclipse" "fountain" "glacier" "horizon" "infinity" "jewel" "knowledge" "legend"
    "mystical" "navigator" "odyssey" "phoenix" "quantum" "revolution" "starlight" "triumph" "utopia" "victory"
    "wanderer" "x-factor" "yearning" "zenith" "beacon" "courage" "destiny" "essence" "freedom" "grace"))

;; Generate 4-word seedphrase
(define (generate-seed)
  (string-join (take (shuffle word-list) 4) " "))

;; Simple hash function (using Racket's equal-hash-code)
(define (simple-hash str)
  (number->string (equal-hash-code str) 16))

;; Derive keys from seed
(define (derive-keys seed)
  (let* ([privkey (simple-hash seed)]
         [pubkey (string-append "pk_" (simple-hash privkey))])
    (values privkey pubkey)))

;; Mock transaction signing
(define (sign-tx tx privkey)
  (hash-set tx 'signature (string-append privkey "-mock-sig")))

;; Create user transaction
(define (create-user-tx pubkey username)
  (hash 'type "create-user"
        'pubkey pubkey
        'username username
        'timestamp (current-inexact-milliseconds)
        'attester-pubkey pubkey))

;; Test the complete flow
(define (test-flow)
  (displayln "=== PoK Persistence Prototype Test ===")
  
  ;; Generate seed
  (define seed (generate-seed))
  (displayln (format "Generated seed: ~a" seed))
  
  ;; Derive keys
  (define-values (privkey pubkey) (derive-keys seed))
  (displayln (format "Private key: ~a" privkey))
  (displayln (format "Public key: ~a" pubkey))
  
  ;; Create user transaction
  (define user-tx (create-user-tx pubkey "test-user"))
  (displayln (format "User tx: ~a" user-tx))
  
  ;; Sign transaction
  (define signed-tx (sign-tx user-tx privkey))
  (displayln (format "Signed tx: ~a" signed-tx))
  
  ;; Test seed recovery
  (define recovered-seed "apple banana cherry dog")  ; Example
  (define-values (recovered-privkey recovered-pubkey) (derive-keys recovered-seed))
  (displayln (format "Recovery test - matches: ~a" 
                     (equal? privkey recovered-privkey)))
  
  (displayln "=== Prototype validation complete ==="))

;; Run test
(test-flow)