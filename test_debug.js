const { JSDOM } = require('jsdom');
const fs = require('fs');

const html = fs.readFileSync('/Users/yml/Desktop/caibaoUI_skill/command-center.html', 'utf8');
const dom = new JSDOM(html, { runScripts: 'dangerously', url: 'http://localhost' });
const document = dom.window.document;
const window = dom.window;

// Wait for scripts to execute
setTimeout(() => {
    console.log('=== Testing openDebugPage with new command ===');
    
    // Access global variables from the script
    const commandData = window.commandData;
    const openDebugPage = window.openDebugPage;
    
    console.log('commandData length:', commandData.length);
    console.log('First item:', commandData[0]);
    
    // Simulate adding a new command like handleSubmit does
    const newCommand = {
        id: Date.now(),
        name: 'Test Command',
        desc: '所属分组：默认分组 | 管理员：余梦玲',
        time: '2024-12-19 14:30',
        group: '默认分组'
    };
    
    commandData.unshift(newCommand);
    
    console.log('New command id:', newCommand.id);
    console.log('New command name:', newCommand.name);
    console.log('New command desc:', newCommand.desc);
    
    // Call openDebugPage
    openDebugPage(newCommand.id);
    
    // Check results
    const breadcrumb = document.getElementById('breadcrumbCommandName');
    const textarea = document.getElementById('debugPromptTextarea');
    
    console.log('Breadcrumb text:', breadcrumb ? breadcrumb.textContent : 'null');
    console.log('Textarea textContent:', textarea ? textarea.textContent : 'null');
    console.log('Textarea innerHTML:', textarea ? textarea.innerHTML : 'null');
    console.log('debugPage active:', document.getElementById('debugPage').classList.contains('active'));
    
    process.exit(0);
}, 100);
