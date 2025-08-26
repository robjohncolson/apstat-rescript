// Main App Component for AP Statistics PoK Blockchain
// ReScript digital twin of Racket simulate-full-flow functionality
// Enhanced with React hooks and modern UI patterns

open Types
open State
open Persistence

// =============================================================================
// APP COMPONENT (Enhanced from Racket demo functions)
// React hooks provide better state management than Racket parameters
// =============================================================================

@react.component
let make = () => {
  // Main application state using React reducer (vs Racket make-parameter)
  let (state, dispatch) = React.useReducer(stateReducer, initialState)
  
  // Initialize app on mount (matches Racket init-app-db)
  React.useEffect0(() => {
    dispatch(Initialize)
    
    // Load curriculum data (enhancement over Racket version)
    loadCurriculumData()
      |> Js.Promise.then_(curriculumData => {
        dispatch(LoadCurriculum(curriculumData))
        Js.Promise.resolve()
      })
      |> Js.Promise.catch(_error => {
        Js.Console.error("[ERROR] Failed to load curriculum data")
        Js.Promise.resolve()
      })
      |> ignore
      
    // Try to restore state from localStorage
    switch loadStateFromLocal("apstat-pok-state") {
    | Some(savedState) => {
        Js.Console.log("[INIT] Restored state from localStorage")
        // TODO: Merge saved state with current state
      }
    | None => {
        Js.Console.log("[INIT] No saved state found, starting fresh")
      }
    }
    
    None
  })
  
  // Save state to localStorage when it changes
  React.useEffect1(() => {
    if state.unlocked {
      saveStateToLocal(state, "apstat-pok-state")
    }
    None
  }, [state])
  
  // =============================================================================
  // EVENT HANDLERS (Enhanced from Racket dispatch-event calls)
  // =============================================================================
  
  let handleGenerateSeed = () => {
    dispatch(GenerateSeed)
    Js.Console.log("[EVENT] Seed generated")
  }
  
  let handleCreateProfile = (username: string) => {
    if username->Js.String.trim != "" {
      dispatch(CreateProfile(username))
      Js.Console.log(`[EVENT] Profile created for ${username}`)
    }
  }
  
  let handleSubmitAnswer = (questionId: string, answer: string) => {
    dispatch(SubmitAnswer(questionId, answer))
    Js.Console.log(`[EVENT] Answer submitted: Q=${questionId} A=${answer}`)
  }
  
  let handleMineBlock = () => {
    dispatch(MineBlock)
    Js.Console.log("[EVENT] Mining block...")
  }
  
  let handleExportQR = () => {
    let qrData = exportStateToJson(state)
    Js.Console.log(`[QR-EXPORT] Generated ${Belt.Int.toString(Js.String2.length(qrData))} characters`)
    // TODO: Display QR code in modal
  }
  
  let handleImportQR = (qrData: string) => {
    switch importStateFromJson(qrData, state) {
    | Some(_importedState) => {
        Js.Console.log("[QR-IMPORT] State imported successfully")
        // TODO: Update state with imported data
      }
    | None => {
        Js.Console.error("[QR-IMPORT] Failed to import state")
      }
    }
  }
  
  // =============================================================================
  // DEMO FUNCTIONS (Matching Racket simulate-full-flow)
  // =============================================================================
  
  let runFullDemo = () => {
    Js.Console.log("🚀 AP Statistics PoK Blockchain - ReScript Digital Twin Demo")
    Js.Console.log("============================================================")
    
    // Generate seed and create profile
    dispatch(GenerateSeed)
    dispatch(CreateProfile("alice-rescript"))
    
    // Load sample question (matches Racket demo)
    let sampleQuestion = Js.Dict.fromArray([
      ("id", "U1-L2-Q01"->Js.Json.string),
      ("type", "multiple-choice"->Js.Json.string),
      ("prompt", "Which variable is categorical?"->Js.Json.string),
      ("choices", [
        Js.Dict.fromArray([("key", "A"->Js.Json.string), ("value", "Length"->Js.Json.string)])->Js.Json.object_,
        Js.Dict.fromArray([("key", "B"->Js.Json.string), ("value", "Type"->Js.Json.string)])->Js.Json.object_,
        Js.Dict.fromArray([("key", "C"->Js.Json.string), ("value", "Speed"->Js.Json.string)])->Js.Json.object_,
      ]->Js.Json.array),
    ])->Js.Json.object_
    
    dispatch(SetCurrentQuestion(sampleQuestion))
    
    // Submit answer and mine block
    Js.Global.setTimeout(() => {
      dispatch(SubmitAnswer("U1-L2-Q01", "B"))
      Js.Global.setTimeout(() => {
        dispatch(MineBlock)
        Js.Console.log("🎉 ReScript Digital Twin demo completed successfully!")
      }, 100)->ignore
    }, 100)->ignore
  }
  
  // =============================================================================
  // RENDER COMPONENTS (Enhanced from Racket printf statements)
  // React JSX provides rich UI vs Racket console output
  // =============================================================================
  
  let renderHeader = () => {
    <div className="app-header">
      <h1> {"🎓 AP Statistics PoK Blockchain"->React.string} </h1>
      <p className="subtitle"> {"ReScript Digital Twin - Enhanced from Racket Implementation"->React.string} </p>
    </div>
  }
  
  let renderProfile = () => {
    switch getProfileVisible(state) {
    | Some(profileJson) => {
        let username = Js.Json.decodeString(Js.Dict.get(Js.Json.decodeObject(profileJson)->Belt.Option.getExn, "username")->Belt.Option.getExn)->Belt.Option.getWithDefault("Unknown")
        let reputation = getReputationScore(state)
        
        <div className="profile-section">
          <h3> {"👤 Profile"->React.string} </h3>
          <p> {`Username: ${username}`->React.string} </p>
          <p> {`Reputation: ${Belt.Float.toString(reputation)}`->React.string} </p>
          <p> {`Unlocked: ${state.unlocked ? "✅" : "❌"}`->React.string} </p>
        </div>
      }
    | None => {
        <div className="profile-section">
          <h3> {"👤 Profile"->React.string} </h3>
          <p> {"No profile created yet"->React.string} </p>
          <button onClick={_event => handleCreateProfile("alice-rescript")}>
            {"Create Profile"->React.string}
          </button>
        </div>
      }
    }
  }
  
  let renderCurrentQuestion = () => {
    let currentQ = getCurrentQuestion(state)
    let qId = Js.Json.decodeString(Js.Dict.get(Js.Json.decodeObject(currentQ)->Belt.Option.getExn, "id")->Belt.Option.getExn)->Belt.Option.getWithDefault("loading")
    let prompt = Js.Json.decodeString(Js.Dict.get(Js.Json.decodeObject(currentQ)->Belt.Option.getExn, "prompt")->Belt.Option.getExn)->Belt.Option.getWithDefault("Loading...")
    
    <div className="question-section">
      <h3> {"📋 Current Question"->React.string} </h3>
      <p> {`ID: ${qId}`->React.string} </p>
      <p> {`Prompt: ${prompt}`->React.string} </p>
      <div className="answer-buttons">
        <button onClick={_event => handleSubmitAnswer(qId, "A")} disabled={!state.unlocked}>
          {"Answer A"->React.string}
        </button>
        <button onClick={_event => handleSubmitAnswer(qId, "B")} disabled={!state.unlocked}>
          {"Answer B"->React.string}
        </button>
        <button onClick={_event => handleSubmitAnswer(qId, "C")} disabled={!state.unlocked}>
          {"Answer C"->React.string}
        </button>
      </div>
    </div>
  }
  
  let renderBlockchain = () => {
    let mempoolLength = Belt.Array.length(getMempool(state))
    let chainLength = Belt.Array.length(getChain(state))
    
    <div className="blockchain-section">
      <h3> {"⛓️ Blockchain"->React.string} </h3>
      <p> {`Mempool: ${Belt.Int.toString(mempoolLength)} transactions`->React.string} </p>
      <p> {`Chain: ${Belt.Int.toString(chainLength)} blocks`->React.string} </p>
      <button onClick={_event => handleMineBlock()} disabled={!state.unlocked || mempoolLength == 0}>
        {"Mine Block"->React.string}
      </button>
    </div>
  }
  
  let renderControls = () => {
    <div className="controls-section">
      <h3> {"🎮 Controls"->React.string} </h3>
      <div className="control-buttons">
        <button onClick={_event => handleGenerateSeed()}>
          {"Generate Seed"->React.string}
        </button>
        <button onClick={_event => runFullDemo()}>
          {"Run Full Demo"->React.string}
        </button>
        <button onClick={_event => handleExportQR()}>
          {"Export QR"->React.string}
        </button>
      </div>
    </div>
  }
  
  let renderComparison = () => {
    <div className="comparison-section">
      <h3> {"🔄 Racket vs ReScript Comparison"->React.string} </h3>
      <div className="comparison-grid">
        <div className="comparison-item">
          <h4> {"State Management"->React.string} </h4>
          <p> {"Racket: Mutable parameters → ReScript: Immutable useReducer"->React.string} </p>
        </div>
        <div className="comparison-item">
          <h4> {"Type Safety"->React.string} </h4>
          <p> {"Racket: Runtime checks → ReScript: Compile-time verification"->React.string} </p>
        </div>
        <div className="comparison-item">
          <h4> {"Error Handling"->React.string} </h4>
          <p> {"Racket: #f for nil → ReScript: option<'a> types"->React.string} </p>
        </div>
        <div className="comparison-item">
          <h4> {"JSON Handling"->React.string} </h4>
          <p> {"Racket: Manual struct conversion → ReScript: Type-safe encoding/decoding"->React.string} </p>
        </div>
      </div>
    </div>
  }
  
  // =============================================================================
  // MAIN RENDER (Enhanced from Racket printf output)
  // =============================================================================
  
  <div className="app-container">
    {renderHeader()}
    <div className="app-content">
      <div className="left-column">
        {renderProfile()}
        {renderCurrentQuestion()}
      </div>
      <div className="right-column">
        {renderBlockchain()}
        {renderControls()}
      </div>
    </div>
    {renderComparison()}
    <div className="status-section">
      <h3> {"📊 Status"->React.string} </h3>
      <p> {`Curriculum loaded: ${Belt.Array.length(state.curriculum) > 0 ? "✅" : "❌"}`->React.string} </p>
      <p> {`Profile unlocked: ${state.unlocked ? "✅" : "❌"}`->React.string} </p>
      <p> {`Distributions tracked: ${Js.Dict.keys(state.distributions)->Belt.Array.length->Belt.Int.toString}`->React.string} </p>
    </div>
  </div>
}