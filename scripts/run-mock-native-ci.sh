#!/usr/bin/env bash
# Explicit GitHub-owned release fixture. Never enumerates or touches a USB phone.
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted && "$(uname -s)" == Linux ]]
[[ "${PLANETS_DISPOSABLE_QA:-}" == 1 ]]
[[ -z "$(git status --porcelain --untracked-files=no)" ]]
[[ ! -e apps/mobile/android/key.properties ]]
root="$PWD"
private="$(mktemp -d /tmp/planets-mock-native.XXXXXX)"
chmod 700 "$private"
phase=setup
backend_pid=''
emulator_started=false
export JAVA_TOOL_OPTIONS='-XX:ActiveProcessorCount=2'
export GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx1536m -Dorg.gradle.workers.max=2'
finish() {
  local result=$?
  trap - EXIT
  set +e
  if [[ "$emulator_started" == true ]]; then adb -s emulator-5554 emu kill >"$private/emulator-cleanup.log" 2>&1; fi
  if [[ -n "$backend_pid" ]] && kill -0 "$backend_pid" 2>/dev/null; then kill -TERM "$backend_pid"; wait "$backend_pid"; fi
  node scripts/mock/collect-native.mjs "$private" "$result" "$phase"
  local collected=$?
  # Exact owned secret/artifact paths; never remove the user's signing material.
  rm -f -- apps/mobile/android/key.properties "$private/native-defines.json" "$private/scan-secrets.json" "$private/mock.apk" "$private/fixture-upload.jks" apps/mobile/build/app/outputs/flutter-apk/app-release.apk
  if [[ "$result" == 0 && "$collected" != 0 ]]; then result=$collected; fi
  exit "$result"
}
trap finish EXIT
run() { phase="$1"; shift; echo "Mock native: $phase"; "$@" >"$private/$phase.log" 2>&1; }
run packages bash -c 'cd apps/mobile && flutter pub get && flutter gen-l10n'
run sdk sdkmanager 'platform-tools' 'emulator' 'platforms;android-36' 'system-images;android-36;google_apis;x86_64'
[[ -c /dev/kvm ]]
run kvm sudo chmod a+rw /dev/kvm
phase=backend
node scripts/mock/qualify-local.mjs --native "$private" >"$private/backend.log" 2>&1 &
backend_pid=$!
for ((attempt=0; attempt<900; attempt++)); do
  [[ -f "$private/native-ready.json" ]] && break
  kill -0 "$backend_pid" 2>/dev/null || { wait "$backend_pid"; exit 1; }
  sleep 1
done
[[ -f "$private/native-ready.json" ]]
export PLANETS_MOCK_QA_PASSWORD="$(openssl rand -hex 32)"
run signing keytool -genkeypair -keystore "$private/fixture-upload.jks" -alias planets-ci-fixture -keyalg RSA -keysize 2048 -validity 2 -dname 'CN=PLANETS CI Fixture,O=PLANETS,C=IT' -storepass:env PLANETS_MOCK_QA_PASSWORD -keypass:env PLANETS_MOCK_QA_PASSWORD
printf 'storeFile=%s\nstorePassword=%s\nkeyAlias=planets-ci-fixture\nkeyPassword=%s\n' "$private/fixture-upload.jks" "$PLANETS_MOCK_QA_PASSWORD" "$PLANETS_MOCK_QA_PASSWORD" > apps/mobile/android/key.properties
run release-build bash -c 'cd apps/mobile && flutter build apk --release --no-pub --build-number=1 --target=integration_test/mock_realm_release_test.dart --dart-define-from-file="$1"' _ "$private/native-defines.json"
cp apps/mobile/build/app/outputs/flutter-apk/app-release.apk "$private/mock.apk"
run artifact-scan python3 scripts/mock/scan-native-apk.py "$private/mock.apk" "$private/scan-secrets.json" mock-native-evidence/apk-scan.json
# No compiler competes with the 2 GiB Android VM.
phase=avd
echo no | avdmanager create avd --name PLANETS_MOCK_CI --package 'system-images;android-36;google_apis;x86_64' --device pixel_4 >"$private/avd.log" 2>&1
emulator -avd PLANETS_MOCK_CI -port 5554 -memory 2048 -cores 2 -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader >"$private/emulator.log" 2>&1 &
emulator_started=true
run device timeout 300 adb -s emulator-5554 wait-for-device
phase=boot
ready=false
for ((attempt=0; attempt<150; attempt++)); do
  if [[ "$(adb -s emulator-5554 shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]; then ready=true; break; fi
  sleep 2
done
[[ "$ready" == true ]]
adb -s emulator-5554 shell input keyevent KEYCODE_HOME >/dev/null
adb -s emulator-5554 shell wm size 640x1520
adb -s emulator-5554 shell wm density 320
for port in 57420 57421 57422; do adb -s emulator-5554 reverse "tcp:$port" "tcp:$port"; done
run install adb -s emulator-5554 install -t "$private/mock.apk"
run launch adb -s emulator-5554 shell am start -n community.planets.app/.MainActivity
phase=first-native-journey
for ((attempt=0; attempt<720; attempt++)); do
  [[ -f "$private/native-restart.json" ]] && break
  kill -0 "$backend_pid" 2>/dev/null || { wait "$backend_pid"; exit 1; }
  sleep 1
done
[[ -f "$private/native-restart.json" ]]
run restart-stop adb -s emulator-5554 shell am force-stop community.planets.app
run restart-launch adb -s emulator-5554 shell am start -n community.planets.app/.MainActivity
phase=restart-native-journey
for ((attempt=0; attempt<360; attempt++)); do
  [[ -f "$private/native-complete.json" ]] && break
  kill -0 "$backend_pid" 2>/dev/null || { wait "$backend_pid"; exit 1; }
  sleep 1
done
[[ -f "$private/native-complete.json" ]]
wait "$backend_pid"
backend_pid=''
phase=complete
