# 🚀 Podman-Deploy Toolkit: The "Vibe Coder's" deployment companion

A lightweight CLI that uses Groq AI to turn any source code folder into a running Podman service in seconds.

## ✨ Key Features

- 🤖 **AI-Powered Configuration**: Automatically generates Dockerfiles and Podman Quadlet configs using Groq AI
- ⚡ **One-Command Deploy**: Analyze, build, verify, and deploy with a single command
- 🔒 **Security Focused**: Creates non-root containers and uses secure deployment practices
- 🧪 **Stability Check**: Automatically verifies container stability before deployment
- 🌐 **Remote Deployment**: Seamlessly ship and deploy to remote servers via SSH (with configurable port)
- 🤕 **AI-Powered Debugging**: Get intelligent help when things go wrong
- 📦 **Multi-Language Support**: Handles Node.js, Python, Go, Rust and other project types

## 🛠️ Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/podman-deploy.git
cd podman-deploy

# Run the installer
bash install.sh

# Configure your Groq API key
# Copy the example file and add your API key
cp ~/.local/share/podman-deploy/.env.example ~/.local/share/podman-deploy/.env
# Edit the .env file to add your GROQ_API_KEY
```

### Prerequisites

- Podman (v4.9.3 or higher)
- jq
- curl
- tree
- bash-compatible shell
- Passwordless SSH configured (for remote deployments)
- SSH server running on target system (port configurable, default 22)

## 🚀 Quick Start

```bash
cd ~/my-awesome-project
podman-deploy build my-service
```

The toolkit will:
1. Analyze your project structure
2. Generate AI-optimized container configurations
3. Build the Podman image
4. Verify container stability with a 60-second test
5. Offer to save locally or deploy to a remote server (with configurable SSH port)

## 📁 Project Structure

```
podman-deploy/
├── bin/
│   ├── podman-deploy          # Main executable
│   └── podman-deploy-remote   # Remote-side deployment script
├── scripts/
│   ├── analyze_project.sh     # Analyzes project structure
│   ├── generate_configs.sh    # AI-powered config generation
│   ├── ship_and_deploy.sh     # Remote deployment with configurable SSH port
│   └── groq_debug.sh          # AI-powered debugging
├── docs/                      # Documentation
├── .env.example              # API key configuration
└── install.sh                # Installation script
```

## 🛠️ Commands

### `build`
```bash
podman-deploy build <service-name>
```
- Analyzes the current project directory
- Generates container configurations with AI
- Builds the Podman image
- Runs a 60-second stability check
- Offers to save locally or ship to remote server (with configurable SSH port)

When choosing remote deployment, you will be prompted for:
- Remote server IP or hostname
- Remote username
- SSH port (defaults to 22, can be changed)

### `ship` (Coming Soon)
For triggering remote deployment directly.

### `deploy` (Remote Only)
Used by the remote script for final deployment steps.

## 🚑 Troubleshooting

If your build or deployment fails, the toolkit automatically triggers the AI debugger (`groq_debug.sh`) which will:
- Collect relevant logs and context
- Send them to Groq for analysis
- Provide actionable solutions

You can also manually run the debugger:
```bash
groq_debug.sh <service-name> [build|runtime|general]
```

## 🧠 How It Works

1. **Analysis**: `analyze_project.sh` inspects your project and creates metadata
2. **Generation**: `generate_configs.sh` uses AI to create Dockerfile and .container files
3. **Building**: Podman builds your optimized container image
4. **Verification**: Automated stability testing ensures reliability
5. **Deployment**: Either save locally or ship to remote servers (with configurable SSH port)

## 🤝 Contributing

We welcome contributions! Here are some ways you can help:

- Report bugs or suggest features
- Add support for new project types
- Improve documentation
- Enhance the AI prompts for better configuration generation

To contribute:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commit messages
4. Submit a pull request with a detailed description

## 📄 License

MIT License - See the `LICENSE` file for details.

## 🙏 Acknowledgments

- Groq for providing the AI API that powers the intelligent configuration generation
- The Podman team for creating an excellent container platform
- The open-source community for making tools that make development better