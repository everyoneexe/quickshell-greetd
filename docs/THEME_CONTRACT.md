# Theme contract

A theme draws. It never authenticates, never opens a window, and never drives
greetd. That split is the whole point: a broken theme can only look wrong, it
cannot stop you from logging in.

## What the core owns

| Responsibility | Where | Why not the theme |
|---|---|---|
| greetd protocol | `QsGreet.Auth` | A theme that mishandles the prompt loop would wedge authentication. SDDM lets themes call `login()` directly; this does not. |
| The window | `QsGreet.ThemeHost` | A theme that forgets to create a Wayland surface produces a black screen with no error. Measured: the previous version of this project created zero `wl_surface`s and showed nothing. |
| Recovery | `QsGreet.FallbackLogin` | Theme fails to load, or loads and draws nothing → the core replaces it with a working login. |
| Users, sessions, power | `QsGreet.Users`, `.Sessions`, `.Power` | Discovery runs once in the launcher; themes read results. |

## What is not a theme

**SDDM themes are out of scope.** Not as a slight, and not because they are
hard to drive - the API they need is small. They reach `sddm`, `userModel`,
`sessionModel`, `keyboard` and `screenModel` as bare names, which SDDM
injects from C++ with `QQmlContext::setContextProperty`. QML cannot supply
those: a type name must begin with an uppercase letter, so a `sddm`
singleton never binds.

```
# qmldir: singleton sddm 1.0 sddm.qml
ReferenceError: sddm is not defined
```

Quickshell offers no way in either - it sets no context properties anywhere.
Supporting SDDM themes would therefore mean shipping a C++ plugin purely to
inject six names, or rewriting every file in the theme that uses them (11 of
16 files and ~91 references in SilentSDDM, measured). Both contradict what
this project is for, which is running Quickshell lockscreens as greeters.

## What a theme is

A directory under `/usr/share/quickshell-greetd/themes/<name>` containing:

```
<name>/
  theme.env                      QSGREET_SURFACE and other overrides
  shell/                         the Quickshell shell tree (the shell root)
    _qsgreet-entry.qml           injected: opens the window
    _qsgreet-main.qml            injected: the theme itself
```

`shell/` is the shell root, not an import path. This is required, not stylistic:
a Quickshell config resolves its own `import qs.*` and `root:` imports only
when it is the root. Loading the same tree through `QML_IMPORT_PATH` fails -
`services/deferred/AnimeService.qml:6` imports `"root:"`, which does not
resolve, and the failure cascades through every singleton.

`qsgreet-theme-prepare` builds this layout. It copies the tree and refuses any
destination inside the source, so your live shell config is never written to.

### Adapter kinds

`_qsgreet-main.qml` is picked by `--kind`:

| `--kind` | For | What the surface gets |
|---|---|---|
| `lockscreen` (default) | A lock surface that expects its host to hand it a `context` object | `GreeterLockContext` |
| `standalone` | A surface that is already a complete greeter and holds its own state | nothing |

Picking the wrong one is not fatal but is visible: assigning `context` to a
surface that has no such property logs
`Cannot assign to non-existent property "context"`.

### Typed contexts

Most lock surfaces declare a *typed* property:

```qml
required property LockContext context      // ii, waffle
required property var context              // iris
```

QML enforces the type, so a foreign object is refused outright:

```
Cannot assign QObject* to LockContext_QMLTYPE_434*
```

The only way to satisfy it is to be that type, and in QML the type is the
file name. So `--kind lockscreen` replaces the shell's own context file with
a greetd-backed one of the same name, keeping the original as
`<name>.qml.qsgreet-orig`. Exactly one file changes, and it is the PAM
boundary - the one place a lockscreen does something a greeter cannot.

Pass `--context <path>` when the file is not next to the surface, as with
`modules/waffle/lock/` whose context lives in `modules/lock/`.

Type identity also depends on *how* the surface reaches the name, and
getting it wrong fails the same way in the other direction. A file in the
surface's own directory beats any module import, so the context is created
by URL in that case and through its `qmldir` module otherwise. Both
directions were measured.

A `standalone` surface usually talks to `Quickshell.Services.Greetd`
directly, which bypasses `QsGreet.Auth`. The window and the recovery path
still belong to the core, but the "themes cannot drive authentication"
guarantee does not hold for it.

## Writing a theme by hand

`_qsgreet-main.qml` is an `Item`. The core anchors it to the window.

```qml
import QtQuick
import QsGreet

Item {
    anchors.fill: parent

    // Non-empty makes the core swap in its built-in login.
    property string themeError: ""

    TextInput {
        id: password
        echoMode: TextInput.Password
        enabled: !Auth.busy
        onAccepted: Auth.login(Users.selectedName, text)
    }

    Text { text: Auth.errorText }
}
```

### API available to themes

`Auth`
- `state` — `idle` | `authenticating` | `prompt` | `launching` | `failed`
- `busy`, `errorText`, `username`, `available`
- `promptActive`, `promptMessage`, `promptEcho`
- `infoMessage` — PAM chatter that needs no answer, e.g. pam_fprintd's
  "Place your finger on the fingerprint reader"
- `login(user, secret)` — an empty secret means "no answer stored, let the
  PAM stack ask", which is how a fingerprint-first stack starts
- `submitSecret(secret)`, `cancel()`
- signals `failed(message)`, `promptRequested(message, echo)`,
  `info(message, error)`, `launching()`

`Users` — `list`, `count`, `selectedName`, `displayName`, `avatar`, `home`,
`select(name)`, `cycle()`

`Sessions` — `list`, `count`, `selected`, `selectedName`, `command`,
`select(id)`, `cycle()`

`Power` — `enabled`, `poweroff()`, `reboot()`, `suspend()`

`GreeterConfig` — `theme`, `user`, `lockUser`, `windowMode`,
`fingerprintEnabled`, `envOr(name, default)`

`respond()` is deliberately absent. The core answers greetd; a theme hands
over a string and nothing more.

## Running an existing lockscreen

Most Quickshell lockscreens take a single `context` object from their host and
talk to nothing else. `QsGreet.GreeterLockContext` reproduces that object's
shape on top of `Auth`, so the surface loads verbatim:

```
qsgreet-theme-prepare ~/.config/quickshell/inir \
    --surface modules/iris/lock/IrisLockSurface.qml \
    /usr/share/quickshell-greetd/themes/iris
```

Surfaces verified to render and authenticate end to end:

| Surface | Lines | Context | Note |
|---|---|---|---|
| `modules/iris/lock/IrisLockSurface.qml` | 426 | `var` | no substitution needed |
| `modules/lock/LockSurface.qml` (end-4 / ii) | 1052 | typed, same dir | the file v1 of this project shipped and could not run |
| `modules/lock/LockSurface.qml` (inir) | 2105 | typed, same dir | heaviest: UPower, Mpris, SystemTray, bar, weather |
| `modules/waffle/lock/WaffleLockSurfaceSafe.qml` | 1575 | typed, other dir | needs `--context modules/lock/LockContext.qml` |

Context members provided: `currentText`, `unlockInProgress`, `showFailure`,
`fingerprintsConfigured`, `statusMessage`, `targetAction` + `ActionEnum`,
`tryUnlock()`, `clearText()`, `resetClearTimer()`, `resetTargetAction()`, and
signals `unlocked(action)`, `failed()`, `shouldReFocus()`.

For code that instantiates `PamContext` directly, `QsGreet.GreetdPamContext`
is a drop-in with the same members (`start()`, `abort()`, `respond()`,
`active`, `responseRequired`, `pamMessage`, `completed(result)`), plus
`QsGreet.PamResult` for the enum.

### Where a lockscreen stops being identical

A lockscreen authenticates *its own* user inside a running session. A greeter
authenticates *another* user from a bare `greeter` account. The gap is real:

| Lockscreen dependency | In a greeter |
|---|---|
| Fingerprint | **Works, but not from the greeter.** A theme-side `PamContext` would fight greetd for the session, so `GreetdPamContext.start()` refuses it. Stack `auth sufficient pam_fprintd.so` in `/etc/pam.d/greetd` instead: greetd already runs PAM as root for the target user. Reader prompts then arrive as ordinary auth messages in `Auth.infoMessage` / `context.statusMessage`, and the launcher sets `QSGREET_FINGERPRINT=1` so themes show the affordance. |
| Keyring unlock | Same answer: `auth optional pam_gnome_keyring.so` plus `session optional pam_gnome_keyring.so auto_start`. The greeter never touches the keyring. |
| Avatar | `~/.face` is unreadable (home is mode 700). Use the shared store: `sudo qsgreet-set-avatar <image>` writes `/var/cache/quickshell-greetd/avatars/<user>`, which the launcher prefers over `/var/lib/AccountsService/icons/<user>`. |
| Wallpaper and generated colours | Also unreadable for the same reason. `qsgreet-theme-prepare --appearance` exports them into the theme and the launcher points `XDG_CONFIG_HOME` / `XDG_STATE_HOME` at the copy. Video wallpapers are skipped; set `background.thumbnailPath` to a still. |
| MPRIS media card | **Not solvable, deliberately.** Nobody is logged in, so there is no session bus and the widget hides itself. Verified by making the bus unreachable: the card disappears. Note that unsetting `DBUS_SESSION_BUS_ADDRESS` alone is *not* enough - libdbus falls back to `$XDG_RUNTIME_DIR/bus`, so what actually isolates the greeter is running as its own user with its own runtime directory. The launcher enforces that: it refuses to start if `XDG_RUNTIME_DIR` is owned by somebody else. |
| Notifications | **Should not be solved.** Notification history is private; rendering it before authentication means anyone at the keyboard reads it. |
| Weather, network, audio | Need user session state or polkit grants. Blank. A greeter-side fetch is possible for weather since it is public data, but is not implemented. |
| Compositor IPC (Hyprland, niri) | No instance signature; dependent features stay inert. |
| `SystemInfo.username` | Resolves to `greeter`. Use `Users.selectedName` / `Users.displayName`. |

### Exporting appearance safely

A theme directory is world-readable, so `--appearance` cannot simply copy
`config.json`: shell configs hold API keys and Wi-Fi passwords. The exporter
blanks any non-empty string under a credential-shaped key and prints exactly
what it redacted. Booleans are left alone, so settings like
`lock.security.requirePasswordToPower` keep working.

Exported layout, matching what Qt's `StandardPaths` will resolve:

```
<theme>/state/config/<shell>/config.json          XDG_CONFIG_HOME
<theme>/state/state/quickshell/user/generated/colors.json   XDG_STATE_HOME
<theme>/state/wallpaper.<ext>
```

## Running a foreign greeter as a theme

Verified with [Airlock](https://github.com/AstraSuite/Airlock), a standalone
Caelestia-styled greeter with its own C++ QML plugin:

```sh
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release && cmake --build build
qsgreet-theme-prepare /path/to/Airlock \
    --kind standalone \
    --surface modules/GreeterSurface.qml \
    /usr/share/quickshell-greetd/themes/airlock
```

It renders, with no warnings, once its own plugin is on `QML_IMPORT_PATH`.
What the experiment showed:

- A surface with no required properties loads as-is under `--kind standalone`.
- Anything the surface imports must be resolvable. Airlock needs
  `Astra.Airlock` (its own plugin, buildable) plus `M3Shapes` and
  `Caelestia.Blobs` from caelestia-shell. Missing modules fail the whole
  tree, and the core falls back to its built-in login rather than showing
  a dead screen.
- `QML_IMPORT_PATH` is the extension point: a theme that needs extra QML
  modules can ship them, and the launcher prepends the core directory
  without clobbering what is already set.

The limit is honest: hosting a foreign greeter gives you its looks, not the
core's guarantees. It drives greetd itself, so `Auth` is bypassed.

## Failure handling

The core gives up on a theme in three cases, and shows the built-in login:

1. `Loader.Error` — the theme's QML failed to load.
2. `themeError` set to a non-empty string by the theme itself.
3. Watchdog: after `QSGREET_THEME_WATCHDOG` seconds (default 6) the theme item
   is missing or has zero width/height.

Set `QSGREET_THEME_WATCHDOG=0` to disable the third check while developing a
slow theme.

## Window modes

`QSGREET_WINDOW_MODE=floating` (default under cage) uses one `FloatingWindow`.
cage does not implement `wlr-layer-shell`; using `PanelWindow` there logs
`Failed to initialize layershell integration` and yields a broken surface.

`QSGREET_WINDOW_MODE=layer` (default under niri and sway) uses one
`PanelWindow` per screen on the overlay layer with exclusive keyboard focus.

Themes are unaffected either way - they never create the window.
