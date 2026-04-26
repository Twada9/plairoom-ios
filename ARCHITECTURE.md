# Architecture
この文書は、このリポジトリの変わりにくい構造を説明する。
目的は、実装の量に関わらず「どこに何を置くか」「どの境界を崩さないか」を
判断できる状態を保つことにある。

ここでは個別 API の詳細や一時的な実装都合は扱わない。
代わりに、責務分担、依存方向、文書の位置づけ、不変条件を記述する。

## 全体像

このリポジトリは、Swiftで作るiOSアプリケーション。アーキテクチャはTCA

### Project Structure

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

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      // Business logic here
    }
  }
}
```
