#!/bin/bash

# ship_and_deploy.sh: Packages the image and artifacts and ships them to a remote server for deployment.

# --- Safety First ---
set -e
set -u
set -o pipefail

# --- Arguments ---
SERVICE_NAME=$1
REMOTE_USER=$2
REMOTE_SERVER=$3
REMOTE_PORT=${4:-22}  # Default to port 22 if not provided

# --- Helper Functions ---
print_status() {
    echo -e "\033[1;34m>>> $1\033[0m"
}

print_success() {
    echo -e "\033[1;32m✅ $1\033[0m"
}

# --- Main Logic ---

# 1. Validate arguments
if [ -z "$SERVICE_NAME" ] || [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_SERVER" ]; then
    echo "❌ Error: Missing arguments." >&2
    echo "Usage: ship_and_deploy.sh <service-name> <remote-user> <remote-server> [port]" >&2
    exit 1
fi

# 2. Package the local image into a tarball
IMAGE_TAR="${SERVICE_NAME}.tar"
print_status "Packaging image '${SERVICE_NAME}:latest' into ${IMAGE_TAR}..."
if ! podman save -o "${IMAGE_TAR}" "${SERVICE_NAME}:latest"; then
    echo "❌ Error: Failed to save the Podman image." >&2
    exit 1
fi

# 3. Create a staging directory on the remote server
REMOTE_STAGING_DIR="~/podman-deploy-staging/${SERVICE_NAME}"
print_status "Creating staging directory on ${REMOTE_SERVER}:${REMOTE_PORT}..."
if ! ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_SERVER}" "mkdir -p ${REMOTE_STAGING_DIR}"; then
    echo "❌ Error: Failed to create remote directory. Check your SSH connection and permissions." >&2
    # Clean up local tar file before exiting
    rm -f "${IMAGE_TAR}"
    exit 1
fi

# 4. Transfer the artifacts to the remote server
print_status "Transferring artifacts to ${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_STAGING_DIR}..."
if ! scp -P "${REMOTE_PORT}" "${IMAGE_TAR}" "${SERVICE_NAME}.container" "Dockerfile" "${REMOTE_USER}@${REMOTE_SERVER}:${REMOTE_STAGING_DIR}/"; then
    echo "❌ Error: Failed to transfer files with scp." >&2
    # Clean up local tar file before exiting
    rm -f "${IMAGE_TAR}"
    exit 1
fi

# 5. Trigger the remote deployment script
# This assumes the corresponding 'podman-deploy-remote' script exists on the server's PATH
print_status "Triggering deployment on the remote server..."
if ! ssh -p "${REMOTE_PORT}" "${REMOTE_USER}@${REMOTE_SERVER}" "cd ${REMOTE_STAGING_DIR} && podman-deploy-remote ${SERVICE_NAME}"; then
    echo "❌ Error: Failed to trigger the remote deployment script." >&2
    echo "   Is 'podman-deploy-remote' installed and in the PATH on the server?" >&2
    # Clean up local tar file before exiting
    rm -f "${IMAGE_TAR}"
    exit 1
fi

# 6. Cleanup
print_status "Cleaning up local artifacts..."
rm -f "${IMAGE_TAR}"

print_success "🎉 Deployment successfully triggered on ${REMOTE_SERVER}:${REMOTE_PORT}!"
echo "You can check the service status with:"
echo "  ssh -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_SERVER} 'systemctl --user status ${SERVICE_NAME}.service'"