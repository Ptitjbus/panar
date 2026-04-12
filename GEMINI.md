# Project Panar

## Project Overview
Panar is a Flutter-based mobile and web application that integrates with Supabase for its backend services. It uses `flutter_dotenv` for environment variable management and `supabase_flutter` for authentication and database interactions.

- **Frontend:** Flutter (Dart)
- **Backend:** Supabase (Auth, Database, Storage)
- **Environment:** `.env` file for configuration

## Building and Running

### Prerequisites
- Flutter SDK installed and configured.
- A `.env` file in the root directory with the following keys:
  ```env
  SUPABASE_URL=your_supabase_url
  SUPABASE_ANON_KEY=your_supabase_anon_key
  ```

### Key Commands
- **Install Dependencies:** `flutter pub get`
- **Run the Application:** `flutter run`
- **Run Tests:** `flutter test`
- **Code Generation:** `dart run build_runner build --delete-conflicting-outputs` (if models or JSON serialization are used)
- **Build APK:** `flutter build apk`
- **Build iOS:** `flutter build ios`

## Development Conventions

### Code Style
- **Naming Conventions:**
  - Files: `snake_case.dart`
  - Classes: `PascalCase`
  - Variables/Methods: `camelCase`
- **Linter:** Uses `package:flutter_lints/flutter.yaml`.

### Architecture & Best Practices
- **Clean Architecture:** Prioritize separation of concerns between UI, domain, and data layers.
- **Service Layer:** Always interact with Supabase through dedicated service classes (e.g., `auth_service.dart`, `database_service.dart`) rather than calling the Supabase client directly within the UI.
- **Error Handling:** Systematically use `try-catch` blocks for all asynchronous API calls and Supabase interactions.
- **Environment Variables:** Never hardcode API keys or URLs. Always use `dotenv.env['KEY_NAME']`.

## Key Files
- `lib/main.dart`: Entry point of the application, handles Supabase and Dotenv initialization.
- `pubspec.yaml`: Project metadata and dependencies.
- `.env`: (Ignored from git) Contains sensitive configuration.
- `CLAUDE.md`: Additional development and stack-specific instructions.
