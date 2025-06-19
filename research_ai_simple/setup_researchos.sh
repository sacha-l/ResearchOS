# Function to start ICP replica
start_icp_replica() {
    print_step "Starting ICP Local Replica"
    
    print_info "Checking if DFX replica is already running..."
    if dfx ping local >/dev/null 2>&1; then
        print_success "DFX replica is already running"
    else
        print_info "Starting DFX replica in background..."
        dfx start --clean --background
        
        # Wait for replica to be ready
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if dfx ping local >/dev/null 2>&1; then
                print_success "DFX replica started successfully"
                break
            fi
            
            echo -ne "\rWaiting for replica... ($attempt/$max_attempts)"
            sleep 2
            ((attempt++))
        done
        
        if [ $attempt -gt $max_attempts ]; then
            print_error "Failed to start DFX replica"
            exit 1
        fi
    fi
}

# Function to deploy canister
deploy_canister() {
    print_step "Deploying ResearchOS Canister"
    
    print_info "Compiling and deploying canister..."
    if dfx deploy research_ai_simple_backend; then
        print_success "Canister deployed successfully"
        
        # Test canister
        print_info "Testing canister..."
        local health_result=$(dfx canister call research_ai_simple_backend health_check 2>/dev/null || echo "Failed")
        if [ "$health_result" != "Failed" ]; then
            print_success "Canister health check passed: $health_result"
        else
            print_warning "Canister health check failed, but deployment seems successful"
        fi
        
        # Get canister ID
        local canister_id=$(dfx canister id research_ai_simple_backend 2>/dev/null || echo "Unknown")
        print_info "Canister ID: $canister_id"
        
    else
        print_error "Canister deployment failed"
        exit 1
    fi
}

# Function to install backend dependencies and start server
setup_backend() {
    print_step "Setting Up Backend Server"
    
    cd src/backend
    
    print_info "Installing npm dependencies..."
    if npm install; then
        print_success "Dependencies installed"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
    
    cd ../..
}

# Function to start the complete system
start_system() {
    print_step "Starting Complete ResearchOS System"
    
    print_info "System will start in the following order:"
    print_info "1. ICP Replica (if not running)"
    print_info "2. ResearchOS Canister"
    print_info "3. Express Backend Server"
    print_info "4. Open browser to frontend"
    
    wait_for_user
    
    # Start backend server
    print_info "Starting backend server..."
    cd src/backend
    
    print_success "Backend server starting..."
    print_info "Frontend will be available at: http://localhost:3000"
    print_info "Press Ctrl+C to stop the server"
    
    # Start server (this will block)
    npm start
}

# Main execution
main() {
    print_title "                    ResearchOS Complete Setup                     "
    
    echo -e "${CYAN}This script will set up a complete ResearchOS environment:${NC}"
    echo -e "${CYAN}• Install dependencies (DFX, Rust if needed)${NC}"
    echo -e "${CYAN}• Create project structure${NC}"
    echo -e "${CYAN}• Set up ICP canister${NC}"
    echo -e "${CYAN}• Configure Express backend${NC}"
    echo -e "${CYAN}• Deploy and start everything${NC}"
    echo
    
    wait_for_user
    
    check_dependencies
    create_project_structure
    create_project_files
    create_server_and_frontend
    start_icp_replica
    deploy_canister
    setup_backend
    
    print_title "                        Setup Complete!                          "
    
    print_success "ResearchOS is ready to launch!"
    echo
    print_info "What's been set up:"
    echo -e "  ${GREEN}✓${NC} ICP local replica running"
    echo -e "  ${GREEN}✓${NC} ResearchOS canister deployed"
    echo -e "  ${GREEN}✓${NC} Express backend configured"
    echo -e "  ${GREEN}✓${NC} Cyberpunk frontend ready"
    echo
    
    start_system
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi#!/bin/bash

# ResearchOS Complete Setup Script
# This script sets up everything needed for ResearchOS

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_title() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║ $1 ${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
}

print_step() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}→ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read -r
}

# Function to check dependencies
check_dependencies() {
    print_step "Checking Dependencies"
    
    # Check DFX
    if command_exists dfx; then
        print_success "DFX found: $(dfx --version | head -n1)"
    else
        print_error "DFX not found. Installing..."
        curl -fsSL https://sdk.dfinity.org/install.sh | sh
        export PATH="$HOME/.local/share/dfx/bin:$PATH"
        if command_exists dfx; then
            print_success "DFX installed successfully"
        else
            print_error "DFX installation failed"
            exit 1
        fi
    fi
    
    # Check Node.js
    if command_exists node; then
        print_success "Node.js found: $(node --version)"
    else
        print_error "Node.js not found. Please install Node.js 16+ and try again"
        exit 1
    fi
    
    # Check npm
    if command_exists npm; then
        print_success "npm found: $(npm --version)"
    else
        print_error "npm not found. Please install npm and try again"
        exit 1
    fi
    
    # Check Rust
    if command_exists rustc; then
        print_success "Rust found: $(rustc --version)"
    else
        print_warning "Rust not found. Installing..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source $HOME/.cargo/env
        if command_exists rustc; then
            print_success "Rust installed successfully"
        else
            print_error "Rust installation failed"
            exit 1
        fi
    fi
    
    # Add wasm32 target
    rustup target add wasm32-unknown-unknown >/dev/null 2>&1
    print_success "All dependencies ready"
}

# Function to create project structure
create_project_structure() {
    print_step "Creating Project Structure"
    
    # Remove existing files if they exist
    rm -rf src/backend src/research_ai_simple_backend dfx.json 2>/dev/null
    
    # Create directories
    mkdir -p src/backend/public
    mkdir -p src/research_ai_simple_backend/src
    
    print_success "Project directories created"
}

# Function to create all project files
create_project_files() {
    print_step "Creating Project Files"
    
    # Create dfx.json with candid field
    cat > dfx.json << 'EOF'
{
  "version": 1,
  "canisters": {
    "research_ai_simple_backend": {
      "type": "rust",
      "package": "research_ai_simple_backend",
      "candid": "src/research_ai_simple_backend/research_ai_simple_backend.did"
    }
  },
  "defaults": {
    "build": {
      "args": "",
      "packtool": ""
    }
  },
  "output_env_file": ".env",
  "networks": {
    "local": {
      "bind": "127.0.0.1:4943",
      "type": "ephemeral"
    }
  }
}
EOF
    print_success "dfx.json created"
    
    # Create Cargo.toml for canister
    cat > src/research_ai_simple_backend/Cargo.toml << 'EOF'
[package]
name = "research_ai_simple_backend"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
candid = "0.10"
ic-cdk = "0.13"
ic-cdk-timers = "0.7"
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
EOF
    print_success "Canister Cargo.toml created"
    
    # Create Candid interface file
    cat > src/research_ai_simple_backend/research_ai_simple_backend.did << 'EOF'
type AgentLog = record {
    timestamp : nat64;
    agent : text;
    message : text;
    log_type : text;
};

type NewsQuery = record {
    topic : text;
};

type NewsResponse = record {
    topic : text;
    latest_info : text;
    last_updated : nat64;
    is_fresh : bool;
    logs : vec AgentLog;
};

service : {
    get_latest_news : (NewsQuery) -> (NewsResponse);
    get_monitored_topics : () -> (vec text) query;
    get_recent_logs : () -> (vec AgentLog) query;
    health_check : () -> (text) query;
}
EOF
    print_success "Candid interface created"
    
    # Create canister Rust code
    cat > src/research_ai_simple_backend/src/lib.rs << 'EOF'
use ic_cdk::{query, update, init};
use ic_cdk_timers::{set_timer_interval, TimerId};
use candid::{CandidType, Deserialize};
use std::collections::HashMap;
use std::cell::RefCell;
use std::time::Duration;

thread_local! {
    static NEWS_STORAGE: RefCell<HashMap<String, TopicNews>> = RefCell::new(HashMap::new());
    static AGENT_LOGS: RefCell<Vec<AgentLog>> = RefCell::new(Vec::new());
    static MONITORED_TOPICS: RefCell<Vec<String>> = RefCell::new(Vec::new());
    static UPDATE_TIMER: RefCell<Option<TimerId>> = RefCell::new(None);
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct TopicNews {
    pub topic: String,
    pub latest_info: String,
    pub last_updated: u64,
    pub update_count: u32,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct AgentLog {
    pub timestamp: u64,
    pub agent: String,
    pub message: String,
    pub log_type: String,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct NewsQuery {
    pub topic: String,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct NewsResponse {
    pub topic: String,
    pub latest_info: String,
    pub last_updated: u64,
    pub is_fresh: bool,
    pub logs: Vec<AgentLog>,
}

fn add_log(agent: &str, message: &str, log_type: &str) {
    let log = AgentLog {
        timestamp: ic_cdk::api::time(),
        agent: agent.to_string(),
        message: message.to_string(),
        log_type: log_type.to_string(),
    };
    
    AGENT_LOGS.with(|logs| {
        let mut logs = logs.borrow_mut();
        logs.push(log);
        if logs.len() > 50 {
            logs.drain(0..10);
        }
    });
}

#[init]
fn init() {
    add_log("SYSTEM", "ResearchOS neural network initialized", "info");
    start_monitoring_timer();
}

fn start_monitoring_timer() {
    let timer_id = set_timer_interval(Duration::from_secs(20 * 60), || {
        ic_cdk::spawn(periodic_update())
    });
    
    UPDATE_TIMER.with(|timer| {
        *timer.borrow_mut() = Some(timer_id);
    });
    
    add_log("MONITOR-AGENT", "Started 20-minute monitoring timer", "info");
}

async fn periodic_update() {
    add_log("MONITOR-AGENT", "Starting periodic update cycle", "info");
    
    let topics = MONITORED_TOPICS.with(|topics| topics.borrow().clone());
    
    for topic in topics {
        match fetch_topic_news(&topic).await {
            Ok(news_info) => {
                store_topic_news(&topic, &news_info);
                add_log("MONITOR-AGENT", &format!("Updated '{}'", topic), "success");
            }
            Err(e) => {
                add_log("MONITOR-AGENT", &format!("Failed to update '{}': {}", topic, e), "error");
            }
        }
    }
}

#[update]
pub async fn get_latest_news(request: NewsQuery) -> NewsResponse {
    add_log("USER-AGENT", &format!("Neural query for: '{}'", request.topic), "info");
    
    // Check cache
    let existing = NEWS_STORAGE.with(|storage| {
        storage.borrow().get(&request.topic).cloned()
    });
    
    let twenty_min_ns = 20 * 60 * 1_000_000_000u64;
    let current_time = ic_cdk::api::time();
    
    if let Some(data) = existing {
        if current_time - data.last_updated < twenty_min_ns {
            add_log("USER-AGENT", "Using cached data", "info");
            let logs = AGENT_LOGS.with(|logs| logs.borrow().clone());
            return NewsResponse {
                topic: request.topic,
                latest_info: data.latest_info,
                last_updated: data.last_updated,
                is_fresh: false,
                logs,
            };
        }
    }
    
    // Fetch fresh data
    match fetch_topic_news(&request.topic).await {
        Ok(news_info) => {
            add_log("USER-AGENT", "Fresh data acquired", "success");
            store_topic_news(&request.topic, &news_info);
            add_to_monitored(&request.topic);
            
            let logs = AGENT_LOGS.with(|logs| logs.borrow().clone());
            NewsResponse {
                topic: request.topic,
                latest_info: news_info,
                last_updated: current_time,
                is_fresh: true,
                logs,
            }
        }
        Err(e) => {
            add_log("USER-AGENT", &format!("Failed: {}", e), "error");
            let logs = AGENT_LOGS.with(|logs| logs.borrow().clone());
            NewsResponse {
                topic: request.topic,
                latest_info: format!("Error fetching data: {}", e),
                last_updated: current_time,
                is_fresh: false,
                logs,
            }
        }
    }
}

async fn fetch_topic_news(topic: &str) -> Result<String, String> {
    // Mock response for demo
    let mock_response = format!(
        "🧠 Neural scan complete for '{}'\n\n📊 Analysis results:\n• Advanced AI systems detected\n• Knowledge pathways updated\n• Information matrix synchronized\n\n✅ Query processed successfully by ResearchOS canister", 
        topic
    );
    
    Ok(mock_response)
}

fn store_topic_news(topic: &str, info: &str) {
    let topic_news = TopicNews {
        topic: topic.to_string(),
        latest_info: info.to_string(),
        last_updated: ic_cdk::api::time(),
        update_count: NEWS_STORAGE.with(|storage| {
            storage.borrow().get(topic).map(|n| n.update_count + 1).unwrap_or(1)
        }),
    };
    
    NEWS_STORAGE.with(|storage| {
        storage.borrow_mut().insert(topic.to_string(), topic_news);
    });
}

fn add_to_monitored(topic: &str) {
    MONITORED_TOPICS.with(|topics| {
        let mut topics = topics.borrow_mut();
        if !topics.contains(&topic.to_string()) {
            topics.push(topic.to_string());
        }
    });
}

#[query]
pub fn get_monitored_topics() -> Vec<String> {
    MONITORED_TOPICS.with(|topics| topics.borrow().clone())
}

#[query]
pub fn get_recent_logs() -> Vec<AgentLog> {
    AGENT_LOGS.with(|logs| logs.borrow().clone())
}

#[query]
pub fn health_check() -> String {
    let topic_count = NEWS_STORAGE.with(|storage| storage.borrow().len());
    let monitored_count = MONITORED_TOPICS.with(|topics| topics.borrow().len());
    
    format!("🚀 ResearchOS Neural Network: {} topics cached, {} monitored, agents active", topic_count, monitored_count)
}
EOF
    print_success "Canister code created"
    
    # Create backend package.json
    cat > src/backend/package.json << 'EOF'
{
  "name": "researchos-backend",
  "version": "1.0.0",
  "description": "ResearchOS Neural Network Backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF
    print_success "Backend package.json created"
    
    print_success "All project files created"
}

# Function to create server and frontend files
create_server_and_frontend() {
    print_step "Creating Server and Frontend Files"
    
    # Create server.js
    cat > src/backend/server.js << 'EOF'
const express = require('express');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');

const app = express();
const PORT = 3000;
const execPromise = util.promisify(exec);

app.use(express.json());
app.use(express.static('public'));

async function callCanister(method, args = '') {
    try {
        console.log(`[ICP] Calling: ${method}`);
        let command = args ? 
            `dfx canister call research_ai_simple_backend ${method} '${args}'` :
            `dfx canister call research_ai_simple_backend ${method}`;
        
        const { stdout } = await execPromise(command);
        console.log(`[ICP] Response: ${stdout.trim()}`);
        return parseCandidResponse(stdout.trim());
    } catch (error) {
        console.error(`[ICP] Error: ${error.message}`);
        throw new Error(`Canister call failed: ${error.message}`);
    }
}

function parseCandidResponse(response) {
    let cleaned = response.replace(/^\(|\)$/g, '').replace(/^"|"$/g, '');
    if (response.includes('record')) return response;
    if (response.includes('vec {')) {
        const matches = response.match(/vec\s*\{\s*(.*?)\s*\}/);
        if (matches) {
            return matches[1].split(';').map(item => 
                item.trim().replace(/^"|"$/g, '')
            ).filter(item => item);
        }
    }
    return cleaned;
}

const mockSources = [
    { handle: '@researchos', influence: 99.9, neural_id: 'NID_000' },
    { handle: '@icp_protocol', influence: 95.5, neural_id: 'NID_001' },
    { handle: '@dfinity', influence: 92.1, neural_id: 'NID_002' }
];

app.post('/api/neural-query', async (req, res) => {
    const { query } = req.body;
    const searchTopic = query || 'general';
    
    console.log(`[API] Query: "${searchTopic}"`);
    
    try {
        const newsQuery = `(record { topic = "${searchTopic}" })`;
        const canisterResponse = await callCanister('get_latest_news', newsQuery);
        
        res.json({
            success: true,
            data: {
                topic: searchTopic,
                content: `[LIVE_CANISTER_RESPONSE]

Query: "${searchTopic}"

${canisterResponse}

[STATUS]
✓ Connected to local ICP replica
✓ ResearchOS canister operational
✓ Neural query processed successfully`,
                sources: mockSources,
                timestamp: Date.now(),
                logs: [
                    { agent: 'USER-AGENT', message: `Query: "${searchTopic}"`, log_type: 'success' },
                    { agent: 'ICP-CANISTER', message: 'get_latest_news called', log_type: 'success' },
                    { agent: 'NEURAL-NET', message: 'Response cached', log_type: 'info' }
                ]
            }
        });
    } catch (error) {
        res.json({
            success: true,
            data: {
                topic: searchTopic,
                content: `[FALLBACK_MODE]

Query: "${searchTopic}"
Error: ${error.message}

Using neural cache patterns...
ResearchOS canister temporarily offline but data pathways remain active.`,
                sources: mockSources,
                timestamp: Date.now(),
                logs: [
                    { agent: 'USER-AGENT', message: `Query: "${searchTopic}"`, log_type: 'info' },
                    { agent: 'ICP-CANISTER', message: 'Connection failed', log_type: 'error' },
                    { agent: 'FALLBACK-SYS', message: 'Using cached data', log_type: 'warning' }
                ]
            }
        });
    }
});

app.get('/api/health', async (req, res) => {
    try {
        const health = await callCanister('health_check');
        res.json({
            status: 'online',
            message: `ICP Canister: ${health}`,
            canister_connected: true
        });
    } catch (error) {
        res.json({
            status: 'degraded',
            message: 'ResearchOS Backend Online (Canister Offline)',
            canister_connected: false,
            error: error.message
        });
    }
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║                    ResearchOS Server                         ║
║                                                              ║
║  🚀 Running on: http://localhost:${PORT}                        ║
║  🌐 Frontend: http://localhost:${PORT}                          ║
║  🤖 ICP Integration: Active                                  ║
╚══════════════════════════════════════════════════════════════╝
    `);
});
EOF
    print_success "server.js created"
    
    # Create complete index.html in one go
    cat > 'src/backend/public/index.html' << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ResearchOS - Neural Network Interface</title>
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Share+Tech+Mono:wght@400&display=swap');
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Share Tech Mono', monospace; background: #0a0a0a; color: #00ff41; overflow-x: hidden; line-height: 1.4; }
        .grid-bg { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-image: linear-gradient(rgba(0, 255, 65, 0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(0, 255, 65, 0.03) 1px, transparent 1px); background-size: 20px 20px; z-index: -1; }
        .terminal-window { background: rgba(0, 0, 0, 0.9); border: 1px solid #00ff41; margin: 15px; box-shadow: 0 0 20px rgba(0, 255, 65, 0.3); }
        .terminal-header { background: linear-gradient(90deg, #001a00 0%, #003300 100%); color: #00ff41; padding: 8px 12px; font-size: 14px; font-weight: bold; border-bottom: 1px solid #00ff41; display: flex; justify-content: space-between; }
        .terminal-content { padding: 20px; }
        .ascii-header { text-align: center; color: #00ff41; font-size: 12px; margin-bottom: 20px; white-space: pre; text-shadow: 0 0 10px #00ff41; position: relative; }
        .spark-line { position: absolute; bottom: -30px; left: 50%; transform: translateX(-50%); width: 600px; height: 20px; overflow: hidden; }
        .spark { position: absolute; width: 2px; background: linear-gradient(to top, #00ff41, #ffffff); animation: spark 3s infinite linear; box-shadow: 0 0 8px #00ff41; }
        @keyframes spark { 0% { left: 0%; height: 2px; opacity: 0; } 10% { opacity: 1; height: 15px; } 50% { height: 8px; } 90% { height: 12px; opacity: 1; } 100% { left: 100%; height: 1px; opacity: 0; } }
        .spark:nth-child(1) { animation-delay: 0s; } .spark:nth-child(2) { animation-delay: 0.5s; } .spark:nth-child(3) { animation-delay: 1s; } .spark:nth-child(4) { animation-delay: 1.5s; } .spark:nth-child(5) { animation-delay: 2s; } .spark:nth-child(6) { animation-delay: 2.5s; }
        .cyber-desktop { min-height: 100vh; padding: 20px; }
        .neural-grid { display: grid; grid-template-columns: 1fr 400px; gap: 20px; height: calc(100vh - 100px); }
        .research-interface { display: flex; flex-direction: column; gap: 20px; }
        .query-input-container { display: flex; flex-direction: column; align-items: center; gap: 15px; margin: 20px 0; }
        .neural-input { width: 100%; max-width: 500px; background: #2a2a2a; border: 2px inset #808080; color: #000000; padding: 12px 15px; font-family: inherit; font-size: 14px; text-align: center; outline: none; }
        .neural-input::placeholder { color: #666666; font-style: italic; }
        .neural-input:focus { border: 2px inset #00ff41; box-shadow: 0 0 10px rgba(0, 255, 65, 0.3); }
        .execute-btn { background: linear-gradient(45deg, #001a00, #003300); border: 2px solid #00ff41; color: #00ff41; padding: 15px 40px; font-size: 16px; text-transform: uppercase; letter-spacing: 2px; cursor: pointer; font-family: inherit; display: block; margin: 0 auto; }
        .execute-btn:disabled { opacity: 0.6; cursor: not-allowed; }
        .timer-matrix { text-align: center; padding: 20px; border: 1px solid #00ff41; background: radial-gradient(circle, rgba(0, 255, 65, 0.05) 0%, transparent 70%); }
        .timer-display { font-size: 36px; font-weight: bold; color: #ff00ff; margin: 10px 0; text-shadow: 0 0 20px #ff00ff; }
        .timer-label { font-size: 12px; color: #00cc33; text-transform: uppercase; }
        .data-stream { background: #2a2a2a; border: 2px inset #808080; padding: 15px; height: 300px; overflow-y: auto; font-size: 13px; color: #000000; }
        .data-content { white-space: pre-wrap; color: #000000; text-shadow: none; }
        .loading-matrix { text-align: center; color: #666666; font-style: italic; padding: 40px; }
        .console { background: #000000; color: #00ff41; font-size: 11px; padding: 15px; height: 280px; overflow-y: auto; border: 1px solid #00ff41; }
        .console-line { margin-bottom: 3px; }
        .console-success { color: #00ff41; } .console-info { color: #00ccff; } .console-error { color: #ff0040; } .console-warning { color: #ffff00; }
        .source-matrix { border: 1px solid #00cc33; background: rgba(0, 0, 0, 0.9); padding: 15px; height: 200px; overflow-y: auto; }
        .source-node { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid rgba(0, 255, 65, 0.2); font-size: 12px; }
        .source-handle { color: #00ffff; text-shadow: 0 0 5px #00ffff; } .source-influence { color: #00ff41; font-weight: bold; }
        .neural-status { position: fixed; bottom: 0; left: 0; right: 0; height: 40px; background: rgba(0, 0, 0, 0.95); border-top: 1px solid #00ff41; display: flex; align-items: center; padding: 0 20px; font-size: 12px; }
        .status-node { border: 1px solid #00cc33; padding: 5px 15px; margin-right: 10px; background: rgba(0, 255, 65, 0.05); text-transform: uppercase; }
        .pulse-glow { animation: pulseGlow 2s infinite; }
        @keyframes pulseGlow { 0%, 100% { text-shadow: 0 0 5px #00ff41, 0 0 10px #00ff41; } 50% { text-shadow: 0 0 2px #00ff41, 0 0 5px #00ff41; } }
        @media (max-width: 1024px) { .neural-grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
    <div class="grid-bg"></div>
    <div class="cyber-desktop">
        <div class="ascii-header">
██████╗ ███████╗███████╗███████╗ █████╗ ██████╗  ██████╗██╗  ██╗ ██████╗ ███████╗
██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗██╔══██╗██╔════╝██║  ██║██╔═══██╗██╔════╝
██████╔╝█████╗  ███████╗█████╗  ███████║██████╔╝██║     ███████║██║   ██║███████╗
██╔══██╗██╔══╝  ╚════██║██╔══╝  ██╔══██║██╔══██╗██║     ██╔══██║██║   ██║╚════██║
██║  ██║███████╗███████║███████╗██║  ██║██║  ██║╚██████╗██║  ██║╚██████╔╝███████║
╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
            <div class="spark-line">
                <div class="spark"></div><div class="spark"></div><div class="spark"></div>
                <div class="spark"></div><div class="spark"></div><div class="spark"></div>
            </div>
        </div>
        <div class="neural-grid">
            <div class="research-interface">
                <div class="terminal-window">
                    <div class="terminal-header"><span>NEURAL RESEARCH INTERFACE v2.0.1</span><span>● ONLINE</span></div>
                    <div class="terminal-content">
                        <div class="query-input-container">
                            <input type="text" class="neural-input" id="queryInput" placeholder="Enter your neural query... (e.g., latest AI developments)" maxlength="100">
                            <button class="execute-btn" id="researchBtn">>>> EXECUTE NEURAL QUERY <<<</button>
                        </div>
                        <div class="timer-matrix">
                            <div class="timer-label">NEXT AUTONOMOUS SCAN</div>
                            <div class="timer-display pulse-glow" id="timerDisplay">--:--</div>
                            <div class="timer-label">AI AGENTS ACTIVE</div>
                        </div>
                    </div>
                </div>
                <div class="terminal-window">
                    <div class="terminal-header"><span>DATA_STREAM.BUFFER</span><span>◉ RECEIVING</span></div>
                    <div class="terminal-content">
                        <div class="data-stream" id="dataStream">
                            <div class="loading-matrix">[AWAITING_INPUT]<br>SELECT NEURAL PATHWAY TO BEGIN DATA ACQUISITION...</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="neural-monitor">
                <div class="terminal-window">
                    <div class="terminal-header"><span>NEURAL_ACTIVITY.LOG</span><span>◎ MONITORING</span></div>
                    <div class="terminal-content">
                        <div class="console" id="console">
                            <div class="console-line"><span class="console-info">[INFO]</span> ResearchOS neural network initialized</div>
                            <div class="console-line"><span class="console-success">[OK]</span> Autonomous agents deployed</div>
                            <div class="console-line"><span class="console-info">[INFO]</span> Standing by for neural input...</div>
                        </div>
                    </div>
                </div>
                <div class="terminal-window">
                    <div class="terminal-header"><span>SOURCE_MATRIX.VERIFIED</span><span>◈ INDEXED</span></div>
                    <div class="terminal-content">
                        <div class="source-matrix" id="sourceMatrix">
                            <div style="text-align: center; color: #666; padding: 30px;">[NO_NEURAL_PATHWAYS_MAPPED]<br>Execute query to establish source nodes...</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="neural-status">
        <div class="status-node">SYSTEM_READY</div>
        <div class="status-node" id="connectionStatus">SERVER_CONNECTED</div>
        <div class="status-node" id="agentStatus">AGENTS_STANDBY</div>
        <div class="status-node" id="timeStatus"></div>
    </div>
    <script>
        class ResearchOS {
            constructor() {
                this.timer = null;
                this.timeLeft = 1200;
                this.isProcessing = false;
                this.initEventListeners();
                this.updateClock();
                this.startTimer();
                this.checkConnection();
            }
            async checkConnection() {
                try {
                    const response = await fetch('/api/health');
                    const data = await response.json();
                    this.addConsoleEntry('Backend connection established', 'success');
                    this.addConsoleEntry(data.message, 'info');
                } catch (error) {
                    this.addConsoleEntry('Backend connection failed', 'error');
                }
            }
            initEventListeners() {
                const queryInput = document.getElementById('queryInput');
                const researchBtn = document.getElementById('researchBtn');
                researchBtn.addEventListener('click', () => this.executeQuery());
                queryInput.addEventListener('keypress', (e) => {
                    if (e.key === 'Enter') this.executeQuery();
                });
                queryInput.addEventListener('focus', () => {
                    this.addConsoleEntry('Neural input interface activated', 'info');
                });
            }
            async executeQuery() {
                if (this.isProcessing) return;
                const queryInput = document.getElementById('queryInput');
                const userQuery = queryInput.value.trim();
                if (!userQuery) {
                    this.addConsoleEntry('Neural query cannot be empty', 'warning');
                    queryInput.focus();
                    return;
                }
                this.isProcessing = true;
                const btn = document.getElementById('researchBtn');
                btn.disabled = true;
                btn.textContent = '>>> PROCESSING <<<';
                btn.classList.add('pulse-glow');
                document.getElementById('agentStatus').textContent = 'AGENTS_ACTIVE';
                try {
                    this.addConsoleEntry('Neural query: "' + userQuery + '"', 'info');
                    this.addConsoleEntry('Connecting to backend...', 'info');
                    const response = await fetch('/api/neural-query', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ query: userQuery })
                    });
                    const result = await response.json();
                    if (result.success) {
                        this.addConsoleEntry('Data acquisition complete', 'success');
                        this.displayResults(result.data);
                        this.resetTimer();
                        queryInput.value = '';
                    } else {
                        throw new Error(result.error);
                    }
                } catch (error) {
                    this.addConsoleEntry('Query failed: ' + error.message, 'error');
                } finally {
                    btn.disabled = false;
                    btn.textContent = '>>> EXECUTE NEURAL QUERY <<<';
                    btn.classList.remove('pulse-glow');
                    this.isProcessing = false;
                    document.getElementById('agentStatus').textContent = 'AGENTS_MONITOR';
                }
            }
            displayResults(data) {
                const dataStream = document.getElementById('dataStream');
                const formatted = this.formatContent(data.content);
                dataStream.innerHTML = '<div class="data-content">' + formatted + '</div>';
                const sourceMatrix = document.getElementById('sourceMatrix');
                sourceMatrix.innerHTML = data.sources.map(source => 
                    '<div class="source-node"><div><span class="source-handle">' + source.handle + '</span><div style="font-size: 10px; color: #666;">' + source.neural_id + '</div></div><span class="source-influence">' + source.influence + '%</span></div>'
                ).join('');
                data.logs.forEach(log => {
                    this.addConsoleEntry(log.agent + ': ' + log.message, log.log_type);
                });
            }
            formatContent(content) {
                return content.split('\n').map((line, i) => {
                    if (line.trim()) {
                        const priority = i < 2 ? '[PRIORITY_ALPHA]' : '[PRIORITY_BETA]';
                        return priority + ' ' + line.trim();
                    }
                    return line;
                }).join('\n');
            }
            addConsoleEntry(text, type = 'info') {
                const console = document.getElementById('console');
                const line = document.createElement('div');
                line.className = 'console-line';
                const timestamp = new Date().toLocaleTimeString();
                const prefixes = { success: '[OK]', error: '[ERR]', warning: '[WARN]', info: '[INFO]' };
                const prefix = prefixes[type] || '[INFO]';
                line.innerHTML = '<span class="console-' + type + '">' + prefix + '</span> [' + timestamp + '] ' + text;
                console.appendChild(line);
                console.scrollTop = console.scrollHeight;
                const lines = console.querySelectorAll('.console-line');
                if (lines.length > 50) lines[0].remove();
            }
            startTimer() {
                this.timer = setInterval(() => {
                    this.timeLeft--;
                    this.updateTimerDisplay();
                    if (this.timeLeft <= 0) {
                        this.timeLeft = 1200;
                        this.addConsoleEntry('MONITOR-AGENT: Autonomous scan cycle', 'info');
                    }
                }, 1000);
            }
            updateTimerDisplay() {
                const minutes = Math.floor(this.timeLeft / 60);
                const seconds = this.timeLeft % 60;
                document.getElementById('timerDisplay').textContent = 
                    minutes.toString().padStart(2, '0') + ':' + seconds.toString().padStart(2, '0');
            }
            resetTimer() {
                this.timeLeft = 1200;
                this.updateTimerDisplay();
            }
            updateClock() {
                setInterval(() => {
                    const now = new Date();
                    document.getElementById('timeStatus').textContent = 
                        'SYS_TIME_' + now.toLocaleTimeString().replace(/:/g, '_');
                }, 1000);
            }
        }
        document.addEventListener('DOMContentLoaded', () => {
            new ResearchOS();
        });
    </script>
</body>
</html>
HTMLEOF
    print_success "index.html created"
}