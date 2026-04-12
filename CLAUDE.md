# Flutter-Supabase Project Setup

## Tech Stack
- Frontend: Flutter (Dart)
- Backend: Supabase
- State management: [Choose: Riverpod / Bloc / Provider]
- Style: Material Design 3

## Development Commands
- Install dependencies: `flutter pub get`
- Run the app: `flutter run`
- Generate code (Build Runner): `dart run build_runner build --delete-conflicting-outputs`
- Tests: `flutter test`

## Code Conventions
- Architecture: Clean Architecture (or specify your own)
- Files: `snake_case` for names, `PascalCase` for classes.
- Supabase: Always use a service (e.g. `auth_service.dart`) rather than calling the client directly in the UI.
- Error handling: Always use try-catch blocks for API calls.

## Database Status (MCP)
- Use the `postgres` tool to read the table schema before generating models or queries.