# Verification — 2026-10-06

- Backend: `python -m pytest tests -q`, run from backend: **30 passed**. One dependency deprecation warning from Starlette/httpx; no failing tests.
- Cases include cryptographically signed Firebase token verification, wrong project/issuer, expiry, tampering, certificate network failure, AI response handling and new CV identity preservation. External requests are mocked; this is not a live Firebase/Gemini account verification.
- All included Dart files parsed with the embedded tree-sitter Dart grammar without syntax errors. This is not Flutter type checking.
- Flutter widget/request tests are included for phone/desktop layout, dialog keyboard/cancel behavior, account layout, AI creation and invalid/backend-error responses.
- Flutter SDK is unavailable in the delivery environment. `flutter analyze`, `flutter test`, emulator runs and APK builds were **not executed here**. Run the README commands locally before release. No zero-error guarantee or built APK is claimed.
- This revision addresses dialog controller lifecycle, stale requests crossing account changes, AI creation, actionable authentication errors and account usability. The intermittent red screen was not directly captured, so its exact original cause cannot be conclusively identified.

## GitHub package checks

- Backend tests rerun from packaged backend: 30 passed, one dependency deprecation warning.
- All 12 Dart files parsed without syntax errors.
- All 36 README image/local file references resolve; JSON configuration examples parse.
- Source scanned for literal Google API keys; none found.
- Hero image visually inspected; all 12 supplied screenshots included.
- Template preview fixed-height overflow addressed and widget regression test added. Flutter execution remains pending.

Final packaging review: gallery reordered into the user journey (workspace, templates/AI, PDF/export, account); README references rechecked. Bootstrap now formats Dart before analysis; Bash setup syntax check passed. Backend tests rerun: 30 passed. Flutter/Android runtime remains unverified because the SDK is unavailable.
