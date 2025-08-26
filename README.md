# apstat-rescript

ReScript port of the AP Statistics Proof of Knowledge (PoK) Blockchain application.

## Overview

This is a modern ReScript implementation of the educational blockchain system originally developed in ClojureScript. The application implements a decentralized proof-of-knowledge system for AP Statistics education with emergent consensus and peer attestation.

## Key Features

- **Decentralized Consensus**: No centralized answer keys - truth emerges through peer agreement
- **Reputation System**: Dynamic scoring with time decay and minority bonuses
- **Blockchain Architecture**: Immutable transaction history with distribution tracking
- **Educational Archetypes**: Students classified as Aces, Strategists, Explorers, Learners, or Socials
- **QR Code Sync**: Share state between devices via QR codes
- **Chart.js Integration**: Rich data visualization for statistics problems

## Architecture References

This ReScript implementation is based on:
- **ClojureScript Original** (`reference/cljs/`): Re-frame + Reagent web application
- **Racket Prototypes** (`reference/racket/`): Original algorithm implementations
- **ADRs** (`adr/`): Architectural Decision Records explaining design choices

Key ADRs:
- ADR-012: Social Consensus and Proof of Knowledge
- ADR-028: Emergent Attestation with Optional Reveals

## Quick Start

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Start development**:
   ```bash
   npm start
   ```
   This runs ReScript in watch mode, rebuilding on file changes.

3. **Build for production**:
   ```bash
   npm run build
   ```

4. **Clean build artifacts**:
   ```bash
   npm run clean
   ```

## Development

- **Source**: `src/` directory (ReScript files)
- **Output**: `lib/js/src/` directory (compiled JavaScript)
- **Entry Point**: `src/Index.res` (create this file to start)

### Recommended File Structure

```
src/
├── Index.res              # Main entry point
├── State.res              # App state management
├── Components/            # React components
│   ├── QuestionPanel.res
│   ├── ProfileDisplay.res
│   └── BlockchainView.res
├── Types.res              # Type definitions
├── Blockchain.res         # Core blockchain logic
├── Reputation.res         # Reputation calculations
└── Utils.res              # Helper functions
```

## Implementation Notes

### Key Differences from ClojureScript Version

1. **Type Safety**: ReScript provides compile-time type checking
2. **Pattern Matching**: More expressive than ClojureScript's cond
3. **Immutability**: Built-in immutable data structures
4. **React Integration**: Native JSX support with ReScript-React

### Porting Guidelines

1. **State Management**: Convert Re-frame subscriptions to React hooks/context
2. **Data Structures**: Use ReScript records and variants instead of maps
3. **Async Operations**: Use promises/async-await instead of core.async
4. **UI Components**: Convert Hiccup syntax to JSX

## Reference Implementation Comparison

| Feature | ClojureScript | Racket | ReScript Target |
|---------|---------------|---------|-----------------|
| State Management | Re-frame | Parameters | React Context |
| UI Framework | Reagent | Console | React |
| Data Structures | Maps/Vectors | Structs/Lists | Records/Arrays |
| Type System | Dynamic | Dynamic | Static |
| Async | core.async | Threads | Promises |

## Data Flow

1. **Question Display**: Load from curriculum.json
2. **Answer Submission**: Create transaction, add to mempool
3. **Mining**: Validate transactions, create block with attestations
4. **Reputation Update**: Calculate new scores based on accuracy
5. **State Persistence**: Save to localStorage, export via QR

## Testing

The reference implementations include comprehensive test suites:
- Racket: `rackunit` tests in prototype modules
- ClojureScript: Integration tests in browser

Plan to add ReScript tests using Jest/ReScript-Jest.

## Contributing

1. Study the reference implementations in `reference/` 
2. Read the ADRs in `adr/` for design context
3. Implement features incrementally, starting with core types
4. Test against the Racket behavioral specifications

## License

Educational use - AP Statistics PoK Blockchain Project

---

🚀 **Ready to start coding!** Begin by creating `src/Index.res` and implementing the core types and state management.
