# Certora Formal Verification

This document describes how to use Certora for formal verification of Story Protocol smart contracts.

## What is Certora?

Certora is a formal verification tool that uses mathematical proofs to verify smart contract properties. It's more powerful than static analysis tools like Slither because it can prove that certain properties always hold true, not just detect potential issues.

## Installation

### Prerequisites
- Python 3.8+
- Foundry (for compilation)
- Solidity 0.8.23+

### Install Certora CLI

```bash
# Download and install Certora CLI
curl -L https://github.com/Certora/certora-cli/releases/latest/download/certora-cli-linux-x86_64 -o certora-cli
chmod +x certora-cli
sudo mv certora-cli /usr/local/bin/

# Verify installation
certora-run --version
```

## Configuration

### certora.conf
The main configuration file that defines:
- Solidity compiler settings
- Contract paths
- Rule files
- Output settings

### Rule Files
Located in `certora/rules/`:
- `access-control.spec`: Access control verification rules
- `reentrancy.spec`: Reentrancy protection rules
- `upgradeability.spec`: Upgrade safety rules

### Harness Files
Located in `certora/harnesses/`:
- Mock contracts for testing specific scenarios
- Extend original contracts with test functions

## Usage

### Basic Verification
```bash
# Run all verifications
make certora

# Run with verification mode
make certora-verify

# Generate detailed report
make certora-report
```

### NPM Scripts
```bash
# Basic verification
npm run certora

# Verification mode
npm run certora:verify

# Generate report
npm run certora:report

# Full security check (includes Certora)
npm run security:check
```

## Understanding Results

### Verification Success
- ✅ Green: Property proven to always hold
- ✅ Yellow: Property proven under certain conditions

### Verification Failure
- ❌ Red: Counterexample found
- 🔍 Review the counterexample to understand why the property failed

### Common Issues
1. **Insufficient preconditions**: Add more `require` statements
2. **Missing invariants**: Add state consistency checks
3. **Complex logic**: Break down complex functions into smaller ones

## Best Practices

### Writing Rules
1. **Be specific**: Write precise, testable properties
2. **Use preconditions**: Limit the scope of verification
3. **Test edge cases**: Include boundary conditions

### Performance
1. **Limit scope**: Focus on critical functions
2. **Use filters**: Exclude irrelevant code paths
3. **Optimize rules**: Combine related properties

## Integration with CI/CD

Certora can be integrated into GitHub Actions workflows:

```yaml
- name: Run Certora verification
  run: |
    make certora-verify
```

## Troubleshooting

### Common Errors
1. **Compilation errors**: Check Solidity version compatibility
2. **Timeout**: Simplify complex rules or increase timeout
3. **Memory issues**: Reduce contract size or rule complexity

### Getting Help
- [Certora Documentation](https://docs.certora.com/)
- [Certora Community](https://community.certora.com/)
- [GitHub Issues](https://github.com/Certora/certora-cli/issues)

## Examples

### Access Control Rule
```solidity
rule onlyAuthorizedAccess() {
    env e;
    address caller = e.msg.sender;
    
    require(!isAuthorized(caller));
    restrictedFunction{env: e}();
    assert false, "Should revert";
}
```

### State Consistency Rule
```solidity
rule stateConsistency() {
    env e;
    
    require(isValidState());
    externalCall{env: e}();
    assert isValidState(), "State should remain valid";
}
```
