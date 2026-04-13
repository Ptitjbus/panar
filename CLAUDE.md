# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Tech Stack
- **Frontend:** Flutter (Dart SDK ^3.11.4)
- **Backend:** Supabase (Auth, Database, Storage)
- **State Management:** Not yet implemented (recommended: Riverpod, Bloc, or Provider)
- **UI Framework:** Material Design (uses-material-design: true)
- **Environment Config:** flutter_dotenv for managing secrets

## Development Commands

### Essential Commands
- **Install dependencies:** `flutter pub get`
- **Run app:** `flutter run`
- **Run on specific device:** `flutter run -d <device-id>`
- **Run tests:** `flutter test`
- **Run single test file:** `flutter test test/path/to/file_test.dart`
- **Run tests with coverage:** `flutter test --coverage`

### Build Commands
- **Android APK:** `flutter build apk`
- **iOS:** `flutter build ios`
- **Web:** `flutter build web`

### Code Generation
- **Build runner (for freezed, json_serializable, etc):**
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- **Watch mode for continuous generation:**
  ```bash
  dart run build_runner watch --delete-conflicting-outputs
  ```

### Code Quality
- **Analyze code:** `flutter analyze`
- **Format code:** `dart format .`
- **Fix lint issues:** `dart fix --apply`

## Project Architecture

### Current State
The project is in its initial setup phase with:
- Basic Supabase initialization in `lib/main.dart`
- Environment variable management via `.env` file
- Minimal UI (Hello World placeholder)

### Expected Architecture
This project should follow **Clean Architecture** principles with the following structure:

```
lib/
├── core/              # Shared utilities, constants, error handling
├── features/          # Feature-based modules
│   └── feature_name/
│       ├── data/      # Data sources, repositories, models
│       ├── domain/    # Entities, use cases, repository interfaces
│       └── presentation/ # UI, widgets, state management
├── shared/            # Shared widgets and utilities
└── main.dart          # App entry point
```

### Supabase Integration

**Environment Configuration:**
- `.env` file (excluded from git) must contain:
  ```
  SUPABASE_URL=your_supabase_project_url
  SUPABASE_ANON_KEY=your_supabase_anon_key
  ```
- Never hardcode API keys or URLs in source code

**Service Layer Pattern:**
- Always interact with Supabase through dedicated service classes
- Never call Supabase client directly from UI widgets
- Example service files: `auth_service.dart`, `database_service.dart`, `storage_service.dart`
- Services should be placed in the `data` layer of each feature

**Error Handling:**
- Wrap all Supabase calls in try-catch blocks
- Handle `AuthException`, `PostgrestException`, and `StorageException` appropriately
- Provide meaningful error messages to users

## Code Conventions

### Naming
- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables/Methods:** `camelCase`
- **Constants:** `SCREAMING_SNAKE_CASE`
- **Private members:** prefix with `_`

### Linting
- Uses `package:flutter_lints/flutter.yaml` (configured in `analysis_options.yaml`)
- All lint warnings should be addressed before committing

## Database Operations (MCP)
When working with Supabase database:
1. Use the `mcp__supabase__list_tables` tool to inspect the current schema
2. Use the `mcp__supabase__apply_migration` tool for DDL operations
3. Use the `mcp__supabase__execute_sql` tool for data queries
4. Always review table schemas before generating models or writing queries

## Platform Support
The project supports all Flutter platforms:
- Android
- iOS
- Web
- macOS
- Windows
- Linux
