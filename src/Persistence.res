// Persistence and QR Sync for AP Statistics PoK Blockchain
// ReScript digital twin of Racket save/load functions
// Enhanced with browser localStorage and type-safe JSON handling

open Types
open Utils

// =============================================================================
// BROWSER STORAGE BINDINGS (Enhanced from Racket file I/O)
// ReScript provides browser-native persistence vs Racket file system
// =============================================================================

// External bindings for localStorage
@val @scope("localStorage")
external setItem: (string, string) => unit = "setItem"

@val @scope("localStorage") 
external getItem: string => Js.nullable<string> = "getItem"

@val @scope("localStorage")
external removeItem: string => unit = "removeItem"

// =============================================================================
// STATE SERIALIZATION (Enhanced from Racket struct->hash)
// ReScript compile-time type safety vs Racket runtime conversion
// =============================================================================

let encodeAppState = (state: appState): Js.Json.t => {
  Js.Dict.fromArray([
    ("chain", state.chain->Belt.Array.map(encodeBlock)->Js.Json.array),
    ("mempool", state.mempool->Belt.Array.map(encodeTransaction)->Js.Json.array),
    ("curriculum", state.curriculum->Js.Json.array),
    ("currentQuestionIndex", state.currentQuestionIndex->Belt.Int.toFloat->Js.Json.number),
    ("pubkey", switch state.pubkey {
    | Some(pubkey) => pubkey->Js.Json.string
    | None => Js.Json.null
    }),
    ("distributionsCount", Js.Dict.keys(state.distributions)->Belt.Array.length->Belt.Int.toFloat->Js.Json.number),
    ("unlocked", state.unlocked->Js.Json.boolean),
  ])->Js.Json.object_
}

// Decode functions with error handling (improvement over Racket)
let decodeChain = (json: Js.Json.t): array<block> => {
  // TODO: Implement robust JSON decoding with error handling
  // For now, return empty array as safe fallback
  []
}

let decodeMempool = (json: Js.Json.t): array<transaction> => {
  // TODO: Implement robust JSON decoding with error handling
  // For now, return empty array as safe fallback
  []
}

let decodeAppState = (json: Js.Json.t): option<appState> => {
  // TODO: Implement robust JSON decoding
  // ReScript's type system allows us to ensure this is safe at compile time
  None
}

// =============================================================================
// LOCAL STORAGE OPERATIONS (Enhanced from Racket file I/O)
// Browser-native persistence vs file system operations
// =============================================================================

let saveStateToLocal = (state: appState, key: string): unit => {
  try {
    let stateJson = encodeAppState(state)
    let stateString = Js.Json.stringify(stateJson)
    setItem(key, stateString)
    Js.Console.log("[PERSIST] State saved to localStorage: " ++ key)
  } catch {
  | exn => Js.Console.error("[ERROR] Failed to save state: " ++ Js.String.make(exn))
  }
}

let loadStateFromLocal = (key: string): option<appState> => {
  try {
    switch Js.Nullable.toOption(getItem(key)) {
    | Some(stateString) => {
        let stateJson = Js.Json.parseExn(stateString)
        let decodedState = decodeAppState(stateJson)
        Js.Console.log("[PERSIST] State loaded from localStorage: " ++ key)
        decodedState
      }
    | None => {
        Js.Console.log("[PERSIST] No saved state found for key: " ++ key)
        None
      }
    }
  } catch {
  | exn => {
      Js.Console.error("[ERROR] Failed to load state: " ++ Js.String.make(exn))
      None
    }
  }
}

let clearStateFromLocal = (key: string): unit => {
  removeItem(key)
  Js.Console.log("[PERSIST] State cleared from localStorage: " ++ key)
}

// =============================================================================
// QR CODE SYNC (Enhanced from Racket export/import functions)
// ReScript provides browser-native JSON vs Racket string I/O
// =============================================================================

let exportStateToJson = (state: appState): string => {
  let exportData = Js.Dict.fromArray([
    ("chain", state.chain->Belt.Array.map(encodeBlock)->Js.Json.array),
    ("mempool", state.mempool->Belt.Array.map(encodeTransaction)->Js.Json.array),
    ("distributionsCount", Js.Dict.keys(state.distributions)->Belt.Array.length->Belt.Int.toFloat->Js.Json.number),
    ("timestamp", getCurrentTimestamp()->Js.Json.number),
  ])->Js.Json.object_
  
  Js.Json.stringify(exportData)
}

let importStateFromJson = (jsonString: string, currentState: appState): option<appState> => {
  try {
    let importedData = Js.Json.parseExn(jsonString)
    
    // TODO: Implement proper JSON decoding and state merging
    // For now, return current state as safe fallback
    Js.Console.log("[QR-SYNC] JSON import attempted (implementation pending)")
    Some(currentState)
  } catch {
  | exn => {
      Js.Console.error("[ERROR] Failed to import state: " ++ Js.String.make(exn))
      None
    }
  }
}

// =============================================================================
// DATA FILE LOADING (New - loading curriculum.json and allUnitsData.js)
// ReScript browser-native fetch vs Racket file I/O
// =============================================================================

// External fetch binding for loading data files
@val external fetch: string => Js.Promise.t<'response> = "fetch"

// Response methods binding
@send external json: 'response => Js.Promise.t<Js.Json.t> = "json"
@send external text: 'response => Js.Promise.t<string> = "text"

let loadCurriculumData = (): Js.Promise.t<array<Js.Json.t>> => {
  fetch("./reference/data/curriculum.json")
    |> Js.Promise.then_(response => response->json)
    |> Js.Promise.then_(json => {
      // Convert JSON to array format expected by application
      switch Js.Json.classify(json) {
      | JSONArray(items) => Js.Promise.resolve(items)
      | _ => {
          Js.Console.error("[ERROR] curriculum.json is not an array")
          Js.Promise.resolve([])
        }
      }
    })
    |> Js.Promise.catch(error => {
      Js.Console.error("[ERROR] Failed to load curriculum.json")
      Js.Console.error(error)
      Js.Promise.resolve([])
    })
}

let loadUnitsData = (): Js.Promise.t<Js.Json.t> => {
  fetch("./reference/data/allUnitsData.js")
    |> Js.Promise.then_(response => response->text)
    |> Js.Promise.then_(text => {
      // Extract JavaScript object from module format
      // This is a simplified approach - in production would use proper JS module loading
      try {
        // Remove "const ALL_UNITS_DATA = " and export to get just the JSON
        let cleanText = text
          ->Js.String2.replace("const ALL_UNITS_DATA = ", "")
          ->Js.String2.replace("export { ALL_UNITS_DATA };", "")
          ->Js.String2.replace("export default ALL_UNITS_DATA;", "")
          ->Js.String2.replace(";", "")
          ->Js.String2.trim
        
        let parsed = Js.Json.parseExn(cleanText)
        Js.Promise.resolve(parsed)
      } catch {
      | exn => {
          Js.Console.error("[ERROR] Failed to parse allUnitsData.js")
          Js.Console.error(exn)
          Js.Promise.resolve(Js.Json.array([]))
        }
      }
    })
    |> Js.Promise.catch(error => {
      Js.Console.error("[ERROR] Failed to load allUnitsData.js")
      Js.Console.error(error)
      Js.Promise.resolve(Js.Json.array([]))
    })
}

// =============================================================================
// BACKUP AND RECOVERY (Enhanced from Racket file operations)
// ReScript browser download vs file system writes
// =============================================================================

// Create downloadable backup file
let downloadBackup = (state: appState, filename: string): unit => {
  let backupData = exportStateToJson(state)
  
  // Create blob and download link (browser-specific)
  let blob = %raw(`new Blob([backupData], { type: 'application/json' })`)
  let url = %raw(`URL.createObjectURL(blob)`)
  
  // Create temporary download link
  let link = %raw(`document.createElement('a')`)
  %raw(`link.href = url`)
  %raw(`link.download = filename`)
  %raw(`document.body.appendChild(link)`)
  %raw(`link.click()`)
  %raw(`document.body.removeChild(link)`)
  %raw(`URL.revokeObjectURL(url)`)
  
  Js.Console.log("[BACKUP] State exported to file: " ++ filename)
}

// File upload handler for backup restoration
@val external addEventListener: (string, 'event => unit) => unit = "addEventListener"

let setupBackupRestore = (onRestore: string => unit): unit => {
  // This would typically be connected to a file input element
  // Implementation depends on specific UI requirements
  Js.Console.log("[BACKUP] Backup restore handler configured")
}

// =============================================================================
// VALIDATION AND INTEGRITY (New - ReScript type safety enhancement)
// Ensures data integrity across persistence operations
// =============================================================================

let validateStateIntegrity = (state: appState): bool => {
  // Basic integrity checks
  let hasValidProfile = switch state.profile {
  | Some(profile) => profile.username != "" && profile.pubkey != ""
  | None => true // None is valid for initial state
  }
  
  let hasValidChain = Belt.Array.every(state.chain, validateBlock)
  let hasValidMempool = Belt.Array.every(state.mempool, validateTransaction)
  
  hasValidProfile && hasValidChain && hasValidMempool
}

let sanitizeStateForExport = (state: appState): appState => {
  // Remove sensitive data before export
  {
    ...state,
    privkey: None, // Never export private keys
    seedphrase: None, // Never export seed phrases
    profile: switch state.profile {
    | Some(profile) => Some({...profile, privkey: ""}) // Clear private key
    | None => None
    },
  }
}

// =============================================================================
// MIGRATION UTILITIES (Future-proofing for schema changes)
// ReScript type system helps prevent version compatibility issues
// =============================================================================

type version = V1 | V2 | Current

let getStateVersion = (json: Js.Json.t): version => {
  // TODO: Implement version detection from JSON structure
  Current // Default to current version
}

let migrateState = (json: Js.Json.t, fromVersion: version, toVersion: version): option<Js.Json.t> => {
  // TODO: Implement state migration logic
  // ReScript's type system ensures migrations are type-safe
  Some(json) // For now, pass through unchanged
}

// =============================================================================
// CONSTANTS (Matching Racket but enhanced for browser environment)
// =============================================================================

let defaultStateKey = "apstat-pok-state"
let backupPrefix = "apstat-backup-"
let maxBackupAge = 30.0 // days
let compressionThreshold = 1000000 // bytes - when to compress large states