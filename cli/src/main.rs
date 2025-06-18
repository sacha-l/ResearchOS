use anyhow::Result;
use candid::{CandidType, Decode, Encode, Principal};
use clap::{Parser, Subcommand};
use ic_agent::{Agent, Identity};
use ic_agent::identity::AnonymousIdentity;
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Parser)]
#[command(name = "research-ai")]
#[command(about = "A CLI for interacting with the decentralized research AI network")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
    
    #[arg(long, default_value = "http://localhost:4943")]
    ic_url: String,
    
    #[arg(long)]
    canister_id: Option<String>,
}

#[derive(Subcommand)]
enum Commands {
    /// Submit a research query
    Query {
        /// The research question to ask
        #[arg(short, long)]
        question: String,
        
        /// Optional user identifier
        #[arg(short, long)]
        user_id: Option<String>,
    },
    /// Get query results by ID
    GetResult {
        /// Query ID to retrieve
        #[arg(short, long)]
        query_id: String,
    },
    /// List all queries for a user
    ListQueries {
        /// User ID to list queries for
        #[arg(short, long)]
        user_id: String,
    },
    /// Get canister stats
    Stats,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
struct ResearchQuery {
    id: String,
    user_id: String,
    question: String,
    timestamp: u64,
    status: QueryStatus,
    ai_response: Option<String>,
    metadata: Option<String>,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
enum QueryStatus {
    Pending,
    Processing,
    Completed,
    Failed,
}

#[derive(CandidType, Serialize, Deserialize)]
struct QueryRequest {
    question: String,
    user_id: String,
}

#[derive(CandidType, Serialize, Deserialize)]
struct QueryStats {
    total_queries: u64,
    completed_queries: u64,
    failed_queries: u64,
    active_users: u64,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    
    let canister_id = cli.canister_id
        .or_else(|| std::env::var("CANISTER_ID").ok())
        .expect("Canister ID must be provided via --canister-id or CANISTER_ID env var");
    
    let agent = create_agent(&cli.ic_url).await?;
    let canister_principal = Principal::from_text(&canister_id)?;
    
    match cli.command {
        Commands::Query { question, user_id } => {
            let user_id = user_id.unwrap_or_else(|| "anonymous".to_string());
            submit_query(&agent, canister_principal, question, user_id).await?;
        }
        Commands::GetResult { query_id } => {
            get_query_result(&agent, canister_principal, query_id).await?;
        }
        Commands::ListQueries { user_id } => {
            list_user_queries(&agent, canister_principal, user_id).await?;
        }
        Commands::Stats => {
            get_stats(&agent, canister_principal).await?;
        }
    }
    
    Ok(())
}

async fn create_agent(url: &str) -> Result<Agent> {
    let agent = Agent::builder()
        .with_url(url)
        .with_identity(AnonymousIdentity)
        .build()?;
        
    if url.contains("localhost") {
        agent.fetch_root_key().await?;
    }
    
    Ok(agent)
}

async fn submit_query(
    agent: &Agent,
    canister_id: Principal,
    question: String,
    user_id: String,
) -> Result<()> {
    let request = QueryRequest { question, user_id };
    
    let response = agent
        .update(&canister_id, "submit_query")
        .with_arg(Encode!(&request)?)
        .call_and_wait()
        .await?;
        
    let query: ResearchQuery = Decode!(&response, ResearchQuery)?;
    
    println!("✅ Query submitted successfully!");
    println!("Query ID: {}", query.id);
    println!("Status: {:?}", query.status);
    println!("Question: {}", query.question);
    
    Ok(())
}

async fn get_query_result(
    agent: &Agent,
    canister_id: Principal,
    query_id: String,
) -> Result<()> {
    let response = agent
        .query(&canister_id, "get_query")
        .with_arg(Encode!(&query_id)?)
        .call()
        .await?;
        
    let result: Option<ResearchQuery> = Decode!(&response, Option<ResearchQuery>)?;
    
    match result {
        Some(query) => {
            println!("📋 Query Details:");
            println!("ID: {}", query.id);
            println!("User: {}", query.user_id);
            println!("Question: {}", query.question);
            println!("Status: {:?}", query.status);
            println!("Timestamp: {}", query.timestamp);
            
            if let Some(response) = query.ai_response {
                println!("\n🤖 AI Response:");
                println!("{}", response);
            }
            
            if let Some(metadata) = query.metadata {
                println!("\n📊 Metadata:");
                println!("{}", metadata);
            }
        }
        None => {
            println!("❌ Query not found with ID: {}", query_id);
        }
    }
    
    Ok(())
}

async fn list_user_queries(
    agent: &Agent,
    canister_id: Principal,
    user_id: String,
) -> Result<()> {
    let response = agent
        .query(&canister_id, "get_user_queries")
        .with_arg(Encode!(&user_id)?)
        .call()
        .await?;
        
    let queries: Vec<ResearchQuery> = Decode!(&response, Vec<ResearchQuery>)?;
    
    if queries.is_empty() {
        println!("No queries found for user: {}", user_id);
        return Ok(());
    }
    
    println!("📚 Queries for user: {}", user_id);
    println!("Found {} queries:\n", queries.len());
    
    for query in queries {
        println!("🔍 Query ID: {}", query.id);
        println!("   Question: {}", query.question);
        println!("   Status: {:?}", query.status);
        println!("   Timestamp: {}", query.timestamp);
        println!();
    }
    
    Ok(())
}

async fn get_stats(agent: &Agent, canister_id: Principal) -> Result<()> {
    let response = agent
        .query(&canister_id, "get_stats")
        .call()
        .await?;
        
    let stats: QueryStats = Decode!(&response, QueryStats)?;
    
    println!("📊 Canister Statistics:");
    println!("Total Queries: {}", stats.total_queries);
    println!("Completed Queries: {}", stats.completed_queries);
    println!("Failed Queries: {}", stats.failed_queries);
    println!("Active Users: {}", stats.active_users);
    
    Ok(())
}