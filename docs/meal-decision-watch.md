# Decyzje o posiłku na zegarku

Telefon opiekuna obsługuje uwierzytelnienie i połączenie z Firebase. Apple Watch użyje WatchConnectivity, a Wear OS użyje Data Layer. Adaptery natywne przekazują ten sam komunikat do Fluttera przez kanał `pl.diabeatthis.app/meal_decision_watch` i metodę `exchange`.

## Protokół v1

Komunikaty są mapami zawierającymi typy obsługiwane przez oba transporty. Czasy to milisekundy od początku epoki Unix.

| Akcja | Żądanie | Odpowiedź przy sukcesie |
| --- | --- | --- |
| `mode` | `{"version":1,"action":"mode"}` | `status: ok` i `mode: child\|caregiver` |
| `list` | `{"version":1,"action":"list"}` | `status: ok` oraz lista `requests`, która może być pusta |
| `open` | `{"version":1,"action":"open","requestId":"…"}` | `status: ok` oraz jeden element w `requests` |
| `claim` | `{"version":1,"action":"claim","requestId":"…"}` | `status: ok`, potwierdzone przejęcie i podgląd posiłku, jeśli dostępny |
| `respond` | `version`, `action: respond`, `requestId`, `type`, opcjonalne `minutes` i `message` | `status: ok` po potwierdzeniu Firebase |
| `presence` | `version`, `action: presence`, `requestId` i `stage` | `status: ok` i odnowione `claimUntilMs` |

Każda odpowiedź zawiera `version` i `status`. Element listy zawiera `requestId`, `mealName`, `deadlineMs` oraz opcjonalne `claimUntilMs` dla aktywnego przejęcia widocznego na danym koncie. Statusy błędów to `invalidRequest`, `unsupportedVersion` i `unavailable`. Gdy telefon nie może potwierdzić dostępności prośby dla bieżącego opiekuna, zegarek traktuje ją jako niedostępną.

## Kolejne etapy

- Sprawdzić wysłanie decyzji na sparowanych urządzeniach. Pięć minut biegnie od utworzenia prośby. Otwarty formularz podtrzymuje przejęcie. Przejęcie wygasa po 30 sekundach od ostatniego potwierdzenia obecności. Brak automatycznego ponawiania żądań z zegarka.
- Obsłużyć otwarcie prośby z powiadomienia oraz osobne powiadomienie pozostałych opiekunów o przejęciu. Na iOS trzeba najpierw uruchomić dostarczanie tych powiadomień na telefon.
- Dołączyć miniapkę watchOS do kompilacji TestFlight. Udostępnić kompilację Wear OS w testach Google Play z możliwością wyboru sparowanego zegarka. Sprawdzić instalację, powiadomienia i komunikację na obu platformach, również przy zablokowanym telefonie.

## Wear OS

Moduł `android/wear` dostarcza jedną miniapkę. Android przekazuje wspólny komunikat JSON przez Wear OS Data Layer pod ścieżką `/diabeatthis/meal-decision`. Zegarek wybiera jeden osiągalny telefon reklamujący funkcję `diabeatthis_meal_decision_phone`. Adapter telefonu działa w czasie życia silnika Fluttera podpiętego do głównej aktywności.

Akcja `mode` zwraca `mode: child` lub `mode: caregiver` po zakończeniu konfiguracji i zalogowaniu na telefonie. Telefon sprawdza tryb i konto ponownie po odczytach. Lista dziecka zwraca wyłącznie jego aktywne prośby i ich stan. Lista opiekuna korzysta z istniejącego sprawdzania dostępności próśb. `open` zwraca podgląd posiłku przejętego przez danego opiekuna. Podgląd korzysta z projekcji posiłku oraz źródła ostatniej glukozy aplikacji telefonu i jest zamykany, gdy upływa termin prośby lub przejęcia.

Podgląd opiekuna pokazuje termin posiłku, makroskładniki, ostatni pomiar glukozy, wykresy glukozy, IOB i COB oraz komunikaty o celach tymczasowych, węglowodanach i aktywności. Telefon i zegarek korzystają z tego samego odczytu historii Nightscout. Jeśli historia nie jest gotowa w ciągu trzech sekund, zegarek pokazuje ostatni dostępny odczyt i oznacza historię jako niedostępną.

Kompilacja lokalna to `:wear:assembleDebug`. Kompilacja testowa Google Play to `:wear:bundleRelease` z przydzielonym dla Wear OS kodem wersji przekazanym przez `-PwearVersionCode` i nazwą wersji przez `-PwearVersionName`. Paczka Wear OS ma ten sam identyfikator i korzysta z tej samej konfiguracji podpisu co telefon. W Google Play jest oddzielnym artefaktem dla zegarka w obrębie tej samej aplikacji.

Gdy telefon opiekuna ma otwarty ekran aplikacji, Flutter pokazuje zaproszenie na telefonie i przekazuje osobny alert do Wear OS. Przy uśpionym telefonie obsługa wiadomości Firebase w tle próbuje dostarczyć alert przez ten sam Wear OS Data Layer. Zegarek potwierdza dopiero po zarejestrowaniu powiadomienia. Jeśli potwierdzi, kopia na telefonie pozostaje w panelu i telefon nie próbuje włączyć ekranu. W razie braku potwierdzenia telefon próbuje krótko wybudzić swój ekran po pokazaniu powiadomienia. Próba wybudzenia respektuje konfigurację kanału i tryb Nie przeszkadzać.
