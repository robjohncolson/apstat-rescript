(ns pok.reputation
  "Reputation and Peer Attestation System for PoK Blockchain
   Complete port from Racket prototype with time decay, peer validation, and minority bonuses")

;; Reputation calculation parameters (ported from Racket consensus.rkt)
(def ^:const REPUTATION-DECAY-RATE 0.05)     ; 5% decay per time window
(def ^:const TIME-WINDOW-HOURS 24)           ; 24-hour reputation windows  
(def ^:const MIN-QUORUM-SIZE 3)              ; Minimum peers for consensus
(def ^:const CONSENSUS-THRESHOLD 0.67)       ; 67% agreement required
(def ^:const MINORITY-BONUS-MULTIPLIER 1.5)  ; Bonus for minority-correct answers
(def ^:const MAX-REPUTATION-SCORE 1000.0)    ; Maximum reputation cap

;; Calculate peer validation score contribution
;; Direct port from consensus.rkt
(defn calculate-peer-score
  "Calculate peer validation score based on attestations
   Input: list of peer attestations
   Output: peer score contribution (0-50)"
  [attestations]
  (if (empty? attestations)
    0
    (let [avg-confidence (/ (reduce + (map :confidence attestations))
                           (count attestations))
          validation-count (count attestations)]
      (* avg-confidence validation-count 10))))

;; Calculate reputation gain based on accuracy, peer validation, and time decay
;; Direct port of calculate-reputation from consensus.rkt
(defn calculate-reputation-gain
  "Calculates reputation score based on accuracy, peer validations, and time decay
   Input: current-score, recent-accuracy, peer-validations, time-windows-passed
   Output: updated reputation score (0.0 to 1000.0)"
  [current-score recent-accuracy peer-validations time-windows]
  (let [accuracy-component (* recent-accuracy 100)
        peer-component (calculate-peer-score peer-validations)
        decay-factor (Math/pow (- 1 REPUTATION-DECAY-RATE) time-windows)
        base-score (* current-score decay-factor)
        new-score (+ base-score accuracy-component peer-component)]
    (min new-score MAX-REPUTATION-SCORE)))

;; Update reputation with time-based decay
;; Direct port of reputation-decay from consensus.rkt
(defn reputation-decay
  "Apply time-based decay to reputation score
   Input: current-reputation, hours-elapsed
   Output: decayed reputation score"
  [current-reputation hours-elapsed]
  (let [windows-passed (/ hours-elapsed TIME-WINDOW-HOURS)
        decay-factor (Math/pow (- 1 REPUTATION-DECAY-RATE) windows-passed)]
    (* current-reputation decay-factor)))

;; Minority bonus calculation for diverse thinking rewards
;; Direct port of minority-correct-bonus from consensus.rkt
(defn minority-correct-bonus
  "Calculate bonus multiplier for minority-correct answers
   Input: answer, question-statistics (consensus distribution)
   Output: bonus multiplier (1.0 for majority, up to 1.5 for minority-correct)"
  [answer question-stats]
  (let [answer-percentage (get question-stats answer 0.5)]
    (if (< answer-percentage 0.3)  ; Less than 30% chose this answer
      MINORITY-BONUS-MULTIPLIER
      1.0)))

;; Form attestation quorum for question validation
;; Direct port of form-attestation-quorum from consensus.rkt
(defn form-attestation-quorum
  "Form attestation quorum for question validation
   Input: question-id, available-validators (list of profiles), min-reputation
   Output: selected quorum (list of pubkeys)"
  [question-id validators min-reputation]
  (let [eligible-validators (filter #(>= (:reputation-score %) min-reputation) validators)
        required-size (max MIN-QUORUM-SIZE (Math/ceil (/ (count validators) 5)))
        shuffled-validators (shuffle eligible-validators)]
    (take (min required-size (count eligible-validators)) shuffled-validators)))

;; Create attestation for peer validation
;; Direct port of make-attestation from consensus.rkt
(defn make-attestation
  "Create a validated attestation record
   Input: validator-pubkey, question-id, submitted-answer, correct-answer, confidence (0.0-1.0)
   Output: attestation map"
  [validator-pubkey question-id submitted-answer correct-answer confidence]
  (when (and (string? validator-pubkey)
             (string? question-id)
             (re-matches #"^U[0-9]+-L[0-9]+-Q[0-9]+$" question-id)  ; Validate question ID format
             (string? submitted-answer)
             (string? correct-answer)
             (number? confidence)
             (<= 0.0 confidence 1.0))
    {:validator-pubkey validator-pubkey
     :question-id question-id
     :submitted-answer submitted-answer
     :correct-answer correct-answer
     :confidence confidence
     :timestamp (.getTime (js/Date.))
     :hash (str (.toString (js/Math.random) 36) (.getTime (js/Date.)))}))

;; Validate quorum consensus for question
;; Direct port of validate-quorum-consensus from consensus.rkt
(defn validate-quorum-consensus
  "Validate that quorum reaches consensus threshold
   Input: list of attestations, consensus threshold
   Output: boolean (true if consensus reached)"
  [attestations threshold]
  (if (< (count attestations) MIN-QUORUM-SIZE)
    false
    (let [total-attestations (count attestations)
          correct-count (count (filter #(= (:submitted-answer %) (:correct-answer %)) attestations))
          consensus-ratio (/ correct-count total-attestations)]
      (>= consensus-ratio threshold))))

;; Validate attestation structure and content
;; Direct port of validate-attestation from consensus.rkt
(defn validate-attestation
  "Validate attestation structure and content
   Input: attestation map
   Output: boolean (true if valid)"
  [attestation]
  (and (map? attestation)
       (string? (:validator-pubkey attestation))
       (string? (:question-id attestation))
       (re-matches #"^U[0-9]+-L[0-9]+-Q[0-9]+$" (:question-id attestation))
       (string? (:submitted-answer attestation))
       (string? (:correct-answer attestation))
       (number? (:timestamp attestation))
       (number? (:confidence attestation))
       (<= 0.0 (:confidence attestation) 1.0)))

;; Streak bonus calculation for consecutive correct answers
;; Port from consensus.rkt streak-bonus
(defn streak-bonus
  "Calculate bonus for consecutive correct answers
   Input: consecutive-correct count
   Output: bonus points (0-50)"
  [consecutive-correct]
  (min 50 (* consecutive-correct 2)))

;; Update reputation with comprehensive scoring
;; Direct port of update-reputation-score from consensus.rkt
(defn update-reputation-score
  "Update reputation with comprehensive scoring including bonuses
   Input: profile, accuracy, peer-attestations, question-stats, streak-count
   Output: updated profile with new reputation score"
  [profile accuracy attestations question-stats streak-count]
  (let [current-rep (:reputation-score profile)
        ;; Fix: Apply negative for wrong answers per Racket formula
        base-accuracy-score (if (> accuracy 0.5) 
                             (* accuracy 100)       ; Positive for correct 
                             (* -50 (- 1 accuracy))) ; Negative for incorrect
        peer-score (calculate-peer-score attestations)
        streak-score (streak-bonus streak-count)
        minority-bonus (if (map? question-stats)
                        (minority-correct-bonus (:submitted-answer (first attestations)) question-stats)
                        1.0)
        delta (+ (* base-accuracy-score minority-bonus) peer-score streak-score)
        total-score (+ current-rep delta)]
    
    ;; Debug logging as requested
    (js/console.log "Result:" accuracy "Current rep:" current-rep "Calculated delta:" delta "New rep:" total-score)
    
    (assoc profile :reputation-score (max 0 (min total-score MAX-REPUTATION-SCORE)))))

;; Reputation leaderboard calculation
;; Direct port of reputation-leaderboard from consensus.rkt
(defn reputation-leaderboard
  "Create sorted reputation leaderboard
   Input: list of profiles
   Output: sorted list by reputation (highest first)"
  [profiles]
  (sort-by :reputation-score > profiles))

;; Calculate reputation participation multiplier
;; Direct port of consensus-participation-multiplier from consensus.rkt
(defn consensus-participation-multiplier
  "Calculate reputation multiplier based on peer consensus participation
   Input: validator-reputation, consensus-accuracy, participation-rate
   Output: reputation multiplier (0.5 to 2.0)"
  [validator-rep consensus-accuracy participation-rate]
  (let [rep-factor (/ validator-rep MAX-REPUTATION-SCORE)
        accuracy-factor consensus-accuracy
        participation-factor participation-rate]
    (+ 0.5 (* 1.5 (/ (+ rep-factor accuracy-factor participation-factor) 3)))))