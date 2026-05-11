# Meal monitor

Meal monitor to foreground task odpowiedzialny za prowadzenie uzytkownika od zaplanowanego posilku, przez decyzje o bolusie i jedzeniu, az do finalizacji oraz przypomnienia o podsumowaniu posilku. Dziala jako maszyna stanow reagujaca na meal eventy, device status, treatmenty i odpowiedzi z powiadomien.

## Co potrafi

- Wyszukuje najblizszy zaplanowany posilek i dobiera stan monitora na podstawie statusu posilku.
- Reaguje na `NextMealEvent`, gdy pojawi sie nowszy lub wazniejszy posilek do monitorowania.
- Reaguje na `MealStatusChangedEvent`, zeby przerwac aktualny stan i przejsc do przeplywu zgodnego z nowym statusem posilku.
- Normalizuje czas posilku do rytmu odczytow CGM, uzywajac ostatniego `DeviceStatus`.
- Przed posilkiem dzieli prace na okna: oczekiwanie do okna monitorowania, sugestie temp targetu oraz meal advisor.
- W oknie temp targetu prosi o ustawienie meal temp targetu, gdy glikemia jest powyzej 100.
- Ponawia prosbe o meal temp target co 5 minut, az collector treatments wykryje `TemporaryTarget` albo monitor przejdzie do kolejnego okna.
- W oknie meal advisor zbiera makroskladniki posilku oraz aktualny `DeviceStatus`.
- Wylicza rekomendacje: jedz teraz i bolus pozniej, bolus i jedz teraz albo bolus, poczekaj i dopiero jedz.
- Wysyla powiadomienie z rekomendacja i czeka na decyzje uzytkownika.
- Obsluguje snooze rekomendacji, przeliczajac planowany czas posilku po przesunieciu.
- Obsluguje scenariusz bolus-then-wait: czeka na treatment z kalkulatora, monitoruje trend glikemii i moze skrocic czekanie, gdy cukier szybko spada.
- Po jedzeniu cyklicznie pyta, czy uzytkownik skonczyl posilek.
- Gdy potrzebny jest bolus po jedzeniu, wysyla osobna sugestie bolusa i czeka na treatment z kalkulatora.
- Obsluguje dodatkowy posilek przez sprawdzenie add-on carbs i przypomnienie o wpisie w kalkulatorze.
- Aktualizuje status posilku, na przyklad `bolused-waiting`, `waited-eating`, `bolused-eating`, `eaten`, `eaten-extra` albo `eaten-bolused`.
- Po finalizacji anuluje aktywne powiadomienia i planuje przypomnienie o podsumowaniu posilku.

## W czym pomaga

- Zdejmuje z uzytkownika koniecznosc pamietania o wszystkich krokach wokol posilku.
- Pilnuje, zeby temp target przed posilkiem byl rzeczywiscie ustawiony, a nie tylko zasugerowany jednym powiadomieniem.
- Laczy dane o posilku, insulinie, aktywnych weglowodanach, trendzie i aktualnej glikemii w jedna rekomendacje.
- Pomaga dobrac kolejnosc bolusa i jedzenia do aktualnej sytuacji glikemicznej.
- Moze skrocic oczekiwanie po bolusie, jezeli cukier zaczyna spadac szybciej niz zakladano.
- Przypomina o zakonczeniu posilku i o brakujacych akcjach, takich jak uzycie kalkulatora.
- Pilnuje finalnego statusu posilku, dzieki czemu dalsze widoki i statystyki moga opierac sie na aktualnym stanie.
- Po posilku przypomina o podsumowaniu, co pomaga domknac wpis i poprawic jakosc danych.

## Glowny przeplyw stanow

1. `NewMealCheckExecutor` szuka najblizszego posilku i mapuje jego status na odpowiedni executor.
2. `MonitorUntilMeal` czeka do okna posilku, obsluguje temp target i wylicza rekomendacje meal advisor.
3. `BolusThenWaitExecutor` prowadzi scenariusz, w ktorym uzytkownik powinien podac bolus i poczekac przed jedzeniem.
4. `DetectFinishedEatingExecutor` pilnuje zakonczenia jedzenia oraz ewentualnego bolusa po posilku.
5. `FinalizeMealExecutor` czysci stan, anuluje powiadomienia i planuje przypomnienie o podsumowaniu.

## Obecne ograniczenia

- Wykrycie ustawienia temp targetu opiera sie na pojawieniu sie `TreatmentAvailableEvent<TemporaryTarget>`, bez dodatkowego sprawdzenia, czy target na pewno dotyczy konkretnego posilku.
- Jesli brakuje aktualnego `DeviceStatus` albo danych makro, monitor czesto wraca do idle zamiast prowadzic alternatywny przeplyw naprawczy.
- Czesc timeoutow i progow jest obecnie zaszyta w executorach, na przyklad 5 minut dla ponawiania, 20 minut dla treatmentu z kalkulatora i 2 minuty dla przypomnienia o podsumowaniu.
