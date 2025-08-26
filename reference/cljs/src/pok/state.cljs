(ns pok.state
  "Profile Management and Re-frame State for PoK Blockchain
   Phase 6 implementation with persistence, seedphrase, and key management"
  (:require [re-frame.core :as rf]
            [re-frame.db :as rfdb]
            [clojure.string :as str]
            [pok.reputation :as reputation]
            [pok.curriculum :as curriculum]
            [pok.blockchain :as blockchain]))

;; Top-level side effect to verify namespace loading
(js/console.log "[INIT] pok.state namespace loaded - registering events and subscriptions...")

;; Removed duplicate registration - using the main one below

(js/console.log "[OK] About to define persistence helpers...")

;; Persistence helper functions
(js/console.log "[OK] Reached start of persistence defns...")
(defn save-to-local
  "Save data to localStorage"
  [key data]
  (.setItem js/localStorage key (js/JSON.stringify (clj->js data))))

(js/console.log "[OK] Defined save-to-local")

(defn load-from-local
  "Load data from localStorage"
  [key]
  (when-let [stored (.getItem js/localStorage key)]
    (try
      (js->clj (js/JSON.parse stored) :keywordize-keys true)
      (catch js/Error _ nil))))

(js/console.log "[OK] Defined load-from-local")

(js/console.log "[OK] Defined persistence helper functions!")

;; Initialize DB after curriculum load
(js/console.log "[INIT] Registering :initialize-with-curriculum event...")
(js/console.log "[OK] About to enter try block for event registration...")
(try
  (rf/reg-event-fx
   :initialize-with-curriculum
   (fn [{:keys [db]} _]
     ;; Try to load existing state first
     (if-let [stored-pubkey (load-from-local "pok-pubkey")]
       ;; Existing profile found - stay locked until unlock
       {:db (assoc db :unlocked false)}
       ;; No existing profile - allow creation
       {:db db})))
  (js/console.log "[OK] :initialize-with-curriculum registered successfully!")
  (catch js/Error e
    (js/console.error "[ERROR] Failed to register :initialize-with-curriculum:" e)))

(js/console.log "[OK] Reached word list definition...")

;; Word list for seed generation (~100 words)
(def ^:const WORD-LIST
  ["apple" "banana" "cherry" "dog" "eagle" "forest" "guitar" "house" "island" "jungle"
   "kite" "lemon" "mountain" "night" "ocean" "piano" "queen" "river" "sunset" "tree"
   "umbrella" "valley" "water" "xray" "yellow" "zebra" "anchor" "bridge" "castle" "dragon"
   "engine" "flower" "garden" "helmet" "igloo" "jacket" "kettle" "laptop" "mirror" "needle"
   "orange" "pencil" "quartz" "rabbit" "spider" "table" "unicorn" "violin" "wizard" "xwing"
   "yacht" "zeppelin" "artifact" "butterfly" "crystal" "diamond" "elephant" "firefly" "galaxy" "harmony"
   "internet" "journey" "keyboard" "lighthouse" "melody" "notebook" "opal" "puzzle" "question" "rainbow"
   "satellite" "telescope" "universe" "volcano" "whisper" "xenon" "yogurt" "zodiac" "adventure" "brilliant"
   "compass" "discovery" "eclipse" "fountain" "glacier" "horizon" "infinity" "jewel" "knowledge" "legend"
   "mystical" "navigator" "odyssey" "phoenix" "quantum" "revolution" "starlight" "triumph" "utopia" "victory"
   "wanderer" "xfactor" "yearning" "zenith" "beacon" "courage" "destiny" "essence" "freedom" "grace"])

;; Simple hash function using ClojureScript hash
(defn simple-hash
  "Simple hash for key derivation"
  [text]
  (str (.toString (hash text) 16)))

;; Generate 4-word seedphrase
(defn generate-seedphrase
  "Generates 4-word seedphrase from word list"
  []
  (str/join " " (take 4 (shuffle WORD-LIST))))

;; Derive keys from seedphrase
(defn derive-keys
  "Derives private and public keys from seedphrase"
  [seedphrase]
  (let [privkey (simple-hash seedphrase)
        pubkey (str "pk_" (simple-hash privkey))]
    {:privkey privkey :pubkey pubkey}))

;; Profile record definition
(defrecord Profile [username archetype pubkey privkey reputation-score])

;; Archetype system constants
(def ^:const ARCHETYPES
  {:aces {:emoji "🏆" :description "High accuracy, fast responses"}
   :strategists {:emoji "🧠" :description "Thoughtful, deliberate responses"}
   :explorers {:emoji "🔍" :description "Learning and discovering"}
   :learners {:emoji "📚" :description "Steady progress and improvement"}
   :socials {:emoji "🤝" :description "Collaborative and helpful"}})

;; Derive pubkey-to-username mapping from chain
(defn derive-pubkey-map-from-chain
  "Derives pubkey->username mapping from create-user transactions in chain"
  [chain]
  (reduce (fn [acc block]
            (reduce (fn [acc2 tx]
                      (if (= (:type tx) "create-user")
                        (assoc acc2 (:pubkey tx) (:username tx))
                        acc2))
                    acc (:transactions block)))
          {} chain))

;; Calculate archetype based on performance metrics
(defn calculate-archetype
  "Calculates user archetype based on performance metrics"
  [accuracy response-time questions-answered social-score]
  (cond
    ;; Aces: High accuracy (>90%) with fast responses (<3s)
    (and (>= accuracy 0.9) (< response-time 3000) (>= questions-answered 50))
    :aces

    ;; Strategists: Good accuracy (>85%) with thoughtful responses (5-8s)
    (and (>= accuracy 0.85) (>= response-time 5000) (<= response-time 8000) (>= questions-answered 30))
    :strategists

    ;; Socials: Good collaboration score (>80%) regardless of other metrics
    (>= social-score 0.8)
    :socials

    ;; Learners: Steady progress (60-80% accuracy) with moderate engagement
    (and (>= accuracy 0.6) (<= accuracy 0.8) (>= questions-answered 20))
    :learners

    ;; Explorers: New users or those still discovering the system
    :else
    :explorers))

;; Persistence effects
(rf/reg-fx
 :save-local
 (fn [[key data]]
   (save-to-local key data)))

(rf/reg-fx
 :load-local
 (fn [key]
   (load-from-local key)))

(js/console.log "[OK] About to register Re-frame event handlers...")

;; Re-frame event handlers
(js/console.log "[INIT] Registering :initialize-db event...")
(try
  (rf/reg-event-db
   :initialize-db
   (fn [_ _]
     (js/console.log "[OK] :initialize-db event executed!")
     {:profile nil
    :curriculum []
    :current-question-index 0
    :current-question nil
    :question-index 0
    :questions curriculum/sample-questions
    :mempool []
    :chain []
    :distributions {}
    :blockchain {:blocks [] :mempool []}
    :reputation {:leaderboard [] :attestations {}}
    :ui {:modals {} :current-view :question}
    :seedphrase nil
    :privkey nil
    :pubkey nil
    :pubkey-map {}
    :unlocked false}))
  (js/console.log "[OK] :initialize-db registered successfully!")
  (catch js/Error e
    (js/console.error "[ERROR] Failed to register :initialize-db:" e)))

;; Load curriculum event  
(js/console.log "[INIT] Registering :load-curriculum event...")
(try
  (rf/reg-event-db
 :load-curriculum
 (fn [db [_ curriculum-data]]
   (assoc db
          :curriculum curriculum-data
          :current-question-index 0
          :current-question (first curriculum-data))))
  (js/console.log "[OK] :load-curriculum registered successfully!")
  (catch js/Error e
    (js/console.error "[ERROR] Failed to register :load-curriculum:" e)))

;; Generate seedphrase event
(rf/reg-event-fx
 :generate-seed
 (fn [{:keys [db]} _]
   (let [seedphrase (generate-seedphrase)
         keys (derive-keys seedphrase)]
     (js/console.log "Generated seed:" seedphrase)
     (js/console.log "Derived pubkey:" (:pubkey keys))
     {:db (assoc db
                 :seedphrase seedphrase
                 :privkey (:privkey keys)
                 :pubkey (:pubkey keys))})))

(rf/reg-event-fx
 :create-profile
 (fn [{:keys [db]} [_ username]]
   (let [;; Generate seed if none exists
         needs-seed (not (:seedphrase db))
         current-seedphrase (if needs-seed (generate-seedphrase) (:seedphrase db))
         keys (if needs-seed (derive-keys current-seedphrase) {:privkey (:privkey db) :pubkey (:pubkey db)})

         new-profile (map->Profile {:username username
                                    :archetype :explorers
                                    :pubkey (:pubkey keys)
                                    :privkey (:privkey keys)
                                    :reputation-score 100.0})

         ;; Create "create-user" transaction
         user-tx {:type "create-user"
                  :pubkey (:pubkey keys)
                  :username username
                  :timestamp (.now js/Date)
                  :attester-pubkey (:pubkey keys)
                  :signature (str (:privkey keys) "-mock-sig")}]

     (when needs-seed
       (js/console.log "Generated seed for new profile:" current-seedphrase))

     {:db (assoc db
                 :profile new-profile
                 :seedphrase current-seedphrase
                 :privkey (:privkey keys)
                 :pubkey (:pubkey keys)
                 :unlocked true)
      :dispatch [:add-to-mempool user-tx]})))

(rf/reg-event-db
 :update-archetype
 (fn [db [_ accuracy response-time questions-answered social-score]]
   (let [new-archetype (calculate-archetype accuracy response-time questions-answered social-score)]
     (assoc-in db [:profile :archetype] new-archetype))))

(rf/reg-event-db
 :update-reputation
 (fn [db [_ {:keys [accuracy attestations question-stats streak-count time-windows]
             :or {accuracy 1.0 attestations [] question-stats {} streak-count 0 time-windows 0}}]]
   (let [current-profile (:profile db)]
     (if current-profile
       ;; Use the complete reputation calculation from reputation.cljs
       (let [updated-profile (reputation/update-reputation-score
                              current-profile accuracy attestations question-stats streak-count)
             ;; Apply time decay if time-windows is provided
             final-profile (if (> time-windows 0)
                             (update updated-profile :reputation-score
                                     #(reputation/reputation-decay % (* time-windows 24)))
                             updated-profile)]
         (assoc db :profile final-profile))
       db))))

;; Submit answer event handler - creates blockchain transaction per ADR-028
(rf/reg-event-fx
 :submit-answer
 (fn [{:keys [db]} [_ question-id answer]]
   (if-not (:unlocked db)
     ;; Block submission if not unlocked
     (do
       (js/alert "Profile must be unlocked to submit answers")
       {:db db})
     ;; Continue with submission
     (let [current-profile (:profile db)
           current-question (:current-question db)
           question-type (:type current-question)

           ;; Determine question type
           current-type (cond
                          (or (:choices current-question) (= question-type "multiple-choice")) "multiple-choice"
                          (= question-type "free-response") "free-response"
                          :else "multiple-choice")]

       (println (str "Processing answer: Q=" question-id " Type=" current-type " A=" answer))

       ;; Create profile if it doesn't exist  
       (when-not current-profile
         (rf/dispatch [:create-profile "test-user"]))

       ;; Create transaction and add to mempool
       (let [tx (blockchain/create-tx question-id answer current-type (:pubkey db) (:privkey db))]
         (rf/dispatch [:add-to-mempool tx]))

       ;; PoK: No immediate reputation updates - mining handles this
       ;; Auto-advance handled in views.cljs

       {:db db}))))

;; Load next question event handler
(rf/reg-event-db
 :load-next-question
 (fn [db _]
   (let [current-index (:current-question-index db)
         curriculum (:curriculum db)
         next-index (mod (inc current-index) (count curriculum))
         next-question (nth curriculum next-index nil)]
     (assoc db
            :current-question-index next-index
            :current-question next-question))))

;; Load previous question event handler
(rf/reg-event-db
 :load-prev-question
 (fn [db _]
   (let [current-index (:current-question-index db)
         curriculum (:curriculum db)
         prev-index (mod (dec current-index) (count curriculum))
         prev-question (nth curriculum prev-index nil)]
     (assoc db
            :current-question-index prev-index
            :current-question prev-question))))

;; Add transaction to mempool with persistence
(rf/reg-event-fx
 :add-to-mempool
 (fn [{:keys [db]} [_ tx]]
   (let [updated-db (update db :mempool conj tx)]
     {:db updated-db
      :dispatch [:save-state]})))

;; Mine block from mempool with persistence (Phase 5: requires peer quorum)
(rf/reg-event-fx
 :mine-block
 (fn [{:keys [db]} _]
   (if-not (:unlocked db)
     ;; Block mining if not unlocked
     (do
       (js/alert "Profile must be unlocked to mine blocks")
       {:db db})
     ;; Continue with mining (now requires peer quorum >= 2)
     (let [mined-result (blockchain/mine-block db)]
       (if (:block mined-result)
         ;; Block mined successfully
         (do
           (js/console.log "Block mined with peer quorum:" (clj->js (:block mined-result)))
           (js/console.log "Updated distributions:" (clj->js (:updated-distributions mined-result)))

           ;; Update reputation for each transaction in the block (only after peer attestation)
           (doseq [rep-update (blockchain/extract-reputation-updates (:block mined-result))]
             (when rep-update
               (rf/dispatch [:update-reputation rep-update])))

           ;; Update database with new block and distributions
           (let [updated-db (assoc db
                                   :chain (:chain mined-result)
                                   :mempool (:mempool mined-result)
                                   :distributions (:distributions mined-result)
                                   :pubkey-map (derive-pubkey-map-from-chain (:chain mined-result)))]
             {:db updated-db
              :dispatch [:save-state]}))

         ;; No block mined (insufficient peer quorum)
         (do
           (js/console.log "Mining failed: Peer quorum not reached (need >=2 attestations)")
           {:db db}))))))

;; Re-frame subscriptions
(rf/reg-sub
 :profile-visible
 (fn [db _]
   (when-let [profile (:profile db)]
     (dissoc profile :pubkey)))) ; Hide pubkey for UI

(rf/reg-sub
 :profile-archetype-data
 (fn [db _]
   (if-let [profile (:profile db)]
     (let [archetype (:archetype profile)
           archetype-data (get ARCHETYPES archetype)]
       (merge archetype-data {:archetype archetype}))
     ;; Default archetype data when no profile
     {:emoji "🔍" 
      :archetype :explorers 
      :description "Getting started"})))

(rf/reg-sub
 :reputation-score
 (fn [db _]
   (get-in db [:profile :reputation-score] 0.0)))

(rf/reg-sub
 :blockchain-height
 (fn [db _]
   (count (get-in db [:blockchain :blocks] []))))

(rf/reg-sub
 :transaction-mempool
 (fn [db _]
   (get-in db [:blockchain :mempool] [])))

;; Debug subscription to access full db state from console
(rf/reg-sub
 :debug/app-db
 (fn [db _]
   db))

;; Curriculum subscriptions
(rf/reg-sub
 :curriculum
 (fn [db _]
   (or (:curriculum db) [])))

;; Current question subscription
(rf/reg-sub
 :current-question
 (fn [db _]
   (or (:current-question db)
       {:id "loading"
        :prompt "Loading questions..."
        :type "loading"
        :choices []})))

;; Blockchain subscriptions
(rf/reg-sub
 :mempool
 (fn [db _]
   (or (:mempool db) [])))

(rf/reg-sub
 :chain
 (fn [db _]
   (or (:chain db) [])))

(rf/reg-sub
 :distributions
 (fn [db _]
   (:distributions db)))

(rf/reg-sub
 :convergence
 (fn [db [_ qid]]
   (get-in db [:distributions qid :convergence-score] 0)))

(rf/reg-sub
 :mempool-count
 (fn [db _]
   (count (or (:mempool db) []))))

;; New subscriptions for persistence system
(rf/reg-sub
 :unlocked
 (fn [db _]
   (:unlocked db)))

(rf/reg-sub
 :pubkey-map
 (fn [db _]
   (:pubkey-map db)))

(rf/reg-sub
 :current-pubkey
 (fn [db _]
   (:pubkey db)))

;; QR Modal subscription
(rf/reg-sub
 :qr-modal-visible
 (fn [db _]
   (get-in db [:ui :modals :qr] false)))

;; Derive pubkey-to-username mapping from chain


;; Save state to localStorage
(rf/reg-event-fx
 :save-state
 (fn [{:keys [db]} _]
   (save-to-local "pok-chain" (:chain db))
   (save-to-local "pok-mempool" (:mempool db))
   (save-to-local "pok-curriculum" (:curriculum db))
   (save-to-local "pok-question-index" (:current-question-index db))
   (save-to-local "pok-pubkey" (:pubkey db))
   {:db db}))

;; Load state from localStorage
(rf/reg-event-fx
 :load-state
 (fn [{:keys [db]} _]
   (let [loaded-chain (or (load-from-local "pok-chain") [])
         loaded-mempool (or (load-from-local "pok-mempool") [])
         loaded-curriculum (or (load-from-local "pok-curriculum") [])
         loaded-index (or (load-from-local "pok-question-index") 0)
         loaded-pubkey (load-from-local "pok-pubkey")

         ;; Derive data from chain
         pubkey-map (derive-pubkey-map-from-chain loaded-chain)
         distributions (blockchain/derive-distributions-from-chain loaded-chain)
         reputation (blockchain/derive-reputation-from-chain loaded-chain)]

     (js/console.log "Loaded state - Chain:" (count loaded-chain) "blocks, Mempool:" (count loaded-mempool) "txs")

     {:db (assoc db
                 :chain loaded-chain
                 :mempool loaded-mempool
                 :curriculum loaded-curriculum
                 :current-question-index loaded-index
                 :current-question (nth loaded-curriculum loaded-index nil)
                 :pubkey loaded-pubkey
                 :pubkey-map pubkey-map
                 :distributions distributions
                 :reputation reputation)})))

;; Unlock profile with seedphrase
(rf/reg-event-fx
 :unlock-profile
 (fn [{:keys [db]} [_ seedphrase]]
   (let [keys (derive-keys seedphrase)
         stored-pubkey (load-from-local "pok-pubkey")]

     (if (and stored-pubkey (= (:pubkey keys) stored-pubkey))
       ;; Correct seedphrase - unlock and load state
       (do
         (js/console.log "Profile unlocked successfully")
         {:db (assoc db
                     :seedphrase seedphrase
                     :privkey (:privkey keys)
                     :pubkey (:pubkey keys)
                     :unlocked true)
          :dispatch [:load-state]})
       ;; Incorrect seedphrase or no stored profile
       (do
         (js/alert "Invalid seedphrase or no existing profile. Create new profile?")
         {:db db})))))

;; QR Sync Events
(rf/reg-event-db
 :show-qr
 (fn [db _]
   (assoc-in db [:ui :modals :qr] true)))

(rf/reg-event-db
 :close-qr
 (fn [db _]
   (assoc-in db [:ui :modals :qr] false)))

(rf/reg-event-fx
 :generate-qr
 (fn [{:keys [db]} _]
   (let [export-data (blockchain/export-state (:chain db) (:mempool db) (:distributions db))]
     ;; Generate QR using qrcode.js CDN
     (when js/QRCode
       (let [container (.getElementById js/document "qr-code-container")]
         (.innerHTML container "")
         (js/QRCode. container export-data #js {:width 200 :height 200})))
     {:db db})))

(rf/reg-event-fx
 :import-qr
 (fn [{:keys [db]} [_ json-str]]
   (if-not (:unlocked db)
     ;; Block import if not unlocked
     (do
       (js/alert "Profile must be unlocked to import data")
       {:db db})
     ;; Process import
     (try
       (let [imported (blockchain/import-state json-str)
             own-answers {} ;; TODO: derive from current user's transactions
             merged-chain (blockchain/merge-chain (:chain db) (:chain imported))
             merged-mempool (blockchain/merge-mempool (:mempool db) (:mempool imported))
             attested-mempool (blockchain/auto-attest-mempool merged-mempool own-answers (:pubkey db) (:privkey db))
             quorum-txs (blockchain/filter-quorum-txs attested-mempool)
             updated-distributions (blockchain/derive-distributions-from-chain merged-chain)
             updated-pubkey-map (derive-pubkey-map-from-chain merged-chain)]

         (js/console.log "Import successful:" (count (:chain imported)) "blocks," (count (:mempool imported)) "transactions")
         (js/console.log "Quorum transactions:" (count quorum-txs))

         ;; Auto-mine if any transactions meet quorum
         (let [updated-db (assoc db
                                 :chain merged-chain
                                 :mempool quorum-txs
                                 :distributions updated-distributions
                                 :pubkey-map updated-pubkey-map)]
           {:db updated-db
            :dispatch-n [[:save-state]
                         [:close-qr]
                         (when (> (count quorum-txs) 0) [:mine-block])]}))

       (catch js/Error e
         (js/alert (str "Import failed: " (.-message e)))
         {:db db})))))

;; Dev-only: Helper functions for console debugging
(defn ^:dev/after-load expose-debug-helpers! []
  (when goog.DEBUG
    ;; Helper to get subscription values without reactive context
    (set! (.-getReputationScore js/window)
          #(get-in (deref rfdb/app-db) [:profile :reputation-score] "No profile"))
    (set! (.-getProfile js/window)
          #(get (deref rfdb/app-db) :profile "No profile"))
    (set! (.-getDbPath js/window)
          (fn [path] (get-in (deref rfdb/app-db) path "Path not found")))
    (set! (.-getSeed js/window)
          #(get (deref rfdb/app-db) :seedphrase "No seed"))
    (println "[INFO] Console helpers: getReputationScore() | getProfile() | getDbPath([path]) | getSeed()")))

;; Profile persistence helpers
(defn save-profile-to-storage!
  "Saves profile to browser localStorage"
  [profile]
  (let [profile-data (dissoc profile :pubkey)] ; Don't persist pubkey
    (.setItem js/localStorage "pok-profile" (.stringify js/JSON (clj->js profile-data)))))

(defn load-profile-from-storage
  "Loads profile from browser localStorage"
  []
  (when-let [stored (.getItem js/localStorage "pok-profile")]
    (try
      (js->clj (js/JSON.parse stored) :keywordize-keys true)
      (catch js/Error _ nil))))

;; Archetype validation and description
(defn get-archetype-description
  "Gets full description for archetype"
  [archetype]
  (get ARCHETYPES archetype {:emoji "❓" :description "Unknown archetype"}))

(defn validate-profile
  "Validates profile structure"
  [profile]
  (and (map? profile)
       (string? (:username profile))
       (keyword? (:archetype profile))
       (contains? ARCHETYPES (:archetype profile))
       (string? (:pubkey profile))
       (number? (:reputation-score profile))))

;; Leaderboard subscription
(rf/reg-sub
 :leaderboard
 (fn [db _]
   (let [chain (:chain db [])
         pubkey-map (:pubkey-map db {})
         users (blockchain/derive-users chain)
         current-pubkey (:pubkey db)]
     (->> users
          (sort-by :rep >)
          (map (fn [user]
                 {:name (if (= (:pubkey user) current-pubkey)
                          "You"
                          (get pubkey-map (:pubkey user) "Anonymous"))
                  :rep (:rep user)}))))))
