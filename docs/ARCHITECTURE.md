# Architecture Diagram - Podman Deploy Toolkit

## High-Level Architecture

```
+-------------------+     +------------------+     +------------------+
|   Source Code     | --> |  podman-deploy   | --> |  AI Generation   |
|   Directory       |     |    (wrapper)     |     |   (Groq API)     |
+-------------------+     +------------------+     +------------------+
                                    |                         |
                                    v                         v
+------------------+     +------------------+     +------------------+
|  Local Machine   | --> |  Analysis &      | --> |  Dockerfile &    |
|  (Dev Env)       |     |  Building        |     |  Quadlet Gen     |
+------------------+     +------------------+     +------------------+
                                    |                         |
                                    v                         v
+------------------+     +------------------+     +------------------+
|  Verification    | --> |  Stability Test  | --> |  Deployment      |
|  & Packaging     |     |  & Archiving     |     |  Options         |
+------------------+     +------------------+     +------------------+
                                    |                         |
                                    +------------+------------+
                                                 |
                                                 v
                                    +----------------------+
                                    |  Remote Server(s)    |
                                    |  (Podman + systemd)  |
                                    +----------------------+
```

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    podman-deploy CLI                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  analyze_       │  │  generate_      │  │  ship_and_      │  │
│  │  project.sh     │  │  configs.sh     │  │  deploy.sh     │  │
│  │                 │  │                 │  │                 │  │
│  │ - Scan project  │  │ - AI prompts    │  │ - SSH/SCP      │  │
│  │ - Detect lang   │  │ - API calls     │  │ - File transfer │  │
│  │ - Enhanced      │  │ - JSON parsing  │  │ - Remote exec   │  │
│  │   framework     │  │ - Quadlet       │  │ - Input val-    │  │
│  │   detection     │  │   validation    │  │   idation       │  │
│  │ - Accurate env  │  │                 │  │ - Git-aware     │  │
│  │   var parsing   │  │                 │  │   image names   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                │              │                      │          │
│                ▼              ▼                      ▼          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                /tmp/podman_metadata.json                    ││
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ ││
│  │  │ Git hash tagging│  │ Accurate meta-  │  │ Input val-  │ ││
│  │  │ for image names │  │ data extraction │  │ idation     │ ││
│  │  └─────────────────┘  └─────────────────┘  └─────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Podman Engine                            ││
│  │  ┌─────────────────┐  ┌─────────────────┐                  ││
│  │  │   Build Image   │  │   Run Container │                  ││
│  │  │                 │  │                 │                  ││
│  │  │ - Dockerfile    │  │ - Stability     │                  ││
│  │  │ - Multi-stage   │  │ - Verification  │                  ││
│  │  │ - Git tagging   │  │ - Proper cleanup│                  ││
│  │  └─────────────────┘  └─────────────────┘                  ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## AI Integration Flow

```
+----------------+    +----------------+    +----------------+
|  Project       |    |  System &      |    |  Groq         |
|  Metadata      | -> |  User Prompts  | -> |  API          |
|  (Enhanced)    |    |  Construction  |    |  (Llama 3.1)  |
+----------------+    +----------------+    +----------------+
         |                       |                      |
         v                       v                      v
+----------------+    +----------------+    +----------------+
|  Framework     | -> |  Validation    | -> |  Generated     |
|  Detection     |    |  & Error       |    |  Configs       |
|  & Env Var     |    |  Handling      |    |  (Validated)   |
|  Extraction    |    |                 |    |                 |
+----------------+    +----------------+    +----------------+
```

## Remote Deployment Flow

```
Client Machine                    Target Server
┌─────────────────┐              ┌─────────────────┐
│  podman-deploy  │              │ podman-deploy-  │
│     build       │              │    remote       │
└─────────┬───────┘              └─────────┬───────┘
          │                                │
          │ (1) Create staging dir         │
          │───────────────────────────────►│
          │                                │
          │ (2) Transfer artifacts         │
          │───────────────────────────────►│
          │                                │
          │ (3) Trigger remote deployment  │
          │───────────────────────────────►│
          │                                │
          │                                │ (4) Load image
          │                                │►───────────────┐
          │                                │                │
          │                                │ (5) Install    │
          │                                │    quadlet     │
          │                                │►───────────────┤
          │                                │                │
          │                                │ (6) Start      │
          │                                │    service     │
          │                                │►───────────────┘
          │                                │
          │ (7) Receive status/confirmation◄───────────────┐
          └────────────────────────────────────────────────┘
```

## Security & Validation Features

```
┌─────────────────────────────────────────────────────────────────┐
│                    Security & Validation                        │
├─────────────────────────────────────────────────────────────────┤
│ • Input validation for service names, SSH users, servers, ports │
│ • Command injection prevention for all user inputs              │
│ • Quadlet file validation using podman quadlet --dry-run        │
│ • Enhanced environment variable extraction (not over-broad)     │
│ • Proper container lifecycle management during stability tests  │
│ • Git-based image tagging to prevent name collisions            │
│ • Enhanced framework detection for better AI prompting          │
└─────────────────────────────────────────────────────────────────┘
```