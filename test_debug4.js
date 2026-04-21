const { JSDOM } = require('jsdom');
const fs = require('fs');

let html = fs.readFileSync('/Users/yml/Desktop/caibaoUI_skill/command-center.html', 'utf8');

// Capture script errors
const virtualConsole = new (require('jsdom').VirtualConsole)();
virtualConsole.on('error', (err) => {
    console.log('Script error:', err.message || err);
});
virtualConsole.on('jsdomError', (err) => {
    console.log('JSDOM error:', err.message || err);
});

const dom = new JSDOM(html, { 
    runScripts: 'dangerously', 
    url: 'http://localhost',
    virtualConsole: virtualConsole
});

const window = dom.window;

setTimeout(() => {
    console.log('=== Checking globals ===');
    console.log('commandData exists:', typeof window.commandData !== 'undefined');
    console.log('openDebugPage exists:', typeof window.openDebugPage === 'function');
    console.log('samplePrompt exists:', typeof window.samplePrompt !== 'undefined');
    console.log('handleSubmit exists:', typeof window.handleSubmit === 'function');
    
    process.exit(0);
}, 1000);
