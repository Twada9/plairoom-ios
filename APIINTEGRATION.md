
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
