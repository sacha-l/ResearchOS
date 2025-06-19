# ResearchOS

Autonomous AI agents on ICP that coordinate to maintain fresh, up-to-date knowledge bases. Built to demonstrate how ICP's unique features enable decentralized research systems.

## What It Does

ResearchOS runs a **news monitoring system** where AI agents work together to keep information current:

- **Ask for news** on any topic → Get instant results from Groq AI
- **System starts monitoring** → Topic gets auto-updated every 20 minutes  
- **Smart caching** → Repeated requests return instantly (no API delays)
- **Grows autonomously** → More topics = more comprehensive monitoring

## User Flow

```
1. User: "What's the latest on AI?"
   ↓
2. Agent fetches fresh news from Groq
   ↓  
3. System caches result + starts monitoring "AI" topic
   ↓
4. Every 20 minutes: Background agent updates all monitored topics
   ↓
5. User asks again → Gets cached data instantly
```

## ICP Features Showcased

- **HTTP Outcalls**: Direct API calls to Groq without oracles
- **Timers**: Autonomous 20-minute update cycles  
- **Persistent Storage**: Knowledge survives canister upgrades
- **Single Canister**: All coordination happens on-chain

## Quick Demo

Run the complete development and user journey:

```bash
chmod +x demo_user_journey.sh
./demo_user_journey.sh
```

**What the script does:**
- Compiles and deploys ResearchOS locally
- Demonstrates user requesting news on multiple topics
- Shows smart caching and autonomous monitoring in action  
- Reveals agent activity logs and system growth
- **Runtime**: 5-7 minutes

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Single ResearchOS Canister              │
├─────────────────────────────────────────────────────────────┤
│  Agent 1: User-Triggered (responds to requests)            │
│  Agent 2: Autonomous Monitor (20-min updates)              │
│  Storage: News cache + Agent logs + Topics list            │
└─────────────────────────────────────────────────────────────┘
```

## Local Development

### Prerequisites
- DFX SDK 0.15.0+
- Rust (latest stable)

### Setup
```bash
git clone https://github.com/yourusername/researchos
cd researchos
dfx start --clean
dfx deploy
```

### Core API
```bash
# Get news (starts monitoring)
dfx canister call research_ai_simple_backend get_latest_news '(record {
  topic = "artificial intelligence"
})'

# Check what's being monitored
dfx canister call research_ai_simple_backend get_monitored_topics

# View agent activity
dfx canister call research_ai_simple_backend get_recent_logs
```

## Why ResearchOS?

**Current news apps** require constant manual refreshing and single-source information.

**ResearchOS** creates an autonomous research network that:
- Maintains freshness automatically
- Builds knowledge over time  
- Operates without centralized infrastructure
- Gets smarter with each user interaction

## Future Roadmap

- **Multi-AI Integration**: OpenAI, Claude, Gemini sources
- **Knowledge Synthesis**: Cross-reference validation  
- **Specialized Domains**: Finance, research, market intelligence
- **Frontend Interface**: User-friendly web app

## Hackathon Submission

**New Features Built**: Complete autonomous agent coordination system using ICP timers, HTTP outcalls, and persistent storage.

**Canister ID**: TODO

**License**: Apache 2.0

---

ResearchOS demonstrates the future of decentralized knowledge systems where AI agents coordinate autonomously to maintain reliable, current information.