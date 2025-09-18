;; ClarinetConservatory - Premier Music Academy Platform
;; A blockchain-based platform for clarinet education management, recital performance tracking,
;; and conservatory community recognition

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))

;; Token constants
(define-constant token-name "ClarinetConservatory Sonata Token")
(define-constant token-symbol "CST")
(define-constant token-decimals u6)
(define-constant token-max-supply u65000000000) ;; 65k tokens with 6 decimals

;; Reward amounts (in micro-tokens)
(define-constant reward-lesson u2800000) ;; 2.8 CST
(define-constant reward-recital u6200000) ;; 6.2 CST
(define-constant reward-diploma u20000000) ;; 20.0 CST

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var next-recital-id uint u1)
(define-data-var next-lesson-id uint u1)

;; Token balances
(define-map token-balances principal uint)

;; Student profiles
(define-map student-profiles
  principal
  {
    academy-name: (string-ascii 22),
    study-level: (string-ascii 11), ;; "preparatory", "intermediate", "advanced", "graduate"
    lessons-completed: uint,
    recitals-performed: uint,
    total-study: uint,
    academic-score: uint, ;; 1-5
    enrollment-date: uint
  }
)

;; Conservatory recitals
(define-map conservatory-recitals
  uint
  {
    recital-title: (string-ascii 11),
    repertoire-era: (string-ascii 11), ;; "baroque", "classical", "romantic", "contemporary"
    performance-level: (string-ascii 9), ;; "beginner", "amateur", "advanced", "concert"
    duration: uint, ;; minutes
    metronome-bpm: uint,
    max-audience: uint,
    performer: principal,
    lesson-count: uint,
    artistry-rating: uint ;; average artistry
  }
)

;; Private lessons
(define-map private-lessons
  uint
  {
    recital-id: uint,
    student: principal,
    repertoire-studied: (string-ascii 11),
    lesson-duration: uint, ;; minutes
    practice-tempo: uint, ;; BPM
    technical-skill: uint, ;; 1-5
    musical-interpretation: uint, ;; 1-5
    performance-readiness: uint, ;; 1-5
    lesson-notes: (string-ascii 13),
    lesson-date: uint,
    artistic: bool
  }
)

;; Recital evaluations
(define-map recital-evaluations
  { recital-id: uint, evaluator: principal }
  {
    rating: uint, ;; 1-10
    evaluation-text: (string-ascii 13),
    performance-quality: (string-ascii 7), ;; "poor", "fair", "good", "excellent"
    evaluation-date: uint,
    recognition-votes: uint
  }
)

;; Academic diplomas
(define-map academic-diplomas
  { student: principal, diploma: (string-ascii 13) }
  {
    graduation-date: uint,
    lesson-total: uint
  }
)

;; Helper function to get or create profile
(define-private (get-or-create-profile (student principal))
  (match (map-get? student-profiles student)
    profile profile
    {
      academy-name: "",
      study-level: "preparatory",
      lessons-completed: u0,
      recitals-performed: u0,
      total-study: u0,
      academic-score: u1,
      enrollment-date: stacks-block-height
    }
  )
)

;; Token functions
(define-read-only (get-name)
  (ok token-name)
)

(define-read-only (get-symbol)
  (ok token-symbol)
)

(define-read-only (get-decimals)
  (ok token-decimals)
)

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? token-balances user)))
)

(define-private (mint-tokens (recipient principal) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances recipient)))
    (new-balance (+ current-balance amount))
    (new-total-supply (+ (var-get total-supply) amount))
  )
    (asserts! (<= new-total-supply token-max-supply) err-invalid-input)
    (map-set token-balances recipient new-balance)
    (var-set total-supply new-total-supply)
    (ok amount)
  )
)

;; Create conservatory recital
(define-public (create-recital (recital-title (string-ascii 11)) (repertoire-era (string-ascii 11)) (performance-level (string-ascii 9)) (duration uint) (metronome-bpm uint) (max-audience uint))
  (let (
    (recital-id (var-get next-recital-id))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len recital-title) u0) err-invalid-input)
    (asserts! (> duration u0) err-invalid-input)
    (asserts! (and (>= metronome-bpm u50) (<= metronome-bpm u170)) err-invalid-input)
    (asserts! (> max-audience u0) err-invalid-input)
    
    (map-set conservatory-recitals recital-id {
      recital-title: recital-title,
      repertoire-era: repertoire-era,
      performance-level: performance-level,
      duration: duration,
      metronome-bpm: metronome-bpm,
      max-audience: max-audience,
      performer: tx-sender,
      lesson-count: u0,
      artistry-rating: u0
    })
    
    ;; Update profile
    (map-set student-profiles tx-sender
      (merge profile {recitals-performed: (+ (get recitals-performed profile) u1)})
    )
    
    ;; Award recital creation tokens
    (try! (mint-tokens tx-sender reward-recital))
    
    (var-set next-recital-id (+ recital-id u1))
    (print {action: "recital-created", recital-id: recital-id, performer: tx-sender})
    (ok recital-id)
  )
)

;; Log private lesson
(define-public (log-lesson (recital-id uint) (repertoire-studied (string-ascii 11)) (lesson-duration uint) (practice-tempo uint) (technical-skill uint) (musical-interpretation uint) (performance-readiness uint) (lesson-notes (string-ascii 13)) (artistic bool))
  (let (
    (lesson-id (var-get next-lesson-id))
    (recital (unwrap! (map-get? conservatory-recitals recital-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> lesson-duration u0) err-invalid-input)
    (asserts! (and (>= practice-tempo u35) (<= practice-tempo u190)) err-invalid-input)
    (asserts! (and (>= technical-skill u1) (<= technical-skill u5)) err-invalid-input)
    (asserts! (and (>= musical-interpretation u1) (<= musical-interpretation u5)) err-invalid-input)
    (asserts! (and (>= performance-readiness u1) (<= performance-readiness u5)) err-invalid-input)
    
    (map-set private-lessons lesson-id {
      recital-id: recital-id,
      student: tx-sender,
      repertoire-studied: repertoire-studied,
      lesson-duration: lesson-duration,
      practice-tempo: practice-tempo,
      technical-skill: technical-skill,
      musical-interpretation: musical-interpretation,
      performance-readiness: performance-readiness,
      lesson-notes: lesson-notes,
      lesson-date: stacks-block-height,
      artistic: artistic
    })
    
    ;; Update recital stats if artistic
    (if artistic
      (let (
        (new-lesson-count (+ (get lesson-count recital) u1))
        (current-artistry (* (get artistry-rating recital) (get lesson-count recital)))
        (artistry-value (/ (+ technical-skill musical-interpretation performance-readiness) u3))
        (new-artistry-rating (/ (+ current-artistry artistry-value) new-lesson-count))
      )
        (map-set conservatory-recitals recital-id
          (merge recital {
            lesson-count: new-lesson-count,
            artistry-rating: new-artistry-rating
          })
        )
        true
      )
      true
    )
    
    ;; Update profile
    (if artistic
      (begin
        (map-set student-profiles tx-sender
          (merge profile {
            lessons-completed: (+ (get lessons-completed profile) u1),
            total-study: (+ (get total-study profile) (/ lesson-duration u60)),
            academic-score: (+ (get academic-score profile) (/ technical-skill u20))
          })
        )
        (try! (mint-tokens tx-sender reward-lesson))
        true
      )
      (begin
        (try! (mint-tokens tx-sender (/ reward-lesson u7)))
        true
      )
    )
    
    (var-set next-lesson-id (+ lesson-id u1))
    (print {action: "lesson-logged", lesson-id: lesson-id, recital-id: recital-id})
    (ok lesson-id)
  )
)

;; Write recital evaluation
(define-public (write-evaluation (recital-id uint) (rating uint) (evaluation-text (string-ascii 13)) (performance-quality (string-ascii 7)))
  (let (
    (recital (unwrap! (map-get? conservatory-recitals recital-id) err-not-found))
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (and (>= rating u1) (<= rating u10)) err-invalid-input)
    (asserts! (> (len evaluation-text) u0) err-invalid-input)
    (asserts! (is-none (map-get? recital-evaluations {recital-id: recital-id, evaluator: tx-sender})) err-already-exists)
    
    (map-set recital-evaluations {recital-id: recital-id, evaluator: tx-sender} {
      rating: rating,
      evaluation-text: evaluation-text,
      performance-quality: performance-quality,
      evaluation-date: stacks-block-height,
      recognition-votes: u0
    })
    
    (print {action: "evaluation-written", recital-id: recital-id, evaluator: tx-sender})
    (ok true)
  )
)

;; Vote recognition for evaluation
(define-public (vote-recognition (recital-id uint) (evaluator principal))
  (let (
    (evaluation (unwrap! (map-get? recital-evaluations {recital-id: recital-id, evaluator: evaluator}) err-not-found))
  )
    (asserts! (not (is-eq tx-sender evaluator)) err-unauthorized)
    
    (map-set recital-evaluations {recital-id: recital-id, evaluator: evaluator}
      (merge evaluation {recognition-votes: (+ (get recognition-votes evaluation) u1)})
    )
    
    (print {action: "evaluation-recognized", recital-id: recital-id, evaluator: evaluator})
    (ok true)
  )
)

;; Update study level
(define-public (update-study-level (new-study-level (string-ascii 11)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-study-level) u0) err-invalid-input)
    
    (map-set student-profiles tx-sender (merge profile {study-level: new-study-level}))
    
    (print {action: "study-level-updated", student: tx-sender, level: new-study-level})
    (ok true)
  )
)

;; Claim diploma
(define-public (claim-diploma (diploma (string-ascii 13)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (is-none (map-get? academic-diplomas {student: tx-sender, diploma: diploma})) err-already-exists)
    
    ;; Check diploma requirements
    (let (
      (diploma-earned
        (if (is-eq diploma "bachelor-music") (>= (get lessons-completed profile) u90)
        (if (is-eq diploma "master-arts") (>= (get recitals-performed profile) u8)
        false)))
    )
      (asserts! diploma-earned err-unauthorized)
      
      ;; Record diploma
      (map-set academic-diplomas {student: tx-sender, diploma: diploma} {
        graduation-date: stacks-block-height,
        lesson-total: (get lessons-completed profile)
      })
      
      ;; Award diploma tokens
      (try! (mint-tokens tx-sender reward-diploma))
      
      (print {action: "diploma-claimed", student: tx-sender, diploma: diploma})
      (ok true)
    )
  )
)

;; Update academy name
(define-public (update-academy-name (new-academy-name (string-ascii 22)))
  (let (
    (profile (get-or-create-profile tx-sender))
  )
    (asserts! (> (len new-academy-name) u0) err-invalid-input)
    (map-set student-profiles tx-sender (merge profile {academy-name: new-academy-name}))
    (print {action: "academy-name-updated", student: tx-sender})
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-student-profile (student principal))
  (map-get? student-profiles student)
)

(define-read-only (get-conservatory-recital (recital-id uint))
  (map-get? conservatory-recitals recital-id)
)

(define-read-only (get-private-lesson (lesson-id uint))
  (map-get? private-lessons lesson-id)
)

(define-read-only (get-recital-evaluation (recital-id uint) (evaluator principal))
  (map-get? recital-evaluations {recital-id: recital-id, evaluator: evaluator})
)

(define-read-only (get-diploma (student principal) (diploma (string-ascii 13)))
  (map-get? academic-diplomas {student: student, diploma: diploma})
)