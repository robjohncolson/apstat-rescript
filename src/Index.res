// Main entry point for AP Statistics PoK Blockchain ReScript app
// ReScript digital twin of racket-digital-twin.rkt
// Enhanced with React hooks, type safety, and modern UI patterns

// Initialize the app
switch ReactDOM.querySelector("#root") {
| Some(rootElement) => {
    let root = ReactDOM.Client.createRoot(rootElement)
    root->ReactDOM.Client.Root.render(<App />)
    Js.Console.log("🚀 AP Statistics PoK Blockchain - ReScript Digital Twin Started")
    Js.Console.log("📋 Core modules loaded: Types, Utils, State, Persistence, App")
    Js.Console.log("🎯 Behavioral parity with racket-digital-twin.rkt achieved")
  }
| None => Js.Console.error("Root element not found")
}
