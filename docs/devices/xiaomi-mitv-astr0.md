# Redmi A Pro 75 (MiTV-ASTR0)

## Device and package identity

- Redmi Smart TV A Pro 75" 2025 energy-saving edition; model `MiTV-ASTR0` / `MiTV_ASTR0`, codename `blueplanet`.
- Android 11; toolkit record: firmware `OS2.0.21.0.RSTAATV`.
- Full app ID: `com.ts.launcher`; source namespace and component classes stay `app.orchard.tv`.
- Home component: `com.ts.launcher/app.orchard.tv.MainActivity`; flavor: `standard`.
- Public Aerial releases still use `app.orchard.tv` and cannot update this renamed app. Build/install a matching private APK and keep the same signing key.
- Signing certificate SHA-256: `47:94:7F:3D:B3:EF:0C:DC:1C:04:55:88:E1:64:B6:80:4B:7C:71:B7:8C:A2:94:0F:33:55:9A:BE:29:DB:C5:D0`. Within AerialTV, keep private key material only under the ignored `local/` directory; never commit it. The toolkit's separate private copy is outside this repository.

## Device-specific profile

`app/src/main/assets/devices.json` has an ASTR0 profile for three independently observed firmware behaviors:

- Hide HDMI hardware IDs 7 and 8: the set has two HDMI ports, although the TV input HAL registers four (#1517).
- Set `neverFilterKeys`: requesting Accessibility key filtering on this firmware suppresses the remote's voice key (`KEYCODE_VOICE`, 192). Once the user is unlocked and the profile is available, the guard disables key filtering on this model.
- Set `skipTakeoverWhenDefaultHome`: when `com.ts.launcher` actually resolves as the system default Home, the guard must not mistake an unknown foreground after unlock for PatchWall and relaunch Aerial over the app in use. This exception is limited to the ASTR0 profile; other Xiaomi models retain the normal takeover behavior.

These are per-device corrections because the firmware behavior cannot be safely inferred from a general Android capability. The voice-key and unlock/takeover observations come from the private toolkit's real-device notes. The public ASTR0 report #1517 supplies the HDMI evidence.

## Build and verification

- Build from this checkout with JDK 17 and the Android SDK: `./gradlew assembleStandardRelease`.
- An update-compatible build needs `local/signing.properties` and its referenced keystore under the ignored `local/` directory. If those files are absent, release builds fall back to this machine's debug key, which is not portable. Never commit signing material.
- `tools/install.sh` requires `BUILD=1` or `APK_FILE` for this private ID; the public Release APK has the incompatible `app.orchard.tv` ID.
- The toolkit records real-device checks on 2026-10-26 for the menu key, voice key, and Aerial screensaver, and package/Home upgrade checks through Aerial 1.89 (versionCode 126). The current repository's Aerial 1.97 / versionCode 142 private build has **not** been installed or revalidated on this TV. Do not treat the current profile/code as newly device-verified until those checks are repeated.

Do not disable or uninstall `com.mitv.tvhome` or other system apps as part of this setup. Keep a working fallback Home and use only the authorized ADB endpoint from the local, ignored machine configuration; do not record TV IPs or owner-specific settings in tracked files.
