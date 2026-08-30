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

Two features, both inside Sleepy Mode.

### 1. Bunny mascot

A fourth grid mascot alongside cmux / cat / ghost, selectable in
**Settings → Sleepy Mode → Mascot**. Tall ears with a blush-colored inner
lining, drawn in whatever theme palette is active.

- `Packages/.../SleepyMode/SleepyMascot.swift` — the `bunny` case.
- `Sources/SleepyArt.swift` — `bunnyMascot`, the 16×16 sprite.
- `Packages/.../Sections/SleepyModeSection.swift` — the picker row.
- `cmuxTests/SleepyMascotArtTests.swift` — sprite invariants.

The grid mascots share one set of face anchors (`openEyes` / `closedEyes` /
`mouthTop` / `mouthOpen`), drawn on top of the sprite. A new mascot's head has
to cover those anchors or the eyes and mouth float in empty space — that is what
`SleepyMascotArtTests` pins down.

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

#### Escape hatch

`deactivate()` is deliberately left ungated, and the debug socket calls it
directly. If the authentication prompt ever fails to appear, this gets you out
without a reboot:

```bash
CMUX_TAG=<tag> scripts/cmux-debug-cli.sh sleepy_mode off
```

`SleepyUnlockDecision` also fails *open* when macOS reports that no prompt can be
shown at all (`.passcodeNotSet`, `.notInteractive`, `.invalidContext`) — a gate
that can strand you behind a full-screen overlay is worse than one that yields
when it cannot ask.

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
