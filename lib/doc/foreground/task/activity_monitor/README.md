# Activity monitor

Activity monitor to foreground task odpowiedzialny za pilnowanie zaplanowanej lub aktywnej aktywnosci. Dziala jako maszyna stanow, ktora reaguje na eventy z collectorow oraz na zmiany wykonane recznie przez uzytkownika.

## Co potrafi

- Wyszukuje najblizszy activity log i buduje kontekst monitorowania na podstawie aktywnosci, jej nazwy, czasu startu oraz czasu trwania.
- Czeka na zaplanowany start aktywnosci, a gdy start jest w przyszlosci, przechodzi przez stan `MonitorUntilActivityExecutor`.
- Na 45 minut przed aktywnoscia prosi o ustawienie activity temp targetu.
- Ponawia prosbe o activity temp target co 5 minut, az collector treatments wykryje `TemporaryTarget` albo nadejdzie czas startu aktywnosci.
- Reaguje na `NextActivityEvent`, jezeli pojawi sie inna aktywnosc do monitorowania.
- Reaguje na `ActivityStartedEvent` i przechodzi do monitorowania aktywnej aktywnosci.
- Reaguje na `ActivityStoppedEvent` oraz `ActivityCancelledEvent`, zeby przerwac aktualny stan i przejsc do finalizacji.
- Dla aktywnosci z ustawionym czasem trwania czeka do planowanego konca, a potem pyta uzytkownika, czy trening zostal zakonczony.
- Po potwierdzeniu zakonczenia ustawia `endedAt` w activity logu.
- Jezeli zaplanowana aktywnosc zostala zakonczona zanim realnie wystartowala, usuwa activity log zamiast oznaczac go jako zakonczony.
- Jezeli uzytkownik wybierze, ze zakonczy aktywnosc recznie, monitor czeka na event zamkniecia aktywnosci.
- Dla aktywnosci bez czasu trwania monitor nie zgaduje konca, tylko czeka na reczne zatrzymanie lub anulowanie.
- Po finalizacji czysci kontekst i anuluje aktywne powiadomienia foreground monitora.

## W czym pomaga

- Zmniejsza ryzyko, ze uzytkownik zapomni ustawic temp target przed aktywnoscia.
- Nie traktuje powiadomienia jako wystarczajacej akcji: czeka na realny `TemporaryTarget` z treatmentow.
- Pozwala prowadzic aktywnosc jako proces, a nie tylko jako pojedynczy wpis w bazie.
- Synchronizuje sie z akcjami uzytkownika wykonanymi poza monitorem, na przyklad recznym startem, zatrzymaniem albo anulowaniem aktywnosci.
- Wykorzystuje czas trwania aktywnosci do przypomnienia o jej zakonczeniu.
- Dla aktywnosci manualnych nie zamyka treningu automatycznie, wiec uzytkownik zachowuje kontrole.
- Po zakonczeniu wraca do szukania kolejnej aktywnosci, dzieki czemu monitor moze obslugiwac nastepne zaplanowane wpisy.

## Glowny przeplyw stanow

1. `NewActivityCheckExecutor` szuka najblizszego activity logu.
2. `MonitorUntilActivityExecutor` czeka do okna startu aktywnosci i obsluguje przypomnienia o temp target.
3. `MonitorActiveActivityExecutor` monitoruje aktywna aktywnosc, czeka na koniec albo na reczne zatrzymanie.
4. `FinishActivityExecutor` czysci stan i wraca do wyszukiwania kolejnej aktywnosci.

## Obecne ograniczenia

- Monitor aktywnej aktywnosci nie przewiduje jeszcze spadku glikemii i nie wysyla ostrzezenia typu "za 15 minut niski cukier".
- Wykrycie ustawienia temp targetu opiera sie na pojawieniu sie `TreatmentAvailableEvent<TemporaryTarget>`, bez dodatkowego sprawdzenia, czy target na pewno dotyczy tej konkretnej aktywnosci.
- Dla aktywnosci bez czasu trwania monitor czeka na reczny stop albo cancel i nie ma wlasnego limitu czasu.
