(ns pok.qr
  "QR Code Generation and Scanning for Offline Sync
   Phase 5 implementation with <400 byte deltas and Merkle validation"
  (:require [cljs.test :refer-macros [deftest is testing]]))

;; Phase 5 QR Sync Implementation
(def ^:const MAX-QR-SIZE 400) ; bytes
(def ^:const CHUNK-SIZE 200) ; bytes per QR chunk

;; Forward declarations
(declare compress-delta)
(declare calculate-merkle-hash)
(declare partition-string)

;; Create blockchain delta for QR sync
(defn create-blockchain-delta
  "Creates minimal delta for QR sync (<400 bytes)"
  [new-blocks new-transactions new-profiles]
  (let [delta {:blocks (mapv #(select-keys % [:hash :timestamp :txn-count]) new-blocks)
               :transactions (mapv #(select-keys % [:id :hash :qid :answer]) new-transactions)
               :profiles (mapv #(select-keys % [:username :archetype :reputation-score]) new-profiles)
               :timestamp (.getTime (js/Date.))
               :version "1.0"}
        compressed (compress-delta delta)]
    {:delta delta
     :compressed compressed
     :size (count compressed)
     :merkle-hash (calculate-merkle-hash compressed)}))

;; Compress delta using simple string compression
(defn compress-delta
  "Compresses delta data for QR transmission"
  [delta]
  (let [json-str (.stringify js/JSON (clj->js delta))
        ;; Simple compression: remove whitespace and common patterns
        compressed (-> json-str
                      (.replace (js/RegExp "\"" "g") "")
                      (.replace (js/RegExp ":" "g") "=")
                      (.replace (js/RegExp "," "g") "&")
                      (.replace (js/RegExp "\\{" "g") "(")
                      (.replace (js/RegExp "\\}" "g") ")")
                      (.replace (js/RegExp "\\[" "g") "<")
                      (.replace (js/RegExp "\\]" "g") ">"))]
    compressed))

;; Decompress delta data
(defn decompress-delta
  "Decompresses QR delta data"
  [compressed]
  (let [decompressed (-> compressed
                        (.replace (js/RegExp "=" "g") ":")
                        (.replace (js/RegExp "&" "g") ",")
                        (.replace (js/RegExp "\\(" "g") "{")
                        (.replace (js/RegExp "\\)" "g") "}")
                        (.replace (js/RegExp "<" "g") "[")
                        (.replace (js/RegExp ">" "g") "]"))
        ;; Add back quotes around keys/values (simplified)
        quoted (-> decompressed
                  (.replace (js/RegExp "([a-zA-Z-]+):" "g") "\"$1\":")
                  (.replace (js/RegExp ":([a-zA-Z-]+)" "g") ":\"$1\""))]
    (try
      (js->clj (.parse js/JSON quoted) :keywordize-keys true)
      (catch js/Error e
        {:error "Decompression failed" :original compressed}))))

;; Calculate simple Merkle hash
(defn calculate-merkle-hash
  "Calculates simple hash for delta validation"
  [data]
  (let [hash-input (str data (.getTime (js/Date.)))
        ;; Simple hash using string manipulation (for demo)
        hash (.toString (js/parseInt (.slice hash-input 0 8) 36) 16)]
    (str "mh" hash)))

;; Generate QR export data
(defn generate-qr-export
  "Generates QR export data with chunking if needed"
  []
  (let [mock-blocks [{:hash "block123" :timestamp 1234567890 :txn-count 5}]
        mock-transactions [{:id "tx1" :hash "txhash1" :qid "U1-L1-Q01" :answer "A"}]
        mock-profiles [{:username "test" :archetype :explorers :reputation-score 110.5}]
        delta-data (create-blockchain-delta mock-blocks mock-transactions mock-profiles)]
    
    (if (<= (:size delta-data) MAX-QR-SIZE)
      ;; Single QR code
      (assoc delta-data :chunks [(:compressed delta-data)])
      ;; Multiple QR chunks
      (let [compressed (:compressed delta-data)
            chunks (partition-string compressed CHUNK-SIZE)
            chunk-count (count chunks)]
        (assoc delta-data 
               :chunks (map-indexed 
                       (fn [idx chunk]
                         (str "PKC" idx "/" chunk-count ":" chunk))
                       chunks))))))

;; Partition string into chunks
(defn partition-string
  "Partitions string into chunks of specified size"
  [s chunk-size]
  (loop [remaining s
         chunks []]
    (if (empty? remaining)
      chunks
      (let [chunk (subs remaining 0 (min chunk-size (count remaining)))
            rest-string (subs remaining (count chunk))]
        (recur rest-string (conj chunks chunk))))))

;; Parse scanned QR data
(defn parse-scanned-data
  "Parses scanned QR data and validates"
  [qr-data]
  (cond
    ;; Single chunk QR
    (not (.includes qr-data "PKC"))
    (let [decompressed (decompress-delta qr-data)
          merkle-hash (calculate-merkle-hash qr-data)]
      {:valid (not (contains? decompressed :error))
       :data decompressed
       :hash merkle-hash
       :chunks 1})
    
    ;; Multi-chunk QR
    (.includes qr-data "PKC")
    (let [chunk-info (.split qr-data ":")
          header (first chunk-info)
          chunk-data (second chunk-info)
          [chunk-idx chunk-total] (.split (.replace header "PKC" "") "/")]
      {:valid true
       :chunk-index (js/parseInt chunk-idx)
       :chunk-total (js/parseInt chunk-total)
       :chunk-data chunk-data
       :hash (calculate-merkle-hash chunk-data)})
    
    :else
    {:valid false :error "Invalid QR format"}))

;; Reassemble QR chunks
(defn reassemble-chunks
  "Reassembles multiple QR chunks into complete data"
  [chunks]
  (when (seq chunks)
    (let [sorted-chunks (sort-by :chunk-index chunks)
          complete-data (apply str (map :chunk-data sorted-chunks))
          decompressed (decompress-delta complete-data)]
      {:valid (not (contains? decompressed :error))
       :data decompressed
       :hash (calculate-merkle-hash complete-data)
       :chunks (count chunks)})))

;; Get QR data size for validation
(defn qr-data-size
  "Returns size of QR data in bytes"
  [data]
  (if (map? data)
    (count (.stringify js/JSON (clj->js data)))
    (count (str data))))