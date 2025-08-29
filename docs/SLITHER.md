# Slither Security Analysis

This document describes how to use Slither for static analysis of smart contracts in the Story Protocol.

## What is Slither?

Slither is a static analysis framework for Solidity that runs a suite of vulnerability detectors, prints visual information about contract details, and provides an API to easily write custom analyses.

## Installation

### Option 1: Using Homebrew (macOS)
```bash
brew install slither-analyzer
```

### Option 2: Using pip
```bash
pip install slither-analyzer
```

### Option 3: Using Docker
```bash
docker pull trailofbits/slither
```

## Usage

### Basic Analysis
```bash
# Run basic analysis (quiet mode with report generation)
npm run slither

# Or using Makefile
make slither
```

### View Reports
```bash
# View summary report
npm run slither:view
# Or
make slither-view

# View detailed report
npm run slither:view:verbose
# Or
make slither-view-verbose
```

### Security Check (with assertions)
```bash
# Run security check with assertions
npm run slither:check

# Or using Makefile
make slither-check
```

### Generate Reports
```bash
# Generate JSON and SARIF reports
npm run slither:report

# Or using Makefile
make slither-report

# Generate Markdown report
npm run slither:markdown

# Or using Makefile
make slither-markdown

# Generate all reports at once
npm run slither:all

# Or using Makefile
make slither-all
```

### Comprehensive Security Check
```bash
# Run both Slither and Solhint
npm run security:check

# Or using Makefile
make security-check
```

## Configuration

The Slither configuration is in `slither.config.json`:

- **filter_paths**: Excludes library directories from analysis
- **solc_remaps**: Solidity import remappings
- **exclude**: Excludes specific detector categories
- **detectors_to_exclude**: Excludes specific detectors
- **json**: Output JSON report file
- **sarif**: Output SARIF report file

## Ignored Files

Files and directories ignored by Slither are specified in `.slitherignore`:

- Test files (`test/`)
- Scripts (`script/`)
- Mock contracts (`contracts/mocks/`)
- Library files (`lib/`)

## GitHub Actions Integration

Slither analysis runs automatically on:
- Push to main/develop branches
- Pull requests to main/develop branches
- Manual workflow dispatch

The workflow:
1. Installs Slither and dependencies
2. Runs security analysis
3. Generates reports (JSON + SARIF)
4. Comments on PRs with results
5. Fails CI if high severity issues are found

## Report Formats

### Human Summary
Default output showing issues in human-readable format.

### JSON Report
Detailed report in JSON format for programmatic analysis.

### SARIF Report
Standard format for security tools integration.

### Markdown Report
Human-readable report in Markdown format, perfect for:
- GitHub issues and discussions
- Code review comments
- Team documentation
- Security reports

## Common Issues and Solutions

### False Positives
Some detectors may generate false positives. You can:
1. Exclude specific detectors in `slither.config.json`
2. Add specific files to `.slitherignore`
3. Use inline comments to suppress specific warnings

### Performance
For large codebases:
1. Use `--filter-paths` to exclude unnecessary directories
2. Run analysis on specific contracts instead of entire directory
3. Use `--max-iterations` to limit analysis depth

## Best Practices

1. **Regular Analysis**: Run Slither regularly during development
2. **CI Integration**: Always run security checks in CI/CD pipeline
3. **Report Management**: Use appropriate report format for different use cases
4. **Issue Prioritization**: Focus on high severity issues first
5. **Team Communication**: Use Markdown reports for team discussions

### Recommended Workflow

1. **Daily Development**:
   ```bash
   make slither-view  # Quick summary check
   ```

2. **Code Review**:
   ```bash
   make slither-markdown  # Generate readable report
   ```

3. **Full Analysis**:
   ```bash
   make slither-all  # All report formats
   ```

4. **CI/CD Pipeline**:
   ```bash
   make slither-check  # Automated security check
   ```
3. **Review Results**: Manually review all reported issues
4. **False Positive Management**: Document and justify ignored warnings
5. **Team Training**: Ensure team understands security implications

## Resources

- [Slither Documentation](https://github.com/crytic/slither/wiki)
- [Detector List](https://github.com/crytic/slither/wiki/Detector-Documentation)
- [Custom Detectors](https://github.com/crytic/slither/wiki/Adding-a-new-detector)
- [Trail of Bits Blog](https://blog.trailofbits.com/tag/slither/)
