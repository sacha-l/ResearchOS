use ic_cdk::{query, update};
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