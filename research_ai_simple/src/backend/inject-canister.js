const fs = require('fs');
const path = require('path');

// Read the original HTML
const htmlPath = path.join(__dirname, 'public', 'index.html');
const originalHtml = fs.readFileSync(htmlPath, 'utf8');

// Inject canister ID configuration
const injectionScript = `
<script>
    // Auto-configure canister ID from deployment
    window.DEPLOYED_CANISTER_ID = 'uxrrr-q7777-77774-qaaaq-cai';
    window.CANISTER_NETWORK = 'local';
    
    window.addEventListener('DOMContentLoaded', () => {
        const canisterInput = document.getElementById('canisterId');
        const networkSelect = document.getElementById('networkSelect');
        
        // If elements exist and are empty, auto-fill them
        if (canisterInput && !canisterInput.value) {
            canisterInput.value = window.DEPLOYED_CANISTER_ID;
            if (networkSelect) {
                networkSelect.value = window.CANISTER_NETWORK;
            }
            // Trigger change event to auto-connect
            canisterInput.dispatchEvent(new Event('change'));
            
            // Add console message
            console.log('Auto-configured with Canister ID:', window.DEPLOYED_CANISTER_ID);
        }
    });
</script>
`;

// Inject before closing body tag
const modifiedHtml = originalHtml.replace('</body>', injectionScript + '</body>');

// Write to a temporary file
fs.writeFileSync(path.join(__dirname, 'public', 'index-configured.html'), modifiedHtml);

console.log('Canister ID injected into UI');
