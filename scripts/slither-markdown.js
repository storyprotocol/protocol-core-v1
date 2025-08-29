#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

// 问题类型分类和修复建议
const issueCategories = {
  "reentrancy": { 
    name: "重入攻击", 
    description: "可能导致资金被盗或状态不一致",
    fix: "使用 ReentrancyGuard 或检查-效果-交互模式"
  },
  "arbitrary-send": { 
    name: "任意转账", 
    description: "可能被恶意利用转移资金",
    fix: "验证接收地址和金额，使用白名单机制"
  },
  "uninitialized-state": { 
    name: "未初始化状态", 
    description: "可能导致意外行为或安全漏洞",
    fix: "确保所有状态变量在构造函数中初始化"
  },
  "incorrect-shift": { 
    name: "位移操作错误", 
    description: "可能导致计算错误或溢出",
    fix: "检查位移操作的逻辑，使用 SafeMath 库"
  },
  "abi-encode-packed": { 
    name: "ABI编码风险", 
    description: "可能导致哈希碰撞或安全问题",
    fix: "避免在 abi.encodePacked 中使用动态类型"
  },
  "external-calls": { 
    name: "外部调用", 
    description: "在循环中的外部调用可能导致性能问题",
    fix: "考虑批量处理，减少外部调用次数"
  },
  "timestamp": { 
    name: "时间戳依赖", 
    description: "可能被矿工操纵",
    fix: "避免依赖 block.timestamp，使用更安全的机制"
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

function generateMarkdownReport(data) {
  const issues = data.results.detectors || [];
  
  if (issues.length === 0) {
    return "# 🎉 Slither 安全分析报告\n\n没有发现安全问题！";
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
  const severityOrder = ["High", "Medium", "Low", "Informational"];
  const sortedSeverities = severityOrder.filter(s => groupedIssues[s]);
  
  let markdown = "# 🔍 Slither 安全分析报告\n\n";
  markdown += "> 自动生成的智能合约安全分析报告\n\n";
  
  // 统计信息
  const totalIssues = issues.length;
  const highCount = groupedIssues.High?.length || 0;
  const mediumCount = groupedIssues.Medium?.length || 0;
  const lowCount = groupedIssues.Low?.length || 0;
  const infoCount = groupedIssues.Informational?.length || 0;
  
  markdown += "## 📊 问题统计\n\n";
  markdown += "| 严重性 | 数量 | 状态 |\n";
  markdown += "|--------|------|------|\n";
  markdown += `| 🔴 高严重性 | ${highCount} | ${highCount > 0 ? "⚠️ 需要立即修复" : "✅ 无问题"} |\n`;
  markdown += `| 🟡 中等严重性 | ${mediumCount} | ${mediumCount > 0 ? "⚠️ 建议尽快修复" : "✅ 无问题"} |\n`;
  markdown += `| 🟢 低严重性 | ${lowCount} | ${lowCount > 0 ? "ℹ️ 可以逐步修复" : "✅ 无问题"} |\n`;
  markdown += `| ℹ️ 信息性 | ${infoCount} | ${infoCount > 0 ? "ℹ️ 代码质量建议" : "✅ 无问题"} |\n\n`;
  markdown += `**总计: ${totalIssues} 个问题**\n\n`;
  
  // 按严重性显示问题
  sortedSeverities.forEach(severity => {
    const issuesInSeverity = groupedIssues[severity];
    const icon = severity === "High" ? "🔴" : severity === "Medium" ? "🟡" : severity === "Low" ? "🟢" : "ℹ️";
    
    markdown += `## ${icon} ${severity} 严重性问题 (${issuesInSeverity.length}个)\n\n`;
    
    issuesInSeverity.forEach((issue, index) => {
      const category = getIssueCategory(issue.description);
      const categoryInfo = issueCategories[category] || { 
        name: "其他", 
        description: "代码质量问题",
        fix: "根据具体问题进行分析和修复"
      };
      
      markdown += `### Issue ${index + 1}: ${issue.check}\n\n`;
      markdown += "**问题类型:** " + categoryInfo.name + "\n\n";
      markdown += "**影响:** " + issue.impact + "\n\n";
      markdown += "**置信度:** " + issue.confidence + "\n\n";
      markdown += "**描述:** " + categoryInfo.description + "\n\n";
      markdown += "**详细说明:** " + issue.description + "\n\n";
      
      if (issue.elements && issue.elements.length > 0) {
        const element = issue.elements[0];
        if (element.type === "function") {
          markdown += "**位置信息:**\n\n";
          markdown += "- **函数:** `" + element.name + "()`\n";
          if (element.source_mapping?.filename_relative) {
            markdown += "- **文件:** `" + element.source_mapping.filename_relative + "`\n";
          }
          if (element.source_mapping?.lines) {
            markdown += "- **行号:** " + element.source_mapping.lines[0] + "\n";
          }
          markdown += "\n";
        }
      }
      
      markdown += "**修复建议:** " + categoryInfo.fix + "\n\n";
      markdown += "---\n\n";
    });
  });
  
  // 修复建议总结
  markdown += "## 💡 修复建议总结\n\n";
  
  if (highCount > 0) {
    markdown += "### 🔴 高严重性问题 (立即修复)\n\n";
    markdown += "- **重入攻击**: 使用 ReentrancyGuard 或检查-效果-交互模式\n";
    markdown += "- **任意转账**: 验证接收地址和金额，使用白名单机制\n";
    markdown += "- **未初始化变量**: 确保所有状态变量在构造函数中初始化\n\n";
  }
  
  if (mediumCount > 0) {
    markdown += "### 🟡 中等严重性问题 (尽快修复)\n\n";
    markdown += "- **数学运算**: 检查除零和溢出情况，使用 SafeMath 库\n";
    markdown += "- **返回值忽略**: 处理函数返回值，避免忽略重要信息\n";
    markdown += "- **循环中的外部调用**: 考虑批量处理，减少外部调用次数\n\n";
  }
  
  if (lowCount > 0) {
    markdown += "### 🟢 低严重性问题 (逐步修复)\n\n";
    markdown += "- **命名约定**: 遵循 Solidity 命名规范\n";
    markdown += "- **未使用代码**: 清理死代码，提高代码质量\n";
    markdown += "- **代码风格**: 提高代码可读性和维护性\n\n";
  }
  
  // 最佳实践建议
  markdown += "## 🚀 最佳实践建议\n\n";
  markdown += "1. **定期运行**: 在每次代码提交前运行 Slither 分析\n";
  markdown += "2. **优先级修复**: 优先修复高严重性问题，逐步处理其他问题\n";
  markdown += "3. **代码审查**: 将 Slither 报告作为代码审查的一部分\n";
  markdown += "4. **持续改进**: 建立安全编码规范和最佳实践\n";
  markdown += "5. **团队培训**: 提高团队对智能合约安全的认识\n\n";
  
  // 报告信息
  markdown += "## 📋 报告信息\n\n";
  markdown += "- **生成时间**: " + new Date().toLocaleString() + "\n";
  markdown += "- **Slither 版本**: " + (data.version || "未知") + "\n";
  markdown += "- **分析合约数**: " + (data.results?.contracts?.length || "未知") + "\n";
  markdown += "- **详细报告**: `slither-report.json`\n";
  markdown += "- **SARIF 报告**: `slither-report.sarif`\n\n";
  
  markdown += "---\n\n";
  markdown += "*此报告由 Slither 自动生成，建议结合人工审查进行安全评估。*\n";
  
  return markdown;
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
    const markdown = generateMarkdownReport(reportData);
    
    // 保存 Markdown 报告
    const markdownPath = path.join(process.cwd(), "slither-report.md");
    fs.writeFileSync(markdownPath, markdown, "utf8");
    
    console.log("✅ Markdown 报告已生成: slither-report.md");
    console.log("📖 可以在 GitHub 或其他 Markdown 查看器中查看");
    
  } catch (error) {
    console.error("❌ 生成 Markdown 报告时出错:", error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
