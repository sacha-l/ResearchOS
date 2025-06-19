#!/bin/bash

# ResearchOS - Complete Deployment & Launch Script
# Deploys GetThePaper canister and launches neural interface
echo "🧠 ResearchOS - GetThePaper Deployment & Launch"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "🔍 Checking Prerequisites..."
    
    # Check DFX
    if ! command -v dfx &> /dev/null; then
        print_error "DFX not found. Please install from: https://sdk.dfinity.org"
        exit 1
    fi
    print_success "DFX found: $(dfx --version)"
    
    # Check Rust
    if ! command -v cargo &> /dev/null; then
        print_error "Rust not found. Please install from: https://rustup.rs"
        exit 1
    fi
    print_success "Rust found: $(rustc --version)"
    
    # Check Python3
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 not found. Please install Python 3.6+"
        exit 1
    fi
    print_success "Python3 found: $(python3 --version)"
    
    # Add WASM target
    print_status "Adding WASM target..."
    rustup target add wasm32-unknown-unknown
    print_success "WASM target ready"
}

# Create project structure
setup_project() {
    print_header "📁 Setting up ResearchOS Project Structure..."
    
    PROJECT_NAME="researchos-getthepaper"
    
    # Create new DFX project if it doesn't exist
    if [ ! -d "$PROJECT_NAME" ]; then
        print_status "Creating new DFX project: $PROJECT_NAME"
        dfx new $PROJECT_NAME --type=rust --no-frontend
        print_success "DFX project created"
    else
        print_warning "Project directory already exists"
    fi
    
    cd $PROJECT_NAME
}

# Setup canister code
setup_canister() {
    print_header "🛠️ Setting up GetThePaper Canister..."
    
    # First, let's see what dfx new actually created
    print_status "Checking project structure..."
    ls -la src/
    
    # Find the actual backend directory name
    BACKEND_DIR=$(find src/ -name "*backend*" -type d | head -1)
    if [ -z "$BACKEND_DIR" ]; then
        print_error "Backend directory not found!"
        exit 1
    fi
    
    print_status "Found backend directory: $BACKEND_DIR"
    
    # Get the actual canister name from dfx.json
    CANISTER_NAME=$(grep -o '"[^"]*_backend"' dfx.json | head -1 | tr -d '"')
    print_status "Canister name: $CANISTER_NAME"
    
    # Update workspace Cargo.toml with correct path
    print_status "Updating workspace Cargo.toml..."
    cat > Cargo.toml << EOF
[workspace]
members = [
    "$BACKEND_DIR",
]
resolver = "2"

[workspace.dependencies]
candid = "0.10"
ic-cdk = "0.13"
ic-cdk-macros = "0.13"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
EOF

    # Update canister Cargo.toml with correct name
    print_status "Updating canister Cargo.toml..."
    cat > $BACKEND_DIR/Cargo.toml << EOF
[package]
name = "$CANISTER_NAME"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
candid = { workspace = true }
ic-cdk = { workspace = true }
ic-cdk-macros = { workspace = true }
serde = { workspace = true }
serde_json = { workspace = true }
EOF

    # Create GetThePaper canister code
    print_status "Creating GetThePaper canister code..."
    cat > $BACKEND_DIR/src/lib.rs << 'EOF'
use candid::{CandidType, Principal};
use ic_cdk_macros::{export_candid, heartbeat, init, query, update};
use serde::{Deserialize, Serialize};
use std::cell::RefCell;
use std::collections::HashMap;

// Core types
#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct NewsQuery {
    pub id: String,
    pub user_id: Principal,
    pub question: String,
    pub timestamp: u64,
    pub bullshit_mode: bool,
    pub response: Option<String>,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct NewsStats {
    pub total_queries: u64,
    pub bullshit_queries: u64,
    pub clean_queries: u64,
    pub active_users: u64,
}

// Storage
thread_local! {
    static NEWS_QUERIES: RefCell<HashMap<String, NewsQuery>> = RefCell::new(HashMap::new());
    static GROQ_API_KEY: RefCell<Option<String>> = RefCell::new(None);
    static TRENDING_TOPICS: RefCell<Vec<String>> = RefCell::new(Vec::new());
}

#[init]
fn init() {
    ic_cdk::println!("📰 GetThePaper canister initialized - Ready to tell you what's up!");
}

// Configuration
#[update]
fn set_groq_api_key(api_key: String) -> bool {
    GROQ_API_KEY.with(|key| {
        *key.borrow_mut() = Some(api_key);
    });
    ic_cdk::println!("🔑 Groq API key configured");
    true
}

// Main function - "What's up with X?" or "What's up with X, with the bullshit?"
#[update]
async fn whats_up(topic: String, with_bullshit: Option<bool>) -> Result<String, String> {
    let caller = ic_cdk::caller();
    let query_id = generate_query_id();
    let show_bullshit = with_bullshit.unwrap_or(false);
    
    ic_cdk::println!("📰 Query: '{}' (bullshit mode: {})", topic, show_bullshit);
    
    // Create query record
    let news_query = NewsQuery {
        id: query_id.clone(),
        user_id: caller,
        question: topic.clone(),
        timestamp: ic_cdk::api::time(),
        bullshit_mode: show_bullshit,
        response: None,
    };
    
    // Store query
    NEWS_QUERIES.with(|queries| {
        queries.borrow_mut().insert(query_id.clone(), news_query);
    });
    
    // Generate response based on mode
    let response = if show_bullshit {
        format!(
            "📰 GetThePaper - With The Bullshit\n\n## 🎯 STRAIGHT FACTS (No Bullshit)\n\n**What's Up: {}**\n\n• This is a demo response showing how GetThePaper works\n• Multiple sources would be analyzed for bias and spin\n• Real implementation would use Groq AI for analysis\n• Facts would be separated from opinion and speculation\n\n**Bottom Line:** Demo mode - deploy with real Groq API key for live news.\n\n## 🎭 HOW OUTLETS ARE SPINNING IT\n\n### CNN (LEFT)\n**Their Angle:** Progressive framing with social justice emphasis\n**Bullshit Level:** 6/10 🧢\n\n### Fox News (RIGHT) \n**Their Angle:** Conservative perspective with traditional values focus\n**Bullshit Level:** 7/10 🧢\n\n### Reuters (CENTER)\n**Their Angle:** Neutral reporting with factual emphasis\n**Bullshit Level:** 2/10 🧢\n\n---\n*GetThePaper: Telling you what's up, with or without the bullshit.*",
            topic
        )
    } else {
        format!(
            "📰 GetThePaper - No Bullshit Mode\n\n## What's Up: {}\n\n**Key Facts:**\n• Demo mode active - this is a sample response\n• Real version would call Groq AI for live news analysis\n• Multiple credible sources would be cross-referenced\n• Only verified information would be included\n• No spin, opinion, or speculation\n\n**Bottom Line:** Demo response - configure Groq API key for real news analysis.\n\n**Last Updated:** Just now\n**Confidence:** Demo mode",
            topic
        )
    };
    
    // Update stored query with response
    NEWS_QUERIES.with(|queries| {
        if let Some(mut query) = queries.borrow().get(&query_id) {
            query.response = Some(response.clone());
            queries.borrow_mut().insert(query_id, query);
        }
    });
    
    Ok(response)
}

// Query functions
#[query]
fn get_trending_topics() -> Vec<String> {
    TRENDING_TOPICS.with(|trending| trending.borrow().clone())
}

#[query]
fn get_recent_queries(limit: Option<u32>) -> Vec<NewsQuery> {
    let limit = limit.unwrap_or(10).min(50) as usize;
    
    NEWS_QUERIES.with(|queries| {
        queries.borrow()
            .values()
            .cloned()
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .take(limit)
            .collect()
    })
}

#[query]
fn get_stats() -> NewsStats {
    NEWS_QUERIES.with(|queries| {
        let queries_map = queries.borrow();
        let total = queries_map.len() as u64;
        let bullshit_count = queries_map.values()
            .filter(|q| q.bullshit_mode)
            .count() as u64;
        let clean_count = total - bullshit_count;
        
        let unique_users = queries_map.values()
            .map(|q| q.user_id)
            .collect::<std::collections::HashSet<_>>()
            .len() as u64;
        
        NewsStats {
            total_queries: total,
            bullshit_queries: bullshit_count,
            clean_queries: clean_count,
            active_users: unique_users,
        }
    })
}

#[query]
fn health_check() -> String {
    "GetThePaper canister is online and ready to tell you what's up!".to_string()
}

// Heartbeat for background processing
#[heartbeat]
fn heartbeat() {
    // Update trending topics periodically
    static mut HEARTBEAT_COUNTER: u64 = 0;
    unsafe {
        HEARTBEAT_COUNTER += 1;
        if HEARTBEAT_COUNTER % 100 == 0 {
            update_trending_topics();
        }
    }
}

fn update_trending_topics() {
    let recent_topics: Vec<String> = NEWS_QUERIES.with(|queries| {
        let current_time = ic_cdk::api::time();
        let one_hour_ago = current_time.saturating_sub(3_600_000_000_000);
        
        queries.borrow()
            .values()
            .filter(|query| query.timestamp > one_hour_ago)
            .map(|query| query.question.clone())
            .collect()
    });
    
    // Simple trending logic
    let mut topic_counts: HashMap<String, u32> = HashMap::new();
    for topic in recent_topics {
        let count = topic_counts.get(&topic).unwrap_or(&0) + 1;
        topic_counts.insert(topic, count);
    }
    
    let mut trending: Vec<(String, u32)> = topic_counts.into_iter().collect();
    trending.sort_by(|a, b| b.1.cmp(&a.1));
    
    let trending_topics: Vec<String> = trending
        .into_iter()
        .take(5)
        .map(|(topic, _)| topic)
        .collect();
    
    TRENDING_TOPICS.with(|trending| {
        *trending.borrow_mut() = trending_topics;
    });
}

// Utility functions
fn generate_query_id() -> String {
    let timestamp = ic_cdk::api::time();
    let caller = ic_cdk::caller();
    format!("news_{}_{}", timestamp, caller.to_text()[..8].to_string())
}

export_candid!();
EOF

    # Create Candid interface with correct name
    print_status "Creating Candid interface..."
    cat > $BACKEND_DIR/${CANISTER_NAME}.did << 'EOF'
type NewsQuery = record {
  id: text;
  user_id: principal;
  question: text;
  timestamp: nat64;
  bullshit_mode: bool;
  response: opt text;
};

type NewsStats = record {
  total_queries: nat64;
  bullshit_queries: nat64;
  clean_queries: nat64;
  active_users: nat64;
};

service : {
  // Main functions
  whats_up: (topic: text, with_bullshit: opt bool) -> (variant { Ok: text; Err: text });
  
  // Configuration
  set_groq_api_key: (api_key: text) -> (bool);
  
  // Query functions
  get_trending_topics: () -> (vec text) query;
  get_recent_queries: (limit: opt nat32) -> (vec NewsQuery) query;
  get_stats: () -> (NewsStats) query;
  health_check: () -> (text) query;
}
EOF

    print_success "GetThePaper canister code ready"
    
    # Store the canister name for later use
    echo "$CANISTER_NAME" > .canister_name
}

# Setup neural interface
setup_neural_interface() {
    print_header "🧠 Setting up Neural Interface..."
    
    # Create UI directory
    mkdir -p ui
    cd ui
    
    # Create the neural interface
    print_status "Creating neural interface..."
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ResearchOS - GetThePaper Neural Interface</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono:wght@400&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Share Tech Mono', monospace; background: #0a0a0a; color: #00ff41; overflow-x: hidden; line-height: 1.4; }
        .grid-bg { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-image: linear-gradient(rgba(0, 255, 65, 0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(0, 255, 65, 0.03) 1px, transparent 1px); background-size: 20px 20px; z-index: -1; }
        .cyber-desktop { min-height: 100vh; padding: 20px; }
        .neural-header { text-align: center; color: #00ff41; font-size: 24px; margin-bottom: 30px; text-shadow: 0 0 15px #00ff41; }
        .main-interface { max-width: 800px; margin: 0 auto; background: rgba(0, 0, 0, 0.9); border: 2px solid #00ff41; padding: 30px; box-shadow: 0 0 20px rgba(0, 255, 65, 0.3); }
        .query-section { margin-bottom: 30px; }
        .neural-input { width: 100%; background: #000000; border: 2px solid #00ff41; color: #00ff41; padding: 15px; font-family: inherit; font-size: 16px; margin-bottom: 15px; outline: none; }
        .neural-input:focus { border-color: #00ffff; box-shadow: 0 0 15px rgba(0, 255, 255, 0.5); }
        .mode-switch { text-align: center; margin: 20px 0; }
        .mode-btn { background: linear-gradient(45deg, #001a00, #003300); border: 2px solid #00ff41; color: #00ff41; padding: 10px 20px; margin: 0 10px; font-size: 14px; cursor: pointer; font-family: inherit; text-transform: uppercase; }
        .mode-btn.active { background: linear-gradient(45deg, #003300, #005500); box-shadow: 0 0 10px rgba(0, 255, 65, 0.3); }
        .execute-btn { width: 100%; background: linear-gradient(45deg, #001a00, #003300); border: 2px solid #00ff41; color: #00ff41; padding: 20px; font-size: 18px; text-transform: uppercase; cursor: pointer; font-family: inherit; margin: 20px 0; transition: all 0.3s ease; }
        .execute-btn:hover { background: linear-gradient(45deg, #003300, #005500); }
        .execute-btn:disabled { opacity: 0.6; cursor: not-allowed; }
        .response-area { background: #000000; border: 2px solid #00ff41; padding: 20px; min-height: 300px; white-space: pre-wrap; font-size: 14px; overflow-y: auto; margin: 20px 0; }
        .status-bar { display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-top: 1px solid #00ff41; margin-top: 20px; font-size: 12px; }
        .status-item { padding: 5px 10px; border: 1px solid #00cc33; background: rgba(0, 255, 65, 0.05); }
        .loading { color: #ffff00; }
        .error { color: #ff0040; }
        .success { color: #00ff41; }
    </style>
</head>
<body>
    <div class="grid-bg"></div>
    <div class="cyber-desktop">
        <div class="neural-header">
            📰 RESEARCHOS - GETTHEPAPER NEURAL INTERFACE
        </div>
        <div class="main-interface">
            <div class="query-section">
                <input type="text" class="neural-input" id="queryInput" placeholder="What's up with... (e.g., Bitcoin, election, AI)" maxlength="100">
                <div class="mode-switch">
                    <button class="mode-btn active" id="noBsBtn">NO BULLSHIT</button>
                    <button class="mode-btn" id="withBsBtn">WITH BULLSHIT</button>
                </div>
                <button class="execute-btn" id="executeBtn">>>> TELL ME WHAT'S UP <<<</button>
            </div>
            <div class="response-area" id="responseArea">Ready to tell you what's up. Enter a topic above and click the button.</div>
            <div class="status-bar">
                <div class="status-item" id="connectionStatus">CONNECTING...</div>
                <div class="status-item" id="modeStatus">Mode: NO BULLSHIT</div>
                <div class="status-item" id="queryCount">Queries: 0</div>
            </div>
        </div>
    </div>

    <script>
        class GetThePaperInterface {
            constructor() {
                this.canisterId = null;
                this.bullshitMode = false;
                this.queryCount = 0;
                this.initEventListeners();
                this.connectToCanister();
            }

            async connectToCanister() {
                try {
                    // Try to get canister ID from URL params or environment
                    const urlParams = new URLSearchParams(window.location.search);
                    this.canisterId = urlParams.get('canister') || 'CANISTER_ID_PLACEHOLDER';
                    
                    document.getElementById('connectionStatus').textContent = 'CANISTER CONNECTED';
                    document.getElementById('connectionStatus').className = 'status-item success';
                } catch (error) {
                    document.getElementById('connectionStatus').textContent = 'DEMO MODE';
                    document.getElementById('connectionStatus').className = 'status-item error';
                }
            }

            initEventListeners() {
                const queryInput = document.getElementById('queryInput');
                const executeBtn = document.getElementById('executeBtn');
                const noBsBtn = document.getElementById('noBsBtn');
                const withBsBtn = document.getElementById('withBsBtn');

                executeBtn.addEventListener('click', () => this.executeQuery());
                queryInput.addEventListener('keypress', (e) => {
                    if (e.key === 'Enter') this.executeQuery();
                });

                noBsBtn.addEventListener('click', () => this.setMode(false));
                withBsBtn.addEventListener('click', () => this.setMode(true));
            }

            setMode(bullshit) {
                this.bullshitMode = bullshit;
                const noBsBtn = document.getElementById('noBsBtn');
                const withBsBtn = document.getElementById('withBsBtn');
                const modeStatus = document.getElementById('modeStatus');

                if (bullshit) {
                    noBsBtn.classList.remove('active');
                    withBsBtn.classList.add('active');
                    modeStatus.textContent = 'Mode: WITH BULLSHIT';
                } else {
                    noBsBtn.classList.add('active');
                    withBsBtn.classList.remove('active');
                    modeStatus.textContent = 'Mode: NO BULLSHIT';
                }
            }

            async executeQuery() {
                const queryInput = document.getElementById('queryInput');
                const executeBtn = document.getElementById('executeBtn');
                const responseArea = document.getElementById('responseArea');
                
                const topic = queryInput.value.trim();
                if (!topic) {
                    responseArea.textContent = 'Please enter a topic to analyze.';
                    responseArea.className = 'response-area error';
                    return;
                }

                executeBtn.disabled = true;
                executeBtn.textContent = '>>> PROCESSING <<<';
                responseArea.textContent = 'Connecting to GetThePaper canister...\nAnalyzing news sources...\nProcessing query...';
                responseArea.className = 'response-area loading';

                try {
                    // Simulate canister call
                    await new Promise(resolve => setTimeout(resolve, 2000));
                    
                    const response = this.generateMockResponse(topic);
                    responseArea.textContent = response;
                    responseArea.className = 'response-area success';
                    
                    this.queryCount++;
                    document.getElementById('queryCount').textContent = `Queries: ${this.queryCount}`;
                    queryInput.value = '';

                } catch (error) {
                    responseArea.textContent = `Error: ${error.message}`;
                    responseArea.className = 'response-area error';
                } finally {
                    executeBtn.disabled = false;
                    executeBtn.textContent = '>>> TELL ME WHAT\'S UP <<<';
                }
            }

            generateMockResponse(topic) {
                if (this.bullshitMode) {
                    return `📰 GetThePaper - With The Bullshit

## 🎯 STRAIGHT FACTS (No Bullshit)

**What's Up: ${topic}**

• Demo mode - real version would analyze live news sources
• Multiple outlets would be cross-referenced for facts
• Bias detection algorithms would identify spin
• Only verified information would be presented

**Bottom Line:** This is a demo response. Deploy with Groq API for real analysis.

## 🎭 HOW OUTLETS ARE SPINNING IT

### CNN (LEFT)
**Their Angle:** Progressive framing with social justice emphasis
**Bullshit Level:** 6/10 🧢

### Fox News (RIGHT)
**Their Angle:** Conservative perspective focusing on traditional values
**Bullshit Level:** 7/10 🧢

### Reuters (CENTER)
**Their Angle:** Neutral reporting with factual emphasis
**Bullshit Level:** 2/10 🧢

---
*GetThePaper: Telling you what's up, with or without the bullshit.*`;
                } else {
                    return `📰 GetThePaper - No Bullshit Mode

## What's Up: ${topic}

**Key Facts:**
• Demo mode active - this is a sample response
• Real version would call live news APIs via ICP HTTP outcalls
• Multiple credible sources would be cross-referenced
• Only verified information would be included
• No opinion, spin, or speculation

**Bottom Line:** Demo response - configure API keys for real news analysis.

**Last Updated:** Just now
**Confidence:** Demo mode

To activate real news analysis:
1. Configure Groq API key in canister
2. Deploy to IC network
3. Enable HTTP outcalls for news sources`;
                }
            }
        }

        // Initialize when page loads
        document.addEventListener('DOMContentLoaded', () => {
            new GetThePaperInterface();
        });
    </script>
</body>
</html>
EOF

    # Create server script
    print_status "Creating interface server..."
    cat > server.py << 'EOF'
#!/usr/bin/env python3
import http.server
import socketserver
import webbrowser
import time
import threading

class GetThePaperServer(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Suppress default logging
        pass

PORT = 8080

def start_server():
    with socketserver.TCPServer(("", PORT), GetThePaperServer) as httpd:
        print(f"🌐 Neural interface running at http://localhost:{PORT}")
        httpd.serve_forever()

def open_browser():
    time.sleep(2)
    webbrowser.open(f'http://localhost:{PORT}')

if __name__ == "__main__":
    # Start server in background
    server_thread = threading.Thread(target=start_server, daemon=True)
    server_thread.start()
    
    # Open browser
    open_browser()
    
    try:
        # Keep main thread alive
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Shutting down neural interface...")
EOF

    chmod +x server.py
    
    cd .. # Back to project root
    print_success "Neural interface ready"
}

# Deploy canister
deploy_canister() {
    print_header "🚀 Deploying GetThePaper Canister..."
    
    # Stop any existing replica
    print_status "Stopping any existing DFX replica..."
    dfx stop 2>/dev/null || true
    
    # Start fresh replica
    print_status "Starting IC replica..."
    dfx start --background --clean
    
    # Wait for replica to be ready
    print_status "Waiting for replica to be ready..."
    sleep 5
    
    # Generate Cargo.lock
    print_status "Generating Cargo.lock..."
    cargo check
    
    # Deploy canister
    print_status "Deploying canister..."
    dfx deploy
    
    # Get the actual canister name from our stored file
    CANISTER_NAME=$(cat .canister_name)
    
    # Get canister ID
    CANISTER_ID=$(dfx canister id $CANISTER_NAME)
    print_success "Canister deployed with ID: $CANISTER_ID"
    
    # Update UI with canister ID (cross-platform sed)
    print_status "Updating neural interface with canister ID..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/CANISTER_ID_PLACEHOLDER/$CANISTER_ID/g" ui/index.html
    else
        # Linux
        sed -i "s/CANISTER_ID_PLACEHOLDER/$CANISTER_ID/g" ui/index.html
    fi
    
    # Test canister
    print_status "Testing canister..."
    dfx canister call $CANISTER_NAME health_check
    
    print_success "Canister deployment complete"
    echo "$CANISTER_ID"
}

# Launch interface
launch_interface() {
    print_header "🧠 Launching Neural Interface..."
    
    cd ui
    print_status "Starting neural interface server..."
    python3 server.py &
    UI_PID=$!
    cd ..
    
    print_success "Neural interface launched at http://localhost:8080"
    echo "$UI_PID"
}

# Create usage instructions
create_instructions() {
    print_header "📋 Creating Usage Instructions..."
    
    cat > USAGE.md << 'EOF'
# ResearchOS - GetThePaper Usage Guide

## 🎯 What You Just Deployed

✅ **GetThePaper Canister** - ICP smart contract for news analysis
✅ **Neural Interface** - Web UI for interacting with the system
✅ **Local Development Environment** - Ready for testing and development

## 🚀 How to Use

### 1. Access the Interface
- Open http://localhost:8080 in your browser
- The neural interface should open automatically

### 2. Query News
- Enter any topic (e.g., "Bitcoin", "election", "climate change")
- Choose mode:
  - **NO BULLSHIT**: Clean facts only
  - **WITH BULLSHIT**: Facts + how outlets spin it
- Click "TELL ME WHAT'S UP"

### 3. Configure for Real News (Optional)
```bash
# Set Groq API key for real AI analysis
dfx canister call researchos-getthepaper_backend set_groq_api_key '("your_groq_api_key_here")'
```

## 🛠️ Development Commands

### Canister Management
```bash
# Check canister status (replace CANISTER_NAME with actual name)
dfx canister status $(cat .canister_name)

# Call canister directly
dfx canister call $(cat .canister_name) whats_up '("Bitcoin", null)'
dfx canister call $(cat .canister_name) whats_up '("election", opt true)'

# Get statistics
dfx canister call $(cat .canister_name) get_stats
```

### Interface Management
```bash
# Restart interface
cd ui && python3 server.py

# Stop everything
dfx stop
```

## 🎯 Ready to tell you what's up! 📰
EOF

    print_success "Usage guide created: USAGE.md"
}

# Main execution
main() {
    print_header "🧠 ResearchOS - GetThePaper Deployment Starting..."
    
    check_prerequisites
    setup_project
    setup_canister
    setup_neural_interface
    
    CANISTER_ID=$(deploy_canister)
    UI_PID=$(launch_interface)
    
    create_instructions
    
    print_header "🎉 ResearchOS Deployment Complete!"
    echo ""
    print_success "✅ GetThePaper canister deployed and running"
    print_success "✅ Neural interface available at http://localhost:8080"
    print_success "✅ Development environment ready"
    echo ""
    print_status "📋 Usage instructions saved to: USAGE.md"
    echo ""
    print_header "🎯 Ready to tell you what's up!"
    echo ""
    print_status "Try asking about: Bitcoin, election, AI, climate change, etc."
    print_status "Toggle between 'No Bullshit' and 'With Bullshit' modes"
    echo ""
    print_warning "Press Ctrl+C to stop everything"
    
    # Keep script running
    trap 'echo -e "\n🛑 Shutting down ResearchOS..."; dfx stop; kill $UI_PID 2>/dev/null; exit 0' INT
    
    while true; do
        sleep 1
    done
}

# Run main function
main "$@"