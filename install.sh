#!/bin/bash

# Install script for Podman Deploy Toolkit

set -e

echo "Installing Podman Deploy Toolkit..."

# Create necessary directories
mkdir -p ~/.local/share/podman-deploy
mkdir -p ~/.local/bin

# Copy the toolkit files
cp -r bin scripts docs .env.example README.md ~/.local/share/podman-deploy/

# Create symlink for the main executable
ln -sf ~/.local/share/podman-deploy/bin/podman-deploy ~/.local/bin/podman-deploy

# Make the main executable executable
chmod +x ~/.local/share/podman-deploy/bin/podman-deploy

echo "Installation complete!"
echo "Add ~/.local/bin to your PATH if it's not already there."
echo "Then copy .env.example to .env and configure your settings."