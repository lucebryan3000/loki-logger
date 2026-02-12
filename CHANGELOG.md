# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Guidelines

- **Added**: New features or functionality
- **Changed**: Changes in existing functionality
- **Deprecated**: Features marked for removal in a future version
- **Removed**: Features or APIs that have been deleted
- **Fixed**: Bug fixes and corrections
- **Security**: Important security updates or vulnerability fixes

## [Unreleased]

### Added
- Initial project setup
- Basic project structure and documentation
- Development environment configuration

### Changed

### Deprecated

### Removed

### Fixed

### Security

---

## [0.1.0] - <YYYY-MM-DD>

### Added
- Initial project setup with standardized directory structure
- `.gitignore` with language-specific patterns
- `.editorconfig` for cross-editor code consistency
- `.env.example` for environment variable template
- `README.md` with comprehensive project documentation
- `CHANGELOG.md` for version tracking
- `.github/` directory with issue templates and PR template
- GitHub Actions CI workflow for automated testing
- `package.json` (or language equivalent) for dependency management
- Claude Code integration (`.claude/CLAUDE.md`)
- Build and private directories (`_build/`, `_private/`)
- License file (MIT, Apache-2.0, etc.)

### Changed
- (none for initial release)

### Deprecated
- (none for initial release)

### Removed
- (none for initial release)

### Fixed
- (none for initial release)

### Security
- Added `.env` to `.gitignore` to prevent secrets leakage
- Configured `.env.example` for safe credential management
- Added secret patterns to `.gitignore`
- Security scan completed - no hardcoded secrets found

---

## Release Notes Template

### For Next Release

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New feature description
- Another new feature

### Changed
- Modified behavior description
- Updated API endpoint behavior

### Deprecated
- Old feature will be removed in X.Y+2.Z

### Removed
- Removed deprecated feature (use X instead)

### Fixed
- Fixed bug where X would cause Y
- Fixed performance issue with Z

### Security
- Fixed security vulnerability #123
- Updated dependencies for security patches
```

---

## How to Use This Changelog

### For Contributors

When making changes, add an entry to the `[Unreleased]` section:

1. Choose the appropriate category (Added, Changed, Fixed, etc.)
2. Write a clear, concise description of the change
3. Include any breaking changes or deprecations
4. Reference issue numbers if applicable: "Fixes #123"

Example entry:
```markdown
### Fixed
- Fixed authentication token expiration (#456)
- Corrected typo in documentation (#457)
```

### For Maintainers

When preparing a release:

1. Update version number in `package.json` and other manifest files
2. Move `[Unreleased]` changes to new `[X.Y.Z]` version section
3. Add release date (YYYY-MM-DD format)
4. Create git tag: `git tag vX.Y.Z`
5. Update release notes on GitHub

---

## Versioning

This project uses [Semantic Versioning](https://semver.org/):
- `MAJOR.MINOR.PATCH` (e.g., 1.2.3)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

---

## Links

- [Releases Page](<repo-url>/releases)
- [Issues Page](<repo-url>/issues)
- [Milestones](<repo-url>/milestones)

---

**Last Updated**: 2026-02-10
**Maintained By**: <Maintainer Name>
