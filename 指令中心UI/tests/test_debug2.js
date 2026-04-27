const { JSDOM } = require('jsdom');

// Create a minimal HTML structure
const html = `
<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body>
<div id="listPage"></div>
<div class="tab-nav"></div>
<div class="debug-page" id="debugPage">
    <span id="breadcrumbCommandName">默认</span>
    <div class="debug-layout">
        <div class="debug-left-column">
            <div class="debug-combined-card">
                <div class="debug-prompt-textarea" id="debugPromptTextarea" contenteditable="true" data-placeholder="请输入 Prompt 内容..."></div>
            </div>
        </div>
    </div>
    <div class="debug-placeholder" id="debugPlaceholder"></div>
    <div class="browser-preview-section"></div>
    <div id="taskStatusSection"></div>
    <div id="taskStatusContent"></div>
    <div id="browserContent"></div>
    <div id="debugResizeBtn"></div>
</div>
<script>
const samplePrompt = "This is a sample prompt content.";

const commandData = [
    { id: 1, name: 'Test', desc: 'A test command desc', time: '2024-01-01', group: '默认分组' }
];

function openDebugPage(id) {
    const item = commandData.find(cmd => cmd.id === id);
    if (!item) {
        console.log('Item not found for id:', id);
        return;
    }
    
    console.log('Found item:', JSON.stringify(item));
    
    document.getElementById('breadcrumbCommandName').textContent = item.name || '未命名指令';
    
    const textarea = document.getElementById('debugPromptTextarea');
    console.log('Textarea element:', textarea ? 'found' : 'not found');
    
    if (item.desc && item.desc.length > 50) {
        textarea.textContent = item.desc;
        console.log('Set desc (long)');
    } else {
        textarea.textContent = samplePrompt;
        console.log('Set samplePrompt');
    }
    
    console.log('After set - textContent:', textarea.textContent);
    console.log('After set - innerHTML:', textarea.innerHTML);
    
    if (textarea) textarea.contentEditable = 'true';
    
    document.getElementById('listPage').classList.add('hidden');
    document.getElementById('debugPage').classList.add('active');
    document.querySelector('.tab-nav').style.display = 'none';
}

// Simulate handleSubmit
const newCommand = {
    id: Date.now(),
    name: 'New Command',
    desc: '所属分组：默认分组 | 管理员：余梦玲',
    time: '2024-12-19 14:30',
    group: '默认分组'
};

commandData.unshift(newCommand);

console.log('Calling openDebugPage with id:', newCommand.id);
openDebugPage(newCommand.id);

console.log('=== Final Results ===');
console.log('Breadcrumb:', document.getElementById('breadcrumbCommandName').textContent);
console.log('Textarea textContent:', document.getElementById('debugPromptTextarea').textContent);
</script>
</body>
</html>
`;

const dom = new JSDOM(html, { runScripts: 'dangerously' });
