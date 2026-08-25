---
layout: default
title: Vorssaint settings portability
---

# Vorssaint settings portability

## Question

Can the Vorssaint 3.3.2 configuration be copied safely between managed Macs,
and can bootstrap apply it without using the app's interface?

## Findings

Vorssaint has a supported plist export and import in its Advanced settings. The
export reads registered defaults as well as user-written values, so it produces
a complete portable snapshot. Import clears the app's exportable keys, applies
the validated snapshot, and relaunches the app. See the 3.3.2
[settings backup implementation](https://github.com/vorssaintapp/vorssaint-utils/blob/v3.3.2/Sources/Vorssaint/Services/SettingsBackup.swift).

The backup uses a versioned envelope and accepts only keys and value types known
to the installed build. It excludes live state, permission state, clipboard
history, machine-specific paths and device identifiers, update and cleaner run
state, and similar local data. See the 3.3.2
[backup allowlist and validation](https://github.com/vorssaintapp/vorssaint-utils/blob/v3.3.2/Sources/Vorssaint/Core/SettingsBackupSupport.swift).

Version 3.3.2 has command-line modes for self-tests, sensor output, and complete
uninstallation. It has no command-line settings export or import. See the
[application entry point](https://github.com/vorssaintapp/vorssaint-utils/blob/v3.3.2/Sources/Vorssaint/main.swift).

## Recommendation

Track only a plist created by Vorssaint's own Export Settings action. Review it
before committing because portable settings may include scratchpad text, text
snippets, saved links, per-app volume choices, and other personal preferences.
Use Vorssaint's Import Settings action on each Mac. Grant macOS permissions on
each device because the backup deliberately does not carry them.

Do not automate this with `defaults import`. That would bypass Vorssaint's
allowlist and type checks, replace the entire preferences domain, and risk
copying or deleting machine-specific state.

## Verification

Export from the source Mac, inspect the plist, and import it on a second Mac.
After Vorssaint relaunches, compare installed features, shortcuts, Keep Awake,
capture, clipboard, and Homebrew Manager settings. Confirm separately that the
second Mac requests only the permissions needed by those features.

The remaining limitation is upstream: fully unattended bootstrap requires a
supported Vorssaint command-line import mode.
