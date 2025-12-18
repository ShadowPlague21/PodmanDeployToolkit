#!/bin/bash

# install.sh: Installation script for Podman Deploy Toolkit

set -e  # Exit on any error

# --- Helper Functions ---
print_status() {
    echo -e "\033[1;34m>>> $1\033[0m"
}

print_success() {
    echo -e "\033[1;32m✅ $1\033[0m"
}

print_error() {
    echo -e "\033[1;31m❌ Error: $1\033[0m"
}

# --- Installation Logic ---

print_status "Starting installation of Podman Deploy Toolkit..."

# 1. Check for required dependencies
print_status "Checking for required dependencies..."
MISSING_DEPS=()

for dep in podman jq curl tree; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    print_error "Missing required dependencies: ${MISSING_DEPS[*]}"
    echo "Please install them before continuing:"
    echo "  On Ubuntu/Debian: sudo apt-get install ${MISSING_DEPS[*]}"
    echo "  On CentOS/RHEL: sudo yum install ${MISSING_DEPS[*]}"
    echo "  On Fedora: sudo dnf install ${MISSING_DEPS[*]}"
    echo "  On macOS: brew install ${MISSING_DEPS[*]}"
    exit 1
fi

print_success "All required dependencies found."

# 2. Create necessary directories
print_status "Creating installation directories..."
mkdir -p ~/.local/share/podman-deploy
mkdir -p ~/.local/bin

# 3. Copy the toolkit files
print_status "Copying toolkit files..."
cp -r bin scripts docs .env.example README.md ~/.local/share/podman-deploy/

# 4. Create symlinks for the executables
print_status "Creating symlinks..."
ln -sf ~/.local/share/podman-deploy/bin/podman-deploy ~/.local/bin/podman-deploy

# Check if podman-deploy-remote already exists as a symlink and remove it if it does
if [ -L ~/.local/bin/podman-deploy-remote ] || [ -f ~/.local/bin/podman-deploy-remote ]; then
    rm -f ~/.local/bin/podman-deploy-remote
fi

ln -sf ~/.local/share/podman-deploy/bin/podman-deploy-remote ~/.local/bin/podman-deploy-remote

# 5. Make the executables executable
print_status "Setting executable permissions..."
chmod +x ~/.local/share/podman-deploy/bin/podman-deploy
chmod +x ~/.local/share/podman-deploy/bin/podman-deploy-remote
chmod +x ~/.local/share/podman-deploy/scripts/*.sh

# 6. Check if ~/.local/bin is in PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    print_status "Adding ~/.local/bin to PATH..."

    # Detect shell and add to appropriate config file
    if [ -n "$ZSH_VERSION" ]; then
        CONFIG_FILE="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        CONFIG_FILE="$HOME/.bashrc"
    else
        # Check if .bashrc exists, otherwise use .profile
        if [ -f "$HOME/.bashrc" ]; then
            CONFIG_FILE="$HOME/.bashrc"
        else
            CONFIG_FILE="$HOME/.profile"
        fi
    fi

    # Add PATH export if not already present
    if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$CONFIG_FILE" 2>/dev/null; then
        echo '' >> "$CONFIG_FILE"
        echo '# Added by Podman Deploy Toolkit installer' >> "$CONFIG_FILE"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CONFIG_FILE"
        print_status "Added PATH export to $CONFIG_FILE"
        print_status "Please run 'source $CONFIG_FILE' or restart your terminal to apply the changes."
    else
        print_status "~/.local/bin is already in PATH"
    fi
else
    print_success "~/.local/bin is already in PATH"
fi

# 7. Create .env file from example if it doesn't exist
ENV_FILE="$HOME/.local/share/podman-deploy/.env"
if [ ! -f "$ENV_FILE" ]; then
    print_status "Creating .env configuration file..."
    cp ~/.local/share/podman-deploy/.env.example "$ENV_FILE"
    print_status "Please edit $ENV_FILE to add your GROQ_API_KEY and other settings."
fi

print_success "🎉 Installation complete!"
echo
echo "🚀 To get started:"
echo "1. Add your GROQ_API_KEY to $ENV_FILE"
echo "2. Ensure you have passwordless SSH access to target servers (for remote deployments)"
echo "3. Restart your terminal or run 'source $CONFIG_FILE'"
echo "4. Run 'podman-deploy build <service-name>' in any project directory"
echo
print_success "Happy deploying! 🚀"