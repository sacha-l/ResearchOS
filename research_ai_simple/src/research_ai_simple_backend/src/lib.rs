use ic_cdk::{init, query, update, pre_upgrade, post_upgrade};
use ic_cdk::api::management_canister::http_request::{http_request as http_request,
    CanisterHttpRequestArgument, HttpHeader, HttpMethod
};
use ic_cdk_timers::{set_timer_interval, TimerId};
use candid::{CandidType, Deserialize};
use std::collections::HashMap;
use std::cell::RefCell;
use std::time::Duration;

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
    pub log_type: String, // "info", "success", "error"
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

// Storage declarations
thread_local! {
    static NEWS_STORAGE: RefCell<HashMap<String, TopicNews>> = RefCell::new(HashMap::new());
    static AGENT_LOGS: RefCell<Vec<AgentLog>> = RefCell::new(Vec::new());
    static MONITORED_TOPICS: RefCell<Vec<String>> = RefCell::new(Vec::new());
    static UPDATE_TIMER: RefCell<Option<TimerId>> = RefCell::new(None);
}

// Helper functions
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
        
        // Keep only last 50 logs to prevent memory bloat
        if logs.len() > 50 {
            logs.drain(0..10);
        }
    });
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

fn add_to_monitored_topics(topic: &str) {
    MONITORED_TOPICS.with(|topics| {
        let mut topics = topics.borrow_mut();
        if !topics.contains(&topic.to_string()) {
            topics.push(topic.to_string());
            add_log("MONITOR", &format!("Added '{}' to monitoring list", topic), "info");
        }
    });
}

// Agent 1: User-triggered news fetching
#[update]
pub async fn get_latest_news(request: NewsQuery) -> NewsResponse {
    add_log("USER-AGENT", &format!("User requested news for: '{}'", request.topic), "info");
    
    // Check if we have recent data (less than 20 minutes old)
    let existing_data = NEWS_STORAGE.with(|storage| {
        storage.borrow().get(&request.topic).cloned()
    });
    
    let twenty_minutes_ns = 20 * 60 * 1_000_000_000u64; // 20 minutes in nanoseconds
    let current_time = ic_cdk::api::time();
    
    if let Some(data) = existing_data {
        if current_time - data.last_updated < twenty_minutes_ns {
            add_log("USER-AGENT", "Using cached data (less than 20min old)", "info");
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
    add_log("USER-AGENT", "Fetching fresh news from Groq...", "info");
    
    match fetch_topic_news(&request.topic).await {
        Ok(news_info) => {
            add_log("USER-AGENT", "Successfully fetched latest news", "success");
            store_topic_news(&request.topic, &news_info);
            add_to_monitored_topics(&request.topic);
            
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
            add_log("USER-AGENT", &format!("Failed to fetch news: {}", e), "error");
            
            // Return cached data if available, even if old
            let fallback_data = NEWS_STORAGE.with(|storage| {
                storage.borrow().get(&request.topic).cloned()
            });
            
            let logs = AGENT_LOGS.with(|logs| logs.borrow().clone());
            if let Some(data) = fallback_data {
                NewsResponse {
                    topic: request.topic,
                    latest_info: format!("⚠️ Using cached data (API failed): {}", data.latest_info),
                    last_updated: data.last_updated,
                    is_fresh: false,
                    logs,
                }
            } else {
                NewsResponse {
                    topic: request.topic,
                    latest_info: format!("❌ Failed to fetch news: {}", e),
                    last_updated: current_time,
                    is_fresh: false,
                    logs,
                }
            }
        }
    }
}

// Agent 2: Timer initialization and monitoring
#[init]
fn init() {
    start_monitoring_timer();
}

fn start_monitoring_timer() {
    let timer_id = set_timer_interval(Duration::from_secs(20 * 60), || {
        ic_cdk::spawn(periodic_news_update())
    });
    
    UPDATE_TIMER.with(|timer| {
        *timer.borrow_mut() = Some(timer_id);
    });
    
    add_log("MONITOR-AGENT", "Started 20-minute monitoring timer", "info");
}

async fn periodic_news_update() {
    add_log("MONITOR-AGENT", "Starting periodic news update cycle", "info");
    
    let topics_to_update = MONITORED_TOPICS.with(|topics| {
        topics.borrow().clone()
    });
    
    if topics_to_update.is_empty() {
        add_log("MONITOR-AGENT", "No topics to monitor", "info");
        return;
    }
    
    add_log("MONITOR-AGENT", &format!("Updating {} monitored topics", topics_to_update.len()), "info");
    
    for topic in topics_to_update {
        add_log("MONITOR-AGENT", &format!("Updating '{}'...", topic), "info");
        
        match fetch_topic_news(&topic).await {
            Ok(news_info) => {
                store_topic_news(&topic, &news_info);
                add_log("MONITOR-AGENT", &format!("Updated '{}' successfully", topic), "success");
            }
            Err(e) => {
                add_log("MONITOR-AGENT", &format!("Failed to update '{}': {}", topic, e), "error");
            }
        }
    }
    
    add_log("MONITOR-AGENT", "Completed periodic update cycle", "info");
}

// Shared Groq API function
async fn fetch_topic_news(topic: &str) -> Result<String, String> {
    let api_url = "https://api.groq.com/openai/v1/chat/completions";
    
    let prompt = format!(
        "What are the latest news and developments about '{}'? Give me the most recent and important updates in 2-3 sentences. Focus on what happened in the last 24-48 hours.",
        topic
    );
    
    let json_payload = format!(
        r#"{{"model": "llama3-8b-8192", "messages": [{{"role": "user", "content": "{}"}}], "max_tokens": 200}}"#,
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
            
            // Parse JSON to extract content
            if let Ok(json_val) = serde_json::from_str::<serde_json::Value>(&response_body) {
                if let Some(content) = json_val["choices"][0]["message"]["content"].as_str() {
                    return Ok(content.trim().to_string());
                }
            }
            
            Err("Failed to parse API response".to_string())
        }
        Err((r, m)) => Err(format!("API request failed: {:?} - {}", r, m))
    }
}

// New query functions for monitoring and debugging
#[query]
pub fn get_monitored_topics() -> Vec<String> {
    MONITORED_TOPICS.with(|topics| topics.borrow().clone())
}

#[query]
pub fn get_all_cached_news() -> Vec<TopicNews> {
    NEWS_STORAGE.with(|storage| {
        storage.borrow().values().cloned().collect()
    })
}

#[query]
pub fn get_recent_logs() -> Vec<AgentLog> {
    AGENT_LOGS.with(|logs| {
        logs.borrow().iter().rev().take(20).cloned().collect()
    })
}

#[query]
pub fn health_check() -> String {
    let topic_count = NEWS_STORAGE.with(|storage| storage.borrow().len());
    let monitored_count = MONITORED_TOPICS.with(|topics| topics.borrow().len());
    
    format!("KnowledgeOS NewsOS - {} cached topics, {} monitored, timer active", topic_count, monitored_count)
}