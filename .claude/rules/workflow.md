## Development Workflow

1. **Check Specifications**: Always refer to parent directory `.md` files before implementing
2. **TCA Pattern**: Follow the established Reducer pattern for new features
3. **Dependency Injection**: Use `@Dependency` for all external dependencies
4. **Testing**: Write tests for Reducers to verify state transitions
5. **Row Level Security**: Content visibility is enforced by Supabase RLS; trust the backend