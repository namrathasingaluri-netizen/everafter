# Set up EverAfter on Android

EverAfter supports foreground NFC scanning on Android phones and can also open
a trip from an `everafter:///nfc/<trip-slug>` link stored on a writable NFC tag.
The app remains local-first: its trip media is bundled into the installation and
does not require an account or network connection after installation.

## 1. Requirements

- An Android phone with NFC hardware.
- NFC enabled in **Settings → Connected devices/Connections → NFC**. The exact
  label varies by manufacturer.
- Android 7.0 or later, matching the packaged app's current minimum SDK 24.

The Android emulator cannot reproduce a physical tag scan. Use a real phone for
the final NFC check.

## 2. Install a development build

Install the current stable Flutter SDK, Android Studio, the Android SDK, and
Git. Enable Developer options and USB debugging on the phone, connect it, and
then run:

```sh
git clone https://github.com/thecodedose/everafter.git
cd everafter
flutter pub get
flutter doctor -v
flutter devices
flutter run -d <android-device-id>
```

If the phone asks whether to allow USB debugging, confirm that the computer's
fingerprint matches before accepting it.

For nontechnical recipients, distribute a signed release through Google Play or
as a signed APK. Do not distribute the repository's debug-signed release build
as a production app. Follow Android's
[app-signing guide](https://developer.android.com/studio/publish/app-signing)
before running `flutter build appbundle --release` or
`flutter build apk --release`.

## 3. Scan a magnet in EverAfter

1. Open EverAfter.
2. Tap **Scan Magnet**.
3. Hold the NFC area on the back of the phone against one magnet. It is usually
   near the upper-middle or camera area.
4. Keep the phone still until EverAfter opens the magnet reveal.
5. Tap **Start** and confirm that the correct trip gallery plays.

EverAfter reads the tag's hardware identifier, normalizes it as uppercase
colon-separated bytes, and looks it up in
`lib/data/trip_repository.dart`. If a tag is not linked yet, the app displays
its UID. Replace the intended demo UID in the private repository, rebuild, and
scan the same physical tag again.

## 4. Optional scan-to-open tags

Android can dispatch an NDEF URI stored on a tag directly to EverAfter. This is
optional—the in-app **Scan Magnet** button does not require rewriting a tag.

For a writable tag:

1. Open a trusted NFC tag-writing app.
2. Add a **URI/URL** record as the first NDEF record.
3. Paste the matching EverAfter link from the table below.
4. Write the record and verify it before locking the tag.
5. With the phone unlocked, scan the tag and confirm that EverAfter opens the
   intended magnet reveal.

Writing an NDEF record changes the tag's stored content. Do not overwrite or
lock an irreplaceable tag until you have read and backed up its existing NDEF
records. A read-only tag can still use EverAfter's foreground UID scanner.

| Trip | Link |
| --- | --- |
| Hong Kong | `everafter:///nfc/hong-kong` |
| China | `everafter:///nfc/china` |
| South Korea | `everafter:///nfc/south-korea` |
| Japan | `everafter:///nfc/japan` |
| Taiwan | `everafter:///nfc/taiwan` |
| Bali | `everafter:///nfc/bali` |
| Thailand | `everafter:///nfc/thailand` |
| Philippines | `everafter:///nfc/philippines` |
| Vietnam | `everafter:///nfc/vietnam` |
| Sri Lanka | `everafter:///nfc/sri-lanka` |

Android recommends NDEF records for portable tag content and dispatches a
recognized URI to an interested app. See Android's
[NFC basics](https://developer.android.com/develop/connectivity/nfc/nfc) and
[deep-link guide](https://developer.android.com/training/app-links/create-deeplinks).

## 5. Verify a trip link without NFC

With the app installed and `adb` connected, run:

```sh
adb shell am start -W \
  -a android.intent.action.VIEW \
  -c android.intent.category.BROWSABLE \
  -d 'everafter:///nfc/south-korea' \
  com.example.everafter
```

This should open the South Korea magnet reveal. It verifies Android deep-link
routing only; complete the physical scan in section 3 or 4 to verify NFC.

## 6. Troubleshooting

### NFC is unavailable

Confirm that the phone actually contains NFC hardware and that NFC is enabled.
Some manufacturers place the toggle under **Connections**, **Connected
devices**, or **More connection settings**.

### The tag is not detected

Remove a thick or magnetic phone case, move the tag slowly around the upper
back of the phone, and keep only one NFC tag near it. Metal directly behind the
tag can interfere with NFC unless the magnet uses an anti-metal NFC layer.

### EverAfter reports an unknown UID

The scan works, but that physical identifier is not yet mapped. Copy the UID
shown by EverAfter into the matching artifact record in
`lib/data/trip_repository.dart`, rebuild, and scan again.

### Scanning an NDEF tag opens another app

Confirm that the first NDEF record is the exact `everafter:///nfc/...` URI and
that the current EverAfter build is installed. If multiple apps claim the
custom scheme, Android may ask which app should open it.
