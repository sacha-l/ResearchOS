#!/bin/bash

echo "🔬 Creating Simple Research AI Canister"

# Check if we're in the right place
if [ -f "dfx.json" ]; then
    echo "❌ DFX project already exists in current directory"
    echo "Either cd to a new directory or remove existing project"
    exit 1
fi

# Create new DFX project
echo "📦 Creating new DFX project..."
dfx new research_ai_simple --type=rust --no-frontend

echo "📁 Moving into project directory..."
cd research_ai_simple

# Add WASM target
echo "🎯 Adding WASM target..."
rustup target add wasm32-unknown-unknown

echo ""
echo "✅ Project created in: research_ai_simple/"
echo ""
echo "Next steps:"
echo "1. cd research_ai_simple"
echo "2. Replace the generated lib.rs with our simple canister code"
echo "3. dfx start --background"
echo "4. dfx deploy"
echo ""
echo "The project structure is now:"
echo "research_ai_simple/"
echo "├── dfx.json"
echo "├── Cargo.toml"  
echo "└── src/"
echo "    └── research_ai_simple_backend/"
echo "        ├── Cargo.toml"
echo "        ├── src/lib.rs"
echo "        └── research_ai_simple_backend.did"