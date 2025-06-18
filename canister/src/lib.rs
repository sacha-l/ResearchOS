use candid::{CandidType, Principal};
use ic_cdk::api::management_canister::http_request::{
    http_request, CanisterHttpRequestArgument, HttpHeader, HttpMethod, HttpResponse, TransformArgs,
};
use ic_cdk_macros::{export_candid, init, post_upgrade, pre_upgrade, query, update};
use ic_stable_structures::{
    memory_manager::{MemoryId, MemoryManager, VirtualMemory},
    storable::Bound,
    DefaultMemoryImpl, StableBTreeMap, StableCell, Storable,
};
use serde::{Deserialize, Serialize};
use std::borrow::Cow;
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use std::time::{SystemTime, UNIX_EPOCH};

// Include modules inline to avoid module resolution issues
// mod types;
// mod http_client;
// mod storage;

// Types module content
#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct ResearchQuery {
    pub id: String,
    pub user_id: String,
    pub question: String,
    pub timestamp: u64,
    pub status: QueryStatus,
    pub ai_response: Option<String>,
    pub metadata: Option<String>,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub enum QueryStatus {
    Pending,
    Processing,
    Completed,
    Failed,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct QueryRequest {
    pub question: String,
    pub user_id: String,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct QueryStats {
    pub total_queries: u64,
    pub completed_queries: u64,
    pub failed_queries: u64,
    pub active_users: u64,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct AIServiceConfig {
    pub endpoint: String,
    pub api_key: Option<String>,
    pub model: String,
    pub max_tokens: u32,
    pub temperature: f32,
}

impl Default for AIServiceConfig {
    fn default() -> Self {
        Self {
            endpoint: "https://api.openai.com/v1/chat/completions".to_string(),
            api_key: None,
            model: "gpt-4".to_string(),
            max_tokens: 1000,
            temperature: 0.7,
        }
    }
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct CanisterConfig {
    pub ai_service: AIServiceConfig,
    pub allowed_origins: Vec<String>,
    pub rate_limit_per_user: u32,
}

impl Default for CanisterConfig {
    fn default() -> Self {
        Self {
            ai_service: AIServiceConfig::default(),
            allowed_origins: vec!["*".to_string()],
            rate_limit_per_user: 100,
        }
    }
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct AIResponse {
    pub content: String,
    pub metadata: AIResponseMetadata,
}

#[derive(CandidType, Serialize, Deserialize, Clone, Debug)]
pub struct AIResponseMetadata {
    pub model: String,
    pub tokens_used: u32,
    pub processing_time_ms: u64,
    pub timestamp: u64,
}

// OpenAI API structures
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct OpenAIRequest {
    pub model: String,
    pub messages: Vec<OpenAIMessage>,
    pub max_tokens: u32,
    pub temperature: f32,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct OpenAIMessage {
    pub role: String,
    pub content: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct OpenAIResponse {
    pub id: String,
    pub object: String,
    pub created: u64,
    pub model: String,
    pub choices: Vec<OpenAIChoice>,
    pub usage: OpenAIUsage,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct OpenAIChoice {
    pub index: u32,
    pub message: OpenAIMessage,
    pub finish_reason: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
// Storable implementations
impl Storable for ResearchQuery {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(serde_json::to_vec(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        serde_json::from_slice(&bytes).unwrap()
    }

    const BOUND: Bound = Bound::Unbounded;
}

impl Storable for Vec<String> {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(serde_json::to_vec(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        serde_json::from_slice(&bytes).unwrap()
    }

    const BOUND: Bound = Bound::Unbounded;
}

impl Storable for CanisterConfig {
    fn to_bytes(&self) -> std::borrow::Cow<[u8]> {
        Cow::Owned(serde_json::to_vec(self).unwrap())
    }

    fn from_bytes(bytes: std::borrow::Cow<[u8]>) -> Self {
        serde_json::from_slice(&bytes).unwrap()
    }

    const BOUND: Bound = Bound::Unbounded;
}

// HTTP Client functions
pub async fn call_ai_service(question: &str) -> Result<AIResponse, String> {
    let config = CONFIG.with(|c| c.borrow().get().clone());
    
    // Prepare the request
    let request_body = prepare_openai_request(question, &config.ai_service)?;
    let request_body_bytes = serde_json::to_vec(&request_body)
        .map_err(|e| format!("Failed to serialize request: {}", e))?;

    let mut headers = vec![
        HttpHeader {
            name: "Content-Type".to_string(),
            value: "application/json".to_string(),
        },
        HttpHeader {
            name: "User-Agent".to_string(),
            value: "IC-Research-AI-Canister/1.0".to_string(),
        },
    ];

    // Add API key if configured
    if let Some(api_key) = &config.ai_service.api_key {
        headers.push(HttpHeader {
            name: "Authorization".to_string(),
            value: format!("Bearer {}", api_key),
        });
    }

    let request_arg = CanisterHttpRequestArgument {
        url: config.ai_service.endpoint.clone(),
        method: HttpMethod::POST,
        body: Some(request_body_bytes),
        max_response_bytes: Some(10_000), // 10KB max response
        transform: Some(ic_cdk::api::management_canister::http_request::TransformContext {
            function: ic_cdk::api::management_canister::http_request::TransformFunc(
                candid::Func {
                    principal: ic_cdk::api::id(),
                    method: "http_request_transform".to_string(),
                }
            ),
            context: vec![],
        }),
        headers,
    };

    let start_time = current_timestamp();
    
    // Make the HTTP request
    let response = http_request(request_arg, 25_000_000_000u64) // 25B cycles
        .await
        .map_err(|e| format!("HTTP request failed: {:?}", e))?
        .0;

    let end_time = current_timestamp();
    let processing_time = end_time - start_time;

    // Check response status
    if response.status != 200u16 {
        return Err(format!(
            "AI service returned error status: {} - {}",
            response.status,
            String::from_utf8_lossy(&response.body)
        ));
    }

    // Parse the response
    let openai_response: OpenAIResponse = serde_json::from_slice(&response.body)
        .map_err(|e| format!("Failed to parse AI response: {}", e))?;

    // Extract the content from the first choice
    let content = openai_response
        .choices
        .first()
        .ok_or("No choices in AI response")?
        .message
        .content
        .clone();

    let ai_response = AIResponse {
        content,
        metadata: AIResponseMetadata {
            model: openai_response.model,
            tokens_used: openai_response.usage.total_tokens,
            processing_time_ms: processing_time * 1000, // Convert to milliseconds
            timestamp: end_time,
        },
    };

    Ok(ai_response)
}

fn prepare_openai_request(question: &str, config: &AIServiceConfig) -> Result<OpenAIRequest, String> {
    let system_message = OpenAIMessage {
        role: "system".to_string(),
        content: "You are a helpful research assistant. Provide accurate, well-researched, and comprehensive answers to research questions. Include relevant sources and references when possible.".to_string(),
    };

    let user_message = OpenAIMessage {
        role: "user".to_string(),
        content: question.to_string(),
    };

    Ok(OpenAIRequest {
        model: config.model.clone(),
        messages: vec![system_message, user_message],
        max_tokens: config.max_tokens,
        temperature: config.temperature,
    })
}

// Storage and validation functions
pub fn validate_query(request: &QueryRequest) -> Result<(), String> {
    if request.question.trim().is_empty() {
        return Err("Question cannot be empty".to_string());
    }

    if request.question.len() > 5000 {
        return Err("Question too long (max 5000 characters)".to_string());
    }

    if request.user_id.trim().is_empty() {
        return Err("User ID cannot be empty".to_string());
    }

    if request.user_id.len() > 100 {
        return Err("User ID too long (max 100 characters)".to_string());
    }

    // Check for potentially harmful content
    let forbidden_patterns = [
        "inject", "script", "eval", "exec", "system",
        "<script", "javascript:", "data:",
    ];

    let question_lower = request.question.to_lowercase();
    for pattern in &forbidden_patterns {
        if question_lower.contains(pattern) {
            return Err("Question contains potentially harmful content".to_string());
        }
    }

    Ok(())
}

type Memory = VirtualMemory<DefaultMemoryImpl>;

thread_local! {
    static MEMORY_MANAGER: RefCell<MemoryManager<DefaultMemoryImpl>> =
        RefCell::new(MemoryManager::init(DefaultMemoryImpl::default()));

    static QUERIES: RefCell<StableBTreeMap<String, ResearchQuery, Memory>> = RefCell::new(
        StableBTreeMap::init(
            MEMORY_MANAGER.with(|m| m.borrow().get(MemoryId::new(0))),
        )
    );

    static USER_QUERIES: RefCell<StableBTreeMap<String, Vec<String>, Memory>> = RefCell::new(
        StableBTreeMap::init(
            MEMORY_MANAGER.with(|m| m.borrow().get(MemoryId::new(1))),
        )
    );

    static CONFIG: RefCell<StableCell<CanisterConfig, Memory>> = RefCell::new(
        StableCell::init(
            MEMORY_MANAGER.with(|m| m.borrow().get(MemoryId::new(2))),
            CanisterConfig::default()
        ).expect("Failed to init config")
    );
}

#[init]
fn init() {
    ic_cdk::println!("Research AI Canister initialized");
}

#[pre_upgrade]
fn pre_upgrade() {
    ic_cdk::println!("Pre-upgrade: Stable storage will be preserved");
}

#[post_upgrade]
fn post_upgrade() {
    ic_cdk::println!("Post-upgrade: Canister state restored");
}

#[update]
async fn submit_query(request: QueryRequest) -> Result<ResearchQuery, String> {
    // Validate the request
    validate_query(&request)?;
    
    let query_id = generate_query_id();
    let timestamp = current_timestamp();
    
    let mut query = ResearchQuery {
        id: query_id.clone(),
        user_id: request.user_id.clone(),
        question: request.question.clone(),
        timestamp,
        status: QueryStatus::Pending,
        ai_response: None,
        metadata: None,
    };

    // Store the query
    QUERIES.with(|q| {
        q.borrow_mut().insert(query_id.clone(), query.clone())
    });

    // Update user query list
    USER_QUERIES.with(|uq| {
        let mut map = uq.borrow_mut();
        let mut user_queries = map.get(&request.user_id).unwrap_or_default();
        user_queries.push(query_id.clone());
        map.insert(request.user_id.clone(), user_queries);
    });

    // Process the query asynchronously
    ic_cdk::spawn(process_query_async(query_id.clone(), request.question));

    query.status = QueryStatus::Processing;
    QUERIES.with(|q| {
        q.borrow_mut().insert(query_id.clone(), query.clone())
    });

    Ok(query)
}

async fn process_query_async(query_id: String, question: String) {
    match call_ai_service(&question).await {
        Ok(response) => {
            // Update query with successful response
            QUERIES.with(|q| {
                if let Some(mut query) = q.borrow().get(&query_id) {
                    query.status = QueryStatus::Completed;
                    query.ai_response = Some(response.content);
                    query.metadata = Some(serde_json::to_string(&response.metadata).unwrap_or_default());
                    q.borrow_mut().insert(query_id.clone(), query);
                }
            });
        }
        Err(error) => {
            // Update query with error status
            QUERIES.with(|q| {
                if let Some(mut query) = q.borrow().get(&query_id) {
                    query.status = QueryStatus::Failed;
                    query.metadata = Some(format!("Error: {}", error));
                    q.borrow_mut().insert(query_id.clone(), query);
                }
            });
        }
    };
}

#[query]
fn get_query(query_id: String) -> Option<ResearchQuery> {
    QUERIES.with(|q| q.borrow().get(&query_id))
}

#[query]
fn get_user_queries(user_id: String) -> Vec<ResearchQuery> {
    let query_ids = USER_QUERIES.with(|uq| {
        uq.borrow().get(&user_id).unwrap_or_default()
    });

    let mut queries = Vec::new();
    QUERIES.with(|q| {
        let queries_map = q.borrow();
        for query_id in query_ids {
            if let Some(query) = queries_map.get(&query_id) {
                queries.push(query);
            }
        }
    });

    queries
}

#[query]
fn get_stats() -> QueryStats {
    let mut total_queries = 0u64;
    let mut completed_queries = 0u64;
    let mut failed_queries = 0u64;
    let mut unique_users = HashSet::new();

    QUERIES.with(|q| {
        for (_, query) in q.borrow().iter() {
            total_queries += 1;
            unique_users.insert(query.user_id.clone());
            
            match query.status {
                QueryStatus::Completed => completed_queries += 1,
                QueryStatus::Failed => failed_queries += 1,
                _ => {}
            }
        }
    });

    QueryStats {
        total_queries,
        completed_queries,
        failed_queries,
        active_users: unique_users.len() as u64,
    }
}

#[update]
async fn set_ai_config(config: AIServiceConfig) -> Result<(), String> {
    CONFIG.with(|c| {
        let mut canister_config = c.borrow().get().clone();
        canister_config.ai_service = config;
        c.borrow_mut().set(canister_config).map_err(|e| format!("Failed to set config: {:?}", e))
    })
}

#[query]
fn get_config() -> CanisterConfig {
    CONFIG.with(|c| c.borrow().get().clone())
}

#[query]
fn http_request_transform(args: TransformArgs) -> HttpResponse {
    HttpResponse {
        status: args.response.status.clone(),
        headers: vec![],
        body: args.response.body.clone(),
    }
}

fn generate_query_id() -> String {
    let timestamp = current_timestamp();
    let caller = ic_cdk::caller();
    format!("query_{}_{}", timestamp, caller.to_text())
}

fn current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

export_candid!();