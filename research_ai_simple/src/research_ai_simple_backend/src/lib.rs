use ic_cdk::{query, update, export_candid};
use ic_cdk::api::management_canister::http_request::{
    http_request, CanisterHttpRequestArgument, HttpHeader, HttpMethod, HttpResponse,
};
use candid::{CandidType, Deserialize};
use std::collections::HashMap;
use std::cell::RefCell;

// Simple in-memory storage (will reset on canister upgrade)
thread_local! {
    static STORAGE: RefCell<HashMap<String, String>> = RefCell::new(HashMap::new());
}

// Simple data structure for agent operations
#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct AgentData {
    pub key: String,
    pub value: String,
    pub agent_id: String,
}

// HTTP query request structure
#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct HttpQueryRequest {
    pub url: String,
    pub agent_id: String,
    pub store_key: String, // Key to store the result under
}

// Groq API request structure
#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct GroqQueryRequest {
    pub prompt: String,
    pub agent_id: String,
    pub store_key: String,
}

// Agent 3: Groq querying agent - queries Groq AI API
#[update]
pub async fn agent_query_groq(request: GroqQueryRequest) -> String {
    // Real Groq API endpoint
    let api_url = "https://api.groq.com/openai/v1/chat/completions";
    
    // Create JSON payload for Groq API
    let json_payload = format!(
        r#"{{"model": "llama3-8b-8192", "messages": [{{"role": "user", "content": "{}"}}], "max_tokens": 100}}"#,
        request.prompt.replace("\"", "\\\"") // Escape quotes
    );

    let request_headers = vec![
        HttpHeader {
            name: "Content-Type".to_string(),
            value: "application/json".to_string(),
        },
        HttpHeader {
            name: "Authorization".to_string(),
            value: "Bearer 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".to_string(),
        },
        HttpHeader {
            name: "User-Agent".to_string(),
            value: "ICP-Groq-Agent/1.0".to_string(),
        },
    ];

    let http_req = CanisterHttpRequestArgument {
        url: api_url.to_string(),
        method: HttpMethod::POST,
        body: Some(json_payload.as_bytes().to_vec()),
        max_response_bytes: Some(4096), // Increased for AI responses
        transform: None,
        headers: request_headers,
    };

    match http_request(http_req, 25_000_000_000).await {
        Ok((response,)) => {
            let response_body = String::from_utf8_lossy(&response.body);
            
            // Store the Groq response in shared memory
            STORAGE.with(|storage| {
                storage.borrow_mut().insert(request.store_key.clone(), response_body.to_string());
            });
            
            format!("Agent {} successfully queried Groq with prompt '{}' and stored under key: {}", 
                    request.agent_id, request.prompt, request.store_key)
        }
        Err((r, m)) => {
            let error_msg = format!("Groq API request failed: {:?} - {}", r, m);
            
            // Store error in shared memory
            STORAGE.with(|storage| {
                storage.borrow_mut().insert(request.store_key.clone(), error_msg.clone());
            });
            
            format!("Agent {} failed to query Groq: {}", request.agent_id, error_msg)
        }
    }
}

// Agent 2: HTTP querying agent - fetches data from external APIs
#[update]
pub async fn agent_query_http(request: HttpQueryRequest) -> String {
    let request_headers = vec![
        HttpHeader {
            name: "User-Agent".to_string(),
            value: "ICP-Agent/1.0".to_string(),
        },
    ];

    let http_req = CanisterHttpRequestArgument {
        url: request.url.clone(),
        method: HttpMethod::GET,
        body: None,
        max_response_bytes: Some(1024), // Limit to 1KB for simple demo
        transform: None, // Keep it simple for now
        headers: request_headers,
    };

    match http_request(http_req, 10_000_000_000).await {
        Ok((response,)) => {
            let response_body = String::from_utf8_lossy(&response.body);
            
            // Store the HTTP response in shared memory
            STORAGE.with(|storage| {
                storage.borrow_mut().insert(request.store_key.clone(), response_body.to_string());
            });
            
            format!("Agent {} successfully fetched and stored data from {} under key: {}", 
                    request.agent_id, request.url, request.store_key)
        }
        Err((r, m)) => {
            let error_msg = format!("HTTP request failed: {:?} - {}", r, m);
            
            // Store error in shared memory too
            STORAGE.with(|storage| {
                storage.borrow_mut().insert(request.store_key.clone(), error_msg.clone());
            });
            
            format!("Agent {} failed to fetch from {}: {}", request.agent_id, request.url, error_msg)
        }
    }
}

// Agent 1: Simple storage agent - can store data to shared memory
#[update]
pub fn agent_store_data(data: AgentData) -> String {
    STORAGE.with(|storage| {
        storage.borrow_mut().insert(data.key.clone(), data.value.clone());
    });
    
    format!("Agent {} stored data with key: {}", data.agent_id, data.key)
}

// Agent 1: Query function - can read from shared memory
#[query]
pub fn agent_get_data(key: String) -> Option<String> {
    STORAGE.with(|storage| {
        storage.borrow().get(&key).cloned()
    })
}

// Helper: Get all stored data (for debugging)
#[query]
pub fn get_all_data() -> Vec<(String, String)> {
    STORAGE.with(|storage| {
        storage.borrow().iter().map(|(k, v)| (k.clone(), v.clone())).collect()
    })
}

// Helper: Clear storage (for testing)
#[update]
pub fn clear_storage() -> String {
    STORAGE.with(|storage| {
        storage.borrow_mut().clear();
    });
    "Storage cleared".to_string()
}

// Health check
#[query]
pub fn health_check() -> String {
    STORAGE.with(|storage| {
        let count = storage.borrow().len();
        format!("Canister is running. {} items in shared storage.", count)
    })
}

export_candid!();