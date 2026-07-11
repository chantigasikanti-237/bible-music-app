# Fix 38 Flutter Analysis Issues

## Step 1: Rewrite `lib/services/api_client.dart` ✅
- Add `ApiException` class with `message` field
- Add instance methods: `get()`, `post()`, `delete()`, `saveToken()`, `clearToken()`
- Keep `baseUrl` accessible

## Step 2: Add `bibleIdForLanguage` to `lib/config/api_config.dart` ✅
- Map language code to fallback Bible ID via `bibleLanguageForCode`

## Step 3: Fix `prefer_const_constructors` info lints ✅
- `lib/screens/bible/chapter_screen.dart` (2x)
- `lib/services/auth_service.dart` (1x)
- `lib/services/scripture_service.dart` (2x)

## Step 4: Verify ✅
- `flutter analyze` reports: **No issues found!**


