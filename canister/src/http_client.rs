use crate::types::*;
use candid::Principal;
use ic_cdk::api::management_canister::http_request::{
    http_request, CanisterHttpRequestArgument, HttpHeader, HttpMethod, HttpResponse,
};
use std::time::{SystemTime, UNIX_EPOCH};

pub async fn call_ai_service(question: &str) -> Result<AIResponse, String> {
    let config = crate::CONFIG.with(|c| c.borrow().get().clone());
    
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

pub async fn call_custom_ai_endpoint(
    endpoint: &str,
    question: &str,
    headers: Vec<HttpHeader>,
) -> Result<String, String> {
    // Custom implementation for other AI services
    // This is a flexible endpoint for different AI providers
    
    let request_body = serde_json::json!({
        "query": question,
        "timestamp": current_timestamp()
    });

    let request_body_bytes = serde_json::to_vec(&request_body)
        .map_err(|e| format!("Failed to serialize request: {}", e))?;

    let request_arg = CanisterHttpRequestArgument {
        url: endpoint.to_string(),
        method: HttpMethod::POST,
        body: Some(request_body_bytes),
        max_response_bytes: Some(10_000),
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

    let response = http_request(request_arg, 25_000_000_000u64)
        .await
        .map_err(|e| format!("HTTP request failed: {:?}", e))?
        .0;

    if response.status != 200u16 {
        return Err(format!(
            "Custom AI service returned error status: {} - {}",
            response.status,
            String::from_utf8_lossy(&response.body)
        ));
    }

    let response_text = String::from_utf8(response.body)
        .map_err(|e| format!("Failed to parse response as UTF-8: {}", e))?;

    Ok(response_text)
}

fn current_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}