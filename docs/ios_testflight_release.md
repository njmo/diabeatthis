# Diabeatthis na TestFlight po zakupie Apple Developer Program

Pierwszy build iOS udostępnia wyłącznie tryb opiekuna. Firebase ma już aplikację
iOS w projekcie `diabeatthis-e634c`, z identyfikatorem pakietu
`pl.diabeatthis.app`. Użyj tego samego identyfikatora w obu panelach Apple.
Wszystkie kroki poniżej możesz wykonać z Linuksa. GitHub Actions buduje
i podpisuje aplikację na runnerze `xcode-27` z Flutterem 3.47.9.
Workflow wymaga SDK iOS 27 lub nowszego. Minimalna wersja systemu
na iPhonie to iOS 15.

## 1. Potwierdź członkostwo i skopiuj Team ID

- Zaloguj się na [Apple Developer Account](https://developer.apple.com/account/)
  tym samym Apple Account, na którym kupiłeś członkostwo. W **Membership
  details** sprawdź status i zapisz **Team ID**.
- Jeśli zakup nadal jest przetwarzany, poczekaj na mail potwierdzający
  członkostwo. Jeśli potwierdzenie nie przyjdzie w ciągu 24 godzin, Apple prosi
  o zgłoszenie z numerem Enrollment ID. [Potwierdzenie członkostwa](https://developer.apple.com/help/account/membership/program-enrollment/)

## 2. Zarejestruj aplikację w Apple

1. W **Apple Developer → Certificates, Identifiers & Profiles → Identifiers**
   kliknij **+ → App IDs → App**. Wpisz opis `Diabeatthis`, wybierz
   **Explicit** i wpisz `pl.diabeatthis.app`. W sekcji **Capabilities**
   zaznacz **App Attest** i **Push Notifications** (APNs). Pozostałe
   ustawienia zostaw domyślne. Zatwierdź **Continue → Register**.
   [Otwórz Identifiers](https://developer.apple.com/account/resources/identifiers/list) · [Pomoc Apple](https://developer.apple.com/help/account/identifiers/register-an-app-id/)
2. W **App Store Connect → Apps → + → New App** wybierz **iOS**. Wprowadź nazwę
   `Diabeatthis`, główny język, np. **Polish**, zarejestrowany **Bundle ID**
   i własny **SKU**, np. `diabeatthis-ios`. Kliknij **Create**. Jeśli panel
   zatrzyma Cię na umowie, właściciel konta musi ją zaakceptować przed
   utworzeniem wpisu. [Otwórz Apps w App Store Connect](https://appstoreconnect.apple.com/apps) · [Pomoc Apple](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)

Jeśli App ID już istnieje, wejdź w **Identifiers → pl.diabeatthis.app → Edit**,
zmień **Capabilities** i kliknij **Save**. Jeśli profil dystrybucyjny już
powstał, po zmianie wygeneruj go ponownie i podmień
`IOS_APP_STORE_PROFILE_BASE64` w GitHub Actions.
[Edycja capabilities i profili](https://developer.apple.com/help/account/identifiers/enable-app-capabilities/)

## 3. Włącz App Attest w Firebase

W **Firebase Console → diabeatthis-e634c → App Check → Apps** znajdź
`pl.diabeatthis.app` (Firebase App ID `1:1018488815956:ios:63f9bc733b1404381f48c1`).
Kliknij **Register**, wybierz **App Attest** i podaj **Team ID** z kroku 1.
Kod iOS deklaruje już App Attest, a backend rodziny wymaga prawidłowego tokenu.
[Otwórz App Check w projekcie Diabeatthis](https://console.firebase.google.com/project/diabeatthis-e634c/appcheck/apps) · [Konfiguracja App Attest](https://firebase.google.com/codelabs/app-attest#3)

Do powiadomień czatu utwórz klucz **Apple Push Notifications service (APNs)**
w **Apple Developer → Keys**. Klucz musi pozwalać wysyłać do aplikacji
`pl.diabeatthis.app` w środowisku **Production**, którego używa TestFlight.
W **Firebase → Project settings → Cloud Messaging → Apple app configuration**
wybierz aplikację iOS i wgraj plik APNs `.p8` z jego **Key ID** i swoim
**Team ID**. Klucz App Store Connect z kroku 5 służy do wysyłki buildów.
[Otwórz Apple Keys](https://developer.apple.com/account/resources/authkeys/list) · [Otwórz Cloud Messaging w Firebase](https://console.firebase.google.com/project/diabeatthis-e634c/settings/cloudmessaging) · [Konfiguracja APNs](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)

## 4. Utwórz certyfikat i profil do podpisania

1. W prywatnym katalogu poza repozytorium utwórz klucz i żądanie podpisania
   certyfikatu (CSR). Na Linuksie możesz użyć OpenSSL.

   ```bash
   umask 077
   mkdir -p ~/diabeatthis-ios-signing
   cd ~/diabeatthis-ios-signing
   openssl req -new -newkey rsa:2048 -nodes \
     -keyout distribution.key -out distribution.csr \
     -subj "/CN=Diabeatthis iOS Distribution"
   ```

2. W **Apple Developer → Certificates → +** wybierz **Apple Distribution**.
   Wyślij `distribution.csr`, pobierz certyfikat `.cer` i zapisz go w tym
   katalogu jako `distribution.cer`. Klucz `distribution.key` zostaje u Ciebie.
   [Otwórz Certificates](https://developer.apple.com/account/resources/certificates/list) · [Pomoc Apple](https://developer.apple.com/help/account/certificates/certificates-overview/)
3. Połącz certyfikat z kluczem w pliku `.p12` i ustaw hasło eksportu.

   ```bash
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -inkey distribution.key -in distribution.pem \
     -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
     -out distribution.p12
   ```

4. W **Apple Developer → Profiles → +** wybierz **Distribution → App Store
   Connect**. Wskaż `pl.diabeatthis.app` i certyfikat z poprzedniego kroku.
   Nadaj nazwę, np. `Diabeatthis TestFlight`, kliknij **Generate → Download**
   i zapisz plik jako `diabeatthis.mobileprovision`.
   [Otwórz Profiles](https://developer.apple.com/account/resources/profiles/list) · [Pomoc Apple](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)

## 5. Utwórz klucz do wysyłki buildów

W **App Store Connect → Users and Access → Integrations → App Store Connect
API** kliknij **Request Access**, jeśli sekcja wymaga aktywacji. O dostęp
występuje właściciel konta. W **Team Keys** utwórz klucz, np.
`Diabeatthis GitHub Actions`, z rolą **Developer**. Zapisz **Key ID**,
**Issuer ID** i pobierz `AuthKey_<KEY_ID>.p8`. Apple udostępnia pobranie pliku
tylko raz. [Otwórz App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api) · [Pomoc Apple](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api/)

## 6. Ustaw zmienne w GitHub Actions

W repozytorium **njmo/diabeatthis → Settings → Secrets and variables →
Actions → Variables** sprawdź, czy `APPLE_TEAM_ID` jest ustawione na
`3T5B88F4H3`. W zakładce **Secrets** dodaj
poniższe wartości jako **repository secrets**.
[Otwórz Actions Variables](https://github.com/njmo/diabeatthis/settings/variables/actions) · [Otwórz Actions Secrets](https://github.com/njmo/diabeatthis/settings/secrets/actions)

| Nazwa sekretu | Wartość |
| --- | --- |
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | Wynik `base64 -w 0 distribution.p12` |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | Hasło eksportu `.p12` z kroku 4 |
| `IOS_APP_STORE_PROFILE_BASE64` | Wynik `base64 -w 0 diabeatthis.mobileprovision` |
| `APP_STORE_CONNECT_API_KEY_BASE64` | Wynik `base64 -w 0 AuthKey_<KEY_ID>.p8` z rzeczywistą nazwą pobranego pliku |
| `APP_STORE_CONNECT_API_KEY_ID` | **Key ID** z App Store Connect |
| `APP_STORE_CONNECT_ISSUER_ID` | **Issuer ID** z App Store Connect |

Polecenia Base64 uruchom w katalogu z plikami i wklej wynik bezpośrednio
do odpowiedniego sekretu w GitHubie. Zachowaj prywatne pliki i hasło poza
repozytorium i czatem.

## 7. Wyślij build i zainstaluj go na iPhonie

1. Utwórz tag na commicie przeznaczonym do testów i wypchnij go do GitHuba.

   ```bash
   git tag v1.0.1-ios
   git push origin v1.0.1-ios
   ```

   Tag `v1.0.1-ios` uruchamia wysyłkę TestFlight z wersją `1.0.1`.
   GitHub Actions nadaje numer buildu automatycznie. Do kolejnego wydania
   użyj nowego taga, np. `v1.0.2-ios`. Tagi z końcówką `-ios` są
   wykluczone z workflow Androida. Po scaleniu workflow do `develop` wciąż
   możesz użyć **Actions → iOS TestFlight → Run workflow** i opcjonalnie
   podać wersję oraz numer buildu. Ręczne uruchomienie domyślnie używa wersji
   z `pubspec.yaml`.
   [Otwórz Actions](https://github.com/njmo/diabeatthis/actions)
2. Sprawdź, czy krok **Upload to App Store Connect** zakończył się sukcesem.
   W **App Store Connect → Apps → Diabeatthis → TestFlight** poczekaj na
   przetworzenie buildu. Jeśli Apple wyświetli **Missing Compliance**,
   uzupełnij pytania o szyfrowanie zgodnie z tym, czego używa aplikacja.
   [Otwórz Apps i wybierz Diabeatthis](https://appstoreconnect.apple.com/apps) · [Przetwarzanie buildów](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
3. W **TestFlight → Internal Testing** utwórz grupę, np. `Diabeatthis Internal`,
   i zaznacz **Enable automatic distribution**. Przez **Invite Testers**
   dodaj konta testerów. Kolejne gotowe buildy będą trafiały do tej grupy
   po przetworzeniu. Na iPhonie zainstaluj **TestFlight**, przyjmij zaproszenie
   i zainstaluj Diabeatthis. Dla grup zewnętrznych obowiązuje beta review
   Apple, kiedy dany build go wymaga.
   [Otwórz TestFlight Diabeatthis](https://appstoreconnect.apple.com/teams/197032ea-c7c4-48e2-8ad1-d40efadd82a2/apps/6837619950/testflight) · [Testy wewnętrzne](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/) · [Testy zewnętrzne](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)
4. Na iPhonie sprawdź start, logowanie Google, konfigurację Nightscout,
   parowanie rodziny i wejście na ekran opiekuna. Sprawdź też powiadomienia
   czatu na otwartym ekranie i po zablokowaniu iPhone’a oraz otwarcie rozmów
   z powiadomienia. Zdalne powiadomienia decyzji posiłkowych korzystają
   obecnie ze ścieżki Androida.
