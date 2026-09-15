# Security Policy

## Supported versions

Gringotts is pre-1.0 and ships as a milestone APK. Security fixes land on `main`; there are no
maintained release branches yet.

| Version | Supported |
|---|---|
| `main` (latest milestone build) | ✅ |
| older APK builds | ❌ |

## Reporting a vulnerability

Please do **not** open a public issue for anything security related. Report it privately through
GitHub's [private vulnerability reporting](../../security/advisories/new) on this repository, or by
email to the address on the maintainer's GitHub profile.

Include, as far as you can:

- what the issue is and which build it affects — the APK filename and, if you have it, its md5
  (for example `gringotts-T21-release.apk`, md5 `8cd0d04b0aaad7f4df7b9bab00c21d87`),
- the steps to reproduce,
- what an attacker gains — data read, data written, bypassed confirmation, crash with data loss.

You can expect an acknowledgement within a few days and an honest assessment of whether it is in
scope. Please give a fix a reasonable window before public disclosure.

## What this project cares about most

1. **Local data integrity.** The ledger is the user's own record. Silent data loss, mangled
   amounts, or a delete that does not behave as a tombstone are treated as the highest severity
   class, ahead of anything else here.
2. **Key handling.** The M2 AI layer is bring-your-own-key. A key must only ever live in
   `flutter_secure_storage`, and must never appear in source, logs, crash output, an export file or
   the repository. Logging a key, even at debug level, is a vulnerability.
3. **Data egress.** The design intent is that the model layer receives aggregated statistics only.
   Any path that could send raw transactions off-device without explicit, informed consent is a
   vulnerability, not a feature request.
4. **Export and import.** Exported CSV/JSON files are plain text by design; anything that makes them
   leak more than the user asked for (for example writing to a shared location silently) counts.

## Out of scope

- The Windows desktop build is a development and preview target, not a supported product surface.
- Attacks that require a rooted device, a modified APK, or physical access to an unlocked phone.
- Denial of service through pathological local data volumes.
- Findings that only apply to third-party dependencies without a plausible impact on this app
  (please report those upstream, and feel free to mention them here if Gringotts is affected).

## Repository hygiene

No secrets belong in this repository. If you find a credential in the working tree or in history,
report it privately rather than opening an issue, and do not attempt to exploit it.
