#!/bin/bash

echo "🧪 Testing Simple Research AI Canister"

CANISTER_ID=$(dfx canister id research_ai_simple_backend)
echo "Canister ID: $CANISTER_ID"

echo ""
echo "📝 Testing question processing..."
dfx canister call research_ai_simple_backend process_question '("What is AI?", "storage_agent_001")'

echo ""
echo "📝 Testing another question..."
dfx canister call research_ai_simple_backend process_question '("How does machine learning work?", "storage_agent_002")'

echo ""
echo "🔖 Testing bookmarks..."
dfx canister call research_ai_simple_backend bookmark_query '("favorite_ai_topic", "neural_networks")'
dfx canister call research_ai_simple_backend bookmark_query '("research_focus", "quantum_computing")'

echo ""
echo "📊 Getting stats..."
dfx canister call research_ai_simple_backend get_stats

echo ""
echo "📋 Getting all questions..."
dfx canister call research_ai_simple_backend get_questions

echo ""
echo "🔖 Getting all bookmarks..."
dfx canister call research_ai_simple_backend get_all_bookmarks

echo ""
echo "🔍 Testing bookmark retrieval..."
dfx canister call research_ai_simple_backend get_bookmark '("favorite_ai_topic")'

echo ""
echo "📈 Final counts..."
echo "Questions:"
dfx canister call research_ai_simple_backend get_question_count
echo "Bookmarks:"
dfx canister call research_ai_simple_backend get_bookmark_count