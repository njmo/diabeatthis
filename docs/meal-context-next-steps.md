# Kontekst posiłku i AI — stan oraz kolejne kroki

Stan sprawdzony w kodzie: 29.10.2026. Wewnętrzny dokument roboczy; poza commitami kodu.
Ten plik jest aktualną listą prac. Pozostałe dokumenty opisują format DML i historyczne próby jakości.

## Zaimplementowane — nie planujemy ich ponownie

- Wspólne use case’y `BuildBeforeMealContextUseCase`, `BuildMealOutcomeContextUseCase` i `FindSimilarMealsUseCase`.
- Analiza historii posiłku i podobieństwo składu, makr oraz porcji.
- AI pojedynczego historycznego posiłku: kontekst przed, przebieg i do trzech wcześniejszych podobnych posiłków z zakończonym oknem obserwacji.
- DML analizy dnia: zdarzenia, glikemia, pompa, insulina, posiłki, eCarbs, dosłodzenia, aktywność, stres, cele tymczasowe i pomiary punktowe.
- Kontekst do siedmiu poprzednich dni z zaakceptowanych podsumowań. Bez ponownego przeliczania ich historii i bez kopiowania wcześniejszych opinii AI. Braki pozostają jawne.
- Podgląd pełnego wejścia i odpowiedzi JSON, jawne wywołanie modelu, odrzucenie podglądu, akceptacja oraz zastąpienie zapisanej analizy dnia i posiłku.
- Zapis zaakceptowanego wyniku z dokładnym wejściem, odpowiedzią, modelem i czasem. Dane źródłowe kontekstu nie tworzą osobnego archiwum całej historii.
- Walidacja JSON; w analizie posiłku również ścieżek do istniejących pól DML, dłuższych opisów i większej liczby cytowań.
- Porty klientów analiz niezależne od dostawcy; obecna implementacja korzysta z Firebase/Gemini.
- Opcjonalny tryb „Meal Advisor wspomagany AI”, domyślnie wyłączony. W oknie „Zjem” ładuje `BeforeMealContext`, pokazuje postęp i pozwala przerwać oczekiwanie decyzją ręczną. Nie wywołuje jeszcze LLM i nie zmienia reguł rekomendacji.
- Zwykły dialog Advisora korzysta ze świeżej, ciągłej serii CGM już dostępnej w aplikacji, zanim zapyta historię. Sprawdzanie świeżości i kompletności danych pozostaje obowiązkowe dla automatycznej sugestii.
- Monitor prośby AAPS o dosłodzenie: ponowienia co 5 minut przy aktualnej prośbie i świeżych danych; potwierdzenie, wycofanie i brak świeżych danych zatrzymują alarmowanie. Spóźnione dane nie odtwarzają starej prośby.
- Formularz dosłodzenia, lokalny kontekst aktywności/stresu, przekazanie do AAPS i uzgadnianie potwierdzenia. Foreground nie uruchamia LLM w każdym cyklu.

- DML Advisora, historii posiłku i dnia korzysta ze wspólnych faktów przed posiłkiem: stan na moment, osobne okna CGM/insuliny, zdarzenia i jakość źródeł.
- Bieżący Advisor zawiera planowany posiłek oraz do trzech wcześniejszych podobnych posiłków z zakończonym wynikiem. Gotowe są prompt, kontrakt akcji/minut i walidacja; wywołanie modelu nie jest jeszcze podłączone.
- Prognozy w jednym dokumencie mają odwołania do wspólnej puli. Scalane są wyłącznie identyczne fakty; różne krzywe z tą samą godziną pozostają osobne.
- Wspólna instrukcja interpretacji jest dołączana raz i dobierana do rodzaju wejścia. Stare zapisane DML/1, prompty i cytowania pozostają odczytywane z archiwum.

## Do zaimplementowania

### 1. Wnioskowanie w opcjonalnym AI-assisted Meal Advisor

Kontekst, DML, prompt i kontrakt odpowiedzi są gotowe. Pozostają klient wywołania, use case wnioskowania i prezentacja zwalidowanej propozycji AI. Przed aktywacją trzeba ustalić obowiązującą politykę dozwolonych działań i czasu oczekiwania oraz ocenić wyniki na rzeczywistych przypadkach.

Zachować ręczną decyzję, anulowanie i ochronę przed nadpisaniem jej spóźnionym wynikiem. Nie rozszerzać zakresu na wyliczanie dodatkowych dawek insuliny.

### 2. Pełniejszy profil AAPS jako opcjonalne źródło kontekstu

DML analiz dnia i posiłku został rozszerzony o dostępne prognozy AAPS, zapisane parametry wrażliwości oraz IC, ISF, cele, procent i składowe Bolus Wizarda. Eksport korzysta z już pobranej historii, bez osobnego przełącznika danych. Istniejący przełącznik dotyczy wyłącznie logiki AI-assisted Advisora.

Nie jest to pełny profil terapii ani historia jego zmian. DML analizy dnia nadal oznacza brak pełnego profilu AAPS.

Pozostaje ustalić źródło i dostępność parametrów, ich czas obowiązywania oraz sposób ujawniania braków. Dane o krzywej/działaniu insuliny powinny pochodzić z AAPS; nie zastępować ich zgadywaną krzywą na podstawie samej nazwy preparatu.

### 3. Rzeczywisty backend lokalnego LLM

Warstwa abstrakcji już istnieje, ale nie ma implementacji uruchamiającej model na telefonie. To osobny etap: silnik, model, zasoby urządzenia, anulowanie oraz zgodność odpowiedzi z tym samym kontraktem. Nie trzeba w tym celu przebudowywać kontekstów i DML.

## Do zweryfikowania — to nie brak implementacji

- Powtórzyć ocenę rzeczywistych odpowiedzi po zmianach czasu i chronologii. Historyczne próby nie potwierdziły jeszcze jakości końcowej wersji.
- Sprawdzić kolejność minimum/maksimum, rozróżnienie średniej od odczytu początkowego, zakres nocnej sumy SMB i brak podwójnego liczenia insuliny.
- Ocenić kilka różnych posiłków: stabilny przebieg, szybki wzrost, późny wzrost oraz dosłodzenie. Wnioski mają dodawać interpretację z ograniczeniami, a nie przepisywać statystyki.
- Sprawdzić nowy dialog „Zjem” przy słabej sieci oraz przejście do ręcznej decyzji w realnym użyciu. Testy automatyczne obejmują wycofanie oczekiwania i ignorowanie spóźnionych odpowiedzi.
- Walidacja struktury odpowiedzi nie potwierdza prawdziwości jej interpretacji.

## Świadomie odłożone

Propozycje dodatkowych bolusów związanych z eCarbs pozostają poza bieżącym zakresem. Temat może wrócić po ustaleniu obsługi węglowodanów przedłużonych jako bolusa. Nie dodajemy go przy okazji opt-in do AI.

Tymczasowy test telefonu, prywatny fixture, sterownik, generator i zależności `integration_test` usunięto 28.10.2026. Zwykłe testy jednostkowe i widgetowe pozostają w repozytorium.

## Pomiar optymalizacji DML — 29.10.2026

Syntetyczne, stałe przykłady; bajty UTF-8 pełnego promptu, nie liczba tokenów ani koszt usługi:
- Advisor z trzema porównaniami: 26860 → 24558.
- Historia posiłku z trzema porównaniami: 31147 → 27294.
- Dzień: 33754 → 28697. Sam DML dnia zawiera teraz więcej faktów przed posiłkami i jawne rekordy węglowodanów; oszczędność dotyczy całego wejścia.
- Bez porównań: Advisor 7936 → 7894, historia posiłku 11551 → 10653.

Nie wywoływano LLM. Testy pokrywają dane, powiązania, budżet wejścia i odczyt archiwum; nie potwierdzają jakości interpretacji medycznej.
