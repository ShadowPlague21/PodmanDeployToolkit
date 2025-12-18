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
│  │ - Metadata gen  │  │ - JSON parsing  │  │ - Remote exec   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                │              │                      │          │
│                ▼              ▼                      ▼          │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                /tmp/podman_metadata.json                    ││
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
│  │  └─────────────────┘  └─────────────────┘                  ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## AI Integration Flow

```
+----------------+    +----------------+    +----------------+
|  Project       |    |  System &      |    |  Groq         |
|  Metadata      | -> |  User Prompts  | -> |  API          |
|  (JSON)        |    |  Construction  |    |  (Llama 3.1)  |
+----------------+    +----------------+    +----------------+
                                                   |
                                                   v
+----------------+    +----------------+    +----------------+
|  Response      | <- |  JSON          | <- |  Generated     |
|  Validation    |    |  Parsing       |    |  Configs       |
|  & Error       |    |  & Extraction  |    |  (Dockerfile,  |
|  Handling      |    |                 |    |  .container)   |
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