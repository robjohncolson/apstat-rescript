(ns pok.flow
  "Complete PoK workflow orchestration and end-to-end processing
   Phase 4 implementation with full cycle testing and validation"
  (:require [pok.state :as state]
            [pok.blockchain :as blockchain]
            [pok.reputation :as reputation]
            [re-frame.core :as rf]))

;; Generate mock peer attestations for testing
(defn generate-mock-attestations
  "Generates mock peer attestations for consensus testing with proper structure"
  [question-id submitted-answer correct-answer]
  (let [validators ["validator1" "validator2" "validator3" "validator4"]
        confidence-scores [0.8 0.9 0.7 0.85]]
    (mapv (fn [validator confidence]
            (reputation/make-attestation validator
                                       question-id
                                       submitted-answer
                                       correct-answer
                                       confidence))
          validators confidence-scores)))

;; High-level function to handle complete answer flow
(defn handle-answer-submission
  "Main function to handle answer submission, validation, and reputation update
   This is the primary integration point for the reputation system"
  [question-id answer correct-answer _user-profile]
  (let [;; Generate peer attestations using the ported reputation logic
        attestations (generate-mock-attestations question-id answer correct-answer)
        
        ;; Validate consensus using the ported validation logic
        consensus-reached (reputation/validate-quorum-consensus 
                          attestations 
                          reputation/CONSENSUS-THRESHOLD)
        
        ;; Calculate accuracy
        accuracy (if (= answer correct-answer) 1.0 0.0)
        
        ;; Mock question statistics for minority bonus calculation
        question-stats {answer 0.25 "A" 0.3 "B" 0.2 "C" 0.15 "D" 0.1}]
    
    ;; Only update reputation if consensus is reached and attestations are valid
    (when (and consensus-reached 
               (every? reputation/validate-attestation attestations))
      (rf/dispatch [:update-reputation {:accuracy accuracy
                                       :attestations attestations
                                       :question-stats question-stats
                                       :streak-count 1  ; Should be tracked in app state
                                       :time-windows 0}]))
    
    {:question-id question-id
     :answer answer
     :correct-answer correct-answer
     :accuracy accuracy
     :attestations attestations
     :consensus-reached consensus-reached
     :reputation-updated (and consensus-reached 
                             (every? reputation/validate-attestation attestations))}))

;; Phase 5 Testing: Complete 5-question cycle with reputation progression
(defn test-complete-cycle
  "Tests complete 5-question cycle with reputation progression"
  []
  (let [start-profile (state/map->Profile {:username "cycle-test" 
                                          :archetype :explorers 
                                          :pubkey "cyclekey123" 
                                          :reputation-score 100.0})
        questions ["U1-L1-Q01" "U1-L1-Q02" "U1-L2-Q01" "U1-L2-Q02" "U1-L3-Q01"]
        answers ["A" "B" "A" "C" "B"]
        correct-answers ["A" "B" "A" "C" "A"]] ; Last one wrong for testing
    
    ;; Process each question-answer pair
    (loop [q-idx 0
           current-rep 100.0
           streak 0
           total-accuracy 0
           performance-times []]
      (if (>= q-idx (count questions))
        ;; Return final results
        {:questions-completed (count questions)
         :total-accuracy total-accuracy
         :final-streak streak
         :final-reputation current-rep
         :final-archetype (state/calculate-archetype (/ total-accuracy (count questions)) 
                                                     (/ (reduce + performance-times) (count performance-times))
                                                     (count questions) 0.6)
         :all-under-50ms (every? #(< % 50) performance-times)
         :average-performance (/ (reduce + performance-times) (count performance-times))}
        ;; Process next question
        (let [question-id (nth questions q-idx)
              answer (nth answers q-idx)
              correct (nth correct-answers q-idx)
              op-start (.now js/performance)
              
              ;; Simulate answer processing with correct answer  
              _ (handle-answer-submission question-id answer correct start-profile)
              op-end (.now js/performance)
              op-time (- op-end op-start)
              
              ;; Update metrics
              is-correct (= answer correct)
              new-accuracy (if is-correct (inc total-accuracy) total-accuracy)
              new-streak (if is-correct (inc streak) 0)
              new-rep (if is-correct (+ current-rep (* 10 (inc new-streak))) current-rep)]
          
          (recur (inc q-idx) new-rep new-streak new-accuracy (conj performance-times op-time)))))))

;; Complete answer processing with reputation integration
(defn process-answer-submission
  "Processes answer submission with full reputation calculation and consensus validation
   Integrates with Re-frame state management for persistent reputation updates"
  [question-id answer profile correct-answer]
  (let [pubkey (get profile :pubkey "default-pubkey")
        privkey (get profile :privkey "default-privkey")
        txn (blockchain/create-tx question-id answer "multiple-choice" pubkey privkey)
        attestations (generate-mock-attestations question-id answer correct-answer)
        consensus (reputation/validate-quorum-consensus attestations reputation/CONSENSUS-THRESHOLD)
        accuracy (if (= answer correct-answer) 1.0 0.0)]
    
    ;; If consensus is reached, update reputation through Re-frame
    (when consensus
      (rf/dispatch [:update-reputation {:accuracy accuracy
                                       :attestations attestations
                                       :question-stats {"A" 0.3 "B" 0.4 "C" 0.2 "D" 0.1} ; Mock stats
                                       :streak-count 1  ; This should be tracked in app state
                                       :time-windows 0}]))
    
    {:transaction txn
     :attestations attestations
     :consensus-reached consensus
     :accuracy accuracy
     :reputation-updated consensus}))

;; Validate quorum consensus
(defn validate-quorum-consensus
  "Validates that quorum reaches consensus threshold"
  [attestations threshold]
  (let [total-attestations (count attestations)
        agreeing-attestations (count (filter #(= (:submitted-answer %) (:correct-answer %)) attestations))
        consensus-ratio (/ agreeing-attestations total-attestations)]
    (and (>= total-attestations 3)
         (>= consensus-ratio threshold))))

;; Validate individual attestation (delegated to reputation module)
(defn validate-attestation
  "Validates individual attestation structure - delegates to reputation module"
  [attestation]
  (reputation/validate-attestation attestation))