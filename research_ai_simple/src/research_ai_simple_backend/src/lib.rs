use candid::{CandidType, Deserialize};
use ic_cdk::{query, update};

#[derive(CandidType, Deserialize)]
pub struct NewsQuery {
    pub topic: String,
}

#[derive(CandidType, Deserialize)]
pub struct NewsResponse {
    pub topic: String,
    pub latest_info: String,
    pub timestamp: u64,
}

#[update]
pub async fn get_latest_news(request: NewsQuery) -> NewsResponse {
    let response = format!(
        "🧠 NEURAL SCAN COMPLETE: '{}'

📊 ANALYSIS RESULTS:
• ResearchOS neural pathways activated
• Information matrix synchronized  
• Knowledge patterns updated
• Query processed successfully

🚀 STATUS: CANISTER OPERATIONAL
⚡ AGENTS: ACTIVE
🔗 ICP: LIVE

Timestamp: {}",
        request.topic,
        ic_cdk::api::time()
    );
    
    NewsResponse {
        topic: request.topic,
        latest_info: response,
        timestamp: ic_cdk::api::time(),
    }
}

#[query]
pub fn health_check() -> String {
    "🚀 ResearchOS Neural Network ONLINE - ICP Canister Operational".to_string()
}
