#!/usr/bin/env bash
# Ephemeral GitHub-hosted Android review; never run against a developer's runtime.
set -Eeuo pipefail
if [[ "${GITHUB_ACTIONS:-}" != true || "${RUNNER_ENVIRONMENT:-}" != github-hosted || "${RUNNER_OS:-}" != Linux || "${PLANETS_DISPOSABLE_QA:-}" != 1 ]]; then
  echo 'Contact native CI requires an explicitly disposable GitHub-hosted Linux runner.' >&2
  exit 1
fi
root="$(git rev-parse --show-toplevel)"
cd "$root"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  echo 'Contact native CI requires a clean reviewed source checkout.' >&2
  exit 1
fi
private="$(mktemp -d "$RUNNER_TEMP/planets-contact-native.XXXXXX")"
chmod 700 "$private"
export PATH="$root/node_modules/.bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export ANDROID_AVD_HOME="$private/avd"
export JAVA_TOOL_OPTIONS='-XX:ActiveProcessorCount=2'
export GRADLE_OPTS='-Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx1536m'
mkdir -p "$ANDROID_AVD_HOME"
phase=setup
backend_started=false
emulator_started=false
finish() {
  local result=$?
  trap - EXIT
  set +e
  node scripts/collect-contact-native-evidence.mjs "$private" "$result" "$phase"
  local collected=$?
  if [[ "$emulator_started" == true ]]; then adb -s emulator-5554 emu kill >"$private/cleanup-emulator.log" 2>&1; fi
  if [[ "$backend_started" == true ]]; then supabase stop --no-backup >"$private/cleanup-backend.log" 2>&1; fi
  # Exact files only: these contain the synthetic sessions, including in APKs.
  rm -f -- "$private/d-defines.json" "$private/m-defines.json" "$private/d.apk" "$private/m.apk" "$root/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk"
  if [[ "$result" == 0 && "$collected" != 0 ]]; then result=$collected; fi
  exit "$result"
}
trap finish EXIT
run() {
  phase="$1"
  shift
  echo "Contact native: $phase"
  "$@" >"$private/$phase.log" 2>&1
}
run packages bash -c 'cd apps/mobile && flutter pub get && flutter gen-l10n'
run sdk sdkmanager 'platform-tools' 'emulator' 'platforms;android-36' 'system-images;android-36;google_apis;x86_64'
[[ -c /dev/kvm ]]
run kvm sudo chmod a+rw /dev/kvm
backend_started=true
run backend supabase start --exclude studio,postgres-meta,edge-runtime,logflare,vector,supavisor,imgproxy
run d-fixture node apps/mobile/integration_test/prepare_group_contact_smoke.mjs "$private/d-defines.json"
run m-fixture node apps/mobile/integration_test/prepare_member_contact_smoke.mjs "$private/m-defines.json"
for lane in d m; do
  if [[ "$lane" == d ]]; then target=group_contact; else target=member_contact; fi
  run "$lane-build" bash -c 'cd apps/mobile && flutter build apk --debug --no-pub --target="integration_test/'"$target"'_smoke_test.dart" --dart-define-from-file="$1"' _ "$private/$lane-defines.json"
  cp apps/mobile/build/app/outputs/flutter-apk/app-debug.apk "$private/$lane.apk"
done
# No Gradle/Flutter compiler runs alongside the 2 GiB Android VM.
phase=avd
echo no | avdmanager create avd --name PLANETS_CONTACT_CI --package 'system-images;android-36;google_apis;x86_64' --device pixel_4 >"$private/avd.log" 2>&1
emulator -avd PLANETS_CONTACT_CI -port 5554 -memory 2048 -cores 2 -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader >"$private/emulator.log" 2>&1 &
emulator_started=true
run device timeout 300 adb -s emulator-5554 wait-for-device
phase=boot
ready=false
for ((attempt=0; attempt<150; attempt++)); do
  if [[ "$(adb -s emulator-5554 shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]; then
    adb -s emulator-5554 shell input keyevent KEYCODE_HOME >/dev/null
    if adb -s emulator-5554 shell dumpsys window | grep -E 'mCurrentFocus=.*Launcher' >/dev/null; then ready=true; break; fi
  fi
  sleep 2
done
[[ "$ready" == true ]]
if adb -s emulator-5554 shell dumpsys window | grep -E 'Application Not Responding|Not Responding:' >/dev/null; then exit 1; fi
adb -s emulator-5554 shell wm size 720x1600
adb -s emulator-5554 shell wm density 360
adb -s emulator-5554 shell settings put secure show_ime_with_hard_keyboard 1
adb -s emulator-5554 reverse tcp:54321 tcp:54321
for lane in d m; do
  if [[ "$lane" == d ]]; then target=group_contact; else target=member_contact; fi
  run "$lane-drive" bash -c 'cd apps/mobile && flutter drive -d emulator-5554 --no-dds --no-pub --use-application-binary="$1" --driver="test_driver/'"$target"'_screenshots.dart" --target="integration_test/'"$target"'_smoke_test.dart"' _ "$private/$lane.apk"
  touch "$private/$lane-driver-passed"
done
phase=complete
