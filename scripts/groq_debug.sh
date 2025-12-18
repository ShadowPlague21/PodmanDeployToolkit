#!/bin/bash

# groq_debug.sh: AI-powered debugging assistant for podman-deploy.
# Gathers logs and context, then sends them to Groq for analysis.

# --- Safety First ---
set -e
set -u
set -o pipefail

# --- Configuration ---
# Changed from relative path to standard location where install.sh places the .env file
ENV_PATH="$HOME/.local/share/podman-deploy/.env"
if [ -f "$ENV_PATH" ]; then
    # shellcheck source=/dev/null
    source "$ENV_PATH"
else
    echo "❌ Error: Configuration file not found at ${ENV_PATH}" >&2
    exit 1
fi

# Check if the API key is set
if [ -z "${GROQ_API_KEY:-}" ]; then
    echo "❌ Error: GROQ_API_KEY is not set in the .env file." >&2
    exit 1
fi

# --- Arguments ---
SERVICE_NAME=$1
DEBUG_CONTEXT=${2:-"general"}  # Context: build, runtime, general

# --- Helper Functions ---
print_status() {
    echo -e "\033[1;34m>>> $1\033[0m"
}

print_error() {
    echo -e "\033[1;31m❌ Error: $1\033[0m"
}

# Gather relevant logs and context based on the debug context
gather_context() {
    local context=$1
    local temp_file=$(mktemp)

    echo "SERVICE_NAME: $SERVICE_NAME" > "$temp_file"
    echo "DEBUG_CONTEXT: $context" >> "$temp_file"
    echo "TIMESTAMP: $(date)" >> "$temp_file"
    echo "" >> "$temp_file"

    case $context in
        "build")
            echo "=== BUILD LOGS ===" >> "$temp_file"
            if [ -f "Dockerfile" ]; then
                echo "Dockerfile contents:" >> "$temp_file"
                cat Dockerfile >> "$temp_file"
                echo "" >> "$temp_file"
            fi

            # Attempt to get any recent build logs if available
            if command -v podman &> /dev/null; then
                echo "Recent Podman system logs (last 50 lines):" >> "$temp_file"
                podman system service --time=0 > /dev/null 2>&1 & 
                sleep 1
                # Note: On some systems this may not work directly, but we'll try to capture info
                echo "Podman version: $(podman --version 2>/dev/null || echo 'Not available')" >> "$temp_file"
                echo "" >> "$temp_file"
            fi
            ;;
        "runtime")
            echo "=== RUNTIME LOGS ===" >> "$temp_file"
            if command -v podman &> /dev/null; then
                # Get logs from any container with the service name in it
                running_containers=$(podman ps --format "json" 2>/dev/null | jq -r '.Names // empty' 2>/dev/null | grep -i "$SERVICE_NAME" || echo "")
                if [ -n "$running_containers" ]; then
                    echo "Running containers matching $SERVICE_NAME:" >> "$temp_file"
                    for container in $running_containers; do
                        echo "Container: $container" >> "$temp_file"
                        podman logs --tail 50 "$container" >> "$temp_file" 2>/dev/null || echo "Could not get logs for $container" >> "$temp_file"
                        echo "" >> "$temp_file"
                    done
                else
                    # Check recently stopped containers
                    recent_containers=$(podman ps -a --format "json" 2>/dev/null | jq -r 'select(.State == "exited") | .Names // empty' 2>/dev/null | grep -i "$SERVICE_NAME" || echo "")
                    if [ -n "$recent_containers" ]; then
                        echo "Recently stopped containers matching $SERVICE_NAME:" >> "$temp_file"
                        for container in $recent_containers; do
                            echo "Container: $container (exited)" >> "$temp_file"
                            podman logs --tail 50 "$container" >> "$temp_file" 2>/dev/null || echo "Could not get logs for $container" >> "$temp_file"
                            echo "" >> "$temp_file"
                        done
                    else
                        echo "No containers found matching $SERVICE_NAME" >> "$temp_file"
                    fi
                    echo "" >> "$temp_file"
                fi
                
                echo "Podman version: $(podman --version 2>/dev/null || echo 'Not available')" >> "$temp_file"
                echo "Current Podman containers:" >> "$temp_file"
                podman ps -a >> "$temp_file" 2>/dev/null || echo "Could not list containers" >> "$temp_file"
                echo "" >> "$temp_file"
            fi
            ;;
        *)
            echo "=== GENERAL CONTEXT ===" >> "$temp_file"
            echo "Current directory: $(pwd)" >> "$temp_file"
            if [ -f "package.json" ]; then
                echo "package.json (first 50 lines):" >> "$temp_file"
                head -n 50 package.json >> "$temp_file"
                echo "" >> "$temp_file"
            fi
            if [ -f "requirements.txt" ]; then
                echo "requirements.txt (first 50 lines):" >> "$temp_file"
                head -n 50 requirements.txt >> "$temp_file"
                echo "" >> "$temp_file"
            fi
            if [ -f "Dockerfile" ]; then
                echo "Dockerfile contents:" >> "$temp_file"
                cat Dockerfile >> "$temp_file"
                echo "" >> "$temp_file"
            fi
            if [ -f "/tmp/podman_metadata.json" ]; then
                echo "Metadata file contents:" >> "$temp_file"
                cat /tmp/podman_metadata.json >> "$temp_file"
                echo "" >> "$temp_file"
            fi
            ;;
    esac

    echo "$temp_file"
}

# --- Main Logic ---

# Validate arguments
if [ -z "$SERVICE_NAME" ]; then
    print_error "No service name provided."
    echo "Usage: groq_debug.sh <service-name> [build|runtime|general]"
    exit 1
fi

print_status "Starting AI-powered debugging for $SERVICE_NAME ($DEBUG_CONTEXT context)..."

# Gather logs and context
CONTEXT_FILE=$(gather_context "$DEBUG_CONTEXT")
CONTEXT=$(cat "$CONTEXT_FILE")

# Construct the system prompt
SYSTEM_PROMPT="You are an expert debugging assistant for containerized applications using Podman.
Your role is to analyze logs, error messages, and configuration files to identify issues and provide clear, actionable solutions.
Be specific, technical, and helpful. If there are no apparent issues, confirm that.
Focus on common Podman, Dockerfile, and container runtime issues."

# Construct the user prompt with context
USER_PROMPT="Analyze the following logs and context for the service '$SERVICE_NAME'. The debug context is '$DEBUG_CONTEXT'.
Identify any issues and provide a clear explanation and solution.
Context and logs:
$CONTEXT"

# Call the Groq API
print_status "Sending debugging request to AI..."
API_RESPONSE=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
    -H "Authorization: Bearer ${GROQ_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg model "llama-3.1-8b-instant" \
        --arg system "$SYSTEM_PROMPT" \
        --arg user "$USER_PROMPT" \
        '{
            "model": $model,
            "messages": [
                {"role": "system", "content": $system},
                {"role": "user", "content": $user}
            ],
            "temperature": 0.1
        }'
    )")

# Parse the API Response and Handle Errors
if echo "$API_RESPONSE" | jq -e '.error' > /dev/null; then
    print_error "Error from Groq API:"
    echo "$API_RESPONSE" | jq -r '.error.message' >&2
    rm -f "$CONTEXT_FILE"
    exit 1
fi

# Extract the content from the response
AI_DIAGNOSIS=$(echo "$API_RESPONSE" | jq -r '.choices[0].message.content')

# Display the AI's analysis
print_status "AI Debugging Results:"
echo "===========================================" 
echo "$AI_DIAGNOSIS"
echo "===========================================" 

# Clean up temporary files
rm -f "$CONTEXT_FILE"

print_status "Debugging complete."