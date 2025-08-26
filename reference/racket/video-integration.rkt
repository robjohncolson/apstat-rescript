#lang racket

;; Video Integration Module for AP Statistics PoK Blockchain
;; Extracts and maps video URLs from allUnitsData.js structure
;; Immutable design for ClojureScript porting

(provide parse-video-data
         extract-video-urls
         map-videos-to-questions
         make-video-entry
         video-entry-url
         video-entry-alt-url
         video-entry-completed
         validate-video-entry
         get-videos-for-unit-lesson
         create-video-mapping)

(require json
         "parser.rkt")

;; Video entry structure (matches allUnitsData.js format)
(struct video-entry (url alt-url completed completion-date topic-id) #:transparent)

;; Unit topic structure for organizing videos
(struct unit-topic (id name description videos quizzes current) #:transparent)

;; Mock data structure representing parsed allUnitsData.js
;; In real implementation, this would be loaded from the JavaScript file
(define sample-units-data
  `((unit-id . "unit1")
    (display-name . "Unit 1: Exploring One-Variable Data")
    (exam-weight . "15-23%")
    (topics . 
      (((id . "1-1")
        (name . "Topic 1.1")
        (description . "Introducing Statistics: What Can We Learn from Data?")
        (videos . 
          (((url . "https://apclassroom.collegeboard.org/d/708w9bpk60?sui=33,1")
            (alt-url . "https://drive.google.com/file/d/1wEbNmDM4KBUWvvoRoQIgIYKYWxG3x6Cv/view?usp=drive_link")
            (completed . #f)
            (completion-date . null))))
        (quizzes . ())
        (current . #f))
       ((id . "1-2")
        (name . "Topic 1.2") 
        (description . "The Language of Variation: Variables")
        (videos . 
          (((url . "https://apclassroom.collegeboard.org/d/o7atnjt521?sui=33,1")
            (alt-url . "https://drive.google.com/file/d/1cJ3a5DSlZ0w3vta901HVyADfQ-qKVQcD/view?usp=drive_link")
            (completed . #f)
            (completion-date . null))))
        (quizzes . ())
        (current . #f))))))

;; Create video entry from parsed data
;; Input: video hash from allUnitsData.js, topic-id
;; Output: video-entry struct
(define (make-video-entry url alt-url completed completion-date topic-id)
  (video-entry url alt-url completed completion-date topic-id))

;; Parse video data from allUnitsData.js structure
;; Input: units data (list of unit hashes)
;; Output: list of video-entry structs
(define (parse-video-data units-data)
  (flatten
    (for/list ([unit units-data])
      (let ([topics (hash-ref unit 'topics '())])
        (for/list ([topic topics])
          (let ([topic-id (hash-ref topic 'id "")]
                [videos (hash-ref topic 'videos '())])
            (for/list ([video videos])
              (make-video-entry
                (hash-ref video 'url "")
                (hash-ref video 'alt-url "")
                (hash-ref video 'completed #f)
                (hash-ref video 'completion-date #f)
                topic-id))))))))

;; Extract video URLs for specific unit and lesson
;; Input: topic-id (e.g., "1-2"), video entries list
;; Output: list of video-entry structs for that topic
(define (get-videos-for-unit-lesson topic-id video-entries)
  (filter (λ (entry) (string=? (video-entry-topic-id entry) topic-id)) video-entries))

;; Map question IDs to corresponding video URLs
;; Uses the question ID format "U1-L2-Q01" to extract unit/lesson info
;; Input: question-id, video entries list
;; Output: list of relevant video-entry structs
(define (map-videos-to-questions question-id video-entries)
  (let* ([parts (string-split question-id "-")]
         [unit-num (if (>= (length parts) 1) (substring (first parts) 1) "")]
         [lesson-num (if (>= (length parts) 2) (substring (second parts) 1) "")]
         [topic-id (string-append unit-num "-" lesson-num)])
    (get-videos-for-unit-lesson topic-id video-entries)))

;; Create comprehensive video mapping hash
;; Input: video entries list
;; Output: hash mapping topic-ids to video lists
(define (create-video-mapping video-entries)
  (let ([grouped (group-by video-entry-topic-id video-entries)])
    (make-hash (map (λ (group) (cons (video-entry-topic-id (first group)) group)) grouped))))

;; Extract all video URLs from entries (for preloading/caching)
;; Input: video entries list
;; Output: list of all unique URLs
(define (extract-video-urls video-entries)
  (remove-duplicates
    (append
      (map video-entry-url video-entries)
      (filter (λ (url) (and url (not (string=? url "")))) 
              (map video-entry-alt-url video-entries)))))

;; Validate video entry structure
(define (validate-video-entry entry)
  (and (video-entry? entry)
       (string? (video-entry-url entry))
       (> (string-length (video-entry-url entry)) 0)
       (or (not (video-entry-alt-url entry))
           (and (string? (video-entry-alt-url entry))
                (> (string-length (video-entry-alt-url entry)) 0)))
       (boolean? (video-entry-completed entry))
       (string? (video-entry-topic-id entry))))

;; Video URL validation
(define (valid-video-url? url)
  (and (string? url)
       (or (string-prefix? url "https://apclassroom.collegeboard.org/")
           (string-prefix? url "https://drive.google.com/")
           (string-prefix? url "https://www.youtube.com/")
           (string-prefix? url "https://youtu.be/"))))

;; Enhanced video entry with metadata
(define (enrich-video-entry entry)
  (let ([url (video-entry-url entry)]
        [alt-url (video-entry-alt-url entry)])
    (hash 'video-entry entry
          'primary-valid (valid-video-url? url)
          'alt-valid (and alt-url (valid-video-url? alt-url))
          'platform (cond
                      [(string-contains? url "apclassroom") "AP Classroom"]
                      [(string-contains? url "drive.google") "Google Drive"]
                      [(or (string-contains? url "youtube") (string-contains? url "youtu.be")) "YouTube"]
                      [else "Unknown"]))))

;; Filter videos by platform
(define (videos-by-platform video-entries platform)
  (filter (λ (entry)
            (let ([enriched (enrich-video-entry entry)])
              (string=? (hash-ref enriched 'platform) platform)))
          video-entries))

;; Video completion tracking utilities
(define (mark-video-completed entry)
  (struct-copy video-entry entry
               [completed #t]
               [completion-date (current-inexact-milliseconds)]))

(define (get-completion-rate video-entries)
  (if (null? video-entries)
      0.0
      (/ (length (filter video-entry-completed video-entries))
         (length video-entries))))

;; Topic progress calculation
(define (calculate-topic-progress topic-id video-entries)
  (let ([topic-videos (get-videos-for-unit-lesson topic-id video-entries)])
    (hash 'topic-id topic-id
          'total-videos (length topic-videos)
          'completed-videos (length (filter video-entry-completed topic-videos))
          'completion-rate (get-completion-rate topic-videos))))

;; Module tests
(module+ test
  (require rackunit)
  
  ;; Test video entry creation
  (define test-video (make-video-entry 
                      "https://apclassroom.collegeboard.org/d/708w9bpk60?sui=33,1"
                      "https://drive.google.com/file/d/1wEbNmDM4KBUWvvoRoQIgIYKYWxG3x6Cv/view"
                      #f
                      #f
                      "1-1"))
  
  (check-true (validate-video-entry test-video))
  (check-equal? (video-entry-topic-id test-video) "1-1")
  (check-false (video-entry-completed test-video))
  
  ;; Test video data parsing
  (define parsed-videos (parse-video-data (list sample-units-data)))
  (check-true (> (length parsed-videos) 0))
  (check-true (andmap validate-video-entry parsed-videos))
  
  ;; Test question-to-video mapping
  (define question-videos (map-videos-to-questions "U1-L2-Q01" parsed-videos))
  (check-true (>= (length question-videos) 0))
  
  ;; Test video URL extraction
  (define all-urls (extract-video-urls parsed-videos))
  (check-true (andmap string? all-urls))
  (check-true (andmap valid-video-url? all-urls))
  
  ;; Test video mapping creation
  (define video-mapping (create-video-mapping parsed-videos))
  (check-true (hash? video-mapping))
  
  ;; Test URL validation
  (check-true (valid-video-url? "https://apclassroom.collegeboard.org/d/708w9bpk60"))
  (check-true (valid-video-url? "https://drive.google.com/file/d/abc123/view"))
  (check-false (valid-video-url? "http://malicious-site.com/video"))
  
  ;; Test video enrichment
  (define enriched (enrich-video-entry test-video))
  (check-equal? (hash-ref enriched 'platform) "AP Classroom")
  (check-true (hash-ref enriched 'primary-valid))
  
  ;; Test completion tracking
  (define completed-video (mark-video-completed test-video))
  (check-true (video-entry-completed completed-video))
  (check-true (number? (video-entry-completion-date completed-video)))
  
  ;; Test platform filtering
  (define ap-videos (videos-by-platform parsed-videos "AP Classroom"))
  (check-true (andmap (λ (v) (string-contains? (video-entry-url v) "apclassroom")) ap-videos))
  
  ;; Test completion rate
  (define mixed-videos (list test-video completed-video))
  (check-equal? (get-completion-rate mixed-videos) 0.5)
  
  ;; Test topic progress
  (define progress (calculate-topic-progress "1-1" parsed-videos))
  (check-equal? (hash-ref progress 'topic-id) "1-1")
  (check-true (number? (hash-ref progress 'total-videos))))
