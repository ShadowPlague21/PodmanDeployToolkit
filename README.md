# Podman Deploy Toolkit

A comprehensive toolkit for containerizing and deploying applications using Podman.

## Overview

The Podman Deploy Toolkit automates the process of containerizing applications and deploying them to remote servers. It analyzes project structures, generates necessary configuration files, and handles the deployment workflow.

## Features

- Project analysis and metadata generation
- Automatic Dockerfile and .container file generation
- Secure remote deployment via SSH/SCP
- AI-powered debugging assistance

## Installation

Run the install script to set up the toolkit:

```bash
./install.sh
```

## Usage

```bash
podman-deploy <command> <service-name>
```

Commands:
- `build`: Analyzes project and generates container configurations
- `ship`: Packages and ships the service to a remote server
- `deploy`: Deploys the service on the remote server (to be run on the remote server)

## License

MIT