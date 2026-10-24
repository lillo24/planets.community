#!/usr/bin/env bash
# Explicit, bounded, task-owned native evidence; no developer emulator or hosting.
set -Eeuo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted && "${RUNNER_OS:-}" == Linux && "${PLANETS_DISPOSABLE_QA:-}" == 1 ]]
[[ "${A1_BEFORE_SHA:-}" =~ ^[a-f0-9]{40}$ ]]
export TMPDIR="$RUNNER_TEMP"
root="$(git rev-parse --show-toplevel)"
private="$(mktemp -d "$RUNNER_TEMP/planets-a1-native.XXXXXX")"
chmod 700 "$private"
export A1_EVIDENCE="$root/a1-native-evidence"
export A1_WORLD_POINTER="$private/world-path"
export ANDROID_AVD_HOME="$private/avd"
export PATH="$root/node_modules/.bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export JAVA_TOOL_OPTIONS='-XX:ActiveProcessorCount=2'
export GRADLE_OPTS='-Dorg.gradle.workers.max=2 -Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx1536m'
mkdir -p "$ANDROID_AVD_HOME" "$A1_EVIDENCE"
phase=setup
world=''
before=''
emulator_started=false
finish(){
  local code=$?
  trap - EXIT
  set +e
  if [[ -z "$world" && -f "$A1_WORLD_POINTER" ]]; then world="$(cat "$A1_WORLD_POINTER")"; fi
  if [[ "$code" != 0 ]]; then node "$root/scripts/a1/diagnostics.mjs" "$private" "$world" "$phase" "$A1_EVIDENCE"; fi
  printf '{"exit_code":%s,"phase":"%s","hosted_operations":false}\n' "$code" "$phase" >"$A1_EVIDENCE/outcome.json"
  if [[ "$emulator_started" == true ]]; then adb -s emulator-5554 emu kill >"$private/stop-emulator.log" 2>&1; fi
  if [[ -f "$A1_WORLD_POINTER" ]]; then
    world="$(cat "$A1_WORLD_POINTER")"
    if [[ "$world" == "$RUNNER_TEMP"/planets-a1-* ]]; then
      node scripts/a1/stop-world.mjs "$world" >"$private/stop-backend.log" 2>&1
    fi
  fi
  if [[ -n "$before" && "$before" == "$RUNNER_TEMP"/planets-a1-before.* ]]; then git worktree remove --force "$before" >"$private/stop-before.log" 2>&1; fi
  # Private fixture/API material, raw logs and binaries are never artifacts.
  rm -f -- "$private/before.apk" "$private/after.apk" "$root/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk"
  exit "$code"
}
trap finish EXIT
run(){ phase="$1";shift;echo "A1 native: $phase";"$@" >"$private/$phase.log" 2>&1; }
cd "$root"
run packages bash -c 'cd apps/mobile && flutter pub get && flutter gen-l10n'
run sdk sdkmanager 'platform-tools' 'emulator' 'platforms;android-36' 'system-images;android-36;google_apis;x86_64'
[[ -c /dev/kvm ]]
run kvm sudo chmod a+rw /dev/kvm
run backend node scripts/a1/local-world.mjs
world="$(cat "$A1_WORLD_POINTER")"
[[ "$world" == "$RUNNER_TEMP"/planets-a1-* ]]
run migrate node scripts/a1/verify-local.mjs "$world" --apply
run fixture node scripts/a1/prepare-world.mjs "$world"
run upgrade node scripts/a1/verify-upgrade.mjs "$world"
before="$(mktemp -d "$RUNNER_TEMP/planets-a1-before.XXXXXX")"
git worktree add --detach "$before" "$A1_BEFORE_SHA" >"$private/before-checkout.log" 2>&1
cp apps/mobile/integration_test/a1_private_pairs_test.dart "$before/apps/mobile/integration_test/"
cp apps/mobile/test_driver/a1_screenshots.dart "$before/apps/mobile/test_driver/"
run before-build bash -c 'cd "$1/apps/mobile" && flutter pub get && flutter gen-l10n && flutter build apk --debug --no-pub --target-platform android-x64 --target=integration_test/a1_private_pairs_test.dart --dart-define-from-file="$2" --dart-define=A1_BEFORE=true && cd android && ./gradlew --stop' _ "$before" "$world/private-defines.json"
cp "$before/apps/mobile/build/app/outputs/flutter-apk/app-debug.apk" "$private/before.apk"
run after-build bash -c 'cd apps/mobile && flutter build apk --debug --no-pub --target-platform android-x64 --target=integration_test/a1_private_pairs_test.dart --dart-define-from-file="$1" && cd android && ./gradlew --stop' _ "$world/private-defines.json"
cp apps/mobile/build/app/outputs/flutter-apk/app-debug.apk "$private/after.apk"
phase=avd
echo no | avdmanager create avd --name PLANETS_A1_CI --package 'system-images;android-36;google_apis;x86_64' --device pixel_9_pro >"$private/avd.log" 2>&1
emulator -avd PLANETS_A1_CI -port 5554 -memory 2048 -cores 2 -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader >"$private/emulator.log" 2>&1 &
emulator_started=true
run device timeout 300 adb -s emulator-5554 wait-for-device
ready=false
for ((n=0;n<150;n++)); do
  if [[ "$(adb -s emulator-5554 shell getprop sys.boot_completed | tr -d '\r')" == 1 ]]; then ready=true;break;fi
  sleep 2
done
[[ "$ready" == true ]]
adb -s emulator-5554 shell input keyevent KEYCODE_HOME >/dev/null
adb -s emulator-5554 shell wm size 1280x2856
adb -s emulator-5554 shell wm density 480
adb -s emulator-5554 shell settings put system font_scale 1.0
adb -s emulator-5554 shell settings put secure show_ime_with_hard_keyboard 1
adb -s emulator-5554 shell cmd uimode night yes
adb -s emulator-5554 reverse tcp:61321 tcp:61321
adb -s emulator-5554 reverse tcp:61324 tcp:61324
for lane in before after;do
  export A1_LANE="$lane"
  if adb -s emulator-5554 shell pm path community.planets.app | grep '^package:' >/dev/null; then
    run "$lane-clear" adb -s emulator-5554 shell pm clear community.planets.app
  fi
  run "$lane-drive" bash -c 'cd apps/mobile && flutter drive -d emulator-5554 --no-dds --no-pub --use-application-binary="$1" --driver=test_driver/a1_screenshots.dart --target=integration_test/a1_private_pairs_test.dart' _ "$private/$lane.apk"
  touch "$private/$lane-driver-passed"
done
# The native world must remain healthy through both captures. HTTP race/block
# checks receive independent fresh fictional actors after the visual journey.
mv -- "$world/private-world.json" "$world/private-native-world.json"
run http-fixture node scripts/a1/prepare-world.mjs "$world"
run http node scripts/a1/verify-http.mjs "$world"
run report node scripts/a1/report.mjs "$A1_EVIDENCE" "$world" "$A1_BEFORE_SHA"
phase=complete
