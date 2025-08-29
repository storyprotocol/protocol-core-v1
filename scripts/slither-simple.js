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

function generateSimpleHTMLReport(data) {
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
    <title>Slither Security Analysis Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { background: white; padding: 30px; text-align: center; border: 1px solid #e9ecef; margin-bottom: 20px; }
        .header h1 { font-size: 2rem; margin-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px; margin-bottom: 20px; }
        .stat-card { background: white; padding: 20px; border: 1px solid #e9ecef; text-align: center; }
        .stat-card.high { border-left: 3px solid #dc3545; }
        .stat-card.medium { border-left: 3px solid #ffc107; }
        .stat-card.low { border-left: 3px solid #28a745; }
        .stat-card.info { border-left: 3px solid #17a2b8; }
        .stat-card.opt { border-left: 3px solid #6f42c1; }
        .stat-number { font-size: 2rem; font-weight: 600; }
        .stat-label { color: #666; font-size: 0.9rem; margin-top: 5px; }
        .controls { background: white; padding: 20px; border: 1px solid #e9ecef; margin-bottom: 20px; }
        .search-box { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; margin-bottom: 15px; }
        .filters { display: flex; gap: 10px; flex-wrap: wrap; }
        .filter-btn { padding: 8px 16px; border: 1px solid #ddd; background: white; cursor: pointer; }
        .filter-btn.active { background: #007bff; color: white; border-color: #007bff; }
        .issues-container { background: white; border: 1px solid #e9ecef; }
        .issues-table { width: 100%; border-collapse: collapse; }
        .issues-table th { background: #f8f9fa; padding: 12px; text-align: left; border-bottom: 1px solid #dee2e6; }
        .issues-table td { padding: 12px; border-bottom: 1px solid #e9ecef; }
        .severity-badge { padding: 3px 8px; border-radius: 3px; font-size: 11px; font-weight: 600; }
        .severity-high { background: #f8d7da; color: #721c24; }
        .severity-medium { background: #fff3cd; color: #856404; }
        .severity-low { background: #d4edda; color: #155724; }
        .severity-info { background: #d1ecf1; color: #0c5460; }
        .severity-opt { background: #e2d9f3; color: #5a2d82; }
        .file-path { font-family: monospace; font-size: 12px; background: #f8f9fa; padding: 3px 6px; border-radius: 3px; }
        .line-number { background: #007bff; color: white; padding: 2px 6px; border-radius: 3px; font-size: 11px; }
        .fix-suggestion { background: #f8f9fa; border-left: 3px solid #28a745; padding: 8px; margin-top: 6px; }
        .footer { text-align: center; margin-top: 30px; color: #666; }
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
                <div class="stat-label">High Severity</div>
            </div>
            <div class="stat-card medium">
                <div class="stat-number">${mediumCount}</div>
                <div class="stat-label">Medium Severity</div>
            </div>
            <div class="stat-card low">
                <div class="stat-number">${lowCount}</div>
                <div class="stat-label">Low Severity</div>
            </div>
            <div class="stat-card info">
                <div class="stat-number">${infoCount}</div>
                <div class="stat-label">Informational</div>
            </div>
            <div class="stat-card opt">
                <div class="stat-number">${optCount}</div>
                <div class="stat-label">Optimization</div>
            </div>
        </div>
        
        <div class="controls">
            <input type="text" class="search-box" placeholder="Search issues..." id="searchBox">
            <div class="filters">
                <button class="filter-btn active" onclick="filterIssues('all')">All</button>
                <button class="filter-btn" onclick="filterIssues('High')">High</button>
                <button class="filter-btn" onclick="filterIssues('Medium')">Medium</button>
                <button class="filter-btn" onclick="filterIssues('Low')">Low</button>
                <button class="filter-btn" onclick="filterIssues('Informational')">Info</button>
                <button class="filter-btn" onclick="filterIssues('Optimization')">Opt</button>
            </div>
        </div>
        
        <div class="issues-container">
            <table class="issues-table">
                <thead>
                    <tr>
                        <th>Severity</th>
                        <th>Type</th>
                        <th>Description</th>
                        <th>Location</th>
                        <th>Fix Suggestion</th>
                    </tr>
                </thead>
                <tbody id="issuesTableBody">
                    ${generateIssuesRows(issues)}
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p>Report generated: ${new Date().toLocaleString()}</p>
            <p>Total issues found: ${totalIssues}</p>
        </div>
    </div>

    <script>
        let allIssues = ${JSON.stringify(issues)};
        let currentFilter = 'all';
        
        function filterIssues(severity) {
            currentFilter = severity;
            
            // Update button states
            document.querySelectorAll('.filter-btn').forEach(btn => {
                btn.classList.remove('active');
            });
            event.target.classList.add('active');
            
            // Filter issues
            const filteredIssues = allIssues.filter(issue => {
                return severity === 'all' || issue.impact === severity;
            });
            
            renderIssues(filteredIssues);
        }
        
        function renderIssues(issues) {
            const tbody = document.getElementById('issuesTableBody');
            tbody.innerHTML = issues.map(issue => {
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
                        <><td>
      <span class="severity-badge severity-${issue.impact.toLowerCase()}">
        ${issue.impact}
      </span>
    </td><td>${categoryInfo.name}</td><td>${issue.description}</td><td>
        <div class="file-path">${fileName}</div>
        <div class="line-number">Line ${lineNumber}</div>
      </td><td>
        <div class="fix-suggestion">${categoryInfo.fix}</div>
      </td></>
                    </tr>
                `;
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
        
        // Search functionality
        document.getElementById('searchBox').addEventListener('input', function() {
            const searchTerm = this.value.toLowerCase();
            const filteredIssues = allIssues.filter(issue => {
                const matchesSearch = issue.description.toLowerCase().includes(searchTerm) ||
                                    (issue.check && issue.check.toLowerCase().includes(searchTerm));
                const matchesFilter = currentFilter === 'all' || issue.impact === currentFilter;
                return matchesSearch && matchesFilter;
            });
            renderIssues(filteredIssues);
        });
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
    <title>Slither Security Analysis Report</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8f9fa; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
        .no-issues { text-align: center; padding: 60px; background: white; border-radius: 20px; border: 1px solid #e9ecef; }
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
        <td>${issue.description}</td>
        <td>
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
    const html = generateSimpleHTMLReport(reportData);
    
    // Save HTML report
    const htmlPath = path.join(process.cwd(), "slither-report.html");
    fs.writeFileSync(htmlPath, html, "utf8");
    
    console.log("✅ HTML report generated: slither-report.html");
    console.log("🌐 Open in browser to view interactive report");
    console.log("💡 Features: search, filter by severity, clean design");
    
  } catch (error) {
    console.error("❌ Error generating HTML report:", error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
