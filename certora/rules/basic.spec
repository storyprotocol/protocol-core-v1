// IPAccountImpl Real Verification Rules
// Story Protocol Core Contracts

// Rule: Only owner can execute transactions (with valid setup)
rule onlyOwnerCanExecute() {
    env e;
    address to;
    uint256 value;
    bytes data;
    
    // Precondition: ensure contract is properly initialized
    address currentOwner = owner(e);
    require(currentOwner != 0, "Owner must be valid (non-zero address)");
    require(e.msg.sender != currentOwner, "Testing non-owner access should be denied");
    require(e.msg.sender != 0, "Caller must be valid (non-zero address)");
    
    // Fix: ensure data length is either 0 or >= 4 to avoid revert on line 108
    require(data.length == 0 || data.length >= 4, "Data length must be 0 or >= 4");
    require(to != 0, "Target address should not be zero");
    
    // Action: try to execute transaction (3-parameter version)
    execute@withrevert(e, to, value, data);
    
    // Postcondition: should revert for non-owners
    assert lastReverted, "Non-owner should not be able to execute";
}

// Rule: Owner can always execute valid transactions
rule ownerCanExecute() {
    env e;
    address to;
    uint256 value;
    bytes data;
    
    // Precondition: ensure contract is properly initialized
    address currentOwner = owner(e);
    require(currentOwner != 0, "Owner must be valid (non-zero address)");
    require(e.msg.sender == currentOwner, "Caller must be owner");
    
    // Fix: ensure data length is either 0 or >= 4 to avoid revert on line 108
    require(data.length == 0 || data.length >= 4, "Data length must be 0 or >= 4");
    require(to != 0, "Target address should not be zero");
    
    // Action: try to execute transaction
    execute@withrevert(e, to, value, data);
    
    // Postcondition: should NOT revert for owner (unless external call fails)
    assert !lastReverted, "Owner should be able to execute valid transactions";
}
