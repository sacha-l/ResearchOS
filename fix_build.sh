#!/bin/bash

# Fix build issues for Research AI Network
set -e

echo "🔧 Fixing build issues..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Generate Cargo.lock file
echo -e "${YELLOW}📦 Generating Cargo.lock file...${NC}"
cargo check

# Step 2: Update dfx.json to remove --locked flag issues
echo -e "${YELLOW}⚙️ Updating dfx.json...${NC}"
cat > dfx.json << 'EOF'
{
  "version": 1,
  "canisters": {
    "research_ai_canister": {
      "type": "rust",
      "package": "research-ai-canister",
      "candid": "canister/research_ai_canister.did"
    }
  },
  "defaults": {
    "build": {
      "args": "--locked",
      "packtool": ""
    }
  },
  "networks": {
    "local": {
      "bind": "127.0.0.1:4943",
      "type": "ephemeral"
    },
    "ic": {
      "providers": ["https://ic0.app"],
      "type": "persistent"
    }
  }
}
EOF

# Step 3: Clean any existing build artifacts
echo -e "${YELLOW}🧹 Cleaning build artifacts...${NC}"
cargo clean
dfx stop 2>/dev/null || true

# Step 4: Add required target for WASM
echo -e "${YELLOW}🎯 Adding WASM target...${NC}"
rustup target add wasm32-unknown-unknown

# Step 5: Try building canister first
echo -e "${YELLOW}🔨 Building canister package...${NC}"
cd canister
cargo check --target wasm32-unknown-unknown
cd ..

# Step 6: Start fresh replica
echo -e "${YELLOW}🚀 Starting fresh IC replica...${NC}"
dfx start --background --clean

echo -e "${GREEN}✅ Build fixes applied!${NC}"
echo ""
echo "Now try deploying with:"
echo "  dfx deploy"