# ResearchOS

A decentralized knowledge coordination system built on the Internet Computer Protocol (ICP) that demonstrates autonomous AI agents working together to maintain and update shared knowledge bases.

## Project Overview

ResearchOS showcases how ICP's unique canister features enable persistent, autonomous knowledge systems. The current implementation demonstrates a news monitoring application where AI agents coordinate to keep information current without external infrastructure.

### Key ICP Features Utilized

- **HTTP Outcalls**: Direct API calls to Groq AI service without external oracles or bridges
- **Timers**: Autonomous background agents that update knowledge every 20 minutes
- **Persistent Memory**: Knowledge survives canister upgrades and maintains state
- **Single Canister Architecture**: All coordination happens on-chain with minimal complexity

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Single ResearchOS Canister              │
├─────────────────────────────────────────────────────────────┤
│  Agent 1: User-Triggered News Fetcher                      │
│  ├─ Responds to user queries                               │
│  ├─ Smart caching (20-minute freshness)                    │
│  └─ Adds topics to monitoring list                         │
│                                                             │
│  Agent 2: Autonomous Monitor                               │
│  ├─ Timer-based updates every 20 minutes                   │
│  ├─ Updates all monitored topics                           │
│  └─ Maintains knowledge freshness                          │
│                                                             │
│  Storage Layer                                              │
│  ├─ Topic news cache                                       │
│  ├─ Agent activity logs                                    │
│  └─ Monitored topics list                                  │
└─────────────────────────────────────────────────────────────┘
```

## News Application Example

The current implementation demonstrates a news monitoring system where:

1. **User requests news** about a trending topic
2. **Agent 1** fetches latest information from Groq AI
3. **System adds topic** to autonomous monitoring list
4. **Agent 2** automatically updates** all monitored topics every 20 minutes
5. **Users get fresh data** without waiting for API calls

This showcases the core ResearchOS concept: AI agents that coordinate to maintain shared, up-to-date knowledge.

## Future Roadmap

ResearchOS is designed as a foundational platform for knowledge coordination. Future developments include:

- **Multi-AI Integration**: Source knowledge from OpenAI, Claude, Gemini, and other AI services
- **Knowledge Synthesis**: Agents that cross-reference and validate information across sources
- **Specialized Domains**: Financial analysis, research coordination, market intelligence
- **Inter-Canister Scaling**: Horizontal scaling across multiple specialized canisters
- **Knowledge Graphs**: Relationship mapping between different pieces of information

## Demo Video

[TODO: Link to demo video with code walkthrough and architecture explanation]

- Code walkthrough of both AI agents
- ICP feature integration (HTTP outcalls, timers, persistence)
- Live deployment and testing
- Architecture explanation and future roadmap

## Local Development

### Prerequisites
- DFX SDK 0.15.0 or later
- Rust (latest stable)
- Node.js 16+ (for frontend development)

### Setup
```bash
# Clone repository
git clone https://github.com/yourusername/ResearchOS
cd ResearchOS

# Install dependencies
npm install

# Start local replica
dfx start --clean

# Deploy canister
dfx deploy
```

### Testing
```bash
# Health check
dfx canister call research_ai_simple_backend health_check

# Request news
dfx canister call research_ai_simple_backend get_latest_news '(record {
  topic = "blockchain technology"
})'

# View monitored topics
dfx canister call research_ai_simple_backend get_monitored_topics

# Check recent activity
dfx canister call research_ai_simple_backend get_recent_logs
```

## API Reference

### Core Functions

#### `get_latest_news(request: NewsQuery) -> NewsResponse`
Fetches latest news for a topic. Uses cache if data is less than 20 minutes old.

#### `get_monitored_topics() -> Vec<String>`
Returns list of topics currently being monitored by autonomous agent.

#### `get_all_cached_news() -> Vec<TopicNews>`
Returns all cached news data with timestamps.

#### `get_recent_logs() -> Vec<AgentLog>`
Returns recent agent activity logs for debugging.

## License

Apache 2.0 - see LICENSE file for details.

---

ResearchOS represents the future of decentralized knowledge systems - where AI agents coordinate autonomously to maintain fresh, reliable information without centralized infrastructure.