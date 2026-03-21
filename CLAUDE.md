# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PLAIROOM** is an iOS app for an AI Content SNS where users generate images and music using AI within themed "rooms", share their creations, and interact through likes and comments.

This iOS project is a **submodule** of the parent PLAIROOM project. All specifications are defined in `.md` files in the parent directory (`../`). When implementing features, always refer to these specification files:

- `../requirements.md` — Product requirements and database design
- `../technical-design.md` — Architecture and technology stack
- `../api-spec.md` — Complete API specification
- `../state-transition.md` — State transition diagrams

## Technology Stack

### Architecture: TCA (The Composable Architecture)

- **UI**: SwiftUI
- **State Management**: TCA (`swift-composable-architecture`)
- **Dependency Injection**: `swift-dependencies`
- **Backend**: Supabase (Database, Auth, Storage, Edge Functions)
- **Deployment Target**: iOS 26.1
- **Swift Version**: 5.0

### Key Features

- Swift 6 Language Mode enabled
- Main Actor isolation by default
- SwiftUI Previews enabled
- Auto-generated asset symbols

## Project Structure

```
PLAIROOM-iOS/
├── Features/              # TCA feature modules
│   ├── RoomList/         # Room list view + feature
│   ├── RoomDetail/       # Room detail view + feature
│   ├── Generate/         # AI generation UI + feature
│   ├── Result/           # Generation result view + feature
│   ├── Settings/         # Settings view + feature
│   └── Auth/             # Authentication view + feature
├── Repository/           # Data access layer
│   ├── RoomRepository.swift
│   ├── ContentRepository.swift
│   ├── AuthRepository.swift
│   ├── LikeRepository.swift
│   └── CommentRepository.swift
├── API/                  # Supabase API client
│   ├── SupabaseAPIClient.swift
│   └── DTO/             # Data transfer objects
│       ├── RoomDTO.swift
│       ├── ImageContentDTO.swift
│       └── MusicContentDTO.swift
├── Entity/              # Domain models
│   ├── Room.swift
│   ├── ImageContent.swift
│   ├── MusicContent.swift
│   ├── Like.swift
│   └── Comment.swift
└── DI/                  # Dependency injection setup
    └── Dependencies.swift
```

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

## TCA Architecture Guidelines

### Layer Responsibilities

| Layer | Responsibility |
|---|---|
| **View (SwiftUI)** | Display UI and handle user interactions |
| **Reducer (Feature)** | Define State, Action, and business logic |
| **Store** | Hold State and dispatch Actions |
| **Repository** | Abstract data sources |
| **APIClient** | Wrapper for Supabase Swift SDK |
| **Entity** | Domain model definitions |

### Feature Structure Pattern

Each feature module should contain:

1. **View**: SwiftUI view file (e.g., `RoomListView.swift`)
2. **Feature**: Reducer with State, Action, and business logic (e.g., `RoomListFeature.swift`)

Example:
```swift
// RoomListFeature.swift
@Reducer
struct RoomListFeature {
  struct State: Equatable {
    var rooms: [Room] = []
    var isLoading = false
  }

  enum Action {
    case onAppear
    case roomsResponse(Result<[Room], Error>)
    case roomTapped(Room)
  }

  @Dependency(\.roomRepository) var roomRepository

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Business logic here
    }
  }
}
```

## API Integration

### Supabase Endpoints

All API interactions follow the specification in `../api-spec.md`:

- **Base URL**: `https://{PROJECT_REF}.supabase.co/rest/v1`
- **Auth API**: `https://{PROJECT_REF}.supabase.co/auth/v1`
- **Edge Functions**: `https://{PROJECT_REF}.supabase.co/functions/v1`

### Authentication

- JWT token-based authentication via Supabase Auth
- All authenticated requests require `Authorization: Bearer {JWT_TOKEN}` header
- Guest users can browse but cannot create content, like, or comment

### Content Status Flow

Content goes through these states:

1. **`generating`**: Edge Function processing (visible to owner only)
2. **`pending`**: Generation complete, awaiting user confirmation (owner only)
3. **`completed`**: Posted to room (visible to everyone)
4. **`failed`**: Generation failed or user chose to retry (owner only)

## Database Schema

Refer to `../requirements.md` for complete database schema. Key tables:

- `profiles` — User profiles (linked to Supabase Auth)
- `rooms` — Themed rooms with prompts
- `image_contents` / `music_contents` — Generated content
- `likes` — User likes on content
- `comments` — User comments on content
- `ai_usage_logs` — Track generation usage for free tier limits

## Development Workflow

1. **Check Specifications**: Always refer to parent directory `.md` files before implementing
2. **TCA Pattern**: Follow the established Reducer pattern for new features
3. **Dependency Injection**: Use `@Dependency` for all external dependencies
4. **Testing**: Write tests for Reducers to verify state transitions
5. **Row Level Security**: Content visibility is enforced by Supabase RLS; trust the backend

## Key Considerations

- **Free vs Premium Users**: Free users have monthly generation limits; check `ai_usage_logs` via Edge Function
- **Content Types**: Rooms support either `image` or `music` (not both)
- **Room Types**: `free`, `battle`, `quiz`, `collaboration` (quiz/collaboration detailed specs TBD)
- **RLS Policy**: Guests can read `completed` content; authenticated users can CRUD their own
- **AI Services**: Hugging Face (images) and MusicGen (music) via Edge Functions

## Bundle Identifier

`com.wadachi.PLAIROOM-iOS`

## Development Team

Team ID: `G6P94ZYTA7`
