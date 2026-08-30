# This fork

`gianlocc/cmux`, forked from [`manaflow-ai/cmux`](https://github.com/manaflow-ai/cmux).

## Branch model

| Branch | Role |
| --- | --- |
| `main` | An exact mirror of `upstream/main`. **Never commit here.** It always fast-forwards, so GitHub's "Sync fork" button keeps working. |
| `personal` | Every fork-local change, kept rebased on top of `main`. |

Keeping `main` pristine is what makes syncing lossless: upstream history is
never merged into fork commits, so a sync can never bury or drop them.

## Syncing

```bash
./scripts/fork-sync.sh
```

It fetches upstream, fast-forwards `main`, updates submodules, and rebases
`personal` onto the new `main`. It never pushes — it prints the two push
commands and stops.

After a clean rebase, `personal` has been rewritten, so the push is a force
push. Use the `--force-with-lease` line the script prints rather than a bare
`--force`.

## What this fork changes

Two features, both inside Sleepy Mode, plus one carried upstream fix.

### 1. Exa logo mascot

A fourth mascot alongside cmux / cat / ghost, selectable in
**Settings → Sleepy Mode → Mascot**, plus a **cmux logo** scene toggle for the
chevron that normally sits under the mascot.

- `Packages/.../SleepyMode/SleepyMascot.swift` — the `exa` case and
  `wearsSharedFace`.
- `Sources/SleepyArt.swift` — `exaMascot`, the 16×16 sprite.
- `Sources/SleepyPalette.swift` — the `"E"` brand-blue palette entry.
- `Packages/.../Sections/SleepyModeSection.swift` — picker row and logo toggle.
- `cmuxTests/SleepyMascotArtTests.swift` — sprite and palette invariants.

The sprite was rasterized from the official asset (crop to the mark's bounding
box, downsample to 16×16, threshold) rather than drawn by eye. Regenerate it the
same way if the mark ever changes.

Two things worth knowing before editing it:

- **The mark keeps Exa blue (#1F40ED) in every theme**, `mono` and `custom`
  included. `"E"` is the one palette entry themes do not move — a brand mark in
  someone else's colors is no longer the mark.
- **It opts out of the shared face.** The grid mascots get blinking eyes, blush
  and a mouth painted on top at fixed anchors chosen for a round head; on line
  art those land on the strokes and read as noise. `wearsSharedFace` gates both
  the face and the stacked cmux chevron.

### 2. Touch ID / password gate on leaving Sleepy Mode

Opt-in **Settings → Sleepy Mode → Require Touch ID to exit**. With it on, every
way out of the scene — any key, any click, the Exit button, the menu bar item —
routes through `SleepyModeController.requestExit()`, which demands device-owner
authentication (Touch ID, falling back to the account password) first.

- `Sources/SleepyUnlockOutcome.swift`, `SleepyUnlockAuthenticating.swift`,
  `SleepyUnlockAuthenticator.swift`, `SleepyUnlockDecision.swift`,
  `SleepyLockUIState.swift` — the gate.
- `Sources/SleepyModeController.swift` — `requestExit()`, and `toggle()` routed
  through it.
- `Sources/SleepyFaceView.swift` — lock badge and hint text.
- `cmuxTests/SleepyUnlockGateTests.swift` — outcome mapping and the fail-open rule.

**It is a deterrent, not a lock.** cmux is an ordinary app: Force Quit still
closes it and reaches the desktop. Upstream removed an earlier Touch ID gate in
`7e0d922c2d` precisely because it was *framed* as security. This one keeps the
mechanism and drops the claim — the settings copy and the code comments say
plainly what it does and does not stop. For real security the scene's
**Lock Mac** button still engages the actual macOS login lock.

#### Why the gate is cancellable

The first version latched. `isPrompting` gates "one prompt at a time", and the
prompt is dismissed by the macOS login lock without `evaluatePolicy` resolving —
so the flag stayed set, and every subsequent key, click and Exit press was
swallowed. Permanent lockout, stuck on "Waiting for Touch ID".

Three things keep that from recurring, and none should be removed casually:

- `SleepyUnlockAuthenticator` retains its `LAContext` so `cancel()` can
  `invalidate()` it, which forces the pending `evaluatePolicy` to throw. The
  `await` always resumes.
- The scene's Exit button becomes **Cancel** while prompting and dismisses the
  prompt, so the UI can always break out of a panel the user cannot see.
- A `com.apple.screenIsLocked` observer clears the prompt state, covering every
  lock route (the Lock Mac button, hot corner, Ctrl-Cmd-Q, the lid).

An unlock attempt also carries a generation number, so a cancelled attempt
resuming late cannot clobber the state of the attempt that replaced it.

The overlay additionally drops from `.screenSaver` to `.normal` while a prompt is
up. The LocalAuthentication panel is presented far below `.screenSaver`, so a
full-screen overlay at that level hides it completely — the prompt is up and
waiting, but invisible, and the scene just looks frozen.

`lockMac()` stands the gate down before engaging the real login lock: that lock is
strictly stronger, and leaving a gated overlay behind it means unlocking the Mac
drops you straight back into a Touch ID prompt for the screensaver.

#### Escape hatch

`deactivate()` is deliberately left ungated, and the debug socket calls it
directly. If the authentication prompt ever fails to appear, this gets you out
without a reboot:

```bash
printf 'sleepy_mode off\n' | nc -U /tmp/cmux-debug-<tag>.sock
```

**Debug builds only.** Two caveats, both learned the hard way:

- `sleepy_mode` sits inside `#if DEBUG` in `TerminalController`, so the command
  does not exist in a Release build. There, the only external way out is Force
  Quit.
- It goes at the socket directly. `scripts/cmux-debug-cli.sh sleepy_mode off`
  does *not* work: the command is handled by the app's socket dispatcher but was
  never added to the CLI, which rejects unknown commands client-side before they
  reach the socket.

The three in-app guards below *do* work in Release; the socket was only the
external backstop. Think twice before arming the gate on a Release build.

`SleepyUnlockDecision` also fails *open* when macOS reports that no prompt can be
shown at all (`.passcodeNotSet`, `.notInteractive`, `.invalidContext`) — a gate
that can strand you behind a full-screen overlay is worse than one that yields
when it cannot ask.

### Carried upstream fix

`Sources/App/AgentHibernationController.swift` declared

```swift
let processLiveness: RestorableAgentProcessLiveness = .unknown
```

A `let` with an initial value is omitted from Swift's synthesized memberwise
initializer, so the type's only construction site -- which passes
`processLiveness:` -- could not compile. Changing it to a `var` with the same
default puts it back in the initializer as a *defaulted* parameter: the call site's
computed value is used again (restoring the intent of #10658, which the `let`
silently pinned to `.unknown`), while the hibernation tests that omit the
argument still compile.

Do not "tidy" this back to `let`. A bare `let` breaks the call site; a `let` with
a default breaks it differently. The `var` is load-bearing.

Not part of either feature. Drop this commit once upstream lands its own fix; if
`fork-sync.sh` reports a conflict there, take upstream's side.

### Known: `cmuxTests` does not compile on Xcode 26.6

Unrelated to this fork, and not worked around here. Upstream's test target hits a
systemic swift-testing problem on Xcode 26.6 -- `#expect` / `#require` macro
expansions rejected with "call can throw, but it is not marked with 'try'" --
across several test files (`FileDropOverlayViewTests`,
`KeyboardShortcutContextSwiftTests`, and probably more). Swift aborts sibling
compile batches, so each clean build surfaces exactly one more file; there is no
cheap way to see the full list. Upstream CI selects its own Xcode 26.x and does
not appear to hit it.

Consequence: `cmuxTests/SleepyMascotArtTests` and `cmuxTests/SleepyUnlockGateTests`
are wired correctly but cannot be run locally on this toolchain. The
`CmuxSettingsUI` package tests do run (`swift test`), and cover the settings model.

Hoisting the macro argument into a local (`let e = f(); try #require(e)`) fixes
each site, if it ever becomes worth chasing.

### Release builds

`Resources/cmux.entitlements` (the plain Release config) uses
`$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`, so it signs cleanly with any
team -- no edits needed to build Release on a fork. The hardcoded `7WLXT3NR37`
lives only in `cmux.release.entitlements` / `cmux.nightly.entitlements`, which are
the upstream release lanes and are not reachable from a fork.

Two things that only surface in Release, both of which cost time here:

- `cmuxDebugLog` is `#if DEBUG`. Calling it from shipping code compiles fine
  locally and fails only in a Release build. Use `os.Logger` instead -- see
  `SleepyModeController.log`.
- Release sets `ONLY_ACTIVE_ARCH = NO`, so it also compiles x86_64. A Debug build
  never exercises that.

A Debug-only green build proves less than it looks. Build Release before
believing a change is done.

## Conflict-prone files on rebase

Kept deliberately small; these are the ones upstream is most likely to touch too.

| File | Fork change |
| --- | --- |
| `cmux.xcodeproj/project.pbxproj` | 7 file entries. Fork-minted UUIDs all start `F02C0DE0…`, so they cannot collide with upstream's. After resolving, run `python3 scripts/normalize-pbxproj.py`. |
| `Resources/Localizable.xcstrings` | 3 new keys plus corrected values on 3 upstream keys. Insert new keys as **text** at the right sorted position — a `json.load` / `json.dump` round-trip reorders all ~5,500 keys and produces an unmergeable diff. |
| `Sources/SleepyArt.swift` | One `switch` case and the sprite. |
| `Sources/SleepyModeController.swift` | `requestExit()` and the two call sites. |
| `Sources/SleepyFaceView.swift` | Lock badge, hint text, `requestExit()` calls. |

The fork reuses upstream's own removed identifiers where they still exist —
`requireAuth`, the `sleepyMode.requireAuth` defaults key, and the orphaned
`sleepyMode.requireAuth.*` / `sleepyMode.unlockReason` / `sleepyMode.dismissHint`
string-catalog entries — so if upstream ever reinstates a gate, the two line up
instead of colliding.
