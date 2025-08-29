#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// 颜色代码
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m'
};

// 严重性图标和颜色
const severityConfig = {
  High: { icon: '🔴', color: colors.red, priority: 1 },
  Medium: { icon: '🟡', color: colors.yellow, priority: 2 },
  Low: { icon: '🟢', color: colors.green, priority: 3 },
  Informational: { icon: 'ℹ️', color: colors.blue, priority: 4 }
};

// Issue type categories
const issueCategories = {
  'reentrancy': { name: 'Reentrancy Attack', description: 'May lead to fund theft or state inconsistency' },
  'arbitrary-send': { name: 'Arbitrary Transfer', description: 'May be exploited to transfer funds maliciously' },
  'uninitialized-state': { name: 'Uninitialized State', description: 'May cause unexpected behavior or security vulnerabilities' },
  'incorrect-shift': { name: 'Incorrect Shift', description: 'May cause calculation errors or overflow' },
  'abi-encode-packed': { name: 'ABI Encode Risk', description: 'May cause hash collisions or security issues' },
  'external-calls': { name: 'External Calls', description: 'External calls in loops may cause performance issues' },
  'timestamp': { name: 'Timestamp Dependency', description: 'May be manipulated by miners' }
};

function colorize(text, color) {
  return `${color}${text}${colors.reset}`;
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

function formatIssue(issue, index) {
  const config = severityConfig[issue.impact] || { icon: '❓', color: colors.white };
  const category = getIssueCategory(issue.description);
  const categoryInfo = issueCategories[category] || { name: '其他', description: '代码质量问题' };
  
  let output = '';
  output += `${config.icon} ${colorize(`Issue ${index + 1}: ${issue.check || 'Unknown'}`, config.color)}\n`;
  output += `   ${colorize('Impact:', colors.bright)} ${issue.impact || 'Unknown'}\n`;
  output += `   ${colorize('Confidence:', colors.bright)} ${issue.confidence || 'Unknown'}\n`;
  output += `   ${colorize('Category:', colors.bright)} ${categoryInfo.name}\n`;
  output += `   ${colorize('Description:', colors.bright)} ${categoryInfo.description}\n`;
  
  if (issue.elements && issue.elements.length > 0) {
    const element = issue.elements[0];
    if (element.type === 'function') {
      output += `   ${colorize('Function:', colors.bright)} ${element.name || 'Unknown'}()\n`;
      if (element.source_mapping?.filename_relative) {
        output += `   ${colorize('File:', colors.bright)} ${element.source_mapping.filename_relative}\n`;
      }
      if (element.source_mapping?.lines && element.source_mapping.lines.length > 0) {
        output += `   ${colorize('Line:', colors.bright)} ${element.source_mapping.lines[0]}\n`;
      }
    }
  }
  
  output += `   ${colorize('Details:', colors.bright)} ${issue.description || 'No description'}\n`;
  output += '\n';
  
  return output;
}

function generateSummaryReport(data) {
  const issues = data.results.detectors || [];
  
  if (issues.length === 0) {
    console.log('🎉 没有发现安全问题！');
    return;
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
  const sortedSeverities = Object.keys(groupedIssues).sort((a, b) => {
    const aPriority = severityConfig[a]?.priority || 999;
    const bPriority = severityConfig[b]?.priority || 999;
    return aPriority - bPriority;
  });
  
  console.log('🔍 Slither 安全分析报告');
  console.log('==================================================\n');
  
  // 统计信息
  const totalIssues = issues.length;
  const highCount = groupedIssues.High?.length || 0;
  const mediumCount = groupedIssues.Medium?.length || 0;
  const lowCount = groupedIssues.Low?.length || 0;
  const infoCount = groupedIssues.Informational?.length || 0;
  
  console.log('📊 问题统计:');
  console.log(`   总问题数: ${totalIssues}`);
  console.log(`   🔴 高严重性: ${highCount}`);
  console.log(`   🟡 中等严重性: ${mediumCount}`);
  console.log(`   🟢 低严重性: ${lowCount}`);
  console.log(`   ℹ️ 信息性: ${infoCount}\n`);
  
  // 按严重性显示问题
  sortedSeverities.forEach(severity => {
    const config = severityConfig[severity] || { icon: '❓', color: colors.white };
    const issuesInSeverity = groupedIssues[severity];
    
    if (issuesInSeverity.length > 0) {
      console.log(`${config.icon} ${colorize(`${severity.toUpperCase()} 严重性问题 (${issuesInSeverity.length}个):`, config.color)}`);
      console.log('='.repeat(50));
      
      issuesInSeverity.forEach((issue, index) => {
        console.log(formatIssue(issue, index));
      });
    }
  });
  
  // 修复建议
  console.log('💡 修复建议:');
  console.log('='.repeat(50));
  
  if (highCount > 0) {
    console.log('🔴 高严重性问题需要立即修复:');
    console.log('   • 重入攻击: 使用 ReentrancyGuard 或检查-效果-交互模式');
    console.log('   • 任意转账: 验证接收地址和金额');
    console.log('   • 未初始化变量: 确保所有状态变量在构造函数中初始化\n');
  }
  
  if (mediumCount > 0) {
    console.log('🟡 中等严重性问题建议尽快修复:');
    console.log('   • 数学运算: 检查除零和溢出情况');
    console.log('   • 返回值忽略: 处理函数返回值');
    console.log('   • 循环中的外部调用: 考虑批量处理\n');
  }
  
  if (lowCount > 0) {
    console.log('🟢 低严重性问题可以逐步修复:');
    console.log('   • 命名约定: 遵循 Solidity 命名规范');
    console.log('   • 未使用代码: 清理死代码');
    console.log('   • 代码风格: 提高代码可读性\n');
  }
  
  console.log('📁 详细报告已保存到: slither-report.json');
  console.log('📊 SARIF 报告已保存到: slither-report.sarif');
}

function generateVerboseReport(data) {
  const issues = data.results.detectors || [];
  
  if (issues.length === 0) {
    console.log('🎉 没有发现安全问题！');
    return;
  }
  
  console.log('🔍 Slither 详细安全分析报告');
  console.log('==================================================\n');
  
  // 按文件分组
  const issuesByFile = {};
  issues.forEach(issue => {
    if (issue.elements && issue.elements.length > 0) {
      const element = issue.elements[0];
      if (element.source_mapping && element.source_mapping.filename_relative) {
        const filename = element.source_mapping.filename_relative;
        if (!issuesByFile[filename]) {
          issuesByFile[filename] = [];
        }
        issuesByFile[filename].push(issue);
      }
    }
  });
  
  // 按严重性排序文件
  const sortedFiles = Object.keys(issuesByFile).sort((a, b) => {
    const aMaxSeverity = Math.min(...issuesByFile[a].map(i => severityConfig[i.impact].priority));
    const bMaxSeverity = Math.min(...issuesByFile[b].map(i => severityConfig[i.impact].priority));
    return aMaxSeverity - bMaxSeverity;
  });
  
  sortedFiles.forEach(filename => {
    const fileIssues = issuesByFile[filename];
    const maxSeverity = fileIssues.reduce((max, issue) => 
      Math.min(max, severityConfig[issue.impact].priority), 4
    );
    
    const severityName = Object.keys(severityConfig).find(k => 
      severityConfig[k].priority === maxSeverity
    );
    const config = severityConfig[severityName];
    
    console.log(`${config.icon} ${colorize(filename, config.color)} (${fileIssues.length} 个问题)`);
    console.log('-'.repeat(60));
    
    // 按严重性排序问题
    fileIssues.sort((a, b) => 
      severityConfig[a.impact].priority - severityConfig[b.impact].priority
    );
    
    fileIssues.forEach((issue, index) => {
      console.log(formatIssue(issue, index));
    });
    
    console.log('');
  });
  
  // 显示所有问题的完整列表
  console.log('📋 所有问题列表:');
  console.log('='.repeat(60));
  
  issues.forEach((issue, index) => {
    console.log(formatIssue(issue, index));
  });
}

function main() {
  const args = process.argv.slice(2);
  const isVerbose = args.includes('--verbose');
  
  try {
    const reportPath = path.join(process.cwd(), 'slither-report.json');
    
    if (!fs.existsSync(reportPath)) {
      console.error('❌ 找不到 Slither 报告文件: slither-report.json');
      console.log('💡 请先运行: make slither');
      process.exit(1);
    }
    
    const reportData = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
    
    if (isVerbose) {
      generateVerboseReport(reportData);
    } else {
      generateSummaryReport(reportData);
    }
    
  } catch (error) {
    console.error('❌ 读取报告文件时出错:', error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
