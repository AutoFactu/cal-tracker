# Agent Operations Guide

This file contains environment-specific instructions for coding agents working on the Cal Tracker project.

---

## Deployed Environment URLs

Current backend API environments:

- Dev: `https://dev-api.bettercalories.app`
- Production: `https://api.bettercalories.app`

Backend deployment rules:

- Dev deploys from pushes to `develop`.
- Production deploys from tags matching `v*`.

When compiling the mobile app against the deployed dev environment, use:

```bash
cd /home/javier/dev/cal-tracker/apps/mobile
flutter build apk --debug --dart-define=API_BASE_URL=https://dev-api.bettercalories.app
```

Use the local emulator URL only for local backend testing:

```bash
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

---

## Flutter E2E Testing and Visual Validation

For Flutter mobile features, use **Patrol** as the main E2E testing framework. Whenever a new feature, screen, permission flow, navigation flow, or critical user interaction is implemented, add or update Patrol tests to verify the behavior on Android/iOS where relevant. Patrol should be used for real end-to-end flows, especially those involving native dialogs, permissions, authentication, recording/audio flows, backend interactions, and multi-screen journeys. Use stable finders such as keys, semantic labels, and visible text; avoid fragile selectors.

Use **Marionette MCP** as a development and visual-validation tool for the coding agent. After implementing UI changes, the agent should use Marionette to interact with the running Flutter app, take screenshots, inspect the visible UI, tap/scroll/type where needed, and verify that the implemented changes are visually correct. Marionette is not a replacement for Patrol tests; it is used to give the agent “eyes and hands” during development so it can detect layout issues, bad spacing, overflow, broken visual states, or screens that do not update correctly after changes. The expected workflow is: implement the feature, run/analyze Flutter checks, use Marionette MCP to visually inspect and interact with the app, fix any visual or interaction issues, then add/update Patrol E2E tests for the final behavior.


---

## Android Emulator Initialization

Required local assumptions:

- Android SDK: `/home/javier/Android/Sdk`
- AVD: `cal_tracker_api36`
- Device ID after boot: `emulator-5554`
- KVM must be available at `/dev/kvm`

Use this exact startup sequence for voice-capable testing. Start the emulator as a transient user systemd service so it is not tied to the coding agent command process.

```bash
export PATH="/home/javier/Android/Sdk/emulator:/home/javier/Android/Sdk/platform-tools:$PATH"

# Remove stale emulator processes only.
systemctl --user stop cal-tracker-emulator.service 2>/dev/null || true
ps aux | awk '/qemu-system/ && !/awk/ {print $2}' | xargs -r kill -9
sleep 2

systemd-run --user --unit=cal-tracker-emulator --collect \
  --working-directory=/home/javier/dev/cal-tracker \
  -E PATH=/home/javier/Android/Sdk/emulator:/home/javier/Android/Sdk/platform-tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -E DISPLAY=:1 \
  -E XAUTHORITY=/run/user/1000/gdm/Xauthority \
  -E XDG_RUNTIME_DIR=/run/user/1000 \
  -E DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  -p StandardOutput=append:/tmp/emulator-systemd.log \
  -p StandardError=append:/tmp/emulator-systemd.log \
  /home/javier/Android/Sdk/emulator/emulator -avd cal_tracker_api36 -no-snapshot -no-snapshot-save -allow-host-audio -no-boot-anim -gpu software -accel on

adb wait-for-device
adb -s emulator-5554 shell 'while [[ $(getprop sys.boot_completed) != 1 ]]; do sleep 1; done; echo Boot completed'
adb -s emulator-5554 shell 'pm list packages -f | grep android | wc -l'
adb -s emulator-5554 shell echo alive
```

Important constraints:

- Always cold boot with `-no-snapshot -no-snapshot-save`; corrupted snapshots have caused missing Android services.
- Do not use `-no-audio` when testing Whisper/STT or microphone flows. `-no-audio` disables emulator audio support.
- Use `-allow-host-audio` for voice testing. Without it, Android Emulator can zero out host microphone input before it reaches the virtual device.
- Use `-gpu software` on this emulator version. `-gpu swiftshader_indirect` has caused host `RenderThread` segfaults when opening the Stats UI on Android Emulator 36.5.11.
- Keep emulator logs in `/tmp/emulator-systemd.log` and inspect the service with `systemctl --user status cal-tracker-emulator.service`.
- Wait for `sys.boot_completed == 1` before `adb install`, `flutter run`, or package-manager checks.
- Do not use broad kill patterns such as `pkill -f bun`; they may kill the backend.

### Emulator Microphone Setup

For Whisper/STT manual testing, the host microphone must be available to the emulator:

1. Start the emulator with the voice-capable command above.
2. Confirm the Linux desktop session allows microphone access for the Android Emulator or its `qemu-system-*` process.
3. After installing the app, grant microphone permission if the runtime prompt is not convenient:

```bash
adb -s emulator-5554 shell pm grant com.example.cal_tracker_mobile android.permission.RECORD_AUDIO
```

4. Open the app, tap the microphone control, speak into the host machine microphone, stop recording, and submit the transcript flow.

If the emulator boots but records silence, cold boot again with an explicit Linux audio backend:

```bash
systemd-run --user --unit=cal-tracker-emulator --collect \
  --working-directory=/home/javier/dev/cal-tracker \
  -E PATH=/home/javier/Android/Sdk/emulator:/home/javier/Android/Sdk/platform-tools:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  -E DISPLAY=:1 \
  -E XAUTHORITY=/run/user/1000/gdm/Xauthority \
  -E XDG_RUNTIME_DIR=/run/user/1000 \
  -E DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  -p StandardOutput=append:/tmp/emulator-systemd.log \
  -p StandardError=append:/tmp/emulator-systemd.log \
  /home/javier/Android/Sdk/emulator/emulator -avd cal_tracker_api36 -no-snapshot -no-snapshot-save -allow-host-audio -audio alsa -no-boot-anim -gpu software -accel on
```

Use `-no-audio` only for non-voice tests where microphone input is irrelevant.

### Installing and Running the Flutter App

```bash
cd /home/javier/dev/cal-tracker/apps/mobile
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.example.cal_tracker_mobile/.MainActivity
```

Use `flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000 -d emulator-5554` only when you need a live debug session.

### Taking Screenshots

```bash
adb -s emulator-5554 shell screencap -p /data/local/tmp/screen.png
adb -s emulator-5554 pull /data/local/tmp/screen.png /tmp/emulator_screen.png
```

### Troubleshooting

- `offline` in `adb devices`: still booting; wait and retry.
- `Can't find service: package`: Android services are not ready; wait for `sys.boot_completed` or cold boot again.
- Sluggish UI is expected with software GPU rendering.
- `adb` not found: export the Android SDK `PATH` shown above.

---

## Backend Startup

### Environment File Location

The backend loads `.env` from **`apps/backend/.env`** (NOT the project root) when using `bun --env-file=.env`.

### Critical: Unset Shell Environment Variables

Bun inherits shell environment variables, which **override** `.env` file values. If the shell has old placeholder values exported, the backend will use those instead of the real keys in `.env`.

```bash
# Always unset these before starting the backend
unset STT_API_KEY OPENROUTER_API_KEY
```

### Start Backend

```bash
cd /home/javier/dev/cal-tracker/apps/backend
bun --env-file=.env src/index.ts
```

### Background Mode

```bash
cd /home/javier/dev/cal-tracker/apps/backend
unset STT_API_KEY OPENROUTER_API_KEY
nohup bun --env-file=.env src/index.ts > /tmp/backend.log 2>&1 &
```

### Verify Health

```bash
curl -s http://localhost:3000/v1/health
# Expected: {"ok":true,"service":"cal-tracker-backend"}
```

---

## PostgreSQL Database

### Start (Docker)

```bash
cd /home/javier/dev/cal-tracker
docker compose up -d postgres
```

### Verify

```bash
docker ps | grep postgres
# Should show cal-tracker-postgres-1 as healthy
```

---

## Full Development Environment Startup

Run these services in separate terminals or detached sessions. For emulator details, use the Android section above.

```bash
# Database
cd /home/javier/dev/cal-tracker && docker compose up -d postgres

# Backend
cd /home/javier/dev/cal-tracker/apps/backend
unset STT_API_KEY OPENROUTER_API_KEY
bun --env-file=.env src/index.ts

# Emulator
# Follow "Android Emulator Initialization".

# Flutter app
cd /home/javier/dev/cal-tracker/apps/mobile
flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000 -d emulator-5554
```

---

## Testing Commands

### Backend Tests

```bash
cd /home/javier/dev/cal-tracker/apps/backend
bun test
```

### Flutter Tests

```bash
cd /home/javier/dev/cal-tracker/apps/mobile
flutter test
```

### Patrol E2E Tests

Patrol tests and `apps/mobile/lib/main_test.dart` must use `CalTrackerBootstrap(apiConfig: ApiConfig(baseUrl: 'http://10.0.2.2:3000'))` directly. Do not depend on a Patrol `--dart-define` for the backend URL; Patrol also injects its own app/test server ports, and those must never become the API base URL. If a Patrol auth failure shows a URL such as `http://10.0.2.2:<random-port>/v1/auth/...`, the test entrypoint is using the wrong API config.

Before running Patrol, verify the backend is reachable from the host on port 3000 and restart it if needed:

```bash
curl -s http://localhost:3000/v1/health
```

Expected response:

```json
{"ok":true,"service":"cal-tracker-backend"}
```

If the backend is not healthy, start it using the Backend Startup section above. Then run Patrol:

```bash
cd /home/javier/dev/cal-tracker/apps/mobile
export PATH="/home/javier/Android/Sdk/emulator:/home/javier/Android/Sdk/platform-tools:$HOME/.pub-cache/bin:$PATH"
export ANDROID_HOME=/home/javier/Android/Sdk ANDROID_SDK_ROOT=/home/javier/Android/Sdk PATROL_ANALYTICS_ENABLED=false

# Stop stale Patrol/Gradle test runs only. Do not kill the emulator or backend.
ps aux | awk '/patrol test|connectedDebugAndroidTest|test_bundle.dart/ && !/awk/ {print $2}' | xargs -r kill
sleep 2

patrol test --target patrol_test/patrol_smoke_test.dart --device emulator-5554 --no-label
```

If Patrol reports `ClassNotFoundException: androidx.test.services.shellexecutor.ShellMain`, `DELETE_FAILED_INTERNAL_ERROR`, or `Total: 0`, the emulator package manager/test-services state is corrupted. Cold boot the emulator using the Android Emulator Initialization section, then rerun Patrol. Do not keep retrying on the corrupted emulator instance.

### Marionette MCP

```bash
cd /home/javier/dev/cal-tracker/apps/mobile
export PATH="$HOME/.pub-cache/bin:$PATH"
marionette_mcp
```

Run the Flutter app in debug mode first and use the VM Service `ws://.../ws` URI printed by `flutter run` with Marionette's `connect` tool.

### Groq STT Isolation Test

```bash
cd /home/javier/dev/cal-tracker/apps/backend
bun --env-file=.env scripts/test-groq-whisper.ts
```


*Last updated: 2026-05-08*
