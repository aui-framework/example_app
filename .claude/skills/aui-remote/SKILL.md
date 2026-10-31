---
name: aui-remote
description: Build, run, look at, click and type into this AUI application through aui-remote. Load it before changing anything visible (views, buttons, layouts, styles) and whenever the user asks to run, test or verify the app, so the result is checked in the real window.
---

# Verifying the UI of this application

Follow the steps in order. A UI change is not done until you have seen it work in the running application.

## 1. Locate aui-remote

Configure a Debug build if there is none. Use the build directory the user has, if it is not `build`:

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Debug
```

On configure, AUI.Boot writes `build/package-lock.json`: what every dependency resolved to, with its `version`,
`source_dir`, `pin` and `as_subdirectory`, and `install_dir` for an installed package. Read it instead of guessing paths
under `~/.aui`. It is also the way to AUI's own sources (`source_dir`) when you need to check an API.

Read the `aui` entry:

- `as_subdirectory` is `false`: AUI is a distribution, the tool is `aui-remote` in `<install_dir>/bin`. If there is no
  such file, `AUI_VERSION` is too old to have it. Tell the user. Do not change `AUI_VERSION` on your own.
- `as_subdirectory` is `true`: AUI is pulled with `-DAUIB_AUI_AS=TRUE`, so `aui-remote` is a target of this build. Run
  `cmake --build build -t aui.remote`; the tool is in `build/bin`.

The name depends on the platform: `aui-remote.exe` on Windows; on macOS, look for
`aui-remote.app/Contents/MacOS/aui-remote` as well.

Below, `aui-remote` stands for that path. Write the full path out in every command.

## 2. Ask for permission to add remote debugging

Search `src/` for `ARemoteDebug`. If it is there and `CMakeLists.txt` links `aui::dev_extras`, go to step 4.

Otherwise stop here, before you edit anything for it, and ask the user. Use the tool for asking questions, or, if you
have none, ask in your reply and end your turn. Say what you are going to add: `aui::dev_extras` linked to Debug builds
and an `ARemoteDebug::start` call under `#if AUI_DEBUG` in `src/main.cpp`, which lets you control the application over a
loopback port, take screenshots and verify the result. Release builds do not get it.

If the user declines, do not add it. Finish with a build and the `Tests` target, and say that the UI was not verified.

## 3. Add debug-only remote debugging

In `CMakeLists.txt`, add `dev_extras` to `COMPONENTS` of `auib_import` and, after `aui_executable`:

```cmake
if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    # remote debugging for aui-remote; never ship aui::dev_extras
    aui_link(${PROJECT_NAME} PRIVATE aui::dev_extras)
endif ()
```

In `src/main.cpp`, next to the includes:

```cpp
#if AUI_DEBUG && __has_include(<AUI/Remote/ARemoteDebug.h>)
#include <AUI/Remote/ARemoteDebug.h>
#define APP_REMOTE_DEBUG 1
#endif
```

and first thing in `AUI_ENTRY`:

```cpp
#if APP_REMOTE_DEBUG
    ARemoteDebug::start(ARemoteDebug::Options::fromEnvironment());
#endif
```

Nothing else in the application changes. Configure and build as in `AGENTS.md`.

## 4. Choose where to run the application

Prefer a headless environment if you can get one: the window does not cover the user's work and their mouse does not
interfere with you. It is a preference, not a requirement. If there is none at hand, run the application on the user's
desktop and say so in your report. Input of `aui-remote` is injected into the application, so it does not move the
user's pointer or type into their other windows. Never send OS-level input (XTest and alike) to their session.

What is available depends on the platform:

- Linux: check what is installed and use it, for example Xvfb or a headless mode of the compositor. With mutter (kill
  it by its pid when you are done, never by name: the user's desktop can be mutter too):

  ```bash
  mutter --headless --wayland --virtual-monitor 1280x800 --wayland-display aui-agent > mutter.log 2>&1 &
  echo $!                                                      # remember the pid
  grep 'public X11 display' mutter.log                         # gives :N, the log may need a second to appear
  ls -t /run/user/$(id -u)/.mutter-Xwaylandauth.* | head -1    # gives the XAUTHORITY file
  ```

  Then prefix `launch` with `env -u WAYLAND_DISPLAY DISPLAY=:N XAUTHORITY=<file>`.
- Windows and macOS: there is usually no headless environment, use the desktop.
- Android and iOS: the application runs on a device or an emulator and can't write a discovery file the host can read.
  It needs `Options::writeDiscoveryFile = false` and a fixed port, forwarded to the host (`adb forward`).
- Emscripten and anything not listed: read `docs/agentic-development.md` in `source_dir` of AUI. If you can't reach
  the application, tell the user.

## 5. Drive the application

```bash
aui-remote cli launch -- <absolute path to example_app>      # prints { pid, port, ... }
aui-remote cli screenshot --annotate --pid <pid>             # numbered views, `marks` maps numbers to refs
aui-remote cli click <ref> --pid <pid>
aui-remote cli wait-idle --pid <pid>
aui-remote cli screenshot --pid <pid>                        # read the PNG at the printed path
aui-remote cli stop <pid>
```

The application is in `build/bin` (`.exe` on Windows, an `.app` bundle on macOS). `launch` passes a key to the application, so no pairing is needed. For an instance the user started themselves, run
`aui-remote cli pair <pid>` and ask them for the 6-digit code shown in the window, then
`aui-remote cli pair <pid> --code <code>`. Never guess a code.

`aui-remote cli help` lists all commands (`tree`, `find`, `type`, `key`, `logs`, `resize` and more).

Exercise the change the way a user would, and look at the PNG before and after: a counter is verified when its text
changes after clicking, not when the button exists. If it is wrong, fix the code, rebuild, `stop`, `launch` and check
again. In your report, say what you clicked and what the screenshot showed.

## Rules

- Always `wait-idle` after input, then `screenshot`. Otherwise you see the frame before the change.
- Every command prints one JSON object on the last line. On failure read `error.data.hint`.
- Refs (`v<gen>:<id>`) go stale when the tree changes. On `STALE_REF`, run `find` again.
- Check `logs --level warn` when something does not react.
- Native dialogs are drawn by the OS: you can't see or click them. Don't click buttons that open a browser or a file
  picker in an environment the user can see.
- `stop` what you launched and shut down the headless environment you started, if any.
- Keep `aui::dev_extras` out of release builds.
