// State Management for AP Statistics PoK Blockchain
// ReScript digital twin of Racket parameter-based state management
// Enhanced with React hooks and functional programming patterns

open Types
open Utils

// =============================================================================
// INITIAL STATE (Enhanced from Racket init-app-db)
// ReScript immutable records vs Racket mutable structs provide better safety
// =============================================================================


// =============================================================================
// INITIAL STATE (Enhanced from Racket init-app-db)
// =============================================================================

let initialState: appState = {
  // Core state
  profile: None,
  curriculum: [],
  currentQuestionIndex: 0,
  currentQuestion: None,
  
  // Blockchain state  
  mempool: [],
  chain: [],
  distributions: Js.Dict.empty(),
  blockchain: {
    blocks: [],
    mempool: [],
  },
  reputation: {
    leaderboard: [],
    attestations: Js.Dict.empty(),
  },
  
  // Key management (enhanced safety with option types)
  seedphrase: None,
  privkey: None,
  pubkey: None,
  pubkeyMap: Js.Dict.empty(),
  unlocked: false,
  
  // UI state
  ui: {
    modals: Js.Dict.empty(),
    currentView: Question,
  },
}

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

type mineResult = {
  newBlock: option<block>,
  remainingMempool: array<transaction>,
  updatedDistributions: Js.Dict.t<questionDistribution>,
}

// =============================================================================
// FUNCTION DEFINITIONS (ordered by dependencies)
// =============================================================================

let createTransactionInternal = (
  questionId: string,
  answer: string, 
  questionType: string,
  pubkey: string,
  privkey: string
): transaction => {
  switch questionType {
  | "multiple-choice" | "mcq" => {
      txType: Attestation,
      questionId: questionId,
      answerHash: Some(sha256Hash(answer)),
      answerText: None,
      score: None,
      attesterPubkey: pubkey,
      signature: privkey ++ "-mock-sig",
      timestamp: getCurrentTimestamp(),
    }
  | "free-response" | "frq" => {
      // For FRQ, answer should be parsed as JSON with text and score
      // For now, simplified implementation
      txType: Attestation,
      questionId: questionId,
      answerHash: None,
      answerText: Some(answer),
      score: Some(3.0), // Default score for demo
      attesterPubkey: pubkey,
      signature: privkey ++ "-mock-sig",
      timestamp: getCurrentTimestamp(),
    }
  | _ => {
      // Default to MCQ
      txType: Attestation,
      questionId: questionId,
      answerHash: Some(sha256Hash(answer)),
      answerText: None,
      score: None,
      attesterPubkey: pubkey,
      signature: privkey ++ "-mock-sig",
      timestamp: getCurrentTimestamp(),
    }
  }
}

let updateSingleDistribution = (
  tx: transaction, 
  distributions: Js.Dict.t<questionDistribution>
): Js.Dict.t<questionDistribution> => {
  let qid = tx.questionId
  let currentDist = Js.Dict.get(distributions, qid)
  let total = switch currentDist {
  | Some(dist) => dist.totalAttestations
  | None => 0
  }
  
  // Create a new dict to maintain immutability
  let newDistributions = Js.Dict.fromArray(Js.Dict.entries(distributions))
  
  switch tx.answerHash {
  | Some(hashVal) => {
      // MCQ transaction
      let choice = if Js.String2.length(hashVal) > 7 {
        hashVal->Js.String2.charAt(7) // Extract character from hash like Racket version
      } else {
        "A" // Default choice
      }
      
      let mcqDist = switch currentDist {
      | Some(dist) => Belt.Option.getWithDefault(dist.mcqDistribution, {a: 0, b: 0, c: 0, d: 0, e: None})
      | None => {a: 0, b: 0, c: 0, d: 0, e: None}
      }
      
      let updatedMcq = switch choice {
      | "A" => {...mcqDist, a: mcqDist.a + 1}
      | "B" => {...mcqDist, b: mcqDist.b + 1}
      | "C" => {...mcqDist, c: mcqDist.c + 1}
      | "D" => {...mcqDist, d: mcqDist.d + 1}
      | "E" => {
          ...mcqDist, 
          e: Some(Belt.Option.getWithDefault(mcqDist.e, 0) + 1)
        }
      | _ => {...mcqDist, a: mcqDist.a + 1} // Default to A
      }
      
      let convergence = calculateMcqConvergence(updatedMcq, total + 1)
      let newDist = {
        questionId: qid,
        totalAttestations: total + 1,
        mcqDistribution: Some(updatedMcq),
        frqDistribution: None,
        convergenceScore: convergence,
        lastUpdated: getCurrentTimestamp(),
      }
      
      Js.Dict.set(newDistributions, qid, newDist)
      newDistributions
    }
    
  | None => {
      switch tx.score {
      | Some(score) => {
          // FRQ transaction
          let frqDist = switch currentDist {
          | Some(dist) => Belt.Option.getWithDefault(dist.frqDistribution, {scores: [], averageScore: 0.0, standardDeviation: 0.0})
          | None => {scores: [], averageScore: 0.0, standardDeviation: 0.0}
          }
          
          let newScores = Belt.Array.concat(frqDist.scores, [score])
          let newAverage = calculateAverage(newScores)
          let newStddev = calculateStandardDeviation(newScores)
          
          let updatedFrq = {
            scores: newScores,
            averageScore: newAverage, 
            standardDeviation: newStddev,
          }
          
          let convergence = calculateFrqConvergence(newAverage, newStddev)
          let newDist = {
            questionId: qid,
            totalAttestations: total + 1,
            mcqDistribution: None,
            frqDistribution: Some(updatedFrq),
            convergenceScore: convergence,
            lastUpdated: getCurrentTimestamp(),
          }
          
          Js.Dict.set(newDistributions, qid, newDist)
          newDistributions
        }
      | None => distributions // No valid score, don't update
      }
    }
  }
}

let updateDistributions = (
  currentDistributions: Js.Dict.t<questionDistribution>,
  transactions: array<transaction>
): Js.Dict.t<questionDistribution> => {
  // Only process attestation transactions
  let attestationTxs = Belt.Array.keep(transactions, tx => tx.txType == Attestation)
  
  Belt.Array.reduce(attestationTxs, currentDistributions, (distributions, tx) => {
    updateSingleDistribution(tx, distributions)
  })
}

let selfAttest = (tx: transaction, correctAnswer: string): option<attestation> => {
  switch tx.answerHash {
  | Some(answerHash) => {
      // MCQ: check hash match
      let isMatch = answerHash == sha256Hash(correctAnswer)
      Some({
        validatorPubkey: "self",
        questionId: tx.questionId,
        submittedAnswer: answerHash,
        correctAnswer: correctAnswer,
        timestamp: getCurrentTimestamp(),
        confidence: if isMatch { 1.0 } else { 0.0 },
        isMatch: isMatch,
      })
    }
  | None => {
      switch tx.answerText {
      | Some(_answerText) => {
          // FRQ: always valid self-attestation
          Some({
            validatorPubkey: "self",
            questionId: tx.questionId,
            submittedAnswer: Belt.Option.getWithDefault(tx.answerText, ""),
            correctAnswer: "self-scored",
            timestamp: getCurrentTimestamp(),
            confidence: 1.0,
            isMatch: true,
          })
        }
      | None => None
      }
    }
  }
}

let mineBlockFromMempool = (state: appState): mineResult => {
  let mempool = state.mempool
  let chain = state.chain
  let distributions = state.distributions
  
  let prevHash = switch Belt.Array.get(chain, 0) {
  | Some(lastBlock) => lastBlock.hash
  | None => "genesis"
  }
  
  // Self-attest each transaction (MVP with mock correct answer "B")
  let attestations = mempool
    ->Belt.Array.map(tx => selfAttest(tx, "B"))
    ->Belt.Array.keepMap(x => x)
  
  let validAttestations = attestations
  
  // Create block if quorum reached (CLJS uses >=1 for MVP)
  if Belt.Array.length(validAttestations) >= 1 {
    let blockData = prevHash ++ Js.Json.stringify(Js.Json.array(Belt.Array.map(mempool, encodeTransaction))) ++ "0"
    let newBlock = {
      hash: sha256Hash(blockData),
      prevHash: prevHash,
      transactions: mempool,
      attestations: validAttestations,
      timestamp: getCurrentTimestamp(),
      nonce: 0,
    }
    
    // Update distributions using original mempool transactions
    let updatedDistributions = updateDistributions(distributions, mempool)
    
    {
      newBlock: Some(newBlock),
      remainingMempool: [], // Clear mempool after successful mining
      updatedDistributions: updatedDistributions,
    }
  } else {
    // No block mined
    {
      newBlock: None,
      remainingMempool: mempool,
      updatedDistributions: distributions,
    }
  }
}

let stateReducer = (state: appState, event: appEvent): appState => {
  switch event {
  | Initialize => {
      ...state,
      unlocked: false, // Initialize with logging like Racket version
    }
    
  | GenerateSeed => {
      let seedphrase = generateSeedphrase()
      let keys = deriveKeysFromSeed(seedphrase)
      {
        ...state,
        seedphrase: Some(seedphrase),
        privkey: Some(keys.privkey),
        pubkey: Some(keys.pubkey),
      }
    }
    
  | CreateProfile(username) => {
      // Handle case where we need to generate seed if not present
      let (finalState, finalSeedphrase, finalKeys) = switch state.seedphrase {
      | Some(seedphrase) => (
          state, 
          seedphrase, 
          {privkey: Belt.Option.getExn(state.privkey), pubkey: Belt.Option.getExn(state.pubkey)}
        )
      | None => {
          let newSeedphrase = generateSeedphrase()
          let newKeys = deriveKeysFromSeed(newSeedphrase)
          (
            {...state, seedphrase: Some(newSeedphrase), privkey: Some(newKeys.privkey), pubkey: Some(newKeys.pubkey)},
            newSeedphrase,
            newKeys
          )
        }
      }
      
      let newProfile = {
        username: username,
        archetype: Explorers, // Start as explorer
        pubkey: finalKeys.pubkey,
        privkey: finalKeys.privkey,
        reputationScore: 100.0,
      }
      
      // Create user transaction (matches Racket create-profile logic)
      let userTx = {
        txType: CreateUser,
        questionId: username, // questionId is username for create-user tx
        answerHash: None,
        answerText: Some(username),
        score: None,
        attesterPubkey: finalKeys.pubkey,
        signature: finalKeys.privkey ++ "-mock-sig",
        timestamp: getCurrentTimestamp(),
      }
      
      {
        ...finalState,
        profile: Some(newProfile),
        unlocked: true,
        mempool: Belt.Array.concat(finalState.mempool, [userTx]),
      }
    }
    
  | SubmitAnswer(questionId, answer) => {
      switch (state.unlocked, state.pubkey, state.privkey) {
      | (true, Some(pubkey), Some(privkey)) => {
          // Create transaction (enhanced from Racket create-transaction)
          let tx = createTransactionInternal(questionId, answer, "multiple-choice", pubkey, privkey)
          {
            ...state,
            mempool: Belt.Array.concat(state.mempool, [tx]),
          }
        }
      | _ => {
          // Profile must be unlocked - matches Racket error handling
          Js.Console.error("[ERROR] Profile must be unlocked to submit answers")
          state
        }
      }
    }
    
  | AddToMempool(tx) => {
      {
        ...state,
        mempool: Belt.Array.concat(state.mempool, [tx]),
      }
    }
    
  | MineBlock => {
      switch state.unlocked {
      | true => {
          let mineResult = mineBlockFromMempool(state)
          switch mineResult.newBlock {
          | Some(block) => {
              ...state,
              chain: Belt.Array.concat(state.chain, [block]),
              mempool: mineResult.remainingMempool,
              distributions: mineResult.updatedDistributions,
            }
          | None => state
          }
        }
      | false => {
          Js.Console.error("[ERROR] Profile must be unlocked to mine blocks")
          state
        }
      }
    }
    
  | LoadCurriculum(curriculumData) => {
      ...state,
      curriculum: curriculumData,
    }
    
  | SetCurrentQuestion(questionData) => {
      ...state,
      currentQuestion: Some(questionData),
    }
    
  | UpdateUI(newView) => {
      ...state,
      ui: {
        ...state.ui,
        currentView: newView,
      },
    }
  }
}

let getProfile = (state: appState): option<profile> => {
  state.profile
}

let getProfileVisible = (state: appState): option<Js.Json.t> => {
  switch state.profile {
  | Some(profile) => {
      let info = archetypeToInfo(profile.archetype)
      Some(Js.Dict.fromArray([
        ("username", profile.username->Js.Json.string),
        ("archetype", info.emoji->Js.Json.string),
        ("reputationScore", profile.reputationScore->Js.Json.number),
      ])->Js.Json.object_)
    }
  | None => None
  }
}

let getCurrentQuestion = (state: appState): Js.Json.t => {
  switch state.currentQuestion {
  | Some(question) => question
  | None => 
      Js.Dict.fromArray([
        ("id", "loading"->Js.Json.string),
        ("prompt", "Loading questions..."->Js.Json.string),
        ("type", "loading"->Js.Json.string),
        ("choices", []->Js.Json.array),
      ])->Js.Json.object_
  }
}

let getMempool = (state: appState): array<transaction> => {
  state.mempool
}

let getChain = (state: appState): array<block> => {
  state.chain
}

let getUnlocked = (state: appState): bool => {
  state.unlocked
}

let getReputationScore = (state: appState): float => {
  switch state.profile {
  | Some(profile) => profile.reputationScore
  | None => 0.0
  }
}
