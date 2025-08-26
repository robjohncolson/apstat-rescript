// Core Utilities for AP Statistics PoK Blockchain
// ReScript digital twin of racket-digital-twin.rkt utility functions
// Enhanced with ReScript type safety and functional programming patterns

open Types

// =============================================================================
// HASH FUNCTIONS (Matching Racket simple-hash and sha256-hash)
// ReScript version provides better type safety
// =============================================================================

// Simple hash function (matches Racket simple-hash)
let simpleHash = (text: string): string => {
  // Use built-in hash for consistency with Racket behavior
  let length = Js.String2.length(text)
  let firstCharCode = if length > 0 {
    text->Js.String2.charCodeAt(0)->Belt.Float.toInt
  } else {
    0
  }
  let hash = length + firstCharCode
  Belt.Int.toString(hash)
}

// SHA-256 hash (mock version matching Racket implementation)
// In production, would use actual crypto library
let sha256Hash = (text: string): string => {
  "sha256:" ++ text
}

// =============================================================================
// SEEDPHRASE GENERATION (Enhanced from Racket generate-seedphrase)
// ReScript version uses Belt.Array for better performance and safety
// =============================================================================

let generateSeedphrase = (): string => {
  let shuffledWords = Belt.Array.shuffle(wordList)
  shuffledWords
    ->Belt.Array.slice(~offset=0, ~len=4)
    ->Belt.Array.joinWith(" ", x => x)
}

// =============================================================================
// KEY DERIVATION (Enhanced from Racket derive-keys-from-seed)
// ReScript version returns record instead of hash for type safety
// =============================================================================

type keyPair = {
  privkey: string,
  pubkey: string,
}

let deriveKeysFromSeed = (seedphrase: string): keyPair => {
  let privkey = simpleHash(seedphrase)
  let pubkey = "pk_" ++ simpleHash(privkey)
  {privkey, pubkey}
}

// =============================================================================
// ARCHETYPE CALCULATION (Enhanced from Racket calculate-archetype)
// ReScript version uses pattern matching for exhaustive checking
// =============================================================================

let calculateArchetype = (
  accuracy: float,
  responseTime: float, 
  questionsAnswered: int,
  socialScore: float
): archetype => {
  switch () {
  // Aces: High accuracy (>90%) with fast responses (<3s)
  | _ if accuracy >= 0.9 && responseTime < 3000.0 && questionsAnswered >= 50 => Aces
  // Strategists: Good accuracy (>85%) with thoughtful responses (5-8s)  
  | _ if accuracy >= 0.85 && responseTime >= 5000.0 && responseTime <= 8000.0 && questionsAnswered >= 30 => Strategists
  // Socials: Good collaboration score (>80%) regardless of other metrics
  | _ if socialScore >= 0.8 => Socials
  // Learners: Steady progress (60-80% accuracy) with moderate engagement
  | _ if accuracy >= 0.6 && accuracy <= 0.8 && questionsAnswered >= 20 => Learners
  // Explorers: New users or those still discovering the system
  | _ => Explorers
  }
}

// =============================================================================
// CONVERGENCE CALCULATIONS (Implementing ADR-028 specifications)
// Major enhancement over Racket version - full ADR-028 compliance
// =============================================================================

let calculateMcqConvergence = (mcqDist: mcqDistribution, total: int): float => {
  if total == 0 {
    0.0
  } else {
    let values = [mcqDist.a, mcqDist.b, mcqDist.c, mcqDist.d]
    let maxChoice = switch mcqDist.e {
    | Some(e) => Belt.Array.reduce([mcqDist.a, mcqDist.b, mcqDist.c, mcqDist.d, e], 0, Js.Math.max_int)
    | None => Belt.Array.reduce(values, 0, Js.Math.max_int)
    }
    Belt.Int.toFloat(maxChoice) /. Belt.Int.toFloat(total)
  }
}

let calculateFrqConvergence = (average: float, stddev: float): float => {
  if average == 0.0 {
    0.0
  } else {
    Js.Math.max_float(0.0, 1.0 -. (stddev /. average))
  }
}

// =============================================================================
// STATISTICAL UTILITIES (New - implementing ADR-028 requirements)
// ReScript functional approach vs Racket imperative calculations
// =============================================================================

let calculateAverage = (scores: array<float>): float => {
  if Belt.Array.length(scores) == 0 {
    0.0
  } else {
    let sum = Belt.Array.reduce(scores, 0.0, (acc, x) => acc +. x)
    sum /. Belt.Int.toFloat(Belt.Array.length(scores))
  }
}

let calculateStandardDeviation = (scores: array<float>): float => {
  if Belt.Array.length(scores) <= 1 {
    0.0
  } else {
    let average = calculateAverage(scores)
    let squaredDiffs = Belt.Array.map(scores, score => {
      let diff = score -. average
      diff *. diff
    })
    let variance = calculateAverage(squaredDiffs)
    Js.Math.sqrt(variance)
  }
}

// =============================================================================
// REPUTATION CALCULATIONS (Enhanced from Racket consensus.rkt)
// ReScript version provides better type safety and error handling
// =============================================================================

let calculatePeerScore = (attestations: array<attestation>): float => {
  if Belt.Array.length(attestations) == 0 {
    0.0
  } else {
    let avgConfidence = attestations
      ->Belt.Array.map(att => att.confidence)
      ->calculateAverage
    let validationCount = Belt.Int.toFloat(Belt.Array.length(attestations))
    avgConfidence *. validationCount *. 10.0
  }
}

let minorityCorrectBonus = (answerPercentage: float): float => {
  if answerPercentage < 0.3 {
    minorityBonusMultiplier
  } else {
    1.0
  }
}

let updateReputationScore = (
  currentReputation: float,
  accuracy: float,
  attestations: array<attestation>,
  questionStats: option<Js.Dict.t<float>>,
  streakCount: int
): float => {
  // Enhanced reputation calculation following Racket formula
  let baseAccuracyScore = if accuracy > 0.5 {
    accuracy *. 100.0  // Positive for correct
  } else {
    -50.0 *. (1.0 -. accuracy)  // Negative for incorrect (matches Racket fix)
  }
  
  let peerScore = calculatePeerScore(attestations)
  let streakScore = Belt.Int.toFloat(streakCount) *. 2.0
  
  let minorityBonus = switch questionStats {
  | Some(stats) => 
    // In a real implementation, would look up actual answer percentage
    minorityCorrectBonus(0.5)  // Default 50% for now
  | None => 1.0
  }
  
  let delta = (baseAccuracyScore *. minorityBonus) +. peerScore +. streakScore
  let totalScore = currentReputation +. delta
  
  // Clamp between 0 and max reputation
  Js.Math.max_float(0.0, Js.Math.min_float(totalScore, maxReputationScore))
}

// =============================================================================
// JSON ENCODING/DECODING UTILITIES (Enhanced from Racket struct->hash)
// ReScript provides compile-time safe JSON handling vs Racket runtime conversion
// =============================================================================

let encodeTransaction = (tx: transaction): Js.Json.t => {
  Js.Dict.fromArray([
    ("txType", switch tx.txType {
    | CreateUser => "create-user"
    | Attestation => "attestation" 
    | APReveal => "ap-reveal"
    }->Js.Json.string),
    ("questionId", tx.questionId->Js.Json.string),
    ("answerHash", switch tx.answerHash {
    | Some(hash) => hash->Js.Json.string
    | None => Js.Json.null
    }),
    ("answerText", switch tx.answerText {
    | Some(text) => text->Js.Json.string
    | None => Js.Json.null
    }),
    ("score", switch tx.score {
    | Some(score) => score->Js.Json.number
    | None => Js.Json.null
    }),
    ("attesterPubkey", tx.attesterPubkey->Js.Json.string),
    ("signature", tx.signature->Js.Json.string),
    ("timestamp", tx.timestamp->Js.Json.number),
  ])->Js.Json.object_
}

let encodeBlock = (block: block): Js.Json.t => {
  Js.Dict.fromArray([
    ("hash", block.hash->Js.Json.string),
    ("prevHash", block.prevHash->Js.Json.string),
    ("transactions", block.transactions->Belt.Array.map(encodeTransaction)->Js.Json.array),
    ("attestations", []->Js.Json.array), // TODO: implement attestation encoding
    ("timestamp", block.timestamp->Js.Json.number),
    ("nonce", block.nonce->Belt.Int.toFloat->Js.Json.number),
  ])->Js.Json.object_
}

// =============================================================================
// VALIDATION FUNCTIONS (New - ReScript compile-time safety)
// Eliminates runtime errors that could occur in Racket version
// =============================================================================

let validateQuestion = (questionData: Js.Json.t): option<question> => {
  // TODO: Implement robust JSON validation
  // For now, return None to indicate need for implementation
  None
}

let validateTransaction = (tx: transaction): bool => {
  // Basic validation rules
  tx.questionId != "" && 
  tx.attesterPubkey != "" &&
  tx.signature != ""
}

let validateBlock = (block: block): bool => {
  block.hash != "" &&
  block.prevHash != "" &&
  Belt.Array.every(block.transactions, validateTransaction)
}

// =============================================================================
// TIMING UTILITIES (Enhanced from Racket timestamp functions)
// =============================================================================

let getCurrentTimestamp = (): float => {
  Js.Date.now()
}

let isWithinTimeWindow = (timestamp: float, windowHours: float): bool => {
  let now = getCurrentTimestamp()
  let windowMs = windowHours *. 60.0 *. 60.0 *. 1000.0
  (now -. timestamp) <= windowMs
}