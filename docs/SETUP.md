# ResumeCraft AI — updated source 1.1.0

This revision uses your uploaded `01-New-folder.zip` as the source of truth. Missing assets and platform setup scripts were restored from `02-ResumeCraft_AI_Source.zip`. It includes AI creation from your facts, reviewed AI improvements, PDF import/export, Firebase sign-in and draft sync, and a redesigned account screen.

## Update your running app (Windows)

Back up your working project first. Copy this package's `lib`, `test`, `assets`, `scripts`, `backend`, pubspec files, rules and documentation into your project. Preserve your existing `android`, `ios`, `web`, `dart_defines.json`, backend `.env` and any credentials. The uploaded sources did not include native platform folders. Do not run bootstrap over your customized native project; bootstrap is for a fresh checkout.

In your existing `backend/.env`, use:

```dotenv
GEMINI_API_KEY=your_real_Gemini_key
GEMINI_MODEL=gemini-flash-latest
FIREBASE_PROJECT_ID=resumecraft-ai-android
APP_ENV=development
DEV_NO_AUTH=false
CHECK_REVOKED=false
CORS_ORIGINS=http://localhost:8080
```

The backend normally verifies Firebase ID tokens using Google's public signing certificates. A service-account key is not required with `CHECK_REVOKED=false`. Backend and Flutter must use the same Firebase project. This verifies signatures, issuer, audience and expiry; immediate revoked/disabled-account checking requires `CHECK_REVOKED=true` plus valid server-side Firebase Admin credentials. Never put an Admin key or Gemini key in Flutter or GitHub.

Terminal 1, backend:

```powershell
cd "D:\ARTIFICIAL INTELLIGENCE\PROJECTS\RESUMECRAFT AI\backend"
# Only if .venv does not already exist:
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m pytest tests -q
.\.venv\Scripts\python.exe -m uvicorn app:app --host 0.0.0.0 --port 8081
```

Keep that terminal running. Terminal 2, Flutter:

```powershell
cd "D:\ARTIFICIAL INTELLIGENCE\PROJECTS\RESUMECRAFT AI"
flutter pub get
dart format lib test scripts
flutter analyze --no-fatal-infos
flutter test
dart run scripts/configure_platforms.dart
flutter devices
flutter run -d YOUR_EMULATOR_ID --dart-define-from-file=dart_defines.json
```

For the Android Studio emulator, `API_BASE_URL` in your existing JSON must be `http://10.0.2.2:8081`. A physical phone needs your computer's reachable LAN IP instead. The emulator must be started in Android Studio's Device Manager. Your Android `applicationId` must remain `com.saadi.resumecraft_ai`, matching the registered Firebase Android app. Debug HTTP is configured by `configure_platforms.dart`; production should use HTTPS.

## Fresh checkout

Install Flutter with Android toolchain and Python 3.10+. Run `flutter doctor` and fix Android toolchain issues. From this source folder:

```powershell
.\scripts\bootstrap.ps1
Copy-Item dart_defines.android.example.json dart_defines.json
Copy-Item backend\.env.example backend\.env
```

Fill the two configuration files before running. Bootstrap generates native platforms and icons, then runs analysis/tests. Android package generation uses `--org=com.saadi --project-name=resumecraft_ai`.

Get Android client values from Firebase Console → Project settings → your Android app → `google-services.json`: `current_key` → API key, `mobilesdk_app_id` → app ID, `project_number` → sender ID. These are client configuration, not the Gemini/server key. Enable Authentication → Email/Password, create Firestore, and deploy the supplied `firestore.rules` before using cloud drafts. Do not enable public read/write rules.

## Try the corrected AI flow

Sign in, open AI Studio and choose **Create resume with AI**. Enter your name, role and actual education, skills and experience in the facts box. Job description is optional context, not personal experience. Review proposed content and press **Apply reviewed content** to save a new CV. Cancel keeps the workspace unchanged. Select a saved draft to improve/review it. The app displays persistent readable request errors and retries an expired Firebase token once.

The account screen includes name editing, email verification, password reset, draft sync, backend configuration check, theme and sign-out. Its backend check reports configuration/reachability; it does not prove a live Gemini generation succeeded.

## Additional checks

```powershell
Invoke-RestMethod http://localhost:8081/health
flutter build apk --debug --dart-define-from-file=dart_defines.json
```

A successful health response should show both configuration flags true. Run creation, improvement, PDF preview and account actions on your emulator as well. See `VERIFICATION.md` for what was actually checked in this delivery.

## GitHub

Commit source and examples. Keep `.env`, real dart-defines, Admin credentials, virtual environments and build outputs private. The provided ignore rules cover these common paths. Inspect `git status` before committing. No native APK is included; the fresh-checkout script generates native scaffolding.
