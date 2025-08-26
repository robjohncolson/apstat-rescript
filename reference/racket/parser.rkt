#lang racket

;; Question Parser Module for AP Statistics PoK Blockchain
;; Parses curriculum.json structure and integrates video URLs
;; Designed for immutable, functional style to ease ClojureScript porting

(provide parse-question
         parse-curriculum
         extract-attachments
         integrate-video-urls
         question-id->unit-lesson
         make-question-struct)

(require json)

;; Question structure definition
(struct question (id type prompt answer-key attachments choices videos) #:transparent)

;; Parse individual question from JSON hash
;; Input: hash table from JSON
;; Output: question struct
(define (parse-question json-hash)
  (question (hash-ref json-hash 'id "")
            (hash-ref json-hash 'type "")
            (hash-ref json-hash 'prompt "")
            (hash-ref json-hash 'answerKey "")
            (extract-attachments (hash-ref json-hash 'attachments (hash)))
            (hash-ref json-hash 'choices '())
            '())) ; videos added separately via integration

;; Extract and normalize attachments from question
;; Handles tables, charts, and other media
(define (extract-attachments attachments-hash)
  (hash 'table (hash-ref attachments-hash 'table '())
        'chart-type (hash-ref attachments-hash 'chart-type #f)
        'chart-data (hash-ref attachments-hash 'chart-data #f)
        'x-labels (hash-ref attachments-hash 'x-labels '())
        'series (hash-ref attachments-hash 'series '())
        'values (hash-ref attachments-hash 'values '())))

;; Parse entire curriculum from JSON file
;; Input: file path string
;; Output: list of question structs
(define (parse-curriculum json-file-path)
  (let ([json-data (call-with-input-file json-file-path
                     (λ (port) (read-json port)))])
    (map parse-question json-data)))

;; Extract unit and lesson from question ID (e.g., "U1-L2-Q01" -> (1 2))
;; Used for video URL mapping
(define (question-id->unit-lesson qid)
  (let ([parts (string-split qid "-")])
    (if (>= (length parts) 2)
        (list (string->number (substring (first parts) 1))  ; Remove "U" prefix
              (string->number (substring (second parts) 1))) ; Remove "L" prefix
        '())))

;; Video URL structure from allUnitsData.js
(struct video-entry (url alt-url completed completion-date) #:transparent)

;; Mock video data structure (would be loaded from allUnitsData.js in real implementation)
(define sample-video-mappings
  (hash '(1 1) (list (video-entry "https://apclassroom.collegeboard.org/d/708w9bpk60?sui=33,1"
                                   "https://drive.google.com/file/d/1wEbNmDM4KBUWvvoRoQIgIYKYWxG3x6Cv/view"
                                   #f #f))
        '(1 2) (list (video-entry "https://apclassroom.collegeboard.org/d/o7atnjt521?sui=33,1"
                                   "https://drive.google.com/file/d/1cJ3a5DSlZ0w3vta901HVyADfQ-qKVQcD/view"
                                   #f #f))))

;; Integrate video URLs into parsed questions
;; Input: question struct, video mappings hash
;; Output: updated question struct with videos
(define (integrate-video-urls q video-mappings)
  (let ([unit-lesson (question-id->unit-lesson (question-id q))])
    (struct-copy question q
                 [videos (hash-ref video-mappings unit-lesson '())])))

;; Helper to create question struct directly (for testing)
(define (make-question-struct id type prompt answer attachments choices videos)
  (question id type prompt answer attachments choices videos))

;; Module-level constants for validation
(define VALID-QUESTION-TYPES '("multiple-choice" "free-response" "simulation"))
(define VALID-CHART-TYPES '("bar" "pie" "histogram" "scatter" "line"))

;; Validation predicates
(define (valid-question-type? type)
  (member type VALID-QUESTION-TYPES))

(define (valid-chart-type? chart-type)
  (or (not chart-type)
      (member chart-type VALID-CHART-TYPES)))

;; Question validator
(define (validate-question q)
  (and (string? (question-id q))
       (not (string=? (question-id q) ""))
       (valid-question-type? (question-type q))
       (string? (question-prompt q))
       (string? (question-answer-key q))))

;; Test data and examples
(module+ test
  (require rackunit)
  
  ;; Test question parsing
  (define test-question-hash
    (hash 'id "U1-L2-Q01"
          'type "multiple-choice"
          'prompt "Which variable is categorical?"
          'answerKey "B"
          'attachments (hash 'table '(("Type" "Steel") ("Type" "Wood")))
          'choices '((hash 'key "A" 'value "Length")
                     (hash 'key "B" 'value "Type"))))
  
  (define parsed-q (parse-question test-question-hash))
  
  (check-equal? (question-id parsed-q) "U1-L2-Q01")
  (check-equal? (question-type parsed-q) "multiple-choice")
  (check-equal? (question-answer-key parsed-q) "B")
  (check-true (validate-question parsed-q))
  
  ;; Test unit-lesson extraction
  (check-equal? (question-id->unit-lesson "U1-L2-Q01") '(1 2))
  (check-equal? (question-id->unit-lesson "U3-L15-Q99") '(3 15))
  
  ;; Test video integration
  (define q-with-videos (integrate-video-urls parsed-q sample-video-mappings))
  (check-equal? (length (question-videos q-with-videos)) 1)
  
  ;; Test attachment extraction
  (define attachments (extract-attachments (hash 'table '(("A" "B")) 'chart-type "bar")))
  (check-equal? (hash-ref attachments 'chart-type) "bar")
  (check-equal? (hash-ref attachments 'table) '(("A" "B"))))
