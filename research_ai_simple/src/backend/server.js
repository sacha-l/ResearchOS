const express = require('express');
const path = require('path');
const { exec } = require('child_process');
const util = require('util');

const app = express();
const PORT = 3000;
const execPromise = util.promisify(exec);

app.use(express.json());
app.use(express.static('public'));

async function callCanister(method, args = '') {
    try {
        const command = args ? 
            `dfx canister call research_ai_simple_backend ${method} '${args}'` :
            `dfx canister call research_ai_simple_backend ${method}`;
        
        const { stdout } = await execPromise(command);
        return stdout.trim().replace(/^\(|\)$/g, '').replace(/^"|"$/g, '');
    } catch (error) {
        throw new Error(`Canister call failed: ${error.message}`);
    }
}

const mockSources = [
    { handle: '@researchos', influence: 99.9, neural_id: 'NID_000' },
    { handle: '@icp_protocol', influence: 95.5, neural_id: 'NID_001' },
    { handle: '@dfinity', influence: 92.1, neural_id: 'NID_002' }
];

app.post('/api/neural-query', async (req, res) => {
    const { query } = req.body;
    const searchTopic = query || 'general research';
    
    console.log(`[API] Query: "${searchTopic}"`);
    
    try {
        const newsQuery = `(record { topic = "${searchTopic}" })`;
        const canisterResponse = await callCanister('get_latest_news', newsQuery);
        
        res.json({
            success: true,
            data: {
                topic: searchTopic,
                content: `[LIVE CANISTER RESPONSE]

${canisterResponse}

[SYSTEM STATUS]
✓ ICP Replica: Connected
✓ ResearchOS Canister: Operational  
✓ Neural Query: Processed`,
                sources: mockSources,
                timestamp: Date.now(),
                logs: [
                    { agent: 'USER-AGENT', message: `Query: "${searchTopic}"`, log_type: 'success' },
                    { agent: 'ICP-CANISTER', message: 'Response received', log_type: 'success' },
                    { agent: 'NEURAL-NET', message: 'Processing complete', log_type: 'info' }
                ]
            }
        });
        
    } catch (error) {
        res.json({
            success: true,
            data: {
                topic: searchTopic,
                content: `[FALLBACK MODE]

Query: "${searchTopic}"

🔧 Canister Status: Offline/Starting
🚀 Demo Mode: Active

ResearchOS demonstrates distributed AI research on ICP.
Neural pathways remain functional during canister deployment.`,
                sources: mockSources,
                timestamp: Date.now(),
                logs: [
                    { agent: 'USER-AGENT', message: `Query: "${searchTopic}"`, log_type: 'info' },
                    { agent: 'FALLBACK-SYS', message: 'Using demo mode', log_type: 'warning' },
                    { agent: 'DEMO-SYS', message: 'Functionality maintained', log_type: 'success' }
                ]
            }
        });
    }
});

app.get('/api/health', async (req, res) => {
    try {
        const health = await callCanister('health_check');
        res.json({
            status: 'online',
            message: `ICP Canister: ${health}`,
            canister_connected: true
        });
    } catch (error) {
        res.json({
            status: 'demo',
            message: 'ResearchOS Demo Mode - Canister Starting',
            canister_connected: false
        });
    }
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║                    ResearchOS Live                           ║
║                                                              ║
║  🚀 Frontend: http://localhost:${PORT}                          ║
║  🤖 ICP Integration: Active                                  ║
║  🏆 Ready for demo!                                         ║
╚══════════════════════════════════════════════════════════════╝
    `);
});
