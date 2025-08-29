#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

// Issue type categories and fix suggestions
const issueCategories = {
  "reentrancy": { 
    name: "Reentrancy Attack", 
    fix: "Use ReentrancyGuard or check-effects-interactions pattern"
  },
  "arbitrary-send": { 
    name: "Arbitrary Transfer", 
    fix: "Validate recipient address and amount, use whitelist mechanism"
  },
  "uninitialized-state": { 
    name: "Uninitialized State", 
    fix: "Ensure all state variables are initialized in constructor"
  },
  "incorrect-shift": { 
    name: "Incorrect Shift", 
    fix: "Check shift operation logic, use SafeMath library"
  },
  "abi-encode-packed": { 
    name: "ABI Encode Risk", 
    fix: "Avoid using dynamic types in abi.encodePacked"
  },
  "external-calls": { 
    name: "External Calls", 
    fix: "Consider batch processing, reduce external call frequency"
  },
  "timestamp": { 
    name: "Timestamp Dependency", 
    fix: "Avoid relying on block.timestamp, use safer mechanisms"
  }
};

function getIssueCategory(description) {
  const desc = description.toLowerCase();
  if (desc.includes("reentrancy")) return "reentrancy";
  if (desc.includes("arbitrary") || desc.includes("transferfrom")) return "arbitrary-send";
  if (desc.includes("never initialized")) return "uninitialized-state";
  if (desc.includes("incorrect shift")) return "incorrect-shift";
  if (desc.includes("abi.encodepacked")) return "abi-encode-packed";
  if (desc.includes("external calls inside a loop")) return "external-calls";
  if (desc.includes("timestamp")) return "timestamp";
  return "other";
}

function generateCleanHTMLReport(data) {
  const issues = data.results.detectors || [];
  
  if (issues.length === 0) {
    return generateEmptyHTML();
  }
  
  // Group issues by severity
  const groupedIssues = {};
  issues.forEach(issue => {
    const impact = issue.impact;
    if (!groupedIssues[impact]) {
      groupedIssues[impact] = [];
    }
    groupedIssues[impact].push(issue);
  });
  
  const totalIssues = issues.length;
  const highCount = groupedIssues.High?.length || 0;
  const mediumCount = groupedIssues.Medium?.length || 0;
  const lowCount = groupedIssues.Low?.length || 0;
  const infoCount = groupedIssues.Informational?.length || 0;
  const optCount = groupedIssues.Optimization?.length || 0;
  
  const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Slither Security Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; padding: 20px; }
        .header { background: white; padding: 20px; text-align: center; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header h1 { font-size: 1.8rem; margin-bottom: 8px; color: #333; }
        .header p { color: #666; }
        
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 12px; margin-bottom: 20px; }
        .stat-card { background: white; padding: 16px; border-radius: 8px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-card.high { border-left: 4px solid #dc3545; }
        .stat-card.medium { border-left: 4px solid #ffc107; }
        .stat-card.low { border-left: 4px solid #28a745; }
        .stat-card.info { border-left: 4px solid #17a2b8; }
        .stat-card.opt { border-left: 4px solid #6f42c1; }
        .stat-number { font-size: 1.5rem; font-weight: 600; color: #333; }
        .stat-label { color: #666; font-size: 0.8rem; margin-top: 4px; }
        
        .controls { background: white; padding: 16px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .search-box { width: 100%; padding: 8px 12px; border: 1px solid #ddd; border-radius: 4px; margin-bottom: 12px; font-size: 14px; }
        .filters { display: flex; gap: 8px; flex-wrap: wrap; }
        .filter-btn { padding: 6px 12px; border: 1px solid #ddd; background: white; cursor: pointer; border-radius: 4px; font-size: 13px; transition: all 0.2s; }
        .filter-btn:hover { background: #f8f9fa; }
        .filter-btn.active { background: #007bff; color: white; border-color: #007bff; }
        
        .issues-container { background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .issues-table { width: 100%; border-collapse: collapse; }
        .issues-table th { background: #f8f9fa; padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; font-weight: 600; color: #495057; }
        .issues-table td { padding: 12px; border-bottom: 1px solid #e9ecef; vertical-align: top; }
        .issues-table tr:hover { background: #f8f9fa; }
        
        .severity-badge { padding: 4px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; display: inline-block; min-width: 60px; text-align: center; }
        .severity-high { background: #f8d7da; color: #721c24; }
        .severity-medium { background: #fff3cd; color: #856404; }
        .severity-low { background: #d4edda; color: #155724; }
        .severity-info { background: #d1ecf1; color: #0c5460; }
        .severity-opt { background: #e2d9f3; color: #5a2d82; }
        
        .file-path { font-family: monospace; font-size: 11px; background: #f8f9fa; padding: 2px 6px; border-radius: 3px; color: #495057; }
        .line-number { background: #007bff; color: white; padding: 2px 6px; border-radius: 3px; font-size: 10px; margin-left: 4px; }
        .fix-suggestion { background: #f8f9fa; border-left: 3px solid #28a745; padding: 6px; margin-top: 4px; font-size: 12px; color: #495057; }
        
        .description { max-width: 400px; word-wrap: break-word; line-height: 1.4; }
        .location { white-space: nowrap; }
        
        .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
        
        .no-results { text-align: center; padding: 40px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Slither Security Analysis Report</h1>
            <p>Smart Contract Static Security Analysis Results</p>
        </div>
        
        <div class="stats">
            <div class="stat-card high">
                <div class="stat-number">${highCount}</div>
                <div class="stat-label">High</div>
            </div>
            <div class="stat-card medium">
                <div class="stat-number">${mediumCount}</div>
                <div class="stat-label">Medium</div>
            </div>
            <div class="stat-card low">
                <div class="stat-number">${lowCount}</div>
                <div class="stat-label">Low</div>
            </div>
            <div class="stat-card info">
                <div class="stat-number">${infoCount}</div>
                <div class="stat-label">Info</div>
            </div>
            <div class="stat-card opt">
                <div class="stat-number">${optCount}</div>
                <div class="stat-label">Opt</div>
            </div>
        </div>
        
        <div class="controls">
            <input type="text" class="search-box" placeholder="Search issues..." id="searchBox">
            <div class="filters">
                <button class="filter-btn active" data-filter="all">All (${totalIssues})</button>
                <button class="filter-btn" data-filter="High">High (${highCount})</button>
                <button class="filter-btn" data-filter="Medium">Medium (${mediumCount})</button>
                <button class="filter-btn" data-filter="Low">Low (${lowCount})</button>
                <button class="filter-btn" data-filter="Informational">Info (${infoCount})</button>
                <button class="filter-btn" data-filter="Optimization">Opt (${optCount})</button>
            </div>
        </div>
        
        <div class="issues-container">
            <table class="issues-table">
                <thead>
                    <tr>
                        <th style="width: 80px;">Severity</th>
                        <th style="width: 120px;">Type</th>
                        <th style="width: 500px;">Description</th>
                        <th style="width: 200px;">Location</th>
                        <th style="width: 200px;">Fix Suggestion</th>
                    </tr>
                </thead>
                <tbody id="issuesTableBody">
                    ${generateIssuesRows(issues)}
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>Report generated: ${new Date().toLocaleString()} | Total issues: ${totalIssues}</p>
        </div>
    </div>

    <script>
        // Simple and reliable filtering system
        const allIssues = ${JSON.stringify(issues)};
        let currentFilter = 'all';
        let currentSearch = '';
        
        // Initialize the page
        document.addEventListener('DOMContentLoaded', function() {
            setupFilters();
            setupSearch();
            renderTable();
        });
        
        function setupFilters() {
            const filterBtns = document.querySelectorAll('.filter-btn');
            filterBtns.forEach(btn => {
                btn.addEventListener('click', function() {
                    const filter = this.getAttribute('data-filter');
                    setActiveFilter(filter);
                    renderTable();
                });
            });
        }
        
        function setupSearch() {
            const searchBox = document.getElementById('searchBox');
            searchBox.addEventListener('input', function() {
                currentSearch = this.value.toLowerCase();
                renderTable();
            });
        }
        
        function setActiveFilter(filter) {
            currentFilter = filter;
            
            // Update button states
            document.querySelectorAll('.filter-btn').forEach(btn => {
                btn.classList.remove('active');
                if (btn.getAttribute('data-filter') === filter) {
                    btn.classList.add('active');
                }
            });
        }
        
        function renderTable() {
            const filteredIssues = allIssues.filter(issue => {
                // Apply severity filter
                if (currentFilter !== 'all' && issue.impact !== currentFilter) {
                    return false;
                }
                
                // Apply search filter
                if (currentSearch) {
                    const searchText = issue.description.toLowerCase();
                    const checkText = (issue.check || '').toLowerCase();
                    if (!searchText.includes(currentSearch) && !checkText.includes(currentSearch)) {
                        return false;
                    }
                }
                
                return true;
            });
            
            const tbody = document.getElementById('issuesTableBody');
            
            if (filteredIssues.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" class="no-results">No issues match the current filter</td></tr>';
                return;
            }
            
            tbody.innerHTML = filteredIssues.map(issue => {
                const category = getIssueCategory(issue.description);
                const categoryInfo = issueCategories[category] || { 
                    name: 'Other', 
                    fix: 'Analyze and fix based on specific issue'
                };
                
                const element = issue.elements && issue.elements[0];
                const fileName = element?.source_mapping?.filename_relative || 'Unknown';
                const lineNumber = element?.source_mapping?.lines?.[0] || 'Unknown';
                
                return \`
                    <tr>
                        <td>
                            <span class="severity-badge severity-\${issue.impact.toLowerCase()}">
                                \${issue.impact}
                            </span>
                        </td>
                        <td>\${categoryInfo.name}</td>
                        <td class="description">\${issue.description}</td>
                        <td class="location">
                            <div class="file-path">\${fileName}</div>
                            <div class="line-number">Line \${lineNumber}</div>
                        </td>
                        <td>
                            <div class="fix-suggestion">\${categoryInfo.fix}</div>
                        </td>
                    </tr>
                \`;
            }).join('');
        }
        
        function getIssueCategory(description) {
            const desc = description.toLowerCase();
            if (desc.includes('reentrancy')) return 'reentrancy';
            if (desc.includes('arbitrary') || desc.includes('transferfrom')) return 'arbitrary-send';
            if (desc.includes('never initialized')) return 'uninitialized-state';
            if (desc.includes('incorrect shift')) return 'incorrect-shift';
            if (desc.includes('abi.encodepacked')) return 'abi-encode-packed';
            if (desc.includes('external calls inside a loop')) return 'external-calls';
            if (desc.includes('timestamp')) return 'timestamp';
            return 'other';
        }
    </script>
</body>
</html>`;
  
  return html;
}

function generateEmptyHTML() {
  return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Slither Security Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
        .no-issues { text-align: center; padding: 60px; background: white; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .no-issues h2 { font-size: 3rem; margin-bottom: 20px; color: #28a745; }
        .no-issues p { font-size: 1.2rem; color: #666; }
    </style>
</head>
<body>
    <div class="no-issues">
        <h2>🎉</h2>
        <p>No security issues found!</p>
        <p>Your code is secure 👍</p>
    </div>
</body>
</html>`;
}

function generateIssuesRows(issues) {
  return issues.map(issue => {
    const category = getIssueCategory(issue.description);
    const categoryInfo = issueCategories[category] || { 
      name: 'Other', 
      fix: 'Analyze and fix based on specific issue'
    };
    
    const element = issue.elements && issue.elements[0];
    const fileName = element?.source_mapping?.filename_relative || 'Unknown';
    const lineNumber = element?.source_mapping?.lines?.[0] || 'Unknown';
    
    return `
      <tr>
        <td>
          <span class="severity-badge severity-${issue.impact.toLowerCase()}">
            ${issue.impact}
          </span>
        </td>
        <td>${categoryInfo.name}</td>
        <td class="description">${issue.description}</td>
        <td class="location">
          <div class="file-path">${fileName}</div>
          <div class="line-number">Line ${lineNumber}</div>
        </td>
        <td>
          <div class="fix-suggestion">${categoryInfo.fix}</div>
        </td>
      </tr>
    `;
  }).join('');
}

function main() {
  try {
    const reportPath = path.join(process.cwd(), "slither-report.json");
    
    if (!fs.existsSync(reportPath)) {
      console.error("❌ Slither report file not found: slither-report.json");
      console.log("💡 Please run: make slither");
      process.exit(1);
    }
    
    const reportData = JSON.parse(fs.readFileSync(reportPath, "utf8"));
    const html = generateCleanHTMLReport(reportData);
    
    // Save HTML report
    const htmlPath = path.join(process.cwd(), "slither-report.html");
    fs.writeFileSync(htmlPath, html, "utf8");
    
    console.log("✅ Clean HTML report generated: slither-report.html");
    console.log("🌐 Open in browser to view interactive report");
    console.log("💡 Features: reliable filtering, better layout, responsive design");
    
  } catch (error) {
    console.error("❌ Error generating HTML report:", error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
