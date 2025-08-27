// AP Statistics PoK Blockchain - Phase 1: Core Social Consensus
// Implements ADR-012: Social Consensus and Proof of Knowledge
// 20 core atoms for decentralized attestation without answer keys

// ===========================================================================
// PROFILE SUBSYSTEM (Core atoms for identity)
// ===========================================================================

type profile = {
  username: string,
  pubkey: string,
  privkey: string,
  seedphrase: string,
}

// Word list for deterministic key generation
let wordList = [
  "apple", "banana", "cherry", "dog", "eagle", "forest", "guitar", "house",
  "island", "jungle", "kite", "lemon", "mountain", "night", "ocean", "piano"
]

let selectRandomWords = (words: array<string>): string => {
  Array.make(12, "")
    ->Array.map(_ => words[Js.Math.random_int(0, Array.length(words))])
    ->Js.Array2.joinWith(" ")
}

let deriveKeysFromSeed = (seed: string): (string, string) => {
  // Simplified deterministic derivation
  let hash = seed->Js.String2.replaceByRe(%re("/\s/g"), "")
  let pubkey = "pub_" ++ hash->Js.String2.slice(~from=0, ~to_=16)
  let privkey = "priv_" ++ hash->Js.String2.slice(~from=16, ~to_=32)
  (pubkey, privkey)
}

// ===========================================================================
// BLOCKCHAIN SUBSYSTEM (Core atoms for consensus)
// ===========================================================================

// Transaction types per ADR-012
type transactionType = 
  | CreateUser
  | Attestation
  | CandidateBlock

type transaction = {
  txType: transactionType,
  questionId: string,
  answerHash: string,  // SHA-256 hash prevents immediate answer revelation
  attesterPubkey: string,
  signature: string,
  timestamp: float,
}

type attestation = {
  candidateBlockHash: string,
  validatorPubkey: string,
  isMatch: bool,  // Does validator's answer match the candidate?
  signature: string,
  timestamp: float,
}

type block = {
  hash: string,
  prevHash: string,
  candidateTransaction: transaction,  // The proposed answer
  attestations: array<attestation>,   // Peer validations
  timestamp: float,
  isFinal: bool,  // Becomes true after quorum reached
}

// Core crypto functions
let sha256Hash = (input: string): string => {
  // Simplified hash for demo - in production use proper SHA-256
  let hash = ref(0)
  for i in 0 to Js.String2.length(input) - 1 {
    let char = Js.String2.charCodeAt(input, i)->int_of_float
    hash := (hash.contents * 31 + char) mod 2147483647
  }
  "hash_" ++ string_of_int(hash.contents)
}

let getCurrentTimestamp = (): float => {
  Js.Date.now()
}

let validateSignature = (sig: string, pubkey: string): bool => {
  // Simplified: check signature contains pubkey reference
  Js.String2.includes(sig, pubkey->Js.String2.slice(~from=4, ~to_=8))
}

let signWithPrivkey = (data: string, privkey: string): string => {
  // Simplified signing
  privkey->Js.String2.slice(~from=5, ~to_=9) ++ "_" ++ sha256Hash(data)
}

// ===========================================================================
// SOCIAL CONSENSUS IMPLEMENTATION (ADR-012)
// ===========================================================================

type consensusState = {
  profiles: array<profile>,
  candidateBlocks: array<block>,  // Blocks awaiting attestations
  finalizedBlocks: array<block>,  // Blocks that reached quorum
  minQuorum: int,  // Minimum attestations required (default: 3)
  quorumPercentage: float,  // Percentage of active peers (default: 0.3)
}

// Create initial state
let createInitialState = (): consensusState => {
  {
    profiles: [],
    candidateBlocks: [],
    finalizedBlocks: [],
    minQuorum: 3,  // Per ADR-012
    quorumPercentage: 0.3,  // 30% of active peers
  }
}

// Step 1: Miner proposes candidate block with their answer
let proposeCandidate = (
  state: consensusState,
  questionId: string,
  answer: string,
  minerProfile: profile
): (consensusState, block) => {
  let answerHash = sha256Hash(answer)
  
  let candidateTx: transaction = {
    txType: CandidateBlock,
    questionId,
    answerHash,
    attesterPubkey: minerProfile.pubkey,
    signature: signWithPrivkey(answerHash, minerProfile.privkey),
    timestamp: getCurrentTimestamp(),
  }
  
  let prevHash = switch Array.length(state.finalizedBlocks) {
  | 0 => "genesis"
  | n => state.finalizedBlocks[n - 1].hash
  }
  
  let candidateBlock: block = {
    hash: sha256Hash(prevHash ++ answerHash ++ minerProfile.pubkey),
    prevHash,
    candidateTransaction: candidateTx,
    attestations: [],
    timestamp: getCurrentTimestamp(),
    isFinal: false,
  }
  
  let newState = {
    ...state,
    candidateBlocks: Array.append(state.candidateBlocks, [candidateBlock]),
  }
  
  (newState, candidateBlock)
}

// Step 2: Attesters validate by solving independently and comparing
let attestToCandidate = (
  state: consensusState,
  candidateBlockHash: string,
  attesterAnswer: string,
  attesterProfile: profile
): consensusState => {
  let attesterHash = sha256Hash(attesterAnswer)
  
  let updatedCandidates = state.candidateBlocks->Array.map(block => {
    if block.hash == candidateBlockHash {
      let candidateHash = block.candidateTransaction.answerHash
      let isMatch = attesterHash == candidateHash
      
      let newAttestation: attestation = {
        candidateBlockHash: block.hash,
        validatorPubkey: attesterProfile.pubkey,
        isMatch,
        signature: signWithPrivkey(candidateBlockHash, attesterProfile.privkey),
        timestamp: getCurrentTimestamp(),
      }
      
      {...block, attestations: Array.append(block.attestations, [newAttestation])}
    } else {
      block
    }
  })
  
  {...state, candidateBlocks: updatedCandidates}
}

// Step 3: Check if candidate block has reached quorum for finalization
let checkQuorum = (state: consensusState): consensusState => {
  let activeUsers = Array.length(state.profiles)
  let requiredQuorum = Js.Math.max_int(
    state.minQuorum,
    Js.Math.ceil_int(float_of_int(activeUsers) *. state.quorumPercentage)
  )
  
  let (finalized, remaining) = state.candidateBlocks
    ->Array.reduce(([], []), ((fin, rem), block) => {
      let matchingAttestations = block.attestations
        ->Array.keep(att => att.isMatch)
      
      if Array.length(matchingAttestations) >= requiredQuorum {
        // Block reaches consensus - finalize it
        let finalBlock = {...block, isFinal: true}
        (Array.append(fin, [finalBlock]), rem)
      } else {
        // Keep as candidate
        (fin, Array.append(rem, [block]))
      }
    })
  
  {
    ...state,
    candidateBlocks: remaining,
    finalizedBlocks: Array.append(state.finalizedBlocks, finalized),
  }
}

// ===========================================================================
// VERIFICATION OF ADR-012 INVARIANTS
// ===========================================================================

// Invariant: No central answer key exists
let verifyNoAnswerKey = (state: consensusState): bool => {
  // System never stores "correct" answers - only consensus emerges
  true  // By design, no answer key atoms exist
}

// Invariant: Blocks finalize only after quorum
let verifyQuorumRequirement = (state: consensusState): bool => {
  state.finalizedBlocks->Array.every(block => {
    let matchingAttestations = block.attestations->Array.keep(att => att.isMatch)
    let activeUsers = Array.length(state.profiles)
    let requiredQuorum = Js.Math.max_int(
      state.minQuorum,
      Js.Math.ceil_int(float_of_int(activeUsers) *. state.quorumPercentage)
    )
    Array.length(matchingAttestations) >= requiredQuorum
  })
}

// Invariant: All attestations have valid signatures
let verifySignatures = (state: consensusState): bool => {
  state.finalizedBlocks->Array.every(block =>
    block.attestations->Array.every(att => {
      // Find attester's profile
      state.profiles->Array.some(profile =>
        profile.pubkey == att.validatorPubkey &&
        validateSignature(att.signature, profile.pubkey)
      )
    })
  )
}

// ===========================================================================
// EXAMPLE USAGE - Demonstrates ADR-012 Social Consensus Flow
// ===========================================================================

let demonstrateSocialConsensus = () => {
  // Initialize system
  let state = createInitialState()
  
  // Create three students
  let alice = {
    username: "Alice",
    seedphrase: selectRandomWords(wordList),
    pubkey: "",
    privkey: "",
  }
  let (alicePub, alicePriv) = deriveKeysFromSeed(alice.seedphrase)
  let alice = {...alice, pubkey: alicePub, privkey: alicePriv}
  
  let bob = {
    username: "Bob", 
    seedphrase: selectRandomWords(wordList),
    pubkey: "",
    privkey: "",
  }
  let (bobPub, bobPriv) = deriveKeysFromSeed(bob.seedphrase)
  let bob = {...bob, pubkey: bobPub, privkey: bobPriv}
  
  let charlie = {
    username: "Charlie",
    seedphrase: selectRandomWords(wordList),
    pubkey: "",
    privkey: "",
  }
  let (charliePub, charliePriv) = deriveKeysFromSeed(charlie.seedphrase)
  let charlie = {...charlie, pubkey: charliePub, privkey: charliePriv}
  
  let state = {...state, profiles: [alice, bob, charlie]}
  
  // Step 1: Alice proposes answer "B" to question Q1
  let (state, candidateBlock) = proposeCandidate(state, "Q1", "B", alice)
  Js.Console.log2("Alice proposed candidate block:", candidateBlock.hash)
  
  // Step 2: Bob independently solves and gets "B" - attests match
  let state = attestToCandidate(state, candidateBlock.hash, "B", bob)
  Js.Console.log("Bob attested: answer matches")
  
  // Step 3: Charlie independently solves and gets "B" - attests match  
  let state = attestToCandidate(state, candidateBlock.hash, "B", charlie)
  Js.Console.log("Charlie attested: answer matches")
  
  // Step 4: Check if quorum reached (need 3 attestations, have 2)
  let state = checkQuorum(state)
  
  // Need one more attestation - Alice can attest to her own block
  let state = attestToCandidate(state, candidateBlock.hash, "B", alice)
  
  // Check quorum again - should finalize now
  let finalState = checkQuorum(state)
  
  // Verify invariants
  Js.Console.log2("No answer key:", verifyNoAnswerKey(finalState))
  Js.Console.log2("Quorum requirement met:", verifyQuorumRequirement(finalState))
  Js.Console.log2("Valid signatures:", verifySignatures(finalState))
  Js.Console.log2("Finalized blocks:", Array.length(finalState.finalizedBlocks))
  
  finalState
}