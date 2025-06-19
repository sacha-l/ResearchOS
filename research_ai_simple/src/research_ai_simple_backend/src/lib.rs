use ic_cdk::{query, update, export_candid, init};
use ic_cdk::api::management_canister::http_request::{
    http_request, CanisterHttpRequestArgument, HttpHeader, HttpMethod, HttpResponse,
};
use candid::{CandidType, Deserialize};
use std::collections::{HashMap, HashSet};
use std::cell::RefCell;
use ic_cdk_timers::set_timer_interval;
use std::time::Duration;

// Storage structures
thread_local! {
    // Main storage for all data
    static STORAGE: RefCell<HashMap<String, String>> = RefCell::new(HashMap::new());
    
    // Track active news topics for periodic updates
    static TRACKED_TOPICS: RefCell<HashSet<String>> = RefCell::new(HashSet::new());
    
    // Store last update times for each topic
    static LAST_UPDATE: RefCell<HashMap<String, u64>> = RefCell::new(HashMap::new());
}

// Request/Response types
#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct NewsQuery {
    pub topic: String,
    pub enable_tracking: bool, // Whether to track this topic for periodic updates
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct NewsResponse {
    pub topic: String,
    pub content: String,
    pub timestamp: u64,
    pub is_tracked: bool,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct TrackedTopic {
    pub topic: String,
    pub last_update: u64,
    pub update_count: u32,
}

// Simple data structure for agent operations
#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct AgentData {
    pub key: String,
    pub value: String,
    pub agent_id: String,
}

// Initialize canister with timer
#[init]
fn init() {
    // Set up a timer to run every 20 minutes (1200 seconds)
    set_timer_interval(Duration::from_secs(1200), || {
        ic_cdk::spawn(async {
            update_all_tracked_topics().await;
        })
    });
    
    ic_cdk::print("News canister initialized with 20-minute update timer");
}

// Main news query function - simplified and focused
#[update]
pub async fn get_news(request: NewsQuery) -> NewsResponse {
    let timestamp = ic_cdk::api::time();
    let topic = request.topic.clone();
    
    // Track this topic if requested
    if request.enable_tracking {
        TRACKED_TOPICS.with(|topics| {
            topics.borrow_mut().insert(topic.clone());
        });
    }
    
    // Query Groq AI for news
    let news_content = query_groq_for_news(&topic).await;
    
    // Store the result
    let key = format!("news_{}_{}", sanitize_topic(&topic), timestamp);
    STORAGE.with(|storage| {
        storage.borrow_mut().insert(key, news_content.clone());
    });
    
    // Update last update time
    LAST_UPDATE.with(|updates| {
        updates.borrow_mut().insert(topic.clone(), timestamp);
    });
    
    // Check if this topic is being tracked
    let is_tracked = TRACKED_TOPICS.with(|topics| {
        topics.borrow().contains(&topic)
    });
    
    NewsResponse {
        topic,
        content: news_content,
        timestamp,
        is_tracked,
    }
}

// Get all tracked topics
#[query]
pub fn get_tracked_topics() -> Vec<TrackedTopic> {
    TRACKED_TOPICS.with(|topics| {
        topics.borrow().iter().map(|topic| {
            let last_update = LAST_UPDATE.with(|updates| {
                updates.borrow().get(topic).copied().unwrap_or(0)
            });
            
            // Count how many updates we have for this topic
            let update_count = STORAGE.with(|storage| {
                storage.borrow().keys()
                    .filter(|k| k.starts_with(&format!("news_{}_", sanitize_topic(topic))))
                    .count() as u32
            });
            
            TrackedTopic {
                topic: topic.clone(),
                last_update,
                update_count,
            }
        }).collect()
    })
}

// Stop tracking a topic
#[update]
pub fn untrack_topic(topic: String) -> bool {
    TRACKED_TOPICS.with(|topics| {
        topics.borrow_mut().remove(&topic)
    })
}

// Get latest news for a specific topic (from storage)
#[query]
pub fn get_latest_stored_news(topic: String) -> Option<NewsResponse> {
    let sanitized = sanitize_topic(&topic);
    let prefix = format!("news_{}_", sanitized);
    
    // Find all entries for this topic
    let mut entries: Vec<(String, String, u64)> = STORAGE.with(|storage| {
        storage.borrow()
            .iter()
            .filter(|(k, _)| k.starts_with(&prefix))
            .map(|(k, v)| {
                // Extract timestamp from key
                let parts: Vec<&str> = k.split('_').collect();
                let timestamp = parts.last()
                    .and_then(|t| t.parse::<u64>().ok())
                    .unwrap_or(0);
                (k.clone(), v.clone(), timestamp)
            })
            .collect()
    });
    
    // Sort by timestamp, newest first
    entries.sort_by(|a, b| b.2.cmp(&a.2));
    
    // Return the most recent
    entries.first().map(|(_, content, timestamp)| {
        NewsResponse {
            topic: topic.clone(),
            content: content.clone(),
            timestamp: *timestamp,
            is_tracked: TRACKED_TOPICS.with(|topics| topics.borrow().contains(&topic)),
        }
    })
}

// Get news history for a topic
#[query]
pub fn get_news_history(topic: String, limit: Option<u32>) -> Vec<NewsResponse> {
    let sanitized = sanitize_topic(&topic);
    let prefix = format!("news_{}_", sanitized);
    let limit = limit.unwrap_or(10) as usize;
    
    // Find all entries for this topic
    let mut entries: Vec<(String, String, u64)> = STORAGE.with(|storage| {
        storage.borrow()
            .iter()
            .filter(|(k, _)| k.starts_with(&prefix))
            .map(|(k, v)| {
                let parts: Vec<&str> = k.split('_').collect();
                let timestamp = parts.last()
                    .and_then(|t| t.parse::<u64>().ok())
                    .unwrap_or(0);
                (k.clone(), v.clone(), timestamp)
            })
            .collect()
    });
    
    // Sort by timestamp, newest first
    entries.sort_by(|a, b| b.2.cmp(&a.2));
    
    // Take only the requested limit
    entries.truncate(limit);
    
    // Convert to NewsResponse
    entries.into_iter().map(|(_, content, timestamp)| {
        NewsResponse {
            topic: topic.clone(),
            content,
            timestamp,
            is_tracked: TRACKED_TOPICS.with(|topics| topics.borrow().contains(&topic)),
        }
    }).collect()
}

// Function to update all tracked topics (called by timer)
async fn update_all_tracked_topics() {
    let topics: Vec<String> = TRACKED_TOPICS.with(|topics| {
        topics.borrow().iter().cloned().collect()
    });
    
    ic_cdk::print(format!("Timer triggered: Updating {} tracked topics", topics.len()));
    
    for topic in topics {
        let news_content = query_groq_for_news(&topic).await;
        let timestamp = ic_cdk::api::time();
        
        // Store the update
        let key = format!("news_{}_{}", sanitize_topic(&topic), timestamp);
        STORAGE.with(|storage| {
            storage.borrow_mut().insert(key, news_content);
        });
        
        // Update last update time
        LAST_UPDATE.with(|updates| {
            updates.borrow_mut().insert(topic.clone(), timestamp);
        });
        
        ic_cdk::print(format!("Updated news for topic: {}", topic));
    }
}

// Query Groq AI for news about a topic
async fn query_groq_for_news(topic: &str) -> String {
    let api_url = "https://api.groq.com/openai/v1/chat/completions";
    
    let prompt = format!(
        "Give me the latest news and updates about '{}'. Please provide: \
        1) Recent headlines (if any) \
        2) Key developments \
        3) Important facts or trends \
        Keep it concise, factual, and well-organized.",
        topic
    );
    
    let json_payload = format!(
        r#"{{"model": "llama3-8b-8192", "messages": [{{"role": "user", "content": "{}"}}], "max_tokens": 300}}"#,
        prompt.replace("\"", "\\\"")
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
    ];

    let http_req = CanisterHttpRequestArgument {
        url: api_url.to_string(),
        method: HttpMethod::POST,
        body: Some(json_payload.as_bytes().to_vec()),
        max_response_bytes: Some(4096),
        transform: None,
        headers: request_headers,
    };

    match http_request(http_req, 25_000_000_000).await {
        Ok((response,)) => {
            let response_body = String::from_utf8_lossy(&response.body);
            
            // Try to parse and extract the content
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(&response_body) {
                if let Some(content) = json["choices"][0]["message"]["content"].as_str() {
                    return content.to_string();
                }
            }
            
            // Return the full response if parsing fails
            response_body.to_string()
        }
        Err((r, m)) => {
            format!("Failed to fetch news: {:?} - {}", r, m)
        }
    }
}

// Helper function to sanitize topic names for storage keys
fn sanitize_topic(topic: &str) -> String {
    topic.to_lowercase()
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '_' })
        .collect()
}

// Legacy support functions (keeping your existing interface)
#[update]
pub async fn agent_query_groq(request: GroqQueryRequest) -> String {
    let result = query_groq_for_news(&request.prompt).await;
    
    // Store in legacy format
    STORAGE.with(|storage| {
        storage.borrow_mut().insert(request.store_key.clone(), result.clone());
    });
    
    format!("Agent {} successfully queried news and stored under key: {}", 
            request.agent_id, request.store_key)
}

#[update]
pub fn agent_store_data(data: AgentData) -> String {
    STORAGE.with(|storage| {
        storage.borrow_mut().insert(data.key.clone(), data.value.clone());
    });
    
    format!("Agent {} stored data with key: {}", data.agent_id, data.key)
}

#[query]
pub fn agent_get_data(key: String) -> Option<String> {
    STORAGE.with(|storage| {
        storage.borrow().get(&key).cloned()
    })
}

#[query]
pub fn get_all_data() -> Vec<(String, String)> {
    STORAGE.with(|storage| {
        storage.borrow().iter().map(|(k, v)| (k.clone(), v.clone())).collect()
    })
}

#[update]
pub fn clear_storage() -> String {
    STORAGE.with(|storage| {
        storage.borrow_mut().clear();
    });
    TRACKED_TOPICS.with(|topics| {
        topics.borrow_mut().clear();
    });
    LAST_UPDATE.with(|updates| {
        updates.borrow_mut().clear();
    });
    "Storage and tracked topics cleared".to_string()
}

#[query]
pub fn health_check() -> String {
    let storage_count = STORAGE.with(|storage| storage.borrow().len());
    let tracked_count = TRACKED_TOPICS.with(|topics| topics.borrow().len());
    
    format!(
        "News canister is running. {} items in storage, {} topics being tracked for updates.",
        storage_count, tracked_count
    )
}

// Manual trigger for testing
#[update]
pub async fn trigger_update_cycle() -> String {
    update_all_tracked_topics().await;
    "Manual update cycle completed".to_string()
}

// Types needed for legacy compatibility
#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct GroqQueryRequest {
    pub prompt: String,
    pub agent_id: String,
    pub store_key: String,
}

#[derive(CandidType, Deserialize, Clone, Debug)]
pub struct HttpQueryRequest {
    pub url: String,
    pub agent_id: String,
    pub store_key: String,
}

// Stub for HTTP agent (not used for news)
#[update]
pub async fn agent_query_http(_request: HttpQueryRequest) -> String {
    "HTTP agent not used for news queries. Use get_news() instead.".to_string()
}

export_candid!();