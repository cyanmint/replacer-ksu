// WebUI JavaScript for Replacer module
const MODULE_PATH = '/data/adb/modules/replacer';
const CONFIG_FILE = `${MODULE_PATH}/conf.csv`;
const DISABLE_FILE = `${MODULE_PATH}/disable`;
const DISABLED_FILES_DIR = `${MODULE_PATH}/disabled_files`;

let currentEditingFile = CONFIG_FILE;
let configTree = null;

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    loadConfig();
    loadModuleState();
    buildConfigTree();
});

// Build configuration tree by parsing includes
async function buildConfigTree() {
    try {
        const tree = await parseConfigTree(CONFIG_FILE, 0);
        configTree = tree;
        renderTree(tree);
    } catch (error) {
        console.error('Error building config tree:', error);
        document.getElementById('configTreeContainer').innerHTML = 
            '<div class="tree-loading">Error loading configuration tree</div>';
    }
}

// Parse configuration file and build tree structure
async function parseConfigTree(filePath, depth, processed = new Set()) {
    // Prevent circular includes
    if (processed.has(filePath)) {
        return null;
    }
    processed.add(filePath);
    
    const node = {
        path: filePath,
        name: filePath.split('/').pop(),
        depth: depth,
        enabled: await isFileEnabled(filePath),
        children: [],
        exists: true
    };
    
    try {
        // Read file content
        const response = await ksu.exec(`cat "${filePath}" 2>/dev/null`);
        if (response.code !== 0) {
            node.exists = false;
            return node;
        }
        
        const lines = response.stdout.split('\n');
        
        for (const line of lines) {
            const trimmed = line.trim();
            
            // Skip comments and empty lines
            if (!trimmed || trimmed.startsWith('#')) continue;
            
            // Parse CSV
            const parts = line.split(',');
            if (parts.length < 2) continue;
            
            const original = parts[0].trim();
            const replacement = parts.slice(1).join(',').trim();
            
            // Check for %include directive
            if (original === '%include') {
                let includePath = replacement.replace(/\$\{mod_dir\}/g, MODULE_PATH)
                                           .replace(/\$\{MODDIR\}/g, MODULE_PATH);
                
                // Check if it's a directory
                const isDirCheck = await ksu.exec(`[ -d "${includePath}" ] && echo "yes" || echo "no"`);
                const isDir = isDirCheck.stdout.trim() === 'yes';
                
                if (isDir) {
                    // Include directory - get all CSV files
                    const filesResponse = await ksu.exec(`find "${includePath}" -maxdepth 1 -name "*.csv" -type f | sort`);
                    if (filesResponse.code === 0) {
                        const files = filesResponse.stdout.split('\n').filter(f => f.trim());
                        for (const file of files) {
                            const childNode = await parseConfigTree(file, depth + 1, new Set(processed));
                            if (childNode) {
                                node.children.push(childNode);
                            }
                        }
                    }
                } else {
                    // Include single file
                    const childNode = await parseConfigTree(includePath, depth + 1, new Set(processed));
                    if (childNode) {
                        node.children.push(childNode);
                    }
                }
            }
        }
    } catch (error) {
        console.error('Error parsing file:', filePath, error);
    }
    
    return node;
}

// Check if a file is enabled
async function isFileEnabled(filePath) {
    try {
        // Use md5 hash of path as marker filename (matching service.sh)
        const hashResponse = await ksu.exec(`echo -n "${filePath}" | md5sum | cut -d' ' -f1`);
        const hash = hashResponse.stdout.trim();
        const disabledMarker = `${DISABLED_FILES_DIR}/${hash}`;
        
        const response = await ksu.exec(`[ -f "${disabledMarker}" ] && echo "no" || echo "yes"`);
        return response.stdout.trim() === 'yes';
    } catch (error) {
        return true; // Default to enabled if check fails
    }
}

// Render tree view
function renderTree(tree) {
    const container = document.getElementById('configTreeContainer');
    container.innerHTML = '<div class="tree-container"></div>';
    const treeContainer = container.querySelector('.tree-container');
    
    renderNode(tree, treeContainer, tree.enabled);
}

// Render a single tree node
function renderNode(node, container, parentEnabled) {
    const nodeDiv = document.createElement('div');
    nodeDiv.className = 'tree-node' + (node.enabled ? '' : ' tree-node-disabled');
    nodeDiv.dataset.path = node.path;
    
    const contentDiv = document.createElement('div');
    contentDiv.className = 'tree-node-content';
    
    // Indent
    const indent = document.createElement('span');
    indent.className = 'tree-node-indent';
    indent.style.width = (node.depth * 20) + 'px';
    contentDiv.appendChild(indent);
    
    // Icon
    const icon = document.createElement('span');
    icon.className = 'tree-node-icon';
    icon.textContent = node.children.length > 0 ? '📁' : '📄';
    contentDiv.appendChild(icon);
    
    // File name
    const name = document.createElement('span');
    name.className = 'tree-node-name';
    name.textContent = node.path;
    contentDiv.appendChild(name);
    
    // Status badge
    if (!node.exists) {
        const status = document.createElement('span');
        status.className = 'tree-node-status';
        status.textContent = 'Not Found';
        contentDiv.appendChild(status);
    } else if (node.children.length > 0) {
        const status = document.createElement('span');
        status.className = 'tree-node-status included';
        status.textContent = `${node.children.length} included`;
        contentDiv.appendChild(status);
    }
    
    // Edit button
    if (node.exists) {
        const editBtn = document.createElement('button');
        editBtn.className = 'tree-node-edit';
        editBtn.textContent = 'Edit';
        editBtn.onclick = (e) => {
            e.stopPropagation();
            editFile(node.path);
        };
        contentDiv.appendChild(editBtn);
    }
    
    // Toggle switch
    const toggleDiv = document.createElement('label');
    toggleDiv.className = 'tree-node-toggle';
    
    const toggleInput = document.createElement('input');
    toggleInput.type = 'checkbox';
    toggleInput.checked = node.enabled;
    toggleInput.disabled = !parentEnabled; // Disable if parent is disabled
    toggleInput.onchange = async (e) => {
        e.stopPropagation();
        await toggleFile(node.path, toggleInput.checked);
        // Rebuild tree to reflect changes in children
        await buildConfigTree();
    };
    
    const toggleSlider = document.createElement('span');
    toggleSlider.className = 'tree-toggle-slider';
    
    toggleDiv.appendChild(toggleInput);
    toggleDiv.appendChild(toggleSlider);
    contentDiv.appendChild(toggleDiv);
    
    nodeDiv.appendChild(contentDiv);
    container.appendChild(nodeDiv);
    
    // Render children
    if (node.children.length > 0) {
        const childrenDiv = document.createElement('div');
        childrenDiv.className = 'tree-node-children';
        
        const effectiveEnabled = parentEnabled && node.enabled;
        for (const child of node.children) {
            renderNode(child, childrenDiv, effectiveEnabled);
        }
        
        nodeDiv.appendChild(childrenDiv);
    }
}

// Toggle file enabled/disabled state
async function toggleFile(filePath, enabled) {
    try {
        await ksu.exec(`mkdir -p "${DISABLED_FILES_DIR}"`);
        
        // Use md5 hash of path as marker filename (matching service.sh)
        const hashResponse = await ksu.exec(`echo -n "${filePath}" | md5sum | cut -d' ' -f1`);
        const hash = hashResponse.stdout.trim();
        const disabledMarker = `${DISABLED_FILES_DIR}/${hash}`;
        
        if (enabled) {
            // Enable file by removing marker
            await ksu.exec(`rm -f "${disabledMarker}"`);
            showStatus(`Enabled: ${filePath}`, 'success');
        } else {
            // Disable file by creating marker
            await ksu.exec(`echo "${filePath}" > "${disabledMarker}"`);
            showStatus(`Disabled: ${filePath} (and all its includes)`, 'success');
        }
    } catch (error) {
        console.error('Error toggling file:', error);
        showStatus('Failed to toggle file: ' + error.message, 'error');
    }
}

// Refresh tree view
async function refreshTree() {
    showStatus('Refreshing configuration tree...', 'success');
    await buildConfigTree();
}

// Edit a specific file
async function editFile(filePath) {
    currentEditingFile = filePath;
    document.getElementById('editingFileName').textContent = filePath.split('/').pop();
    
    try {
        const response = await ksu.exec(`cat "${filePath}" 2>/dev/null || echo "# New file"`);
        document.getElementById('configEditor').value = response.stdout || '';
        
        // Scroll to editor
        document.getElementById('configEditor').scrollIntoView({ behavior: 'smooth', block: 'center' });
        showStatus(`Editing: ${filePath}`, 'success');
    } catch (error) {
        console.error('Error loading file:', error);
        showStatus('Failed to load file: ' + error.message, 'error');
    }
}

// Load configuration file
async function loadConfig() {
    try {
        const response = await ksu.exec(`cat "${currentEditingFile}" 2>/dev/null || echo "# Configuration file not found"`);
        const config = response.stdout || '';
        document.getElementById('configEditor').value = config;
        showStatus('Configuration loaded', 'success');
    } catch (error) {
        console.error('Error loading config:', error);
        showStatus('Failed to load configuration: ' + error.message, 'error');
    }
}

// Save configuration file
async function saveConfig() {
    const content = document.getElementById('configEditor').value;
    
    try {
        // Write config file
        await ksu.exec(`cat > "${currentEditingFile}" << 'EOFCONFIG'\n${content}\nEOFCONFIG`);
        
        showStatus(`Configuration saved: ${currentEditingFile}! Changes will take effect on next boot.`, 'success');
        
        // Rebuild tree if we edited a file that might affect includes
        await buildConfigTree();
    } catch (error) {
        console.error('Error saving config:', error);
        showStatus('Failed to save configuration: ' + error.message, 'error');
    }
}

// Load module enable/disable state
async function loadModuleState() {
    try {
        const response = await ksu.exec(`[ -f "${DISABLE_FILE}" ] && echo "disabled" || echo "enabled"`);
        const state = response.stdout.trim();
        const checkbox = document.getElementById('moduleEnabled');
        checkbox.checked = (state === 'enabled');
        
        // Add event listener for toggle
        checkbox.addEventListener('change', toggleModule);
    } catch (error) {
        console.error('Error loading module state:', error);
    }
}

// Toggle module enable/disable
async function toggleModule() {
    const checkbox = document.getElementById('moduleEnabled');
    const enabled = checkbox.checked;
    
    try {
        if (enabled) {
            // Enable module by removing disable file
            await ksu.exec(`rm -f "${DISABLE_FILE}"`);
            showStatus('Module enabled! Reboot to apply changes.', 'success');
        } else {
            // Disable module by creating disable file
            await ksu.exec(`touch "${DISABLE_FILE}"`);
            showStatus('Module disabled! Reboot to apply changes.', 'success');
        }
    } catch (error) {
        console.error('Error toggling module:', error);
        // Revert checkbox state
        checkbox.checked = !enabled;
        showStatus('Failed to toggle module: ' + error.message, 'error');
    }
}

// Show status message
function showStatus(message, type) {
    const statusEl = document.getElementById('statusMessage');
    statusEl.textContent = message;
    statusEl.className = `status-message status-${type}`;
    statusEl.style.display = 'block';
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
        statusEl.style.display = 'none';
    }, 5000);
}

// KSU WebUI API wrapper (fallback for testing)
if (typeof ksu === 'undefined') {
    window.ksu = {
        exec: async function(command) {
            console.log('KSU exec (mock):', command);
            
            // Mock file contents
            const mockFiles = {
                '/data/adb/modules/replacer/conf.csv': `# Replacer main configuration
# This file supports %include directive to include other configurations

# Include system-wide configuration file
%include, /data/adb/replacer.conf

# Include all configurations from directory
%include, /data/adb/replacer.conf.d/
`,
                '/data/adb/replacer.conf': `# System-wide replacer configuration
# Add your global replacements here

# Example:
# /system/fonts/myfont.ttf, /data/adb/fonts/newfont.ttf
`,
                '/data/adb/replacer.conf.d/10-fonts.csv': `# Font replacements
/system/fonts/NotoSans.ttf, /data/adb/fonts/custom.ttf
`,
                '/data/adb/replacer.conf.d/20-apps.csv': `# App replacements
/system/priv-app/bloat/, _
`
            };
            
            // Handle cat commands for reading files
            if (command.includes('cat ')) {
                for (const [path, content] of Object.entries(mockFiles)) {
                    if (command.includes(path)) {
                        return { stdout: content, stderr: '', code: 0 };
                    }
                }
                // File not found
                return { stdout: '', stderr: 'File not found', code: 1 };
            }
            
            // Handle md5sum for file markers
            if (command.includes('md5sum')) {
                const match = command.match(/echo -n "([^"]+)"/);
                if (match) {
                    const input = match[1];
                    // Simple mock hash based on input length
                    const hash = 'abc' + input.length.toString().padStart(29, '0');
                    return { stdout: hash + '\n', stderr: '', code: 0 };
                }
                return { stdout: 'abc123def456\n', stderr: '', code: 0 };
            }
            
            // Handle file existence checks in disabled_files
            if (command.includes('[ -f ') && command.includes('disabled_files')) {
                // Mock: files are enabled by default
                return { stdout: 'yes', stderr: '', code: 0 };
            }
            
            // Handle directory checks
            if (command.includes('[ -d ')) {
                if (command.includes('replacer.conf.d')) {
                    return { stdout: 'yes', stderr: '', code: 0 };
                }
                return { stdout: 'no', stderr: '', code: 0 };
            }
            
            // Handle find command for directory listing
            if (command.includes('find') && command.includes('replacer.conf.d')) {
                return {
                    stdout: `/data/adb/replacer.conf.d/10-fonts.csv
/data/adb/replacer.conf.d/20-apps.csv`,
                    stderr: '',
                    code: 0
                };
            }
            
            // Handle module disable check
            if (command.includes('disable')) {
                return { stdout: 'enabled', stderr: '', code: 0 };
            }
            
            // Handle mkdir, rm, touch, echo commands (return success)
            if (command.includes('mkdir') || command.includes('rm ') || 
                command.includes('touch') || command.includes('echo ')) {
                return { stdout: '', stderr: '', code: 0 };
            }
            
            // Default success response
            return { stdout: '', stderr: '', code: 0 };
        }
    };
}
