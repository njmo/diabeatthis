# Pierwsza konfiguracja

## Wymagania

Zainstalowana aplikacja i dostęp do wybranego źródła danych. Nightscout jest
obsługiwanym źródłem; lokalne połączenie z AAPS jest opcjonalne.

## Kroki

1. Otwórz konfigurację aplikacji i wybierz źródło danych.
2. Dla Nightscout podaj adres swojej instancji oraz wymagane dane dostępu.
   Korzystaj z danych własnej instancji, a nie przykładowego publicznego serwera.
3. Zapisz konfigurację. Sprawdź, czy aplikacja pokazuje aktualny odczyt glukozy
   i czy jego czas odpowiada odczytowi w źródle danych.
4. Zezwól na powiadomienia, gdy Android o to poprosi.
5. Sprawdź ustawienia działania aplikacji w tle i oszczędzania baterii w telefonie,
   jeżeli system ogranicza monitorowanie. Nazwy tych ustawień zależą od producenta.
6. Jeśli chcesz odbierać dane lokalnie z AAPS, wykonaj
   [osobną instrukcję integracji](AAPS-integration).

## Oczekiwany rezultat

Dane są aktualne, a aplikacja ma możliwość wyświetlania przypomnień.
Przed poleganiem na monitorowaniu sprawdź jego działanie także przy wygaszonym ekranie.

## Gdy coś nie działa

Nieaktualny odczyt nie oznacza, że glukoza się nie zmienia. Sprawdź czas pomiaru,
połączenie i [poradnik rozwiązywania problemów](Troubleshooting).
