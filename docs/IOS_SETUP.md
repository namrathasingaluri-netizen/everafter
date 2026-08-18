# Set up EverAfter on iPhone

This guide starts with the public demo, installs a private build on an iPhone,
and explains how to replace the demo content with your own trips. EverAfter is
local-first: it has no account, backend, media upload, or automatic sync.

If you want Codex to help inspect, edit, validate, and install the local
checkout, follow [`CODEX_SETUP.md`](CODEX_SETUP.md) alongside this guide.

## 1. Choose the iPhone NFC mode

EverAfter supports two iPhone workflows:

| Apple account | Magnet workflow | Build path |
| --- | --- | --- |
| Free Personal Team | An iOS Shortcut recognizes the physical NFC tag and opens `everafter:///nfc/<trip-slug>` | `tool/install_ios_shortcuts.sh` |
| Paid Apple Developer Program | EverAfter starts a foreground Core NFC session when the user taps **Scan Magnet** | Normal Flutter/Xcode build |

Core NFC is foreground and user-initiated. It is not an always-on reader. A
free Personal Team cannot provision Apple's NFC Tag Reading entitlement, so use
the Shortcuts build instead of trying to force the capability into that profile.
See Apple's [supported iOS capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios)
and [Core NFC documentation](https://developer.apple.com/documentation/corenfc)
for the current platform requirements.

The app targets iOS 13 or later. NFC requires a physical, NFC-capable iPhone;
the simulator is useful for UI and deep-link testing only.

## 2. Prepare the Mac

Install:

- the latest stable [Flutter SDK and iOS toolchain](https://docs.flutter.dev/platform-integration/ios/setup);
- Xcode from the Mac App Store;
- an Apple ID added under **Xcode → Settings → Accounts**;
- Git.

Then verify the toolchain:

```sh
flutter doctor -v
xcodebuild -version
flutter devices
```

Resolve every iOS/Xcode item reported by `flutter doctor` before continuing.

## 3. Clone and run the public demo

```sh
git clone https://github.com/thecodedose/everafter.git
cd everafter
flutter pub get
open ios/Runner.xcworkspace
```

In Xcode:

1. Select the **Runner** target.
2. Open **Signing & Capabilities**.
3. Select your Apple development team.
4. Replace `com.example.everafter` with a bundle identifier you control, such
   as `com.yourname.everafter`.

Do not commit a personal Team ID or private bundle configuration to a public
fork.

For a simulator or configured iPhone, copy the device identifier from
`flutter devices`, then run:

```sh
flutter run -d <device-id>
```

If a Personal Team build fails because of the NFC entitlement, use the
Shortcuts installation path below.

## 4. Install with a free Personal Team

Connect and trust the iPhone, keep it unlocked, and list paired devices:

```sh
xcrun devicectl list devices
```

Copy the iPhone identifier and run:

```sh
./tool/install_ios_shortcuts.sh <iphone-device-id> japan
```

The script:

1. configures EverAfter with native NFC disabled;
2. builds with the empty `RunnerShortcuts.entitlements` file;
3. verifies that the resulting app has no NFC entitlement;
4. optimizes the generated app bundle without changing source media;
5. installs it and opens `everafter:///nfc/japan` as a deep-link check.

The first launch may require **Settings → General → VPN & Device Management**
to trust the development certificate. Personal Team provisioning is temporary;
reinstall the app when its profile expires.

### Connect a physical magnet with Shortcuts

On the iPhone:

1. Open **Shortcuts → Automation → + → NFC**.
2. Scan the NFC tag inside the magnet and give it a recognizable name.
3. Add an **Open URLs** action.
4. Enter `everafter:///nfc/japan`, replacing `japan` with the destination slug.
5. Choose **Run Immediately**, or disable **Ask Before Running** when that is
   the wording offered by the installed iOS version.
6. Scan the physical magnet and confirm that EverAfter opens the intended trip.

Repeat the automation for each magnet. This mapping lives in Shortcuts on that
iPhone; it does not need a real NFC UID in the repository.
Apple's [Shortcuts automation guide](https://support.apple.com/guide/shortcuts/welcome/ios)
documents the current iOS interface if the labels differ on a newer release.

## 5. Install with paid-team Core NFC

The repository already contains:

- `NFCReaderUsageDescription` in `ios/Runner/Info.plist`;
- the `TAG` reader-session entitlement in `ios/Runner/Runner.entitlements`;
- the native Core NFC reader in `ios/Runner/AppDelegate.swift`.

In Xcode, confirm that the selected paid team and App ID support **Near Field
Communication Tag Reading**. Then run:

```sh
flutter run -d <iphone-device-id> \
  --dart-define=EVERAFTER_NATIVE_NFC=true
```

In EverAfter, tap **Scan Magnet** and hold the top of the iPhone near one tag.
The app normalizes identifiers as uppercase, colon-separated bytes and looks
them up in `lib/data/trip_repository.dart`.

To bind a real tag for this mode:

1. read its identifier using a trusted local NFC utility, or temporarily log
   the value returned by `IosNfcService.startScan` in a private debug build;
2. replace the matching demo `uid` in `lib/data/trip_repository.dart`;
3. keep the other bindings unchanged;
4. rebuild and physically scan the tag to verify the full route.

Physical NFC identifiers are private device data. Keep them in a private fork
or ignored local overlay rather than publishing them.

## 6. Add private photos and videos

The public repository deliberately uses placeholder media. It does not scan a
folder dynamically, and the TSV manifests are not loaded automatically at
runtime. A private build must both bundle and register each asset.

### Add the files

Use the ignored media tree:

```text
assets/memories/
  japan/
    tokyo/
      photo-001.jpg
      reel-001.mp4
      reel-001-poster.jpg
```

For a private branch or uncommitted local build, add the directory to the
`flutter.assets` list in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/memories/
```

A public clone does not contain that directory, so do not commit this manifest
change to the public branch unless the referenced media is also public and
redistributable.

### Register a location collection

Collections live in `lib/data/*_memory_collection.dart`. A location lists its
assets in display order and maps each video to a poster:

```dart
final tokyo = JapanMemoryLocation(
  slug: 'tokyo',
  label: 'Tokyo',
  assetPaths: <String>[
    'assets/memories/japan/tokyo/photo-001.jpg',
    'assets/memories/japan/tokyo/reel-001.mp4',
  ],
  videoPosterPaths: <String, String>{
    'assets/memories/japan/tokyo/reel-001.mp4':
        'assets/memories/japan/tokyo/reel-001-poster.jpg',
  },
);
```

Replace the corresponding demo location in:

- `lib/data/japan_memory_collection.dart`;
- `lib/data/china_memory_collection.dart`;
- `lib/data/south_korea_memory_collection.dart`;
- `lib/data/hong_kong_memory_collection.dart`;
- `lib/data/taiwan_memory_collection.dart`;
- `lib/data/bali_memory_collection.dart`;
- `lib/data/sri_lanka_memory_collection.dart`.

`lib/data/gallery_memory_content.dart` connects those collections to gallery
frames and the admin photo chooser. To support another destination, create its
collection and add its slug to `galleryMemoryLocationsFor` there.

After changing media, rebuild the app. Hot reload is not enough to add a new
asset to an already-built iPhone bundle.

## 7. Curate the trip and global gallery

Trip curation has three layers:

| Content | Source |
| --- | --- |
| Trip name, coordinates, card, and destination order | `lib/widgets/trip_gallery.dart` |
| Artifact copy and paid-team NFC UID binding | `lib/data/trip_repository.dart` |
| Frames, trinkets, dates, crops, and wall geometry | `assets/data/gallery_layouts.json` |

### Edit the global layout on the Mac

Run the browser admin from the repository root:

```sh
flutter run -d web-server \
  --web-hostname 127.0.0.1 \
  --web-port 8080
```

Open <http://127.0.0.1:8080/admin/gallery> in a Chromium browser. The editor
automatically loads the bundled global JSON. It can edit:

- trip travel dates;
- frame position, size, style, visibility, title, crop, zoom, and photo choice;
- bundled trinket placement;
- Instagram placeholder and food-menu placement;
- gallery width and visible bounds.

On the first **Save global**, choose
`assets/data/gallery_layouts.json` and confirm replacement. Rebuild and reinstall
the iOS app to bundle that global layout. There is no realtime or background
sync to an already-installed iPhone.

The browser editor does not upload media. Add photos, videos, posters, and
trinkets to source folders first, register them, and restart the browser build
before selecting them in the layout.

### Make an override only on one iPhone

Open `everafter:///admin/gallery` on the iPhone using an **Open URLs** Shortcut
or a development deep-link launch. Native admin displays **THIS DEVICE ONLY**.
Its **Save this device** action stores a patch in local application preferences;
it does not modify `gallery_layouts.json` or another device.

**Reset** removes the selected trip's device-specific changes and reveals the
bundled global layout. Deleting EverAfter or clearing its application data also
removes device overrides.

## 8. Verify a curated build

Before installing:

```sh
dart format .
flutter analyze
flutter test
flutter build ios --release --no-codesign
```

On the physical iPhone, verify separately:

1. every bundled photo and video opens;
2. every trip date and frame layout is correct;
3. `everafter:///nfc/<trip-slug>` opens the expected trip;
4. each physical magnet triggers the correct trip through either Shortcuts or
   the foreground Core NFC scanner;
5. the app still works after disconnecting the network.

## Troubleshooting

### Provisioning profile does not support NFC

Use `tool/install_ios_shortcuts.sh` for a free Personal Team. Do not add the NFC
entitlement to a profile that Apple does not allow to carry it.

### Xcode cannot sign Runner

Confirm the team, use a unique bundle identifier, keep the phone unlocked, and
open Xcode once to accept any developer-mode or trust prompts.

### An asset is missing

Check exact filename case, its `pubspec.yaml` asset directory, and the matching
collection entry. Then run:

```sh
flutter clean
flutter pub get
```

Rebuild and reinstall; assets cannot be added to an existing bundle by hot
reload.

### The wrong trip opens

Shortcuts mode routes by the URL configured in the NFC automation. Paid-team
mode routes by the normalized UID in `lib/data/trip_repository.dart`. Test the
physical tag; opening a URL manually proves only the deep link, not the NFC
automation.

## Privacy checklist

Before pushing a public branch:

```sh
git add -n .
git status --short --ignored
```

Confirm that the candidate commit contains no private media, exact dates,
physical NFC identifiers, Apple Team ID, signing certificates, provisioning
profiles, absolute home paths, or restricted audio/font assets. See
[`PRIVATE_MEDIA.md`](PRIVATE_MEDIA.md) for the repository boundary.
