# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language
All responses must be in Japanese

## Project Overview

**PLAIROOM** is an iOS app for an AI Content SNS where users generate images and music using AI within themed "rooms", share their creations, and interact through likes and comments.

This iOS project is a **submodule** of the parent PLAIROOM project. All specifications are defined in `.md` files in the parent directory (`../`). When implementing features, always refer to these specification files:

- `../requirements.md` — Product requirements and database design
- `../technical-design.md` — Architecture and technology stack
- `../api-spec.md` — Complete API specification
- `../state-transition.md` — State transition diagrams

## Technology Stack
- Development Language: Swift
- UI Framework: SwiftUI
- Testing Framework: Swift Testing

### Architecture: TCA (The Composable Architecture)

- **UI**: SwiftUI
- **State Management**: TCA (`swift-composable-architecture`)
- **Dependency Injection**: `swift-dependencies`
- **Backend**: Supabase (Database, Auth, Storage, Edge Functions)
- **Deployment Target**: iOS 26.0
- **Swift Version**: 5.0

### Key Features

- Swift 6 Language Mode enabled
- Main Actor isolation by default
- SwiftUI Previews enabled
- Auto-generated asset symbols

## Initial Files to Check
- Always review `CLAUDE.md`, `ARCHITECTURE.md`, and `README.md` before starting work
- For API-related work, also check `APIINTEGRATION.md`

## Agent Usage Policy
- Proactively use sub-agents without requiring explicit user instruction
- When parallel work is possible with non-overlapping modification targets, actively use dynamic sub-agents to work in parallel

## Workflow
- Don't implement immediately; first determine the target layer and where responsibilities belong
- For changes affecting terminology, use cases, API contracts, or usage methods, treat code and related documentation as the same unit of change
- When proceeding with TDD, first create a perspective analysis or test item table, then proceed to tests and implementation after approval
- Choose tests according to the nature of changes; don't judge quality solely by fixed coverage numbers

## Common Development Commands

### Build & Run

```bash
# Open project in Xcode
open PLAIROOM-iOS.xcodeproj

# Build from command line
xcodebuild -project PLAIROOM-iOS.xcodeproj -scheme PLAIROOM-iOS -configuration Debug build

# Run tests
xcodebuild test -project PLAIROOM-iOS.xcodeproj -scheme PLAIROOM-iOS -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Testing

```bash
# Run unit tests
xcodebuild test -project PLAIROOM-iOS.xcodeproj -scheme PLAIROOM-iOSTests

# Run UI tests
xcodebuild test -project PLAIROOM-iOS.xcodeproj -scheme PLAIROOM-iOSUITests
```

