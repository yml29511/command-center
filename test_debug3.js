const { JSDOM } = require('jsdom');
const fs = require('fs');

// Read only the HTML structure without scripts
let html = fs.readFileSync('/Users/yml/Desktop/caibaoUI_skill/command-center.html', 'utf8');

// Create DOM
const dom = new JSDOM(html, { runScripts: 'dangerously', url: 'http://localhost' });
const window = dom.window;
const document = window.document;

// Wait a bit for scripts to run
setTimeout(() => {
    console.log('commandData exists:', typeof window.commandData !== 'undefined');
    console.log('openDebugPage exists:', typeof window.openDebugPage === 'function');
    console.log('samplePrompt exists:', typeof window.samplePrompt !== 'undefined');
    
    if (window.commandData) {
        console.log('Initial commandData length:', window.commandData.length);
        
        // Simulate handleSubmit
        const newCommand = {
            id: Date.now(),
            name: 'Test New Command',
            desc: '所属分组：默认分组 | 管理员：余梦玲',
            time: '2024-12-19 14:30',
            group: '默认分组'
        };
        
        window.commandData.unshift(newCommand);
        console.log('Added new command, id:', newCommand.id);
        
        // Call openDebugPage
        window.openDebugPage(newCommand.id);
        
        // Check results
        const breadcrumb = document.getElementById('breadcrumbCommandName');
        const textarea = document.getElementById('debugPromptTextarea');
        const debugPage = document.getElementById('debugPage');
        
        console.log('Breadcrumb text:', breadcrumb ? breadcrumb.textContent : 'null');
        console.log('Textarea content:', textarea ? textarea.textContent.substring(0, 50) + '...' : 'null');
        console.log('DebugPage active:', debugPage ? debugPage.classList.contains('active') : 'null');
    }
    
    process.exit(0);
}, 500);
