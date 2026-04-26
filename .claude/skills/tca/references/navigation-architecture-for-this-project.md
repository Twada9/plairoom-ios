## Navigation Architecture for This Project

```
AppFeature (TabView)
├── Tab 1: RoomListFeature
│   └── @Presents → RoomDetailFeature (push)
│       └── @Presents → GenerateFeature (push)
│           └── @Presents → ResultFeature (push)
└── Tab 2: SettingsFeature
    └── (loggedOut) → AppFeature sets auth = AuthFeature.State()

AppFeature
└── @Presents → AuthFeature (global sheet)
```

Child features propagate results upward via **delegate actions**. Parent features
listen for `case .destination(.presented(.child(.delegate(.someEvent))))`.