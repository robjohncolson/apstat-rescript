(ns pok.curriculum
  "Question Parsing and Curriculum Loading for AP Statistics PoK Blockchain
   Phase 5 implementation with Chart.js integration"
  (:require [cljs.test :refer-macros [deftest is testing]]))

;; Question record definition
(defrecord Question [id type prompt answer-key attachments choices])

;; Parse question from JSON format
(defn parse-question
  "Parses question from curriculum.json format"
  [question-data]
  (when (map? question-data)
    (map->Question {:id (get question-data "id" (:id question-data))
                   :type (get question-data "type" (:type question-data))
                   :prompt (get question-data "prompt" (:prompt question-data))
                   :answer-key (get question-data "answerKey" (:answer-key question-data))
                   :attachments (get question-data "attachments" (:attachments question-data))
                   :choices (get question-data "choices" (:choices question-data))})))

;; Validate question structure
(defn validate-question
  "Validates question structure and required fields"
  [question]
  (and (map? question)
       (string? (:id question))
       (re-matches #"U\d+-L\d+-Q\d+" (:id question))
       (string? (:type question))
       (contains? #{"multiple-choice" "free-response" "simulation"} (:type question))
       (string? (:prompt question))
       (> (count (:prompt question)) 0)))

;; Extract unit and lesson from question ID
(defn question-id->unit-lesson
  "Extracts [unit lesson] from question ID format U#-L#-Q##"
  [question-id]
  (when (string? question-id)
    (let [matches (re-matches #"U(\d+)-L(\d+)-Q\d+" question-id)]
      (when matches
        [(js/parseInt (nth matches 1))
         (js/parseInt (nth matches 2))]))))

;; Parse complete curriculum from JSON array
(defn parse-curriculum
  "Parses complete curriculum from JSON array"
  [json-array]
  (when (vector? json-array)
    (mapv parse-question json-array)))

;; Chart.js configuration creation
(defn create-chart-config
  "Creates Chart.js configuration from question attachments"
  [chart-data options]
  (let [chart-type (:chart-type chart-data)
        x-labels (:x-labels chart-data)
        series (:series chart-data)]
    {:type chart-type
     :data {:labels x-labels
            :datasets (mapv (fn [serie]
                             {:label (:name serie)
                              :data (:values serie)
                              :backgroundColor (case chart-type
                                               "pie" ["#FF6384" "#36A2EB" "#FFCE56" "#4BC0C0"]
                                               "#36A2EB")
                              :borderColor "#36A2EB"
                              :borderWidth 1})
                           series)}
     :options (merge {:responsive true
                     :maintainAspectRatio false}
                    options)}))

;; Video URL integration
(defn integrate-video-urls
  "Integrates video URLs from allUnitsData.js mapping"
  [question video-mapping]
  (let [[unit lesson] (question-id->unit-lesson (:id question))
        video-key (str "U" unit "-L" lesson)
        video-url (get video-mapping video-key)]
    (if video-url
      (assoc question :video-url video-url)
      question)))

;; Table rendering helper
(defn render-table-data
  "Prepares table data for HTML rendering"
  [table-data]
  (when (vector? table-data)
    {:headers (first table-data)
     :rows (rest table-data)
     :column-count (count (first table-data))
     :row-count (dec (count table-data))}))

;; Question filtering and search
(defn filter-questions-by-unit
  "Filters questions by unit number"
  [questions unit]
  (filter (fn [q]
            (let [[q-unit _] (question-id->unit-lesson (:id q))]
              (= q-unit unit)))
          questions))

(defn filter-questions-by-type
  "Filters questions by type"
  [questions question-type]
  (filter #(= (:type %) question-type) questions))

(defn search-questions
  "Searches questions by prompt content"
  [questions search-term]
  (let [term-lower (.toLowerCase search-term)]
    (filter #(.includes (.toLowerCase (:prompt %)) term-lower) questions)))

;; Question difficulty assessment
(defn assess-question-difficulty
  "Assesses question difficulty based on attachments and prompt length"
  [question]
  (let [base-difficulty 1
        prompt-length (count (:prompt question))
        has-chart (contains? (:attachments question) :chart-type)
        has-table (contains? (:attachments question) :table)
        has-choices (and (:choices question) (> (count (:choices question)) 4))]
    (+ base-difficulty
       (if (> prompt-length 200) 1 0)
       (if has-chart 1 0)
       (if has-table 1 0)
       (if has-choices 1 0))))

;; Statistics calculation helpers
(defn calculate-curriculum-stats
  "Calculates statistics about the curriculum"
  [questions]
  (let [total-count (count questions)
        by-type (group-by :type questions)
        by-unit (group-by #(first (question-id->unit-lesson (:id %))) questions)
        avg-difficulty (/ (reduce + (map assess-question-difficulty questions)) total-count)]
    {:total-questions total-count
     :questions-by-type (into {} (map (fn [[k v]] [k (count v)]) by-type))
     :questions-by-unit (into {} (map (fn [[k v]] [k (count v)]) by-unit))
     :average-difficulty (.toFixed avg-difficulty 2)}))

;; Mock video data for testing
(def mock-video-mapping
  {"U1-L1" "https://classroom.google.com/u/0/c/example1"
   "U1-L2" "https://drive.google.com/file/d/example2"
   "U2-L1" "https://classroom.google.com/u/0/c/example3"
   "U2-L2" "https://drive.google.com/file/d/example4"})

;; Sample questions for testing
(def sample-questions
  [{:id "U1-L1-Q01"
    :type "multiple-choice"
    :prompt "Which of the following is a categorical variable?"
    :answer-key "B"
    :choices [{:key "A" :value "Height"}
              {:key "B" :value "Eye color"}
              {:key "C" :value "Weight"}
              {:key "D" :value "Temperature"}]}
   
   {:id "U1-L2-Q01"
    :type "multiple-choice"
    :prompt "What type of chart is best for showing the distribution of a categorical variable?"
    :answer-key "A"
    :attachments {:chart-type "bar"
                  :x-labels ["Category A" "Category B" "Category C"]
                  :series [{:name "Frequency" :values [15 25 18]}]}
    :choices [{:key "A" :value "Bar chart"}
              {:key "B" :value "Histogram"}
              {:key "C" :value "Scatter plot"}
              {:key "D" :value "Line graph"}]}
   
   {:id "U2-L1-Q01"
    :type "free-response"
    :prompt "Explain the difference between a population and a sample in statistics."
    :answer-key "A population includes all members of a defined group, while a sample is a subset of the population selected for study."}])