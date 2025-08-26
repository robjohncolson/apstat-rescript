// Core Types for AP Statistics PoK Blockchain
// ReScript digital twin of racket-digital-twin.rkt
// Enhanced with ADR-028 Emergent Attestation specifications

// =============================================================================
// ARCHETYPE DEFINITIONS (matches Racket ARCHETYPES hash)
// =============================================================================

type archetype = Aces | Strategists | Explorers | Learners | Socials

type archetypeInfo = {
  emoji: string,
  description: string,
}

let archetypeToInfo = archetype =>
  switch archetype {
  | Aces => {emoji: "🏆", description: "High accuracy, fast responses"}
  | Strategists => {emoji: "🧠", description: "Thoughtful, deliberate responses"}
  | Explorers => {emoji: "🔍", description: "Learning and discovering"}
  | Learners => {emoji: "📚", description: "Steady progress and improvement"}
  | Socials => {emoji: "🤝", description: "Collaborative and helpful"}
  }

// =============================================================================
// PROFILE TYPES (Enhanced from Racket Profile struct)
// =============================================================================

type profile = {
  username: string,
  archetype: archetype,
  pubkey: string,
  privkey: string,
  reputationScore: float,
}

// =============================================================================
// BLOCKCHAIN TRANSACTION TYPES (Enhanced from Racket Transaction struct)
// Implementing ADR-028 AttestationTransaction specification
// =============================================================================

type transactionType = 
  | CreateUser
  | Attestation
  | APReveal // ADR-028 Optional AP Reveal System

type transaction = {
  txType: transactionType,
  questionId: string,
  answerHash: option<string>,  // For MCQs - SHA-256 hash (ReScript option vs Racket #f)
  answerText: option<string>,  // For FRQs - text-based scoring
  score: option<float>,        // FRQ score 1-5 scale
  attesterPubkey: string,
  signature: string,
  timestamp: float,
}

// =============================================================================
// ATTESTATION TYPES (New - implementing ADR-028 specifications)
// =============================================================================

type attestation = {
  validatorPubkey: string,
  questionId: string,
  submittedAnswer: string,
  correctAnswer: string,
  timestamp: float,
  confidence: float,
  isMatch: bool,
}

// =============================================================================
// BLOCK TYPES (Enhanced from Racket Block struct)
// =============================================================================

type block = {
  hash: string,
  prevHash: string,
  transactions: array<transaction>,
  attestations: array<attestation>,
  timestamp: float,
  nonce: int,
}

// =============================================================================
// DISTRIBUTION TRACKING (Implementing ADR-028 QuestionDistribution)
// Major enhancement over Racket version
// =============================================================================

type mcqDistribution = {
  a: int,
  b: int, 
  c: int,
  d: int,
  e: option<int>,
}

type frqDistribution = {
  scores: array<float>,
  averageScore: float,
  standardDeviation: float,
}

type questionDistribution = {
  questionId: string,
  totalAttestations: int,
  mcqDistribution: option<mcqDistribution>,
  frqDistribution: option<frqDistribution>,
  convergenceScore: float,  // ADR-028: Percentage of highest consensus option
  lastUpdated: float,
}

// =============================================================================
// APPLICATION STATE (Enhanced from Racket AppDB struct)
// Using ReScript record vs mutable Racket struct for safer state management
// =============================================================================

type currentView = Question | Profile | Blockchain | Statistics

type uiState = {
  modals: Js.Dict.t<bool>,
  currentView: currentView,
}

type reputationState = {
  leaderboard: array<profile>,
  attestations: Js.Dict.t<array<attestation>>,
}

type blockchainState = {
  blocks: array<block>,
  mempool: array<transaction>,
}

type appState = {
  // Core state
  profile: option<profile>,
  curriculum: array<Js.Json.t>, // Will be parsed from curriculum.json
  currentQuestionIndex: int,
  currentQuestion: option<Js.Json.t>,
  
  // Blockchain state
  mempool: array<transaction>,
  chain: array<block>,
  distributions: Js.Dict.t<questionDistribution>,
  blockchain: blockchainState,
  reputation: reputationState,
  
  // Key management (enhanced safety vs Racket's mutable fields)
  seedphrase: option<string>,
  privkey: option<string>,
  pubkey: option<string>,
  pubkeyMap: Js.Dict.t<string>,
  unlocked: bool,
  
  // UI state
  ui: uiState,
}

// =============================================================================
// EVENT TYPES (Implementing Re-frame style events vs Racket case dispatch)
// ReScript's variant types provide compile-time exhaustiveness checking
// =============================================================================

type appEvent = 
  | Initialize
  | GenerateSeed
  | CreateProfile(string)  // username
  | SubmitAnswer(string, string)  // questionId, answer
  | AddToMempool(transaction)
  | MineBlock
  | LoadCurriculum(array<Js.Json.t>)
  | SetCurrentQuestion(Js.Json.t)
  | UpdateUI(currentView)

// =============================================================================
// QUESTION TYPES (Enhanced from curriculum.json structure)
// =============================================================================

type questionChoice = {
  key: string,
  value: string,
}

type rubricCriterion = {
  description: string,
  points: int,
}

type rubric = {
  criteria: array<rubricCriterion>,
  maxScore: int,
}

type chartData = {
  labels: array<string>,
  datasets: array<Js.Json.t>, // Keep flexible for Chart.js integration
}

type questionAttachments = {
  chartType: option<string>,
  data: option<chartData>,
}

type question = {
  id: string,
  questionType: string,  // "multiple-choice" | "free-response"
  prompt: string,
  choices: option<array<questionChoice>>,  // For MCQ
  correct: option<string>,  // For MCQ
  rubric: option<rubric>,  // For FRQ
  attachments: option<questionAttachments>,
}

// =============================================================================
// CONSTANTS (Matching Racket constants with ReScript enhancements)
// =============================================================================

let reputationDecayRate = 0.05
let timeWindowHours = 24.0
let minQuorumSize = 2
let consensusThreshold = 0.67
let minorityBonusMultiplier = 1.5
let maxReputationScore = 1000.0

// Word list for seedphrase (exact match to Racket WORD-LIST)
let wordList = [
  "apple", "banana", "cherry", "dog", "eagle", "forest", "guitar", "house", "island", "jungle",
  "kite", "lemon", "mountain", "night", "ocean", "piano", "queen", "river", "sunset", "tree",
  "umbrella", "valley", "water", "xray", "yellow", "zebra", "anchor", "bridge", "castle", "dragon",
  "engine", "flower", "garden", "helmet", "igloo", "jacket", "kettle", "laptop", "mirror", "needle",
  "orange", "pencil", "quartz", "rabbit", "spider", "table", "unicorn", "violin", "wizard", "xwing",
  "yacht", "zeppelin", "artifact", "butterfly", "crystal", "diamond", "elephant", "firefly", "galaxy", "harmony",
  "internet", "journey", "keyboard", "lighthouse", "melody", "notebook", "opal", "puzzle", "question", "rainbow",
  "satellite", "telescope", "universe", "volcano", "whisper", "xenon", "yogurt", "zodiac", "adventure", "brilliant",
  "compass", "discovery", "eclipse", "fountain", "glacier", "horizon", "infinity", "jewel", "knowledge", "legend",
  "mystical", "navigator", "odyssey", "phoenix", "quantum", "revolution", "starlight", "triumph", "utopia", "victory",
  "wanderer", "xfactor", "yearning", "zenith", "beacon", "courage", "destiny", "essence", "freedom", "grace"
]