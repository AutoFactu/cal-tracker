# Agent Operations Guide

This file contains environment-specific instructions for coding agents working on the Cal Tracker project.

---

## Android Emulator Initialization

> **Critical:** The Android emulator must be started with the process fully detached from the shell. Running it in the foreground or with a simple `&` will cause the emulator to be killed when the shell command times out.

### Prerequisites

- Android SDK installed at `/home/javier/Android/Sdk`
- Emulator binary at `/home/javier/Android/Sdk/emulator/emulator`
- ADB at `/home/javier/Android/Sdk/platform-tools/adb`
- AVD configured: `cal_tracker_api36` (API 36, x86_64)
- KVM acceleration available (`/dev/kvm` exists)

### Step-by-Step Initialization

#### 1. Export required PATH

```bash
export PATH="/home/javier/Android/Sdk/emulator:/home/javier/Android/Sdk/platform-tools:$PATH"
```

#### 2. Kill any existing emulator process

Always clean up stale processes first:

```bash
ps aux | grep qemu | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
sleep 2
```

#### 3. Start the emulator fully detached

Use `nohup` to detach from the shell, redirect all output to a log file, and run in background:

```bash
nohup emulator -avd cal_tracker_api36 \
  -no-snapshot \
  -no-snapshot-save \
  -no-audio \
  -no-boot-anim \
  -gpu swiftshader_indirect \
  -accel on \
  > /tmp/emulator.log 2>&1 &
```

**Why these flags:**
- `-no-snapshot` / `-no-snapshot-save`: Forces a **cold boot** every time. This is the most reliable method — snapshot restore has been observed to corrupt the Android system state, leading to "Can't find service: package" errors.
- `-no-audio`: Prevents audio device conflicts on the host.
- `-no-boot-anim`: Speeds up boot by skipping the animation.
- `-gpu swiftshader_indirect`: Software GPU rendering. The host GPU (NVIDIA RTX 2060) works with `-gpu host` but `swiftshader_indirect` is more stable for this environment.
- `-accel on`: Enables CPU hardware acceleration (KVM). Critical for acceptable performance.

**Why `nohup`:**
The emulator process must survive shell disconnects and command timeouts. A simple `&` is not sufficient — the process may still receive SIGHUP when the shell session ends. `nohup` ensures the emulator continues running.

#### 4. Wait for full boot

The emulator appears in `adb devices` as `emulator-5554` long before Android services are ready. Wait for `sys.boot_completed`:

```bash
sleep 45
adb devices
adb -s emulator-5554 shell "while [[ \$(getprop sys.boot_completed) != 1 ]]; do sleep 1; done; echo 'Boot completed'"
```

This typically takes 45–60 seconds total.

#### 5. Verify health

```bash
# Check package manager is responsive
adb -s emulator-5554 shell "pm list packages -f | grep android | wc -l"
# Should return ~240+ packages

# Test shell responsiveness
adb -s emulator-5554 shell echo "alive"
```

#### 6. What NOT to do

- ❌ Do NOT run `emulator ... &` without `nohup` — the process will be killed on shell timeout.
- ❌ Do NOT use snapshot boot (`-no-snapshot-load` alone is not enough) — corrupted snapshots cause "Can't find service: package" errors.
- ❌ Do NOT try to `adb install` or `flutter run` immediately after `adb devices` shows the device — wait for `sys.boot_completed == 1`.
- ❌ Do NOT kill the emulator with broad patterns like `pkill -9 -f "bun"` — this will kill unrelated processes including the backend.

### Installing and Running the Flutter App

#### Build APK

```bash
cd /home/javier/dev/cal-tracker/apps/mobile
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

#### Install APK

```bash
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

#### Launch App

```bash
adb -s emulator-5554 shell am start -n com.example.cal_tracker_mobile/.MainActivity
```

#### Alternative: Use `flutter run`

```bash
flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000 -d emulator-5554
```

Note: `flutter run` handles build, install, and attach automatically, but will disconnect if the process is backgrounded.

### Taking Screenshots

```bash
adb -s emulator-5554 shell screencap -p /data/local/tmp/screen.png
adb -s emulator-5554 pull /data/local/tmp/screen.png /tmp/emulator_screen.png
```

### Troubleshooting

**Problem: Emulator shows `offline` in `adb devices`**
- The emulator is still booting. Wait 30–45 more seconds and retry.

**Problem: `adb install` fails with "Can't find service: package"**
- Android system services are not fully initialized. Wait for `sys.boot_completed == 1`.
- If this persists, the snapshot may be corrupted. Kill the emulator and cold boot with `-no-snapshot`.

**Problem: App installs but UI is sluggish**
- Normal for software GPU rendering. The emulator is functional but frame drops are expected.

**Problem: `adb` command not found**
- PATH is not set. Run:
  ```bash
  export PATH="/home/javier/Android/Sdk/emulator:/home/javier/Android/Sdk/platform-tools:$PATH"
  ```

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

Run these in separate terminals (or background them with `nohup`):

```bash
# Terminal 1: Database
cd /home/javier/dev/cal-tracker && docker compose up -d postgres

# Terminal 2: Backend
cd /home/javier/dev/cal-tracker/apps/backend
unset STT_API_KEY OPENROUTER_API_KEY
bun --env-file=.env src/index.ts

# Terminal 3: Emulator
export PATH="/home/javier/Android/Sdk/emulator:/home/javier/Android/Sdk/platform-tools:$PATH"
ps aux | grep qemu | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null; sleep 2
nohup emulator -avd cal_tracker_api36 -no-snapshot -no-snapshot-save -no-audio -no-boot-anim -gpu swiftshader_indirect -accel on > /tmp/emulator.log 2>&1 &
sleep 50
adb devices

# Terminal 4: Flutter (after emulator boots)
cd /home/javier/dev/cal-tracker/apps/mobile
flutter run --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000 -d emulator-5554
```

---

## Key Project Paths

| Component | Path |
|-----------|------|
| Project root | `/home/javier/dev/cal-tracker` |
| Backend | `/home/javier/dev/cal-tracker/apps/backend` |
| Mobile | `/home/javier/dev/cal-tracker/apps/mobile` |
| Backend env | `/home/javier/dev/cal-tracker/apps/backend/.env` |
| Android SDK | `/home/javier/Android/Sdk` |
| AVD | `/home/javier/.android/avd/cal_tracker_api36.avd` |
| Emulator log | `/tmp/emulator.log` |
| Backend log | `/tmp/backend.log` |
| Docker compose | `/home/javier/dev/cal-tracker/docker-compose.yml` |

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

### Groq STT Isolation Test

```bash
cd /home/javier/dev/cal-tracker/apps/backend
bun --env-file=.env scripts/test-groq-whisper.ts
```

### API Quick Checks

```bash
# Health
curl -s http://localhost:3000/v1/health

# Login
TOKEN=$(curl -s -X POST http://localhost:3000/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"demo@example.com","password":"password123"}' | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
echo $TOKEN

# STT (requires valid audio file)
curl -s -X POST http://localhost:3000/v1/stt/transcriptions \
  -H "Authorization: Bearer $TOKEN" \
  -F "audio=@/tmp/test_audio.m4a;type=audio/m4a"
```

---

*Last updated: 2026-05-08*
