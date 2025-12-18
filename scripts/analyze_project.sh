#!/bin/bash

# analyze_project.sh: Inspects a project directory and generates metadata JSON.

# --- Safety First ---
set -e
set -u
set -o pipefail

# --- Configuration ---
PROJECT_DIR=$1
METADATA_FILE="/tmp/podman_metadata.json"

# --- Helper Functions ---
# Function to safely get a JSON value from a file
get_json_value() {
    local file=$1
    local key=$2
    # Use jq to safely get the value, return empty string if not found
    jq -r ".${key} // empty" "$file" 2>/dev/null || echo ""
}

# --- Main Logic ---

# Check if project directory was provided
if [ -z "$PROJECT_DIR" ] || [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Invalid or no project directory provided." >&2
    exit 1
fi

# Initialize a temporary JSON object
# We use 'jq' to build the JSON incrementally to avoid syntax errors
JSON_OUTPUT=$(jq -n \
    --arg project_dir "$PROJECT_DIR" \
    '{
        project_dir: $project_dir,
        project_type: "unrecognized",
        language: "",
        framework: "",
        package_manager: "",
        start_command: "",
        ports: [],
        env_vars: []
    }'
)

# 1. Detect Project Type and Language
if [ -f "${PROJECT_DIR}/package.json" ]; then
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg lang "javascript" '.language = $lang | .project_type = "nodejs"')
    PACKAGE_MANAGER="npm"
    if command -v yarn &> /dev/null && [ -f "${PROJECT_DIR}/yarn.lock" ]; then
        PACKAGE_MANAGER="yarn"
    elif command -v pnpm &> /dev/null && [ -f "${PROJECT_DIR}/pnpm-lock.yaml" ]; then
        PACKAGE_MANAGER="pnpm"
    fi
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg pm "$PACKAGE_MANAGER" '.package_manager = $pm')

    # Get framework and start command from package.json
    FRAMEWORK=$(get_json_value "${PROJECT_DIR}/package.json" "dependencies" | jq -r 'keys | map(select(contains("express") or contains("react") or contains("vue") or contains("angular"))) | .[0] // empty')
    START_CMD=$(get_json_value "${PROJECT_DIR}/package.json" "scripts.start")
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg fw "$FRAMEWORK" --arg cmd "$START_CMD" '.framework = $fw | .start_command = $cmd')

elif [ -f "${PROJECT_DIR}/requirements.txt" ] || [ -f "${PROJECT_DIR}/pyproject.toml" ]; then
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg lang "python" '.language = $lang | .project_type = "python"')
    PACKAGE_MANAGER="pip"
    if [ -f "${PROJECT_DIR}/pyproject.toml" ]; then
        PACKAGE_MANAGER="poetry" # Assume poetry if pyproject.toml exists
    fi
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg pm "$PACKAGE_MANAGER" '.package_manager = $pm')

    # Try to find main.py or app.py
    if [ -f "${PROJECT_DIR}/main.py" ]; then
        START_CMD="python main.py"
    elif [ -f "${PROJECT_DIR}/app.py" ]; then
        START_CMD="python app.py"
    fi
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg cmd "$START_CMD" '.start_command = $cmd')

elif [ -f "${PROJECT_DIR}/go.mod" ]; then
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg lang "go" '.language = $lang | .project_type = "go"')
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg cmd "go run ." '.start_command = $cmd')

elif [ -f "${PROJECT_DIR}/Cargo.toml" ]; then
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg lang "rust" '.language = $lang | .project_type = "rust"')
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --arg cmd "cargo run" '.start_command = $cmd')

# Add more language/framework checks here as needed (e.g., Ruby, Java, PHP)
fi

# 2. Extract README information
README_FILE=$(find "$PROJECT_DIR" -maxdepth 1 -iname "README*" -print -quit)
if [ -n "$README_FILE" ] && [ -f "$README_FILE" ]; then
    README_CONTENT=$(head -n 50 "$README_FILE")

    # Extract ports (e.g., "runs on port 3000", ":8080")
    PORTS=$(echo "$README_CONTENT" | grep -oE 'port [0-9]+|:[0-9]+' | grep -oE '[0-9]+' | sort -u | jq -R . | jq -s .)
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --argjson p "$PORTS" '.ports = $p')

    # Extract environment variables (e.g., "API_KEY=your_key", "DB_HOST")
    ENV_VARS=$(echo "$README_CONTENT" | grep -oE '\b[A-Z_]{2,}\b' | sort -u | jq -R . | jq -s .)
    JSON_OUTPUT=$(echo "$JSON_OUTPUT" | jq --argjson e "$ENV_VARS" '.env_vars = $e')
fi

# 3. Finalize and write the metadata to a file
echo "$JSON_OUTPUT" > "$METADATA_FILE"

echo "✅ Analysis complete. Metadata saved to ${METADATA_FILE}"