# /py-basher - Python Test Template Remediation

Execute py-basher toolkit against a target folder to fix pytest template errors.

## Usage

```
/py-basher [TARGET_DIR] [COMMAND] [OPTIONS]
```

## Arguments

- `TARGET_DIR` (required) - Path to the project directory to remediate
- `COMMAND` (optional) - Specific command to run (default: remediate)
  - `remediate` - Complete fix (templates + stubs + validate)
  - `discover-patterns` - Scan for error patterns only
  - `fix-templates` - Fix {{VARIABLE}} placeholders only
  - `create-stubs` - Create stub modules only
  - `validate` - Run pytest validation only
  - `orchestrate` - Auto-discover and apply fixes
- `OPTIONS` (optional) - Additional options like project name, src dir, timezone

## Examples

```
/py-basher /path/to/project
/py-basher /path/to/project remediate myapp
/py-basher /path/to/project discover-patterns
/py-basher /path/to/project orchestrate --dry-run
```

## What It Does

1. **Fixes template variables** - Replaces {{SRC_DIR}}, {{PROJECT_NAME}}, etc.
2. **Creates stub modules** - Generates src/ with all required stubs
3. **Validates tests** - Runs pytest to show real test failures

## Execution

<assistant_action>
Execute py-basher toolkit against the specified target directory.

**Steps:**

1. Parse the target directory from user input (required)
2. Parse optional command (default: remediate) and options
3. Validate target directory exists and is accessible
4. Determine project name from directory if not specified
5. Execute py-basher with appropriate command
6. **Parse test results and calculate statistics**
7. **Report: passed count, failed count, total, pass percentage**

**Commands Available:**

- **remediate** (default) - Complete remediation workflow
  - Fix template variables
  - Create stub modules
  - Run pytest validation
  - **Report: templates fixed, stubs created, test results (passed/failed/total/percentage)**

- **discover-patterns** - Scan for error patterns
  - Analyze Python files for common issues
  - Report: template variables, imports, methods, storage patterns
  - Provide recommended fixes

- **fix-templates** - Fix template variables only
  - Replace {{VARIABLE}} placeholders
  - Report: number of files fixed

- **create-stubs** - Create stub modules only
  - Generate src/ directory with stubs
  - Generate optional package directory
  - Report: files created

- **validate** - Run pytest only
  - Execute pytest with short traceback
  - **Report: test results (passed/failed/total/percentage)**

- **orchestrate** - Auto-discover and apply fixes
  - Discover patterns automatically
  - Apply appropriate fixes
  - Support --dry-run to preview changes
  - Report: patterns found, fixes applied, results

**Implementation:**

```bash
# Parse arguments
TARGET_DIR="$1"
COMMAND="${2:-remediate}"
shift 2 || true
OPTIONS="$@"

# Validate target directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Directory not found: $TARGET_DIR"
    exit 1
fi

# Determine project name if not provided
if [ -z "$PROJECT_NAME" ] && [ "$COMMAND" = "remediate" ]; then
    PROJECT_NAME=$(basename "$TARGET_DIR")
fi

# Execute py-basher
/home/luce/apps/_dev-tools/tools/py-basher/py-basher "$COMMAND" "$TARGET_DIR" $OPTIONS
```

**Error Handling:**

- Validate TARGET_DIR is provided and exists
- Check py-basher toolkit is accessible
- Report clear error messages if validation fails
- Show py-basher output directly to user

**Output Format:**

For **remediate** command:
```
Executing py-basher remediate on: /path/to/target
Project: project_name

🔧 Fixing template variables...
✅ Fixed template variables in X Python files

📦 Creating stub modules...
✓ Stub modules created in target/src/

✅ Running validation tests...
[pytest output]

## Test Results

✅ Passed: 675
❌ Failed: 0
📊 Total: 675
✨ Pass Rate: 100.0%

Summary:
- Templates fixed: 84 files
- Stubs created: src/ + myapp/
- Tests: 675 passed (100.0%)
```

For **discover-patterns** command:
```
Discovering patterns in: /path/to/target

📋 PATTERN 1: Template Variables
  ✓ Found in X files

📋 PATTERN 2: Missing Module Imports
  ✓ Found Y unique imports

📊 PATTERN SUMMARY
Recommended fixes:
1. py-basher fix-templates /path/to/target
2. py-basher create-stubs /path/to/target
```

For **orchestrate --dry-run**:
```
🚀 py-basher Orchestrator (DRY RUN)

📂 Processing: /path/to/target
🔍 Discovering patterns...
  [DRY RUN] Would run: fix-templates
  [DRY RUN] Would run: create-stubs
  [DRY RUN] Would run: validate
```

**Test Result Parsing:**

Parse pytest output to extract:
1. Line with format: `X passed in Y.YYs` or `X passed, Y failed in Z.ZZs`
2. Calculate:
   - Passed count
   - Failed count (0 if not present)
   - Total = Passed + Failed
   - Pass percentage = (Passed / Total) × 100

**Report Format (REQUIRED for all test runs):**

```
## Test Results

✅ Passed: X
❌ Failed: Y
📊 Total: Z
✨ Pass Rate: XX.X%
```

**Special Handling:**

- If command is `orchestrate` and `--dry-run` not specified, ask user to confirm before applying fixes
- For `remediate`, automatically infer project name from directory basename
- Pass through all additional options to py-basher
- Show full output from py-basher commands
- **ALWAYS parse and report test statistics after pytest runs**
</assistant_action>

## Location

py-basher toolkit: `/home/luce/apps/_dev-tools/tools/py-basher/`

## Documentation

- Full docs: `/home/luce/apps/_dev-tools/tools/py-basher/docs/`
- Usage guide: `/home/luce/apps/_dev-tools/tools/py-basher/docs/usage.md`
- Patterns: `/home/luce/apps/_dev-tools/tools/py-basher/docs/patterns.md`
