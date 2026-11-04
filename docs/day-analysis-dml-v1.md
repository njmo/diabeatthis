# Analiza dnia — DML v1

Opis roboczy, zaktualizowany 28.10.2026. Aktualna lista dalszych prac: [meal-context-next-steps.md](meal-context-next-steps.md).

## Zakres obecnego etapu

Generator łączy zatwierdzone agregaty z aktualnie odczytaną historią dnia i posiłków.
Nie zmienia archiwum i nie wywołuje modelu podczas przygotowywania wejścia.
`dayDmlProvider(date)` udostępnia eksport albo `null`, gdy brak zatwierdzonego dnia.

Format: nagłówek `DML/1`, następnie sekcje `NAZWA {obiekt JSON}` — po jednej na wiersz.
Sekcje: DAY, QUALITY, GLUCOSE, INSULIN, NIGHT, MEALS, LOW_TREATMENTS, ACTIVITY,
DEVICES oraz chronologiczne wiersze REVIEW. Każda sekcja ma stabilne `id` do
cytowania przez model. Wartości liczbowe i klucze są niezależne od języka UI.

- `null` oznacza brak danych; zero pozostaje zerem, jeśli mamy obserwację.
- Procenty zakresów CGM dotyczą czasu obserwowanego, pokrycie całego okna.
- Bolusy łącznie zawierają SMB. Noc może nakładać się na dzień.
- Baza i suma insuliny są szacunkami; brak pokrycia nie oznacza zerowej podaży.
- Makro może być niepełne lub pochodzić z planu; mówi o tym QUALITY.
- REVIEW opisuje rozstrzygnięcia, a nie oś czasu jedzenia i podawania insuliny.
- Kilka wpisów kalkulatora może mieć ten sam anonimowy `meal_ref`.
- Znaczniki czasu zawierają UTC i czas lokalny odtworzony z zapisanego offsetu.
- Eksport nie ujawnia identyfikatorów Nightscout ani lokalnych identyfikatorów posiłków.

## Granica remote/local

`DayAnalysisInputController` przygotowuje kontekst i DML.
`AnalyzeDaySummaryUseCase` przyjmuje gotowy dokument, korzysta z `DayAnalysisClient` i waliduje odpowiedź JSON.
`LlmDayAnalysisClient` używa istniejącego transportu `LocalLlmClient`, który pomimo
nazwy obsługuje również Firebase. `dayAnalysisClientProvider` wybiera klienta analizy dnia, a wspólny
`analysisLlmTransportProvider` dostarcza obecny transport remote. Lokalny silnik można podłączyć przez ten sam port.
Logika dnia i dokument DML nie zależą od Firebase.

Wynik to niezapisany `DayAnalysisDraft`: DML, zweryfikowane sekcje odpowiedzi,
identyfikator modelu, czas wygenerowania i wersja promptu. Sam odczyt providera
nie uruchamia generacji. Przycisk z iskierką na stronie dnia otwiera panel AI;
generacja następuje po wybraniu „Analizuj dzień”. Wynik to niezapisany podgląd.
Po akceptacji `DayAiRepository` zapisuje wynik, dokładny prompt i DML, surową odpowiedź,
model oraz czas. Można odrzucić nowy podgląd albo jawnie zastąpić zapisany wynik.

Odpowiedź JSON ma wersję 1, język pl/en i osiem sekcji: overview, glucose, night,
insulin, meals, low_treatments, activity, devices. Każda ma status, krótkie summary,
findings i missing_data. Walidacja odrzuca nieznane pola, brak sekcji, błędne
wartości enum, niewłaściwy język, zbyt długie treści i nieistniejące evidence_refs.
Walidacja struktury nie potwierdza prawdziwości interpretacji medycznej.

## Kontekst zdarzeń w DML v1

`LoadDayAnalysisHistoryUseCase` pobiera równolegle sześć źródeł przez istniejące
providery historii. Odczyt obejmuje 24 godziny przed wcześniejszym z początku dnia
lub nocy i do 3 godzin po zakończeniu dnia, najwyżej do chwili budowania.
Szczegóły posiłków są ładowane lokalnie partiami po cztery. Historia CGM/pompy/
zabiegów nie jest pobierana osobno dla każdego posiłku.

`BuildDayAnalysisContextUseCase` używa `BuildBeforeMealContextUseCase` i
`BuildMealOutcomeContextUseCase` na wspólnych danych. W DML dochodzą HISTORY,
CGM, PUMP, BOLUSES, ECARBS, RESCUE_CARBS, ACTIVITY_EVENTS, NIGHT_COURSE i MEAL.
Serie mają nagłówki kolumn oraz bloki z datą i offsetem UTC. Wiersze zawierają
czas HH:mm; nowy blok powstaje przy zmianie daty albo offsetu (również przy
cofaniu zegara). Koniec aktywności lub czas obserwacji pompy poza blokiem ma
własną datę i offset. Odczyty z tej samej minuty nie są scalane. Skrócenie czasu
dotyczy tylko tekstu DML, nie obliczeń. CGM zawiera wyłącznie odczyty ciągłe.
Noc ma dodatkowo godzinowe statystyki CGM, bazy względem profilu i SMB.

Posiłek zawiera skład, makro i jego źródło (zjedzone/planowane), etapy jedzenia,
czas oczekiwania, kontekst przed i wynik okna 90 min/3 h. Widoczne są nakładające
się kolejne posiłki i harmonogramy eCarbs. Harmonogram nie jest pomiarem wchłaniania.
Ostatni posiłek przed nocą i posiłki po granicy dnia są kontekstem; osobną sekcję
odpowiedzi modelu otrzymują wyłącznie posiłki z analizowanego dnia.

HISTORY zapisuje czas odczytu i braki źródeł. Uzupełniona historia może różnić się
od zaakceptowanych wcześniej agregatów; model ma to rozróżniać. Nie dublujemy serii
w bazie ani nie modyfikujemy zaakceptowanego podsumowania. Podgląd i wywołanie AI
używają tego samego przygotowanego dokumentu w trakcie otwartego panelu.

Prompt wymaga wskazania konkretnych przedziałów czasu, sekwencji zdarzeń,
ostrożnej interpretacji i alternatyw. Sam SMB nie dowodzi złej bazy, CGM nie
udowadnia przewagi wchłaniania nad insuliną. Nie generujemy instrukcji dawkowania.
Puste sekcje nie tworzą pustych kart. JSON zawiera osiem głównych sekcji oraz
sekcję pod identyfikatorem każdego analizowanego posiłku, zgodną z wejściem.

DML zawiera zaakceptowane podsumowania do siedmiu poprzednich dni, z zachowaniem braków
i pokrycia. Nie przelicza ponownie ich historii ani nie kopiuje wcześniejszych opinii LLM.
Nadal nie ma pełnego profilu AAPS ani wiarygodnego pomiaru tempa wchłaniania.
Zapis i akceptacja analiz są już zaimplementowane. Format pozostaje DML v1.

Przygotowany kontekst jest formatowany przez czysty serializer DML. Kontroler przygotowuje wejście raz na otwarcie panelu. Ponowne generowanie odpowiedzi LLM używa tego samego dokumentu. Ponowienie przygotowania jest dostępne wyłącznie po błędzie uniemożliwiającym utworzenie dokumentu; częściowe braki pozostają jawnie opisane w DML. Błąd pojedynczego posiłku nie usuwa pozostałych; DML podaje liczbę niedostępnych posiłków. Wywołanie modelu przyjmuje wyłącznie przygotowany dokument, bez alternatywnej ścieżki budowania danych.


Dodatkowy kontekst zdarzeń:
- STRESS_EVENTS: początek, opcjonalny koniec, poziom stresu, źródło i notatka; brak końca nie oznacza ciągłego stresu.
- TEMP_TARGETS: żądania celu tymczasowego AAPS; czas 0 oznacza anulowanie, kolejny wpis zastępuje poprzedni.
- BG_CHECKS: punktowe pomiary z historii glikemii i zabiegów, bez dodawania do statystyk CGM. Identyczne pomiary w obu źródłach są scalane; braki źródeł są jawne.
Te dane wykorzystują istniejący odczyt historii i nie wymagają dodatkowego pobierania ani zapisu do bazy.


Walidacja dodatkowego kontekstu: dla celu o dodatnim czasie trwania niepełny lub odwrócony zakres jest zapisywany jako null, nigdy jako cel 0 mg/dl. Anulowanie pozostaje rozpoznawane po czasie 0. Scalone pomiary zachowują różne niepuste notatki bez powtórzeń; zapis tej samej chwili w UTC i czasie lokalnym nie tworzy dodatkowego pomiaru.


Rozszerzony kontekst AAPS (28.10.2026): `AAPS_CONTEXT` zawiera zapisane parametry wrażliwości, prognozy i szczegóły kalkulatora. Prognozy na osi czasu wybierane są po jednej najnowszej poprawnej na godzinę oraz na granicach posiłków; ich krzywe zachowują punkty kontrolne, minimum, maksimum i koniec bez interpolacji. `before.aaps` zawiera oddzielny snapshot sprzed posiłku, czas obliczenia oraz wiek prognozy. Nie podstawiamy późniejszej prognozy w miejsce tej dostępnej przed posiłkiem.

IC jest wyrażone w g/U, a ISF i cele z kalkulatora zachowują własne zapisane jednostki (`recorded_units`), których brak pozostaje jawny. `isf_for_carbs_mg_dl_u` z DeviceStatus ma osobno opisaną jednostkę. `stored_sensitivity_ratio` może zawierać historyczną wartość domyślną 1. Składowe kalkulatora i jego wynik nie są potwierdzeniem podania insuliny i nie są dodawane do sum. Dane są eksportowane zawsze, gdy są dostępne; nie dodano przełącznika danych ani nowych odczytów sieciowych.
