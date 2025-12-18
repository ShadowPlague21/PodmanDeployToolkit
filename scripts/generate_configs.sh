#!/bin/bash

# generate_configs.sh: Uses AI to generate Dockerfile and Quadlet files from project metadata.

# --- Safety First ---
set -e
set -u
set -o pipefail

# --- Configuration ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
METADATA_FILE="/tmp/podman_metadata.json"

# Source the .env file to get the API key
if [ -f "${SCRIPT_DIR}/../.env" ]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/../.env"
else
    echo "❌ Error: .env file not found. Please create it and add your GROQ_API_KEY." >&2
    exit 1
fi

# Check if the API key is set
if [ -z "${GROQ_API_KEY:-}" ]; then
    echo "❌ Error: GROQ_API_KEY is not set in the .env file." >&2
    exit 1
fi

# --- Arguments ---
SERVICE_NAME=$1
PROJECT_DIR=$2

# --- Main Logic ---

# 1. Read and Validate Metadata
if [ ! -f "$METADATA_FILE" ]; then
    echo "❌ Error: Metadata file not found at ${METADATA_FILE}. Did you run the analyzer?" >&2
    exit 1
fi

PROJECT_TYPE=$(jq -r '.project_type' "$METADATA_FILE")
if [ "$PROJECT_TYPE" == "unrecognized" ]; then
    echo "❌ Error: Project type is unrecognized. Cannot generate configuration." >&2
    exit 1
fi

# 2. Construct the System Prompt
# This is the most critical part. It locks the AI into generating valid, secure, and version-specific code.
SYSTEM_PROMPT="You are an expert in creating Podman 4.9.3 Quadlet files and optimized Dockerfiles.
Your task is to generate a Dockerfile and a Quadlet file for a systemd user service based on the provided project metadata.

STRICT RULES:
- The Quadlet file MUST only use keys and syntax valid for Podman 4.9.3. Do NOT use features from Podman 5.0 or later.
- The Dockerfile MUST use multi-stage builds for compiled languages (Go, Rust, TypeScript).
- The final container image MUST run as a non-root user.
- Use official, minimal base images (e.g., alpine, slim).
- Combine RUN commands in Dockerfile to minimize layers.
- The output MUST be a valid JSON object with two keys: 'dockerfile' and 'quadlet'.
- The value for 'quadlet' must be the content for a file named '${SERVICE_NAME}.container'.
- The Quadlet should use 'Podman=' to reference the image name, which will be '${SERVICE_NAME}:latest'.
- Assume a rootless user service.
- Expose any ports mentioned in the metadata.
- Ensure the container restarts on failure."

# 3. Construct the User Prompt (with metadata)
USER_PROMPT="Generate the configuration files for a project with the following details:
$(cat "$METADATA_FILE")"

# #################################################################################
# # THIS IS THE CORE AI INTERACTION PART
# #################################################################################

# 4. Call the Groq API
echo "🤖 Requesting configuration from AI..."
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
            "response_format": {"type": "json_object"}
        }'
    )")

# 5. Parse the API Response and Handle Errors
# Check for API errors
if echo "$API_RESPONSE" | jq -e '.error' > /dev/null; then
    echo "❌ Error from Groq API:" >&2
    echo "$API_RESPONSE" | jq -r '.error.message' >&2
    exit 1
fi

# Extract the content from the response
GENERATED_CONTENT=$(echo "$API_RESPONSE" | jq -r '.choices[0].message.content')

# Validate that the content is valid JSON
if ! echo "$GENERATED_CONTENT" | jq . > /dev/null 2>&1; then
    echo "❌ Error: AI response was not valid JSON." >&2
    echo "Raw response:" >&2
    echo "$GENERATED_CONTENT" >&2
    exit 1
fi

# 6. Write the Generated Files to Disk
echo "✅ AI response received. Writing files..."

# Extract and write the Dockerfile
DOCKERFILE_CONTENT=$(echo "$GENERATED_CONTENT" | jq -r '.dockerfile')
if [ -z "$DOCKERFILE_CONTENT" ] || [ "$DOCKERFILE_CONTENT" == "null" ]; then
    echo "❌ Error: 'dockerfile' key not found in AI response." >&2
    exit 1
fi
echo "$DOCKERFILE_CONTENT" > "${PROJECT_DIR}/Dockerfile"

# Extract and write the Quadlet file
QUADLET_CONTENT=$(echo "$GENERATED_CONTENT" | jq -r '.quadlet')
if [ -z "$QUADLET_CONTENT" ] || [ "$QUADLET_CONTENT" == "null" ]; then
    echo "❌ Error: 'quadlet' key not found in AI response." >&2
    exit 1
fi
echo "$QUADLET_CONTENT" > "${PROJECT_DIR}/${SERVICE_NAME}.container"

echo "🎉 Successfully generated Dockerfile and ${SERVICE_NAME}.container in ${PROJECT_DIR}"