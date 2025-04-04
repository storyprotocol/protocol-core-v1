# Engineering Guidelines

## Testing

Code must be thoroughly tested with quality unit tests.

We defer to the [Foundry Best Practices](https://book.getfoundry.sh/guides/best-practices) and [Moloch Testing Guide](https://github.com/MolochVentures/moloch/tree/master/test#readme) for specific recommendations, though not all of it is relevant here. Note the introduction in Moloch Testing Guide:

> Tests should be written, not only to verify correctness of the target code, but to be comprehensively reviewed by other programmers. Therefore, for mission critical Solidity code, the quality of the tests are just as important (if not more so) than the code itself, and should be written with the highest standards of clarity and elegance.

Every addition or change to the code must come with relevant and comprehensive tests.

Flaky tests are not acceptable.

The test suite should run automatically for every change in the repository, and in pull requests tests must pass before merging.

The test suite coverage must be kept as close to 100% as possible, enforced in pull requests.

Tests should use Foundry, unless for some reason js or hardhat are needed (for example, upgrades).

The test function names will follow

```
- test_contextCamel_descriptionOfTheTestCamel
- context = method name, contract or functionality.
```

In some cases unit tests may be insufficient and complementary techniques should be used:

1. Property-based tests (aka. fuzzing) for math-heavy code.
2. hardhat test using `hardhat-upgrades` OZ plugin to verify storage and upgradeability (until they support Foundry).
3. Fork tests for upgradeability to new implementations for upgradeable contracts, testing against the deployed contracts.
4. E2E tests for critical (happy) paths.
5. Formal verification for state machines.

## Security Testing

Critical security aspects that must be tested:
- Access control and permission systems
- Token economics and balance accounting
- Upgrade mechanisms and storage layouts
- External contract interactions and reentrancy guards
- Event emission for state changes

## Documentation

For contributors, project guidelines and processes must be documented publicly.

Every method and contract must have Natspec, using the `///` flavour always.

For users, features must be abundantly documented. Documentation should include answers to common questions, solutions to common problems, and recommendations for critical decisions that the user may face.

All changes to the core codebase (excluding tests, auxiliary scripts, etc.) must be documented in a changelog, except for purely cosmetic or documentation changes.

## Peer review

All changes must be submitted through pull requests and go through peer code review.

The review must be approached by the reviewer in a similar way as if it was an audit of the code in question (but importantly it is not a substitute for and should not be considered an audit).

Reviewers should enforce code and project guidelines.

External contributions must be reviewed separately by multiple maintainers.

## Automation

Automation should be used as much as possible to reduce the possibility of human error and forgetfulness.

Automations that make use of sensitive credentials must use secure secret management, and must be strengthened against attacks such as [those on GitHub Actions workflows](https://github.com/nikitastupin/pwnhub).

Some other examples of automation are:

- Looking for common security vulnerabilities or errors in our code (eg. reentrancy analysis).
- Keeping dependencies up to date and monitoring for vulnerable dependencies.

## Pull requests

Pull requests are squash-merged to keep the `main` branch history clean. The title of the pull request becomes the commit message, so it should be written in a consistent format:

1) Begin with a capital letter.
2) Do not end with a period.
3) Write in the imperative: "Add feature X" and not "Adds feature X" or "Added feature X".

We welcome conventional commits, with prefixes the title with "fix:" or "feat:".

Work in progress pull requests should be submitted as Drafts and should **not** be prefixed with "WIP:".

Branch names don't matter, and commit messages within a pull request mostly don't matter either, although they can help the review process.

## Code style

Solidity code should be written in a consistent format enforced by a linter, following the official [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html). See below for further [Solidity Conventions](#solidity-conventions).

The code should be simple and straightforward, prioritizing readability and understandability. Consistency and predictability should be maintained across the codebase. In particular, this applies to naming, which should be systematic, clear, and concise.

Sometimes these guidelines may be broken if doing so brings significant efficiency gains, but explanatory comments should be added.

Modularity should be pursued, but not at the cost of the above priorities.

# Solidity Conventions

In addition to the official Solidity Style Guide we have a number of other conventions that must be followed.

* Minimize exposing state variables, unless they help with external systems integration or readability.

* Changes to state should be accompanied by events, and in some cases it is not correct to arbitrarily set state.

* Internal or private state variables or functions should have an underscore prefix.

  ```solidity
  contract TestContract {
      uint256 private _privateVar;
      uint256 internal _internalVar;
      function _testInternal() internal { ... }
      function _testPrivate() private { ... }
  }
  ```
* constant or immutable variables must be ALL_CAPS with underscores. _ALL_CAPS if private or internal.

* Events should be emitted immediately after the state change that they
  represent, and should be named in the past tense.

  ```solidity
  function _burn(address who, uint256 value) internal {
      super._burn(who, value);
      emit TokensBurned(who, value);
  }
  ```

  Some standards (e.g. ERC20) use present tense, and in those cases the
  standard specification is used.
  
* Interface names should have a capital I prefix.

  ```solidity
  interface IERC777 {
  ```

* Group contracts by functionality within folders if possible.
  
* Interfaces should go inside the `interface` folder, mirroring the folder structure of the implementations

* Folder names must be lowercase, hyphen separated.

  ```
  example-folder
  ```

* Contract names must be camel case, starting with uppercase letter

  ```
  ExampleContract.sol
  ```

* Acronyms should be
  * Uppercase all if in contract name (`UUPSUpgradeable`, `IPAsset`)
  * Camelcase in properties and function names (`ipAssetId`), except if they are defined otherwise in external contracts or interfaces (`tokenURI`)

* Unchecked arithmetic blocks should contain comments explaining why overflow is guaranteed not to happen. If the reason is immediately apparent from the line above the unchecked block, the comment may be omitted.

* Interfaces should contain methods and events. Structs showing in an interface should be grouped in a library

* Function parameter names will have the **suffix** `_`
  
*  Naming conventions
  - Contract: CamelCase (adjectiveNoun)
  - Struct (noun)
  - Event (past-tense)
  - Function Name (verb noun)
    - local variable (noun / compound noun)
        - Booleans (use `isXXX`)
        - `isValid`
        - `valid`
    - Modifier (prepositionNoun)
        - `onlyOwner`
