# AGENTS.md

Guidance for AI coding agents working on this AUI application (a consumer of the
[AUI Framework](https://github.com/aui-framework/aui)).

## Layout

- `src/` — sources, auto-globbed by `aui_executable`. Entry point is `AUI_ENTRY` (`<AUI/Platform/Entry.h>`).
- `tests/` — GTest/GMock tests, enabled by `aui_enable_tests`.
- `assets/` — compiled into the binary by `aui_compile_assets`.
- `aui.boot.cmake` — AUI.Boot package manager; `AUI_VERSION` in `CMakeLists.txt` selects the AUI release.

Edit this project's files only. To read or change AUI itself, reconfigure with `-DAUIB_AUI_AS=TRUE`; AUI.Boot prints
where the editable sources are.

## Build and test

```bash
cmake -B build -GNinja
cmake --build build --parallel 8
cmake --build build --target Tests && ./build/bin/Tests
```

## Code style

4 spaces, max 120 columns, `mLikeThis` members, `lowerCamelCase` functions, `UPPER_SNAKE_CASE` constants, `A`-prefixed
public classes. Always put a trailing comma in UI DSL initializer lists:

```cpp
setContents(Vertical {
    Label { "Up" },
    Label { "Down" },   // <- trailing comma
});
```

Use `_new<T>(...)` / `_<T>`, signal-slot `connect(...)` and properties for data binding. Formatting follows
`.clang-format`. Keep comments and docs plain: no filler, no AI-flavoured prose.

## Looking at the running application

Verify UI changes in the real window with the `aui-remote` skill in `.claude/skills`. It locates `aui-remote` (needs an
AUI version that has `aui::dev_extras`), asks the user before adding a debug-only `ARemoteDebug::start` to the
application and then drives the app: inspect views, click, type, take screenshots.

> **Warning:** never link `aui::dev_extras` to release builds: the agent lets a client click, type and read the screen.

### Android devices and the local network

`aui-remote` runs on the host; an app on an Android device is attached to it first. The agent prints its discovery JSON
to logcat (tag `ARemoteDebug`), the client takes it from there and runs `adb forward`:

```bash
adb install -r <apk> && adb shell am start -n <package>/<activity>
aui-remote cli attach --adb [--serial <serial>]    # then: pair <pid> (the code is on the device screen), and the usual commands with --pid
```

`aui-remote` is `<install_dir>/bin/aui-remote` of the `aui` entry in `build/package-lock.json` (with `-DAUIB_AUI_AS=TRUE`
build it: `cmake --build build -t aui.remote`). The same entry's `source_dir` (`~/.aui/repo/aui-<hash>`) holds the AUI
sources. Android builds don't build `aui-remote`: use the host one.

Over Wi-Fi instead of a cable, set `adb shell setprop debug.aui.remote.bind 0.0.0.0` (and optionally
`debug.aui.remote.port 40000`) before the app starts, then `aui-remote cli attach --adb --lan`. On desktop the same is
`AUI_REMOTE_BIND` and `AUI_REMOTE_PORT`. Traffic is encrypted and needs pairing, but use only a network you trust.
Details: `docs/agentic-development.md` of AUI.

Pitfalls (learned on a large AUI game, they apply to any AUI Android app):

- Start the agent from a macro that CMake defines for every build except the shipped release (`target_compile_definitions`
  from `VERSION_NAME != release`), not from `AUI_DEBUG`: then a staging APK is debuggable too, and release still isn't.
  Link `aui::dev_extras` under the same condition; with `-DAUIB_AUI_AS=TRUE` Android builds it from source.
- Port and certificate are new on every start: `attach` again after a restart. A stale logcat line makes `attach` say
  the agent does not answer; start the app and retry (`adb logcat -c` first helps).
- Properties set with `setprop` are read at start only. With several devices pass `--serial`; `adb` may be missing from
  `PATH` (`--adb-path`, `$ADB` or `$ANDROID_HOME/platform-tools`).
- The device screen must be on: with it off the GL surface does not exist and an engine that starts on it never starts, so
  there is no agent and logcat is empty (`adb shell input keyevent KEYCODE_WAKEUP`).
- The pairing code is also written to logcat (`Pairing code: ...`); the pairing is remembered across restarts. A screenshot
  comes in the answer and is saved on the host, no `adb pull` needed.
- A debug APK built with `-Pandroid.injected.build.abi=...` is `testOnly`: `adb install -r -t`.
- A custom-drawn UI (GL canvas, game) is a single view: use coordinates and `registerFunction`, not `tree`.
- All agent calls run on the UI thread of AUI. In engines that own the render loop it is the GL thread, so a handler must
  not block; touch UI state only from there.
- JNI binds by string names: never rename or move Kotlin classes that C++ calls, and `external fun` ↔ `Java_*`; wrap
  `AUI_JNI_CLASS` in `// clang-format off/on`. A mistake shows up at run time only.
- Keep `extractNativeLibs="true"` and `useLegacyPackaging true`; build `libgame.so` with 16 KB pages
  (`-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON`), which Google Play requires.
- Keep AGP, Kotlin and NDK versions in step (the NDK is also named in the Docker image if you build there). Gradle 8.x
  were built with JDK 17 here (`JAVA_HOME`); a newer default JDK was not tried.
