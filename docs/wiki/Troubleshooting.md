# Rozwiązywanie problemów

## Nie ma aktualnych danych

1. Sprawdź czas ostatniego odczytu w DiaBeatThis i w źródle danych.
2. Sprawdź wybrane źródło i zapisane ustawienia połączenia.
3. Dla Nightscout sprawdź dostępność swojej instancji i dane dostępu.
4. Dla AAPS sprawdź [ustawienia rozgłaszania](AAPS-integration), odbiorcę
   oraz wymagane typy danych.

## Brakuje przypomnień

Sprawdź uprawnienia powiadomień, kanały powiadomień Androida, tryb „Nie przeszkadzać”
oraz ograniczenia baterii i działania w tle. Sprawdź też, czy posiłek lub aktywność
ma czas i status, dla których oczekujesz przypomnienia.

## Aplikacja nadal czeka na bolus

Otwarcie kalkulatora nie oznacza podania insuliny. Najpierw sprawdź w AAPS,
czy działanie rzeczywiście zostało wykonane, a następnie sprawdź synchronizację
zdarzeń. Nie ponawiaj podania tylko po to, żeby zniknęło przypomnienie.

## Nie można rozpocząć kolejnego posiłku

Sprawdź, czy poprzedni posiłek nadal jest aktywny, również z wcześniejszego dnia.
Zakończ lub anuluj go zgodnie z rzeczywistym przebiegiem.

## Zgłoszenie problemu

W [zgłoszeniu błędu](https://github.com/njmo/diabeatthis/issues) podaj:

- wersję DiaBeatThis, Androida i model telefonu;
- źródło danych i wersję AAPS, jeśli go używasz;
- kroki odtworzenia problemu;
- oczekiwany i rzeczywisty rezultat;
- przybliżony czas wystąpienia oraz zanonimizowany zrzut ekranu, jeśli pomaga.

Usuń klucze API, tokeny, adresy prywatnych serwerów i dane osobowe przed publikacją.
