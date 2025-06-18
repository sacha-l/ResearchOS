use crate::types::*;
use std::collections::HashMap;

/// Rate limiting functionality
pub struct RateLimiter {
    user_request_counts: HashMap<String, (u64, u32)>, // (timestamp, count)
    window_duration: u64, // in seconds
}

impl RateLimiter {
    pub fn new(window_duration: u64) -> Self {
        Self {
            user_request_counts: HashMap::new(),
            window_duration,
        }
    }

    pub fn check_rate_limit(&mut self, user_id: &str, limit: u32) -> Result<(), String> {
        let current_time = crate::current_timestamp();
        
        let (last_reset, count) = self.user_request_counts
            .get(user_id)
            .cloned()
            .unwrap_or((current_time, 0));

        // Reset counter if window has passed
        if current_time - last_reset >= self.window_duration {
            self.user_request_counts.insert(user_id.to_string(), (current_time, 1));
            return Ok(());
        }

        // Check if limit exceeded
        if count >= limit {
            return Err(format!(
                "Rate limit exceeded. Max {} requests per {} seconds",
                limit, self.window_duration
            ));
        }

        // Increment counter
        self.user_request_counts.insert(user_id.to_string(), (last_reset, count + 1));
        Ok(())
    }
}

/// Query validation utilities
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

/// Data cleanup utilities
pub fn cleanup_old_queries(max_age_seconds: u64) -> u32 {
    let current_time = crate::current_timestamp();
    let mut cleaned_count = 0u32;
    let mut queries_to_remove = Vec::new();

    crate::QUERIES.with(|q| {
        let queries_map = q.borrow();
        for (query_id, query) in queries_map.iter() {
            if current_time - query.timestamp > max_age_seconds {
                queries_to_remove.push(query_id.clone());
            }
        }
    });

    // Remove old queries
    crate::QUERIES.with(|q| {
        let mut queries_map = q.borrow_mut();
        for query_id in &queries_to_remove {
            queries_map.remove(query_id);
            cleaned_count += 1;
        }
    });

    // Clean up user query lists
    crate::USER_QUERIES.with(|uq| {
        let mut user_queries_map = uq.borrow_mut();
        let mut users_to_update = Vec::new();

        for (user_id, query_ids) in user_queries_map.iter() {
            let mut updated_queries = Vec::new();
            for query_id in &query_ids {
                if !queries_to_remove.contains(query_id) {
                    updated_queries.push(query_id.clone());
                }
            }
            
            if updated_queries.len() != query_ids.len() {
                users_to_update.push((user_id.clone(), updated_queries));
            }
        }

        for (user_id, updated_queries) in users_to_update {
            if updated_queries.is_empty() {
                user_queries_map.remove(&user_id);
            } else {
                user_queries_map.insert(user_id, updated_queries);
            }
        }
    });

    cleaned_count
}

/// Export/Import functionality for backup
#[derive(candid::CandidType, serde::Serialize, serde::Deserialize)]
pub struct CanisterBackup {
    pub queries: Vec<(String, ResearchQuery)>,
    pub user_queries: Vec<(String, Vec<String>)>,
    pub config: CanisterConfig,
    pub timestamp: u64,
}

pub fn export_data() -> CanisterBackup {
    let mut queries = Vec::new();
    let mut user_queries = Vec::new();
    
    crate::QUERIES.with(|q| {
        for (id, query) in q.borrow().iter() {
            queries.push((id, query));
        }
    });

    crate::USER_QUERIES.with(|uq| {
        for (user_id, query_ids) in uq.borrow().iter() {
            user_queries.push((user_id, query_ids));
        }
    });

    let config = crate::CONFIG.with(|c| c.borrow().get().clone());

    CanisterBackup {
        queries,
        user_queries,
        config,
        timestamp: crate::current_timestamp(),
    }
}

pub fn import_data(backup: CanisterBackup) -> Result<(), String> {
    // Clear existing data
    crate::QUERIES.with(|q| {
        let mut queries_map = q.borrow_mut();
        for (query_id, _) in queries_map.iter() {
            queries_map.remove(&query_id);
        }
    });

    crate::USER_QUERIES.with(|uq| {
        let mut user_queries_map = uq.borrow_mut();
        for (user_id, _) in user_queries_map.iter() {
            user_queries_map.remove(&user_id);
        }
    });

    // Import new data
    crate::QUERIES.with(|q| {
        let mut queries_map = q.borrow_mut();
        for (query_id, query) in backup.queries {
            queries_map.insert(query_id, query);
        }
    });

    crate::USER_QUERIES.with(|uq| {
        let mut user_queries_map = uq.borrow_mut();
        for (user_id, query_ids) in backup.user_queries {
            user_queries_map.insert(user_id, query_ids);
        }
    });

    crate::CONFIG.with(|c| {
        c.borrow_mut().set(backup.config)
            .map_err(|e| format!("Failed to import config: {:?}", e))
    })?;

    Ok(())
}