# Nimble Albums — Specification

**Version:** 1.0 (draft) · **Date:** 2026-08-03
**Platform:** macOS 15+ (Sequoia), Swift / SwiftUI, Xcode, Mac App Store
**Price:** Free

## 1. Product summary

Nimble Albums is a small, focused Mac utility that exports the **original, full-quality photos and videos** from albums the user selects in their Photos (iCloud Photo Library) library to a folder on disk. Assets that are only in iCloud (e.g. because "Optimize Mac Storage" is on) are downloaded on demand at full quality.

It is a **one-shot exporter**: the user picks albums, picks a destination, and runs an export. The app keeps no database of past exports; re-running an export into the same destination is handled through conflict resolution (§6.5).

### Non-goals (v1)

- No continuous sync or mirroring of albums.
- No editing, tagging, or library management.
- No companion resources: Live Photo video components, RAW+JPEG second files, and non-representative burst frames are not exported (§6.3).
- No XMP sidecars or metadata written beyond what is embedded in the files (§6.7).
- No localization beyond English (strings structured for future localization).
- No iOS version.

## 2. Target user

Anyone who wants their photos back out of iCloud as plain files: for backup, migration to another service, archiving to a NAS/external drive, or handing a folder of originals to someone else. No technical knowledge assumed.

## 3. UI

### 3.1 Single-window layout

One main window (no wizard), Mac-like:

- **Sidebar (left):** the album tree with checkboxes (§4). A search field filters albums by name.
- **Detail area (right):**
  - **Destination picker** — path field + "Choose…" button (NSOpenPanel, folders only). The last destination is remembered via a security-scoped bookmark.
  - **Options** — conflict policy default, "prevent sleep during export" toggle (default on).
  - **Pre-flight summary** — selected album count, total item count, estimated size, free space at destination (§6.1).
  - **Export button** — primary action; disabled until ≥1 album and a destination are chosen.
- **Progress area (inline, replaces/overlays the options during export):** overall progress bar (items + bytes), current file name, per-album breakdown, counts of done / failed / skipped, and **Pause / Resume / Cancel** buttons (§7).
- **Summary sheet** at the end (§7.4).

### 3.2 App structure

- Standard menu bar (About, Settings if needed, Close). No menu-bar-extra agent, no Dock-less mode.
- Single instance, single export at a time.

## 4. Album selection

The sidebar shows the Photos library structure:

| Group | Contents | Notes |
|---|---|---|
| **Albums** | User-created albums, nested inside their folders | Folder hierarchy shown as a disclosure tree. Checking a folder checks all albums inside it (tri-state checkbox for partial selection). |
| **Smart Albums** | System smart albums: Favorites, Videos, Screenshots, Selfies, Panoramas, etc. | Flat list. Hidden and Recently Deleted are **excluded**. |
| **Shared Albums** | iCloud Shared Albums | Flat list, with a footnote/tooltip: shared albums may only contain reduced-quality copies — the app exports the best quality iCloud has for them, which may not be the true original. |

Each row shows the album name and its item count. Empty albums are shown but export nothing.

## 5. On-disk output

### 5.1 Folder layout

One folder per album inside the chosen destination. Folder hierarchy from Photos is mirrored for albums inside folders:

```
Destination/
  Vacations/               ← Photos folder
    Italy 2024/            ← album
      2024-06-15_IMG_1234.heic
      2024-06-15_IMG_1234_edited.jpg
      2024-06-16_IMG_1250.mov
  Favorites/               ← smart album
    ...
```

An asset appearing in several selected albums is written **once per album** (plain copies, no hardlinks).

Folder/file names are sanitized: `/` and `:` replaced with `-`, leading dots stripped, names trimmed to a safe length. Two sibling albums that sanitize to the same name get a ` (2)` suffix.

### 5.2 File naming

`<capture date>_<original filename>`:

- `2024-06-15_IMG_1234.heic` — capture date in `yyyy-MM-dd` (local time zone of the Mac).
- Assets with no capture date use the file's earliest known date, else `unknown-date`.
- The **edited version**, when exported (§6.4), gets an `_edited` suffix before its extension: `2024-06-15_IMG_1234_edited.jpg`. Extension follows the actual rendered format (usually JPEG/HEIC for photos, MOV for videos).
- Two different assets in the same album that resolve to the same filename get ` (2)`, ` (3)`… suffixes (this is *not* a conflict in the §6.5 sense — it's disambiguation within one run).

## 6. Export behavior

### 6.1 Pre-flight

When albums/destination change, the app computes and shows:

- Number of selected albums and total items (deduplicated count also shown: "1,240 items (1,180 unique)").
- **Estimated total size**, summed from asset resource file sizes where available. Items whose size is unknown (some cloud-only items) are counted and the estimate is labeled "≈ at least X GB".
- Free space at the destination volume; a warning banner if estimated size > free space (export is still allowed — estimate may be off, user may free space).

### 6.2 What gets exported

For each asset in each selected album:

1. **The untouched original** — the primary photo or video resource as originally imported (before any Photos edits). For a RAW+JPEG asset, the primary resource only (whichever Photos treats as primary).
2. **The edited version, if the asset has edits** — the full-size rendered current version, saved alongside with the `_edited` suffix. Assets without edits produce only file 1.

### 6.3 Asset-type handling (v1 simplifications)

- **Live Photos:** still image only; the paired `.mov` is not exported.
- **RAW+JPEG:** primary resource only.
- **Bursts:** representative (picked) frame only.
- **Videos, slo-mo, time-lapse:** original video file (slo-mo is exported as the original footage; the Photos-rendered slow-motion effect exists only in the edited version, which is exported if present).

These are explicitly listed as candidates for a v2 "companion files" option.

### 6.4 Detecting edits

An asset is considered edited when a full-size rendered resource exists (`fullSizePhoto` / `fullSizeVideo` in its resource list). Only then is the `_edited` file produced.

### 6.5 Conflict handling (existing files in destination)

Before writing a file that already exists at the target path, the app resolves a conflict. Default policy is **Ask**: on the first conflict, a dialog offers:

- **Skip** — keep the existing file. (Dialog notes: "existing file with the same name and size" vs "different size".)
- **Overwrite** — replace it.
- **Keep both** — write `name (2).ext`.
- ☑ **Apply to all remaining conflicts** (checked by default).

The chosen apply-to-all policy holds for the rest of the run. The options panel lets the user pre-select a policy (Ask / Skip / Overwrite / Keep both) to avoid the dialog entirely. Skipped files are counted separately in progress and summary. Downloads are written to a temporary file and renamed into place only on success, so an interrupted export never leaves truncated media files.

### 6.6 iCloud download

- Network access is always allowed for resource requests; cloud-only items are downloaded at full quality.
- Per-file download progress feeds the overall progress bar.
- If iCloud is unreachable (offline, not signed in), affected items fail with a clear reason and go to the retry list; the app does not abort the whole run.

### 6.7 Metadata & file attributes

- Exported files keep whatever metadata is embedded in them (EXIF, GPS, etc.). Nothing is stripped, nothing is added.
- After writing, the file's **creation and modification dates are set to the asset's capture date**, so Finder sorting matches reality.
- No sidecar files, no `.plist`/manifest left in the destination.

## 7. Long-running export: controls & resilience

### 7.1 Controls

- **Pause / Resume:** pause finishes (or aborts and requeues) in-flight items and stops dequeuing; resume continues. Pause state survives only within the session (no cross-launch resume — re-running with "Skip" conflicts is the recovery path).
- **Cancel:** stops the run after confirming; already-completed files remain on disk; partial temp files are cleaned up.

### 7.2 Retry & failure

- Each item is automatically retried up to **3 times with exponential backoff** (e.g. 2 s / 8 s / 30 s) on transient errors (network, iCloud timeouts).
- Permanent errors (asset deleted mid-run, destination full, permission lost) fail immediately with a specific reason.
- Destination-full pauses the run with an alert rather than failing every remaining item.

### 7.3 System interaction

- While exporting, the app takes a power assertion preventing **system sleep** (display may still sleep). Toggleable in options; default on. Released on pause/cancel/finish.
- App Nap is disabled during export.
- Closing the window during an export prompts: "An export is running — cancel it and quit?"

### 7.4 End summary

A sheet shows: exported count, skipped count, failed count, total bytes, elapsed time, and a scrollable list of failures (file, album, reason) with:

- **Retry Failed** — re-runs just the failed items with the same settings.
- **Reveal in Finder** — opens the destination.
- **Copy report** — copies a plain-text failure list to the clipboard.

## 8. Permissions & first-run

1. On first launch, a short explainer screen, then the system **Photos access** prompt. The app requests read/write-level library access (PhotoKit requires this level even for reading; the app never writes to the library).
2. **Limited library access** (user granted only selected photos): supported — the app shows only what it can see and displays a banner "You've granted access to only part of your library" with a button to open the system setting.
3. **Denied access:** a full-window empty state explaining how to enable access in System Settings › Privacy & Security › Photos, with a direct link.
4. Destination access comes from the user's folder choice (security-scoped bookmark, persisted so the last destination works across launches).

## 9. Technical architecture

### 9.1 Frameworks & entitlements

- **UI:** SwiftUI with the Observation framework (`@Observable`), macOS 15 SDK.
- **Photos:** PhotoKit (`Photos` framework). No private APIs, with one noted gray area: resource file size (§9.4).
- **Sandbox entitlements:**
  - `com.apple.security.app-sandbox`
  - `com.apple.security.personal-information.photos-library` + `NSPhotoLibraryUsageDescription`
  - `com.apple.security.files.user-selected.read-write`
  - `com.apple.security.files.bookmarks.app-scope` (persist destination)
  - `com.apple.security.network.client` (iCloud downloads)

### 9.2 Module breakdown

| Module | Responsibility |
|---|---|
| `PhotoLibraryService` | Authorization; fetching the album tree (`PHCollectionList` for folders, `PHAssetCollection` for user albums `.albumRegular`, smart albums `.smartAlbum` subtypes, shared `.albumCloudShared`); fetching `PHAsset`s per album; change observation to refresh counts. |
| `ExportPlanner` | Expands the selection into an ordered list of `ExportItem`s (asset × album × variant original/edited), resolves target paths, computes the pre-flight estimate. |
| `ExportEngine` | Async task-group pipeline executing the plan: download → temp file → conflict check → rename → set file dates. Owns pause/resume/cancel state machine and retry logic. |
| `ConflictCenter` | Applies the conflict policy; surfaces the Ask dialog via a continuation when policy is Ask. |
| `PowerAssertion` | `ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .userInitiated], …)` wrapper. |
| UI layer | `AlbumSidebarView`, `ExportSetupView`, `ExportProgressView`, `SummarySheet`, backed by an `@Observable` `AppModel` / `ExportSession`. |

### 9.3 Export pipeline details

- **Resource selection:** from `PHAssetResource.assetResources(for:)`:
  - Original = first resource of type `.photo` (or `.video` for videos).
  - Edited = resource of type `.fullSizePhoto` / `.fullSizeVideo` when present.
- **Download:** `PHAssetResourceManager.requestData` / `writeData(for:toFile:options:)` with `PHAssetResourceRequestOptions.isNetworkAccessAllowed = true` and a `progressHandler` for per-file progress. Writing goes to a temp file in the destination volume (same volume → atomic rename).
- **Concurrency:** a `TaskGroup` with bounded parallelism, default **4 concurrent items** (tunable constant). Downloads are I/O-bound; parallelism improves throughput on cloud-only libraries without hammering `photolibraryd`.
- **Pause:** implemented as an `AsyncStream`-gated dequeue; **Cancel** via structured task cancellation.
- **File dates:** `FileManager.setAttributes([.creationDate, .modificationDate], …)` from `PHAsset.creationDate`.

### 9.4 Size estimation caveat

PhotoKit has no public API for resource file size. The de-facto approach is `resource.value(forKey: "fileSize") as? Int64`, which is widely used and has passed App Review for many shipping apps, but is technically undocumented. The spec treats size as **optional data**: the UI must degrade gracefully ("size unknown for N items"), and if the key ever stops working the only loss is the estimate. Decision: use it, guarded, behind a single helper.

### 9.5 Error taxonomy

`ExportError` cases with user-facing strings: `cloudUnavailable`, `networkTimeout` (retryable); `assetMissing`, `resourceUnavailable`, `destinationFull`, `destinationPermission`, `writeFailed` (permanent). Every failure in the summary maps to one of these plus the underlying description.

## 10. Edge cases

- **Album renamed/deleted mid-run:** items already planned keep their planned path; fetch failures become `assetMissing`.
- **Asset in library but resource truly unavailable** (e.g. shared album where the owner's original is gone): export the best available resource; if none, fail with `resourceUnavailable`.
- **Weird characters / emoji in album names:** preserved except filesystem-invalid characters (§5.1).
- **Destination on external/network volume:** supported; free-space check runs against that volume; temp files created on the same volume so renames stay atomic.
- **Very large libraries:** the sidebar loads counts lazily; planning streams rather than materializing all assets for the pre-flight count only when selection is huge (fetch counts are cheap via `PHFetchResult.count`).
- **System time zone changes mid-run:** date prefix is computed once at planning time.

## 11. v2 candidates (out of scope, recorded for later)

Live Photo `.mov` companions · RAW+JPEG both files · all burst frames · XMP sidecars (keywords, favorites, location from the Photos DB) · configurable filename pattern & date-based layout · incremental sync with a manifest · hardlink dedupe across albums · localization (French first).

## 12. Open questions

- App icon & visual identity.
- Exact wording for the shared-album quality caveat.
- Whether the pre-flight deduplicated count is worth the extra fetch pass on very large selections (measure first).
