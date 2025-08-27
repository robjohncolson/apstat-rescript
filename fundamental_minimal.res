// AP Statistics PoK Blockchain - Minimal Implementation
// Generated from 55-atom mathematical template

// ===========================================================================
// PROFILE ATOMS (11)
// ===========================================================================

type profileData = {
  username: string,
  pubkey: string,
  privkey: string,
  reputationScore: float,
  archetype: string, // Simplified for minimal version
  transactionHistory: array<transaction>,
  seedphrase: string,
}

and transaction = {
  questionId: string,
  answerHash: option<string>,
  answerText: option<string>,
  score: option<float>,
  attesterPubkey: string,
  signature: string,
  timestamp: float,
  txType: string,
  isMatch: bool,
}

// Profile functions
let selectRandomWords = (wordList: array<string>): string => {
  // Minimal: just join 12 random words
  Array.make(12, "")
    ->Array.map(_ => wordList[Js.Math.random_int(0, Array.length(wordList))])
    ->Js.Array2.joinWith(" ")
}

let deriveKeysFromSeed = (seed: string): (string, string) => {
  // Minimal: simple hash-based derivation
  let pubkey = "pub_" ++ seed->Js.String2.slice(~from=0, ~to_=8)
  let privkey = "priv_" ++ seed->Js.String2.slice(~from=8, ~to_=16)
  (pubkey, privkey)
}

let calculateArchetype = (history: array<transaction>): string => {
  // Minimal: based on transaction count
  switch Array.length(history) {
  | n if n < 5 => "Explorer"
  | n if n < 20 => "Learner"
  | _ => "Ace"
  }
}

// ===========================================================================
// BLOCKCHAIN ATOMS (21)
// ===========================================================================

type blockData = {
  hash: string,
  prevHash: string,
  timestamp: float,
  nonce: int,
  transactions: array<transaction>,
}

type distributionData = {
  questionId: string,
  mcqDistribution: Js.Dict.t<int>,
  frqScores: array<float>,
  convergence: float,
  totalAttestations: int,
}

// Blockchain functions
let sha256Hash = (input: string): string => {
  // Minimal: simple hash simulation
  "hash_" ++ input->Js.String2.slice(~from=0, ~to_=8)
}

let getCurrentTimestamp = (): float => {
  Js.Date.now()
}

let validateSignature = (sig: string, pubkey: string): bool => {
  // Minimal: check prefix match
  Js.String2.startsWith(sig, "priv_")
}

let calculateConsensus = (attestations: array<transaction>): bool => {
  // Minimal: require 2+ attestations
  Array.length(attestations) >= 2
}

let updateDistributions = (
  txs: array<transaction>, 
  dists: Js.Dict.t<distributionData>
): Js.Dict.t<distributionData> => {
  // Minimal: count attestations per question
  txs->Array.forEach(tx => {
    let qid = tx.questionId
    let existing = Js.Dict.get(dists, qid)
    let updated = switch existing {
    | Some(d) => {...d, totalAttestations: d.totalAttestations + 1}
    | None => {
        questionId: qid,
        mcqDistribution: Js.Dict.empty(),
        frqScores: [],
        convergence: 0.0,
        totalAttestations: 1,
      }
    }
    Js.Dict.set(dists, qid, updated)
  })
  dists
}

// ===========================================================================
// QUESTIONS ATOMS (14)
// ===========================================================================

type questionData = {
  id: string,
  questionType: string, // "mcq" | "frq"
  prompt: string,
  correct: option<string>,
  choices: option<array<(string, string)>>, // (key, value) pairs
  rubricCriteria: option<array<(string, int)>>, // (description, points)
  maxScore: option<int>,
}

// Question functions
let parseQuestion = (json: Js.Json.t): questionData => {
  // Minimal: basic parsing
  {
    id: "q1",
    questionType: "mcq",
    prompt: "Sample question",
    correct: Some("B"),
    choices: Some([("A", "Choice A"), ("B", "Choice B")]),
    rubricCriteria: None,
    maxScore: None,
  }
}

let validateAnswer = (answer: string, correct: string): bool => {
  answer == correct
}

let scoreFRQ = (answer: string, rubric: array<(string, int)>): float => {
  // Minimal: length-based scoring
  let len = Js.String2.length(answer)
  if len > 100 { 5.0 } else if len > 50 { 3.0 } else { 1.0 }
}

// ===========================================================================
// REPUTATION ATOMS (10)
// ===========================================================================

type reputationData = {
  leaderboard: array<profileData>,
  streakCount: int,
  bonusMultiplier: float,
  decayRate: float,
  timeWindow: float,
  lastActivity: float,
}

// Reputation functions
let updateLeaderboard = (profiles: array<profileData>): array<profileData> => {
  // Sort by reputation score
  profiles->Js.Array2.sortInPlaceWith((a, b) => 
    int_of_float(b.reputationScore -. a.reputationScore)
  )
}

let applyBonuses = (
  baseReward: float, 
  streak: int, 
  consensusType: string
): float => {
  let streakBonus = 1.0 +. (float_of_int(streak) *. 0.1)
  let consensusBonus = switch consensusType {
  | "minority_correct" => 1.5
  | "incorrect" => -0.1
  | _ => 1.0
  }
  baseReward *. streakBonus *. consensusBonus
}

let decayScores = (score: float, timeSinceActivity: float): float => {
  // Minimal: linear decay
  let decayFactor = 1.0 -. (timeSinceActivity /. (24.0 *. 60.0 *. 60.0 *. 1000.0))
  score *. Js.Math.max_float(decayFactor, 0.5)
}

// ===========================================================================
// PERSISTENCE ATOMS (7)
// ===========================================================================

type persistenceData = {
  stateJson: string,
  qrCode: string,
  storageKey: string,
  syncTimestamp: float,
}

// Persistence functions
let saveState = (state: 'a): string => {
  // Minimal: stringify
  "saved_state"
}

let loadState = (json: string): 'a => {
  // Minimal: return default
  Obj.magic({})
}

let encodeQR = (data: string): string => {
  // Minimal: prefix
  "qr_" ++ data
}

// ===========================================================================
// UI ATOMS (6)
// ===========================================================================

type uiData = {
  currentView: string, // "question" | "profile" | "blockchain"
  modalState: Js.Dict.t<bool>,
  inputEvent: string,
  inputBuffer: string,
}

// UI functions
let renderState = (state: 'a): string => {
  // Minimal: return view name
  "rendered"
}

let eventTrigger = (event: string): string => {
  // Minimal: return action
  switch event {
  | "submit" => "create_transaction"
  | "mine" => "mine_block"
  | _ => "noop"
  }
}

// ===========================================================================
// SYSTEM COMPOSITION
// ===========================================================================

type systemState = {
  profile: profileData,
  blockchain: array<blockData>,
  questions: array<questionData>,
  reputation: reputationData,
  persistence: persistenceData,
  ui: uiData,
  distributions: Js.Dict.t<distributionData>,
}

// Create initial minimal state
let createInitialState = (): systemState => {
  let wordList = ["apple", "banana", "cherry", "dog", "eagle", "forest"]
  let seedphrase = selectRandomWords(wordList)
  let (pubkey, privkey) = deriveKeysFromSeed(seedphrase)
  
  {
    profile: {
      username: "user",
      pubkey,
      privkey,
      reputationScore: 100.0,
      archetype: "Explorer",
      transactionHistory: [],
      seedphrase,
    },
    blockchain: [],
    questions: [],
    reputation: {
      leaderboard: [],
      streakCount: 0,
      bonusMultiplier: 1.0,
      decayRate: 0.05,
      timeWindow: 24.0 *. 60.0 *. 60.0 *. 1000.0,
      lastActivity: getCurrentTimestamp(),
    },
    persistence: {
      stateJson: "",
      qrCode: "",
      storageKey: "apstat_state",
      syncTimestamp: getCurrentTimestamp(),
    },
    ui: {
      currentView: "question",
      modalState: Js.Dict.empty(),
      inputEvent: "",
      inputBuffer: "",
    },
    distributions: Js.Dict.empty(),
  }
}

// Verify invariants
let checkInvariant1 = (state: systemState): bool => {
  // Identity: all transactions have valid pubkeys
  state.blockchain->Array.every(block =>
    block.transactions->Array.every(tx =>
      tx.attesterPubkey == state.profile.pubkey
    )
  )
}

let checkInvariant11 = (state: systemState): bool => {
  // UI Safety: render never returns null
  renderState(state) != ""
}