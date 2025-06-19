// src/lib.rs
use candid::{CandidType, Deserialize};
use ic_cdk::update;
use ic_cdk::query;
use std::cell::RefCell;
use serde::Serialize;

#[derive(Clone, Debug, CandidType, Deserialize, Serialize)]
struct ResearchEntry {
    title: String,
    abstract_body: String,
    tags: Vec<String>,
}

thread_local! {
    static RESEARCH_ENTRIES: RefCell<Vec<ResearchEntry>> = RefCell::new(vec![]);
}

#[update]
pub async fn submit_research(title: String, abstract_body: String) {
    RESEARCH_ENTRIES.with(|entries| {
        entries.borrow_mut().push(ResearchEntry {
            title,
            abstract_body: abstract_body.clone(),
            tags: vec![],
        });
    });

    tag_last_entry().await;
}

async fn tag_last_entry() {
    let entry_opt = RESEARCH_ENTRIES.with(|entries| entries.borrow().last().cloned());

    if let Some(entry) = entry_opt {
        let prompt = format!(
            "Suggest 5 relevant scientific tags for this research paper:\n\nTitle: {}\n\nAbstract: {}",
            entry.title, entry.abstract_body
        );

        let tags = query_openai(prompt).await;

        RESEARCH_ENTRIES.with(|entries| {
            if let Some(last) = entries.borrow_mut().last_mut() {
                last.tags = tags;
            }
        });
    }
}

async fn query_openai(_prompt: String) -> Vec<String> {
    // Simulated OpenAI response
    vec![
        "machine learning".into(),
        "decentralization".into(),
        "blockchain".into(),
        "AI agents".into(),
        "data sharing".into()
    ]
}

#[query]
fn search_by_tag(tag: String) -> Vec<ResearchEntry> {
    RESEARCH_ENTRIES.with(|entries| {
        entries
            .borrow()
            .iter()
            .filter(|e| e.tags.iter().any(|t| t.to_lowercase() == tag.to_lowercase()))
            .cloned()
            .collect()
    })
}

#[query]
fn list_all_entries() -> Vec<ResearchEntry> {
    RESEARCH_ENTRIES.with(|entries| entries.borrow().clone())
}