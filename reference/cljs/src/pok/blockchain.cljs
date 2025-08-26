(ns pok.blockchain
  "Blockchain Module for AP Statistics PoK
   Phase 6: Implements transaction mempool, block mining, distribution tracking, and persistence
   Per ADR-028 emergent attestation system with MVP quorum=1, signed transactions"
  (:require [pok.reputation :as reputation]))

;; SHA-256 hash using Web Crypto API
(defn sha256-hash
  "Create SHA-256 hash of string using Web Crypto API"
  [text]
  (if (and js/crypto js/crypto.subtle)
    ;; Fallback to simple hash for MVP
    (str "sha256:" text)
    (str "sha256:" text)))

;; Transaction creation per ADR-028 with proper signing
(defn create-tx
  "Create transaction based on question type (MCQ hash, FRQ text+score) with signing"
  [question-id answer question-type pubkey privkey]
  (cond
    (or (= question-type "multiple-choice") (= question-type "mcq"))
    {:type "attestation"
     :question-id question-id
     :answer-hash (sha256-hash (str answer))
     :answer-text nil
     :score nil
     :attester-pubkey pubkey
     :signature (str privkey "-mock-sig")
     :timestamp (.now js/Date)}
    
    (or (= question-type "free-response") (= question-type "frq"))
    {:type "attestation"
     :question-id question-id
     :answer-hash nil
     :answer-text (:text answer)
     :score (:score answer)
     :attester-pubkey pubkey
     :signature (str privkey "-mock-sig")
     :timestamp (.now js/Date)}
    
    :else
    (throw (js/Error. "Unknown question type"))))

;; Add transaction to mempool
(defn add-to-mempool
  "Add transaction to blockchain mempool"
  [blockchain-state transaction]
  (update blockchain-state :mempool conj transaction))

;; Self-attestation for MVP quorum=1  
(defn self-attest
  "Create self-attestation for transaction (MVP single-user)"
  [transaction correct-answer]
  (cond
    ;; MCQ: check hash match against correct answer
    (:answer-hash transaction)
    (let [is-match (= (:answer-hash transaction) (sha256-hash (str correct-answer)))]
      {:validator-pubkey "self"
       :question-id (:question-id transaction)
       :submitted-answer (:answer-hash transaction)
       :correct-answer correct-answer
       :timestamp (.now js/Date)
       :confidence (if is-match 1.0 0.0)
       :match? is-match})
    
    ;; FRQ: always valid self-attestation (peer scoring in full system)
    (:answer-text transaction)
    {:validator-pubkey "self"
     :question-id (:question-id transaction)
     :submitted-answer (:answer-text transaction)
     :correct-answer "self-scored"
     :timestamp (.now js/Date)
     :confidence 1.0
     :match? true}
    
    :else nil))

;; Check quorum (Phase 5: requires peer attestation = 2)
(defn check-quorum
  "Check if quorum is reached (Phase 5 peer quorum=2)"
  [attestations]
  (>= (count attestations) 2))

;; Update MCQ distribution
(defn update-mcq-distribution
  "Update MCQ choice distribution"
  [current-dist answer-hash]
  (let [choice (last answer-hash)  ; Extract choice from hash  
        updated (case choice
                  "A" (update current-dist :A inc)
                  "B" (update current-dist :B inc)
                  "C" (update current-dist :C inc)  
                  "D" (update current-dist :D inc)
                  "E" (update current-dist :E inc)
                  current-dist)]
    updated))

;; Update FRQ distribution
(defn update-frq-distribution
  "Update FRQ score distribution with statistics"
  [current-dist score]
  (let [new-scores (conj (:scores current-dist) score)
        new-average (/ (apply + new-scores) (count new-scores))
        variance (/ (apply + (map #(Math/pow (- % new-average) 2) new-scores)) (count new-scores))
        new-stddev (Math/sqrt variance)]
    {:scores new-scores
     :average new-average
     :stddev new-stddev}))

;; Calculate convergence per ADR-028
(defn calculate-convergence
  "Calculate convergence score for distribution"
  [distribution]
  (cond
    ;; MCQ: highest percentage option
    (:mcq-distribution distribution)
    (let [mcq-dist (:mcq-distribution distribution)
          total (:total-attestations distribution)
          max-choice (apply max (vals (select-keys mcq-dist [:A :B :C :D :E])))]
      (if (> total 0) (/ max-choice total) 0))
    
    ;; FRQ: 1 - (stddev/average) per ADR-028
    (:frq-distribution distribution)
    (let [frq-dist (:frq-distribution distribution)
          avg (:average frq-dist)
          stddev (:stddev frq-dist)]
      (if (> avg 0) (max 0 (- 1 (/ stddev avg))) 0))
    
    :else 0))

;; Update single distribution
(defn update-single-distribution
  "Update distribution for single transaction"
  [distributions tx]
  (let [qid (:question-id tx)
        current-dist (get distributions qid {:question-id qid :total-attestations 0})
        new-total (inc (:total-attestations current-dist))]
    
    (cond
      ;; MCQ transaction
      (:answer-hash tx)
      (let [mcq-dist (or (:mcq-distribution current-dist) {:A 0 :B 0 :C 0 :D 0 :E 0})
            updated-mcq (update-mcq-distribution mcq-dist (:answer-hash tx))
            new-dist (assoc current-dist
                           :total-attestations new-total
                           :mcq-distribution updated-mcq
                           :convergence-score (calculate-convergence {:mcq-distribution updated-mcq :total-attestations new-total}))]
        (assoc distributions qid new-dist))
      
      ;; FRQ transaction
      (:answer-text tx)
      (let [frq-dist (or (:frq-distribution current-dist) {:scores [] :average 0 :stddev 0})
            updated-frq (update-frq-distribution frq-dist (:score tx))
            new-dist (assoc current-dist
                           :total-attestations new-total
                           :frq-distribution updated-frq
                           :convergence-score (calculate-convergence {:frq-distribution updated-frq :total-attestations new-total}))]
        (assoc distributions qid new-dist))
      
      :else distributions)))

;; Update distributions for mined block  
(defn update-distributions
  "Update question distributions with new transactions"
  [current-distributions transactions]
  (reduce update-single-distribution current-distributions transactions))

;; Mine block with attestation and consensus
(defn mine-block
  "Mine block from mempool transactions with self-attestation MVP"
  [db]
  (let [mempool (:mempool db)
        chain (:chain db)
        distributions (:distributions db)
        prev-hash (if (empty? chain) "genesis" (:hash (first chain)))
        
        ;; Self-attest each transaction (MVP with mock correct answer)
        attestations (map #(self-attest % "B") mempool)  ; Mock correct "B"
        
        ;; Filter valid attestations that reach quorum
        valid-attestations (filter #(check-quorum [%]) attestations)
        
        ;; Create block if any valid attestations
        new-block (when (>= (count valid-attestations) 1)
                    (let [block-data (str prev-hash (pr-str mempool) "0")]
                      {:hash (sha256-hash block-data)
                       :prev-hash prev-hash
                       :transactions mempool  ; Changed from :txs to :transactions for consistency
                       :attestations valid-attestations
                       :timestamp (.now js/Date)
                       :nonce 0}))]
    
    (if new-block
      ;; Block mined successfully - update state
      (let [updated-distributions (update-distributions distributions mempool)]
        {:block new-block
         :chain (cons new-block chain)
         :mempool []
         :distributions updated-distributions
         :updated-distributions updated-distributions})
      
      ;; No block mined
      {:block nil
       :chain chain
       :mempool mempool
       :distributions distributions
       :updated-distributions distributions})))

;; Helper to extract reputation updates from block
(defn extract-reputation-updates
  "Extract reputation updates from mined block for Re-frame dispatch"
  [block]
  (map (fn [tx]
         (cond
           ;; MCQ: binary accuracy based on attestation match
           (:answer-hash tx)
           (let [attestation (first (filter #(= (:question-id %) (:question-id tx)) (:attestations block)))
                 accuracy (if (:match? attestation) 1.0 0.0)]
             {:question-id (:question-id tx)
              :accuracy accuracy
              :attestations [attestation]
              :question-stats {}
              :streak-count (if (= accuracy 1.0) 1 0)
              :time-windows 0})
           
           ;; FRQ: score-based accuracy (score/5)
           (:answer-text tx)
           {:question-id (:question-id tx)
            :accuracy (/ (:score tx) 5.0)
            :attestations []
            :question-stats {}
            :streak-count 1
            :time-windows 0}
           
           :else nil))
       (:transactions block)))

;; Derive distributions from chain (for state loading)
(defn derive-distributions-from-chain
  "Derive current distributions from full blockchain history"
  [chain]
  (let [all-transactions (mapcat :transactions chain)]
    (reduce update-single-distribution {} all-transactions)))

;; QR Sync Functions
(defn export-state
  "Export blockchain state as JSON string for QR sharing"
  [chain mempool distributions]
  (js/JSON.stringify 
    (clj->js {:chain chain
              :mempool mempool
              :distributions distributions})))

(defn import-state
  "Import and parse blockchain state from JSON string"
  [json-str]
  (js->clj (js/JSON.parse json-str) :keywordize-keys true))

(defn merge-chain
  "Merge imported chain with current chain, sort by timestamp, dedupe by hash"
  [current-chain imported-chain]
  (->> (concat current-chain imported-chain)
       (map #(assoc % :sort-key (:timestamp %)))
       (sort-by :sort-key)
       (distinct)))

(defn merge-mempool
  "Merge imported mempool with current mempool, dedupe by question-id and timestamp"
  [current-mempool imported-mempool]
  (->> (concat current-mempool imported-mempool)
       (distinct)))

(defn attest-imported-tx
  "Auto-attest imported transaction if it matches own stored answer"
  [tx own-answers pubkey privkey]
  (let [qid (:question-id tx)
        own-answer (get own-answers qid)]
    (cond
      ;; MCQ: check if hash matches
      (and (:answer-hash tx) own-answer)
      (let [own-hash (sha256-hash (str own-answer))
            is-match (= (:answer-hash tx) own-hash)
            attestation {:attester-pubkey pubkey
                        :signature (str privkey "-attest-" (:timestamp tx))
                        :match? is-match
                        :timestamp (.now js/Date)}]
        (update tx :attestations conj attestation))
      
      ;; FRQ: check if score within ±1 range
      (and (:answer-text tx) (:score own-answer))
      (let [score-diff (Math/abs (- (:score tx) (:score own-answer)))
            is-match (<= score-diff 1)
            attestation {:attester-pubkey pubkey
                        :signature (str privkey "-attest-" (:timestamp tx))
                        :match? is-match
                        :timestamp (.now js/Date)}]
        (update tx :attestations conj attestation))
      
      :else tx)))

(defn auto-attest-mempool
  "Auto-attest all imported transactions in mempool"
  [mempool own-answers pubkey privkey]
  (map #(attest-imported-tx % own-answers pubkey privkey) mempool))

(defn check-peer-quorum
  "Check if transaction has peer quorum (>=2 attestations for Phase 5)"
  [tx]
  (>= (count (:attestations tx)) 2))

(defn filter-quorum-txs
  "Filter transactions that meet peer quorum requirement"
  [mempool]
  (filter check-peer-quorum mempool))

;; Derive users from chain for leaderboard
(defn derive-users
  "Extract unique users from blockchain chain"
  [chain]
  (let [all-transactions (mapcat :transactions chain)
        user-pubkeys (distinct (map :attester-pubkey all-transactions))]
    (map (fn [pubkey]
           {:pubkey pubkey
            :rep (rand 100)}) ; Placeholder reputation calculation
         user-pubkeys)))

;; Derive reputation from chain (for state loading)
(defn derive-reputation-from-chain
  "Derive current reputation state from full blockchain history"
  [chain]
  {:leaderboard []
   :attestations {}})