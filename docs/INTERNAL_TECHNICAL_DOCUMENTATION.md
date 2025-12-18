# Internal Technical Documentation - Podman Deploy Toolkit

## Architecture Overview
The toolkit consists of multiple interconnected scripts that work together to provide a seamless deployment experience powered by AI.

## Component Breakdown

### 1. Main Wrapper (`bin/podman-deploy`)
- Entry point for all user commands
- Orchestrates the entire workflow
- Handles user interaction and choices
- Calls other scripts as needed
- Implements workflow logic for build, ship, deploy
- NEW: **Git-Aware Tagging**: Automatically tags images with Git commit hashes (or timestamps) to prevent collisions
- NEW: **Enhanced Container Testing**: Proper lifecycle management during stability tests (no --rm flag)

### 2. Project Analyzer (`scripts/analyze_project.sh`)
- Scans project directory structure
- NEW: **Enhanced Framework Detection**: Improved Node.js framework detection that reads both `dependencies` and `devDependencies` to identify frameworks like Express, React, Vue, Angular, Next, Nuxt, Svelte, etc.
- NEW: **Accurate Environment Variable Extraction**: Refined pattern matching to extract only actual environment variables (KEY=value patterns) rather than all capitalized words
- Extracts dependency information from package managers
- Gathers port and environment variable information from README
- Creates metadata JSON file at `/tmp/podman_metadata.json`

### 3. Config Generator (`scripts/generate_configs.sh`)
- Reads metadata from `/tmp/podman_metadata.json`
- Sends project information to Groq AI API
- Receives AI-generated Dockerfile and Quadlet configuration
- NEW: **Quadlet Validation**: Validates generated Quadlet files using `podman quadlet --dry-run` before saving
- Writes generated files to project directory
- Implements strict prompting to ensure valid Podman 4.9.3 Quadlet syntax

### 4. Ship & Deploy (`scripts/ship_and_deploy.sh`)
- NEW: **Enhanced Input Validation**: Comprehensive validation to prevent command injection
- Packages built container image into tarball
- NEW: **Git-Aware Image Handling**: Supports unique image names with Git hash tags
- Transfers artifacts to remote server via SSH/SCP with configurable port
- Triggers remote deployment script
- Handles cleanup and status reporting

### 5. AI Debugger (`scripts/groq_debug.sh`)
- Gathers relevant logs and context based on debug context
- Sends debugging information to Groq AI API
- Receives and displays AI analysis and solutions
- Supports build-time, runtime, and general debugging contexts

### 6. Remote Deployer (`bin/podman-deploy-remote`)
- Runs on target deployment server
- Loads container image from tarball
- Installs Quadlet configuration
- Sets up systemd user service using pure Quadlet workflow
- Starts and verifies service operation

## Data Flow

1. User runs `podman-deploy build <service-name>`
2. `analyze_project.sh` creates metadata JSON (with enhanced detection)
3. `generate_configs.sh` creates Dockerfile and .container file (with validation)
4. Podman builds the image with Git hash tagging
5. Container stability is verified with proper cleanup
6. User chooses to save locally or ship to server (with configurable port)
7. If shipping, user is prompted for SSH port (defaults to 22)
8. `ship_and_deploy.sh` packages and transfers files using specified port and unique image name
9. Remote server runs `podman-deploy-remote` to complete deployment

## Security Considerations

- All containers run as non-root users
- SSH keys used for secure remote transfers with configurable ports
- API keys stored in local .env file (not committed)
- Input validation on all user-provided data
- Enhanced validation for service names to prevent command injection

## Dependencies

- Podman (v4.9.3+)
- jq (for JSON processing)
- curl (for API calls)
- tree (for directory exploration)
- bash (for script execution)

## Error Handling Strategy

- Each script checks for dependencies and required files
- Fallback to AI debugging when errors occur
- Proper cleanup of temporary files
- Clear error messages for users
- Validation of AI-generated files before usage