# Contributing to USB Bench

Thank you for helping improve USB Bench. Contributions should preserve the
project's non-destructive storage-safety model and remain suitable for a public
open-source repository.

## Before opening a pull request

1. Open or reference an issue for behavior changes that affect benchmark
   semantics, persisted data, packaging, or the user interface.
2. Keep each pull request focused on one logical change.
3. Add or update tests for behavior changes.
4. Keep source code, comments, commit messages, and repository documentation in
   English. User-facing Italian strings may be added alongside their English
   source strings.
5. Do not commit build output, DMGs, credentials, signing certificates,
   notarization keys, device logs containing private data, or local databases.

## Required checks

Run these commands from the repository root:

```sh
./scripts/check_all.sh
```

This command checks formatting, metadata, shell syntax, brand assets, tests,
packaging, and the generated DMG. Local DMGs use an ad-hoc signature. Do not
create a public release from an ad-hoc-signed artifact.

## Storage-safety invariants

Changes to the benchmark engine must preserve all of the following:

1. No formatting, unmounting, or raw-disk writes.
2. No opening or enumeration of the user's existing files.
3. Writes are limited to one `.usbbench-<UUID>.tmp` file.
4. Cleanup is limited to the exact temporary URL created by the current run.
5. Free space is checked before the benchmark and immediately before I/O.
6. The benchmark stops if `F_NOCACHE` cannot be enabled.
7. Automated tests use isolated temporary directories.

## Compatibility

Persisted benchmark payloads are JSON values stored in SQLite. New persisted
fields must be optional or decode safely when reading results created by older
versions. Changes to measurement semantics must increment
`BenchmarkEngine.measurementProtocolVersion`.

## Licensing

By submitting a contribution, you agree that it may be distributed under the
project's [MIT License](LICENSE).
