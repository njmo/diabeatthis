# Ocena jakości analizy dnia AI — roboczo

Historyczny zapis prób z 15.09.2026; nie opisuje obecnego stanu implementacji.
Przegląd i porządki: 28.10.2026. Dokument wewnętrzny, poza commitami kodu.
Aktualny zakres i dalsze prace: [meal-context-next-steps.md](meal-context-next-steps.md).

## Cel i kryterium zakończenia

Analiza ma pomagać rodzicowi dziecka z CT1 i osobie z CT1 zrozumieć istotne zdarzenia. Poprawny JSON i zapis w bazie nie wystarczają. Wymagane są poprawne godziny i kolejność, zgodność wartości i zakresów agregacji, rozróżnienie danych i hipotez, uwzględnienie nakładania posiłków i ograniczeń zapisów. Brak oceniania użytkownika, nieuzasadnionych przyczyn, porad dawkowania oraz przepisywania dashboardu.

## Wykonane próby

- Pierwsza seria 8–10 IX: trzy poprawne JSON-y i poprawny zapis/odczyt archiwum, ale krytyczne błędy interpretacji UTC/local, kolejności zdarzeń, znaczenia oczekiwania i wniosków o sensorze.
- Po zmianie czasu na lokalny ISO z offsetem: poprawiona analiza 8 IX. Rozpoznano anomalię zapisu i sekwencję spadek–wzrost. Nadal odwrócona kolejność minimum i maksimum obiadu, nieprawidłowy zakres nocnej sumy SMB i nadinterpretacje.
- Jedna próba przerwana błędem połączenia po przejściu aplikacji w tło; kolejna odpowiedź 9 IX odrzucona przez ówczesną walidację tekstu. Późniejsza analiza posiłku ma osobne limity; nie oznacza to potwierdzenia jakości tych dawnych wyników.
- Końcowa wersja z chronologicznymi punktami nie otrzymała odpowiedzi: quotaExceeded, limit 20 darmowych wywołań Gemini 2.5 Flash. Ponowienie po czasie wskazanym przez serwer także odrzucone.

## Końcowa zmiana do weryfikacji zdalnej

- Jedna reprezentacja lokalnego czasu historii, z offsetem i zachowaniem instantu.
- Chronologiczne punkty baseline/minimum/maximum/last_observed, z deduplikacją i listą ról. Nie stanowią detekcji przyczyny ani ciągłego trendu.
- Dokładny czas bazowego odczytu CGM, także gdy jest po początku posiłku.
- Jawne pochodzenie czasu posiłku z etapów aplikacji; wyjaśnienie oczekiwania po oznaczeniu bolusa i przed jedzeniem.
- Sumy insuliny przypisane do granic własnego okna; SMB zawarte w sumie.
- Krótkie, neutralne wnioski ponad statystyki, ostrożność przy przyczynach i danych niepotwierdzonych. Bez zmian modelu, dawek ani działania AAPS.

## Co sprawdzić po odblokowaniu limitu

1. 8 IX: minimum przed maksimum obiadu; nocna suma SMB tylko w odpowiadającym jej oknie; niepewna tortilla nie staje się potwierdzonym drugim porannym posiłkiem.
2. 9 IX: maksimum przed deserem nie zostaje przypisane deserowi; redukcja bazy nie staje się przyczyną spadku; aktywność opisana z wcześniejszym kontekstem.
3. 10 IX: minimum po śniadaniu nie staje się minimum przed nim; średnia przed posiłkiem nie staje się wartością na start; brak dublowania SMB.
4. Ponownie ocenić odpowiedzi z perspektywy rodzica i osoby z CT1, nie tylko asercjami formatu.

Tymczasowy test telefonu, prywatne dane testowe, sterownik, generator i zależności usunięto 28.10.2026. Powtórzenie prób wymaga przygotowania nowego, jawnie uruchamianego testu. Ten dokument nie potwierdza aktualnego limitu usługi ani dostępności historycznych raportów. Nie zastępuje oceny jakości obecnej wersji.
