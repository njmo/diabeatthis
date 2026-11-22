# Decyzja opiekuna i start posiłku na telefonie i zegarku

Monitor wysyła prośbę w oknie zaczynającym się 20 minut przed zaplanowanym posiłkiem. „Akceptuj” zapisuje decyzję opiekuna. Dalszy krok zależy od wybranego przebiegu.

| Decyzja | Po akceptacji | Co uruchamia kolejny etap |
| --- | --- | --- |
| Jedzenie → bolus | Telefon i zegarek pokazują „Zaczynam jeść”. Akcja jest też dostępna na kafelku dziecka. | Dziecko rozpoczyna jedzenie. Po „Zjadłem” i podsumowaniu ilości pojawia się karta bolusa z węglami i eCarbs. |
| Bolus → jedzenie | „Zaczynam jeść” otwiera etap oczekiwania na bolus z kartą węgli i eCarbs. | Potwierdzone podanie przełącza posiłek na „Jedzenie w trakcie”. |
| Bolus → czekanie → jedzenie | Przy zaplanowanej prośbie po akceptacji widać godzinę otwarcia karty bolusa. Monitor wylicza ją z pory posiłku i czasu podanego przez opiekuna. | Dla posiłku o 13:00 i 10 minut czekania karta jest zaplanowana na 12:50. Odliczanie zaczyna się po potwierdzonym podaniu bolusa. Po zakończeniu czekania pojawia się powiadomienie o jedzeniu. |

Podczas oczekiwania na bolus nadal obowiązuje weryfikacja podania z istniejącego monitora. Otwarcie kalkulatora i częściowe podanie nie przełączają ekranu na jedzenie.

## Zapis i wznowienie

- Zapis decyzji jest powiązany z kontem dziecka, prośbą i terminem posiłku. Zmiana terminu unieważnia poprzedni start.
- Jeżeli zaakceptowana decyzja czeka na termin, monitor po restarcie odczytuje ją z bazy. Spóźnioną akceptację może podjąć w istniejącym oknie odzyskiwania zaplanowanych próśb.
- Dwa równoległe kliknięcia „Zaczynam jeść” mogą uruchomić posiłek tylko raz.
- Kafelek i aplikacja zegarka pokazują akcję na podstawie tego samego stanu z telefonu.

## Widok zegarka

Na ekranie posiłku u góry jest „Wstecz ›”, które podpowiada ruch od lewej do prawej. Na środku jest zielone „Zjem”, a pod nim tekstowe „Pomiń”. Po akceptacji decyzji wymagającej ręcznego startu przycisk zmienia się na „Zaczynam jeść”.

## Weryfikacja

Regresja korzysta z kontrolowanego zegara, lokalnej bazy i symulowanych danych o podaniu bolusa. Obejmuje wyprzedzenie prośby, zapis i start, ścieżki jedzenia, oczekiwanie, wznowienie po restarcie, zmianę terminu i równoległą aktywację. Natywne testy Wear OS porównują dane, tekst i widoczność akcji aplikacji z tym, co renderuje kafelek.

W regresji odtworzono dwa błędy przed poprawką. Wczesne „Akceptuj” uruchamiało etap bolusa, a rozpoczęty odczyt z Firebase blokował monitor mimo zapisanej już decyzji. Oba przypadki są objęte testami z lokalną bazą. Dane o bolusie były symulowane.

Wynik końcowy obejmuje 174 testy Fluttera oraz siedem sprawdzeń natywnych na emulatorze Wear OS. Cztery sprawdzenia porównują etapy aktywnego posiłku, a trzy sprawdzają widoki po akceptacji. Zbudowano i zainstalowano lokalne APK na obu telefonach i zegarkach. Weryfikacja nie obejmowała fizycznego zestawu ani faktycznego podania bolusa.
