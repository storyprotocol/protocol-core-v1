#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

// Issue type categories and fix suggestions
const issueCategories = {
  "reentrancy": { 
    name: "Reentrancy Attack", 
    description: "May lead to fund theft or state inconsistency",
    fix: "Use ReentrancyGuard or check-effects-interactions pattern",
    color: "#dc3545"
  },
  "arbitrary-send": { 
    name: "Arbitrary Transfer", 
    description: "May be exploited to transfer funds maliciously",
    fix: "Validate recipient address and amount, use whitelist mechanism",
    color: "#dc3545"
  },
  "uninitialized-state": { 
    name: "Uninitialized State", 
    description: "May cause unexpected behavior or security vulnerabilities",
    fix: "Ensure all state variables are initialized in constructor",
    color: "#dc3545"
  },
  "incorrect-shift": { 
    name: "Incorrect Shift", 
    description: "May cause calculation errors or overflow",
    fix: "Check shift operation logic, use SafeMath library",
    color: "#ffc107"
  },
  "abi-encode-packed": { 
    name: "ABI Encode Risk", 
    description: "May cause hash collisions or security issues",
    fix: "Avoid using dynamic types in abi.encodePacked",
    color: "#ffc107"
  },
  "external-calls": { 
    name: "External Calls", 
    description: "External calls in loops may cause performance issues",
    fix: "Consider batch processing, reduce external call frequency",
    color: "#28a745"
  },
  "timestamp": { 
    name: "Timestamp Dependency", 
    description: "May be manipulated by miners",
    fix: "Avoid relying on block.timestamp, use safer mechanisms",
    color: "#ffc107"
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

function generateIssuesRows(issues) {
  return issues.map(issue => {
    const category = getIssueCategory(issue.description);
    const categoryInfo = issueCategories[category] || { 
      name: '其他', 
      description: '代码质量问题',
      fix: '根据具体问题进行分析和修复'
    };
    
    const element = issue.elements && issue.elements[0];
    const fileName = element?.source_mapping?.filename_relative || 'Unknown';
    const lineNumber = element?.source_mapping?.lines?.[0] || 'Unknown';
    
    return `
      <tr data-severity="${issue.impact}">
        <td>
          <span class="severity-badge severity-${issue.impact.toLowerCase()}">
            ${issue.impact}
          </span>
        </td>
        <td>
          <div class="category-tag">${categoryInfo.name}</div>
          <div style="font-size: 12px; color: #6c757d; margin-top: 4px;">
            ${issue.check || 'Unknown'}
          </div>
        </td>
        <td>
          <div class="description">${issue.description}</div>
        </td>
        <td>
          <div class="file-path">${fileName}</div>
          <div class="line-number" style="margin-top: 8px;">行 ${lineNumber}</div>
        </td>
        <td>
          <div class="fix-suggestion">${categoryInfo.fix}</div>
        </td>
      </tr>
    `;
  }).join('');
}

function generateHTMLReport(data) {
  const issues = data.results.detectors || [];
  
  if (issues.length === 0) {
    return generateEmptyHTML();
  }
  
  // 按严重性分组
  const groupedIssues = {};
  issues.forEach(issue => {
    const impact = issue.impact;
    if (!groupedIssues[impact]) {
      groupedIssues[impact] = [];
    }
    groupedIssues[impact].push(issue);
  });
  
  // 按严重性优先级排序
  const severityOrder = ["High", "Medium", "Low", "Informational", "Optimization"];
  const sortedSeverities = severityOrder.filter(s => groupedIssues[s]);
  
  const totalIssues = issues.length;
  const highCount = groupedIssues.High?.length || 0;
  const mediumCount = groupedIssues.Medium?.length || 0;
  const lowCount = groupedIssues.Low?.length || 0;
  const infoCount = groupedIssues.Informational?.length || 0;
  const optCount = groupedIssues.Optimization?.length || 0;
  
  const html = `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Slither 安全分析报告</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f8f9fa;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: #f8f9fa;
            color: #333;
            padding: 30px 20px;
            text-align: center;
            border-bottom: 1px solid #e9ecef;
            margin-bottom: 30px;
        }
        
        .header h1 {
            font-size: 2rem;
            margin-bottom: 10px;
            font-weight: 400;
        }
        
        .header p {
            font-size: 1rem;
            color: #666;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        
        .stat-card {
            background: white;
            padding: 20px;
            border: 1px solid #e9ecef;
            text-align: center;
            border-radius: 6px;
        }
        
        .stat-card.high { border-left: 3px solid #dc3545; }
        .stat-card.medium { border-left: 3px solid #ffc107; }
        .stat-card.low { border-left: 3px solid #28a745; }
        .stat-card.info { border-left: 3px solid #17a2b8; }
        .stat-card.opt { border-left: 3px solid #6f42c1; }
        
        .stat-number {
            font-size: 2rem;
            font-weight: 600;
            margin-bottom: 8px;
        }
        
        .stat-label {
            color: #666;
            font-size: 0.85rem;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .controls {
            background: white;
            padding: 20px;
            border: 1px solid #e9ecef;
            border-radius: 6px;
            margin-bottom: 30px;
        }
        
        .search-box {
            width: 100%;
            padding: 10px 15px;
            border: 1px solid #ddd;
            border-radius: 4px;
            font-size: 14px;
            margin-bottom: 15px;
        }
        
        .search-box:focus {
            outline: none;
            border-color: #007bff;
        }
        
        .filters {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .filter-btn {
            padding: 6px 12px;
            border: 1px solid #ddd;
            background: white;
            border-radius: 4px;
            cursor: pointer;
            font-size: 13px;
        }
        
        .filter-btn:hover {
            background: #f8f9fa;
        }
        
        .filter-btn.active {
            background: #007bff;
            color: white;
            border-color: #007bff;
        }
        
        .issues-container {
            background: white;
            border: 1px solid #e9ecef;
            border-radius: 6px;
            overflow: hidden;
        }
        
        .issues-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .issues-table th {
            background: #f8f9fa;
            padding: 12px 15px;
            text-align: left;
            font-weight: 600;
            color: #333;
            border-bottom: 1px solid #dee2e6;
        }
        
        .issues-table td {
            padding: 12px 15px;
            border-bottom: 1px solid #e9ecef;
            vertical-align: top;
        }
        
        .issues-table tr:hover {
            background: #f8f9fa;
        }
        
        .severity-badge {
            padding: 3px 8px;
            border-radius: 3px;
            font-size: 11px;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .severity-high { background: #f8d7da; color: #721c24; }
        .severity-medium { background: #fff3cd; color: #856404; }
        .severity-low { background: #d4edda; color: #155724; }
        .severity-info { background: #d1ecf1; color: #0c5460; }
        .severity-opt { background: #e2d9f3; color: #5a2d82; }
        
        .category-tag {
            display: inline-block;
            padding: 2px 6px;
            background: #e9ecef;
            color: #495057;
            border-radius: 3px;
            font-size: 11px;
            margin: 1px;
        }
        
        .file-path {
            font-family: 'Monaco', 'Menlo', monospace;
            font-size: 12px;
            color: #666;
            background: #f8f9fa;
            padding: 3px 6px;
            border-radius: 3px;
        }
        
        .line-number {
            background: #007bff;
            color: white;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 11px;
            font-weight: bold;
        }
        
        .description {
            max-width: 300px;
            line-height: 1.4;
            font-size: 13px;
        }
        
        .fix-suggestion {
            background: #f8f9fa;
            border-left: 3px solid #28a745;
            padding: 8px;
            border-radius: 3px;
            margin-top: 6px;
            font-size: 12px;
        }
        
        .no-issues {
            text-align: center;
            padding: 60px 20px;
            color: #6c757d;
        }
        
        .no-issues h2 {
            font-size: 2rem;
            margin-bottom: 10px;
            color: #28a745;
        }
        
        .footer {
            text-align: center;
            margin-top: 40px;
            padding: 20px;
            color: #6c757d;
            font-size: 14px;
        }
        
        @media (max-width: 768px) {
            .container { padding: 10px; }
            .header h1 { font-size: 2rem; }
            .stats-grid { grid-template-columns: repeat(2, 1fr); }
            .filters { justify-content: center; }
            .issues-table { font-size: 14px; }
            .issues-table th, .issues-table td { padding: 10px 8px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Slither Security Analysis Report</h1>
            <p>Smart Contract Static Security Analysis Results</p>
        </div>
        
        <div class="stats-grid">
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
            <input type="text" class="search-box" placeholder="🔍 Search issues..." id="searchBox">
            <div class="filters">
                <button class="filter-btn active" data-severity="all">All</button>
                <button class="filter-btn" data-severity="High">High</button>
                <button class="filter-btn" data-severity="Medium">Medium</button>
                <button class="filter-btn" data-severity="Low">Low</button>
                <button class="filter-btn" data-severity="Informational">Info</button>
                <button class="filter-btn" data-severity="Optimization">Opt</button>
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
        // Search and filter functionality
        const searchBox = document.getElementById('searchBox');
        const issuesTableBody = document.getElementById('issuesTableBody');
        const filterBtns = document.querySelectorAll('.filter-btn');
        
        let currentFilter = 'all';
        let allIssues = ${JSON.stringify(issues)};
        
        function filterIssues() {
            const searchTerm = searchBox.value.toLowerCase();
            
            const filteredIssues = allIssues.filter(issue => {
                const matchesSearch = issue.description.toLowerCase().includes(searchTerm) ||
                                    (issue.check && issue.check.toLowerCase().includes(searchTerm));
                
                const matchesFilter = currentFilter === 'all' || issue.impact === currentFilter;
                
                return matchesSearch && matchesFilter;
            });
            
            renderIssues(filteredIssues);
        }
        
        function renderIssues(issues) {
            issuesTableBody.innerHTML = issues.map(issue => {
                const category = getIssueCategory(issue.description);
                const categoryInfo = issueCategories[category] || { 
                    name: 'Other', 
                    description: 'Code quality issue',
                    fix: 'Analyze and fix based on specific issue'
                };
                
                const element = issue.elements && issue.elements[0];
                const fileName = element?.source_mapping?.filename_relative || 'Unknown';
                const lineNumber = element?.source_mapping?.lines?.[0] || 'Unknown';
                
                return \`
                    <tr data-severity="\${issue.impact}">
                        <td>
                            <span class="severity-badge severity-\${issue.impact.toLowerCase()}">
                                \${issue.impact}
                            </span>
                        </td>
                        <td>
                            <div class="category-tag">\${categoryInfo.name}</div>
                            <div style="font-size: 12px; color: #666; margin-top: 4px;">
                                \${issue.check || 'Unknown'}
                            </div>
                        </td>
                        <td>
                            <div class="description">\${issue.description}</div>
                        </td>
                        <td>
                            <div class="file-path">\${fileName}</div>
                            <div class="line-number" style="margin-top: 8px;">Line \${lineNumber}</div>
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
        
        // Event listeners
        searchBox.addEventListener('input', filterIssues);
        
        filterBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                filterBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentFilter = btn.dataset.severity;
                filterIssues();
            });
        });
        
        // Initialize
        filterIssues();
    </script>
</body>
</html>`;
  
  return html;
}

function generateEmptyHTML() {
  return `
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Slither 安全分析报告</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f8f9fa;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
        }
        .no-issues {
            text-align: center;
            padding: 60px;
            background: white;
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .no-issues h2 {
            font-size: 3rem;
            margin-bottom: 20px;
            color: #28a745;
        }
        .no-issues p {
            font-size: 1.2rem;
            color: #6c757d;
        }
    </style>
</head>
<body>
    <div class="no-issues">
        <h2>🎉</h2>
        <p>没有发现安全问题！</p>
        <p>你的代码很安全 👍</p>
    </div>
</body>
</html>`;
}

function main() {
  try {
    const reportPath = path.join(process.cwd(), "slither-report.json");
    
    if (!fs.existsSync(reportPath)) {
      console.error("❌ 找不到 Slither 报告文件: slither-report.json");
      console.log("💡 请先运行: make slither");
      process.exit(1);
    }
    
    const reportData = JSON.parse(fs.readFileSync(reportPath, "utf8"));
    const html = generateHTMLReport(reportData);
    
    // 保存 HTML 报告
    const htmlPath = path.join(process.cwd(), "slither-report.html");
    fs.writeFileSync(htmlPath, html, "utf8");
    
    console.log("✅ HTML 报告已生成: slither-report.html");
    console.log("🌐 在浏览器中打开查看交互式报告");
    console.log("💡 支持搜索、过滤、排序等功能");
    
  } catch (error) {
    console.error("❌ 生成 HTML 报告时出错:", error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
