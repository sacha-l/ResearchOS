use candid::{CandidType, Principal};
use ic_stable_structures::{storable::Bound, Storable};
use serde::{Deserialize, Serialize};
use std::borrow::Cow;
use std::collections::HashMap;

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
pub struct OpenAIUsage {
    pub prompt_tokens: u32,
    pub completion_tokens: u32,
    pub total_tokens: u32,
}

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