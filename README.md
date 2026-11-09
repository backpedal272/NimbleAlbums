# Nimble Albums

**Export full-quality albums from Photos and iCloud into plain folders on your Mac, drive or NAS.**

Pick the albums, pick a folder, click Export. Nimble Albums copies the original files, not previews, with one folder per album and file names that sort by date.

> Free and open source (GPL-3.0). Part of [Nimble Apps](https://nimbleapps.ch).

## Features

- **Original quality.** Exports the original file exactly as it came off the camera. If you edited a photo, the edited version is saved next to it.
- **Fetches from iCloud.** With "Optimize Mac Storage" on, photos that live only in iCloud are downloaded at full resolution.
- **Sensible folders.** One folder per album, with your Photos folders mirrored on disk. Files are named like `2024-06-15_IMG_1234.heic`, and Finder dates match when the photo was taken.
- **Clear before you start.** Albums, smart albums and shared albums in one list. Before exporting you see the item count, the estimated size and the free space.
- **Built for large exports.** Pause, resume or cancel. Failed items are retried, the Mac stays awake until the job is done, and no half-written files are left behind.
- **Safe to run again.** When exporting to the same folder twice, choose once to skip, replace or keep both.
- **Private.** No account, no tracking, no network service of its own. The Photos library is only read, never changed.

## Requirements

- macOS 15 Sequoia or later
- Access to your Photos library (macOS asks on first launch)

## Install

Nimble Albums is in beta. [Join the beta on TestFlight](https://testflight.apple.com/join/Xtn7Qdry). It's free. More on [nimbleapps.ch](https://nimbleapps.ch/nimblealbums/index.html).

## Build from source

You need Xcode.

```sh
git clone https://github.com/backpedal272/NimbleAlbums.git
cd NimbleAlbums
open NimbleAlbums.xcodeproj
```

Then choose **Product › Run**. To run it signed on your own Mac, pick your team under **Signing & Capabilities**.

## Project layout

| Path | Contents |
|---|---|
| `NimbleAlbums/` | SwiftUI app: models, services (Photos access, export planning, file naming) and views |
| `docs/SPEC.md` | Product and behavior specification |
| `scripts/` | App icon generator |

## Contributing

Bug reports and suggestions are welcome in [Issues](https://github.com/backpedal272/NimbleAlbums/issues). Contact: info@nimbleapps.ch.

## License

GPL-3.0. See [LICENSE](LICENSE).

Photos and iCloud are trademarks of Apple Inc. This project is not affiliated with or endorsed by Apple.
