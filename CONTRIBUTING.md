# Contributing to shint

Thanks for your interest in contributing to shint! This document provides guidelines and conventions for contributing.

## Development Setup

1. Clone the repo:

   ```bash
   git clone https://github.com/hvignolo87/shint.git
   cd shint
   ```

2. Make sure you have the dependencies installed:

   ```bash
   brew install bash carapace fzf
   ```

3. Source the script for testing:

   ```bash
   source shint.bash
   ```

## How to Contribute

### Reporting Bugs

Open a [GitHub issue](https://github.com/hvignolo87/shint/issues) with:

- Your bash version (`echo $BASH_VERSION`)
- Your OS and terminal emulator
- Steps to reproduce the bug
- Expected vs actual behavior

### Suggesting Features

Open a [GitHub issue](https://github.com/hvignolo87/shint/issues) describing:

- The problem you're trying to solve
- Your proposed solution (if any)
- Example use cases

### Submitting Pull Requests

1. Fork the repository and create your branch from `main`.
2. Make your changes following the conventions below.
3. Test your changes manually across different commands (git, dbt, docker, etc.).
4. Commit your changes using a descriptive commit message (see conventions below).
5. Open a PR with a clear title and description of what you changed and why.

## Branch Naming Convention

Format: `{username}/{description}`

Examples:

- `johndoe/fix-quote-tokenization`
- `janedoe/add-pipe-support`

Always branch from `main`.

## Commit Message Conventions

This project follows [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

### Format

```text
<type>: <description>

[optional body]
```

### Types

- **fix**: A bug fix
- **feat**: A new feature
- **docs**: Documentation only changes
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **chore**: Changes to build process or auxiliary tools

### Examples

```text
fix: handle quoted tokens with spaces correctly
```

```text
feat: add pipe-aware tokenization

Split command line by |, &&, ||, ; and complete only
the last segment.
```

```text
docs: add configuration examples to README
```

### Description guidelines

- Use the imperative, present tense: "change" not "changed" nor "changes"
- Don't capitalize the first letter
- No period at the end

## Code Style

- Pure bash (no external languages)
- Functions prefixed with `_shint_`
- Variables prefixed with `SHINT_` (config) or `_SHINT_` (internal)
- Keep it minimal — the entire tool should stay under a few hundred lines
- Comments only where the intent isn't obvious from the code

## Testing

There's no automated test suite yet (contributions welcome!). Before submitting a PR, manually verify:

1. **Basic completion**: `git push --[Tab]` shows flags with descriptions
2. **Dynamic values**: `git checkout [Tab]` shows branches
3. **Smart advancement**: `dbt run[Tab]` shows flags, not subcommand matches
4. **Single result**: `git pus[Tab]` auto-completes to `git push`
5. **Cancel**: Open picker, press Esc — line should remain unchanged
6. **Unsupported commands**: Non-carapace commands should degrade gracefully

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
