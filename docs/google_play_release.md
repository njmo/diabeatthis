# Google Play release from GitHub Actions

The Android release workflow builds a signed app bundle and APK, uploads both as GitHub Actions artifacts, creates a GitHub Release for version tags, and can upload the app bundle to Google Play.

## Android build toolchain

Both GitHub Actions workflows use Flutter 3.47.0 and Java 17. The project uses Gradle 9.3.1, Android Gradle Plugin 9.1.0, and built-in Kotlin with compiler version 2.4.0. Keep the Flutter version aligned in both workflows when upgrading it.

Android plugin versions are managed in `android/settings.gradle.kts`, including those used by the local `foreground_power_lock` plugin. Built-in Kotlin is enabled globally in `android/gradle.properties`; neither the app nor the local plugin applies the legacy Kotlin Android plugin. The Kotlin declaration with `apply false` selects the compiler version required by Flutter. The old Android DSL remains enabled for compatibility with Flutter dependencies.

Commit `pubspec.lock` with dependency upgrades. Both workflows enforce it when resolving packages so builds use the plugin versions validated for built-in Kotlin. Some upstream plugins retain conditional KGP declarations for AGP 8; Flutter 3.47 may list them in its text-based warning even though those declarations do not run on AGP 9.

CI builds a debug APK after analysis and tests; the release workflow builds the signed AAB and APK.

The plugin upgrades also require the updated iOS configuration: Flutter 3.47 uses an iOS 15 deployment target and Swift Package Manager integration, with CocoaPods retained for plugins that still need it. Keep the Swift package resolution files and `ios/Podfile.lock` with dependency changes.

## Trigger

Push a semantic version tag:

```bash
git tag v1.0.2
git push github v1.0.2
```

The workflow also supports manual runs from GitHub Actions with a selected Google Play track.

## Required GitHub secrets

- `ANDROID_KEYSTORE_BASE64`: base64-encoded release upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`: keystore password.
- `ANDROID_KEY_ALIAS`: upload key alias.
- `ANDROID_KEY_PASSWORD`: upload key password.
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Google Play service account JSON.

## Google Play setup

1. Create the app in Play Console with package name `pl.diabeatthis.app`.
2. Enable Play App Signing for the app.
3. Upload the first app bundle manually in Play Console if the Google Play API does not recognize the package yet.
4. Enable the Google Play Android Developer API.
5. Create a Google Cloud service account for Play publishing.
6. In Play Console, grant the service account access to the app with release permissions.
7. Add the service account JSON as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` in GitHub repository secrets.
8. Use the `internal` track first, then move to closed testing when the app is ready.

If `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` is missing, the workflow still builds the app bundle and APK, then creates a GitHub Release, but it skips the Google Play upload.

## Firebase App Check setup

Release builds use `AndroidPlayIntegrityProvider`, so testers installed from Google Play do not need Firebase App Check debug tokens.

1. In Play Console, open app integrity settings after the first app bundle upload.
2. Copy the SHA-256 fingerprint from the Play App Signing app signing certificate.
3. Add that SHA-256 fingerprint to the Android app in Firebase.
4. In Firebase App Check, register the Android app with the Play Integrity provider.
5. Keep App Check enforcement disabled until internal testers confirm Firebase AI works from the Play-installed build.

Debug and profile builds still use a locally generated Firebase App Check debug token for development.
