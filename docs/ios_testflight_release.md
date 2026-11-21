# iOS TestFlight

Diabeatthis uses the bundle identifier `pl.diabeatthis.app` and the Firebase
project `diabeatthis-e634c`. iOS starts in caregiver mode and requires Google
sign-in during setup. The minimum supported version is iOS 15. The upload
workflow uses a macOS 26 runner with Xcode.

## Set up the Apple and Firebase accounts

1. Enroll in the Apple Developer Program or get access to the existing team.
   Register `pl.diabeatthis.app` for that team and create its iOS app record
   in App Store Connect.
2. Create an Apple Distribution certificate and an App Store Connect
   provisioning profile for that app. Export the certificate and private key
   as a password-protected `.p12`.
3. Create a team API key in App Store Connect with permission to upload builds.
4. In Firebase Console, register app
   `1:1018488815956:ios:63f9bc733b1404381f48c1` with App Check using App Attest
   and the Apple Team ID. The family backend requires App Check.

## Configure GitHub Actions

Set repository variable `APPLE_TEAM_ID`. Add these Actions secrets directly
in GitHub:

| Secret | Value |
| --- | --- |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution `.p12` |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Password for that `.p12` |
| `IOS_APP_STORE_PROFILE_BASE64` | Base64-encoded App Store provisioning profile |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Base64-encoded team API key `.p8` |
| `APP_STORE_CONNECT_API_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | API issuer ID |

Once the workflow exists on the default branch, run **iOS TestFlight** with an
unused build number. The version comes from `pubspec.yaml`. After Apple has
processed the build, complete any export compliance questions and add the
build to the intended TestFlight group. An internal group with automatic
distribution can receive subsequent uploads automatically.

Verify on a physical iPhone that the app opens, offers the caregiver flow,
completes Google sign-in and Nightscout setup, and reaches the caregiver
dashboard. Verify family pairing and local notifications separately. Remote
family chat and meal decision pushes currently use the Android delivery paths.
