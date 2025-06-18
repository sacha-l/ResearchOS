#!/bin/bash

# Simplified setup for Research AI Network
set -e

echo "🔬 Setting up Research AI Network (Simplified)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check prerequisites
if ! command -v dfx &> /dev/null; then
    echo -e "${RED}❌ DFX not found. Install from: https://sdk.dfinity.org${NC}"
    exit 1
fi

if ! command -v cargo &> /dev/null; then
    echo -e "${RED}❌ Rust not found. Install from: https://rustup.rs${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}"

# Add WASM target
echo -e "${YELLOW}🎯 Adding WASM target...${NC}"
rustup target add wasm32-unknown-unknown

# Generate Cargo.lock
echo -e "${YELLOW}📦 Generating lock file...${NC}"
cargo check

# Clean up
echo -e "${YELLOW}🧹 Cleaning up...${NC}"
dfx stop 2>/dev/null || true
cargo clean

# Start replica
echo -e "${YELLOW}🚀 Starting IC replica...${NC}"
dfx start --background --clean

# Deploy
echo -e "${YELLOW}📦 Deploying canister...${NC}"
dfx deploy

# Get canister ID
CANISTER_ID=$(dfx canister id research_ai_canister)
echo -e "${GREEN}✅ Deployed! Canister ID: ${CANISTER_ID}${NC}"

# Build CLI
echo -e "${YELLOW}🔧 Building CLI...${NC}"
cd cli && cargo build --release && cd ..

echo -e "${GREEN}🎉 Setup complete!${NC}"
echo ""
echo "Test with:"
echo "  ./target/release/research-ai-cli --canister-id ${CANISTER_ID} query -q \"What is AI?\" -u test"
echo ""
echo "Or using dfx directly:"
echo "  dfx canister call research_ai_canister submit_query '(record { question = \"What is AI?\"; user_id = \"test\" })'"