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

### 2. Project Analyzer (`scripts/analyze_project.sh`)
- Scans project directory structure
- Identifies project language and framework
- Extracts dependency information from package managers
- Gathers port and environment variable information from README
- Creates metadata JSON file at `/tmp/podman_metadata.json`

### 3. Config Generator (`scripts/generate_configs.sh`)
- Reads metadata from `/tmp/podman_metadata.json`
- Sends project information to Groq AI API
- Receives AI-generated Dockerfile and Quadlet configuration
- Writes generated files to project directory
- Implements strict prompting to ensure valid Podman 4.9.3 Quadlet syntax

### 4. Ship & Deploy (`scripts/ship_and_deploy.sh`)
- Packages built container image into tarball
- Transfers artifacts to remote server via SSH/SCP
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
- Sets up systemd user service
- Starts and verifies service operation

## Data Flow

1. User runs `podman-deploy build <service-name>`
2. `analyze_project.sh` creates metadata JSON
3. `generate_configs.sh` creates Dockerfile and .container file
4. Podman builds the image
5. Container stability is verified
6. User chooses to save locally or ship to server
7. If shipping, `ship_and_deploy.sh` packages and transfers files
8. Remote server runs `podman-deploy-remote` to complete deployment

## Security Considerations

- All containers run as non-root users
- SSH keys used for secure remote transfers
- API keys stored in local .env file (not committed)
- Input validation on all user-provided data

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