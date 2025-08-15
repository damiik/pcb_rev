# PCBRev: Asystent Inżynierii Odwrotnej PCB

## 1. Założenia Projektu

PCBRev to aplikacja Flutter, której celem jest wspieranie inżynierii odwrotnej urządzeń elektronicznych. Umożliwia ona użytkownikom tworzenie schematów urządzeń na podstawie pomiarów fizycznych i analizy wizualnej płytek PCB, z wykorzystaniem wsparcia sztucznej inteligencji.

### 1.1. Podstawowa Funkcjonalność

Aplikacja ma za zadanie ułatwić proces rekonstrukcji schematu urządzenia elektronicznego poprzez:
- **Pomiary komponentów i połączeń:** Rejestrowanie wartości komponentów (np. rezystancji, pojemności) oraz śledzenie połączeń między nimi za pomocą omomierza lub innych narzędzi pomiarowych.
- **Analiza wizualna PCB:** Przetwarzanie zdjęć płytek PCB (zarówno strony komponentów, jak i strony połączeń) w celu dopasowania ich i wnioskowania o połączeniach między komponentami/wyprowadzeniami. Kluczowym elementem jest możliwość odwrócenia poziomego strony połączeń (dolnej) i nałożenia jej na stronę komponentów (górnej), co pozwala na wizualizację połączeń między warstwami płytki.
- **Wsparcie AI:** Wykorzystanie sztucznej inteligencji (za pośrednictwem `mcp-server`) do interpretacji połączeń, identyfikacji komponentów i analizy architektury urządzenia. AI otrzymuje bazę danych z aktualnymi danymi urządzenia, jego połączeniami, architekturą i obrazami, a następnie aktualizuje tę bazę.






### 1.2. Platforma Docelowa

Aplikacja jest rozwijana w technologii Flutter, co umożliwia jej działanie na wielu platformach, w tym na **Androidzie**, co jest głównym celem projektu. Architektura została zaprojektowana z myślą o skalowalności i łatwej adaptacji do różnych środowisk.

### 1.3. Kluczowe Funkcje

- **Zarządzanie obrazami PCB:** Wczytywanie i wyświetlanie zdjęć PCB (strona komponentów, strona połączeń).
- **Narzędzia do edycji obrazu:** Obracanie, odwracanie (poziome/pionowe - kluczowe dla nałożenia strony połączeń na stronę komponentów), regulacja kontrastu, jasności i inwersja kolorów dla lepszej analizy wizualnej.
- **Rejestrowanie pomiarów:** Moduł do wprowadzania i zarządzania pomiarami rezystancji, napięcia i ciągłości.
- **Modelowanie schematu:** Tworzenie i aktualizowanie cyfrowego modelu PCB, zawierającego komponenty, piny i połączenia (netlistę).
- **Integracja z AI (MCP Server):** Dwukierunkowa komunikacja z zewnętrznym serwerem AI, wysyłając dane PCB i obrazy do analizy oraz odbierając wyniki.
- **Zapis/Odczyt Projektu:** Możliwość zapisywania i wczytywania stanu projektu (w tym obrazów i ich modyfikacji) do/z pliku.

## 2. Architektura Aplikacji

### 2.1. Przegląd

Architektura PCBRev opiera się na warstwowym podejściu, co zapewnia modularność, łatwość testowania i rozszerzalność. Główne warstwy to:
- **Warstwa UI (User Interface):** Odpowiedzialna za prezentację danych i interakcję z użytkownikiem.
- **Warstwa Serwisów (Services):** Zawiera logikę biznesową i komunikację z zewnętrznymi systemami.
- **Warstwa Danych (Data/Models):** Definiuje struktury danych używane w aplikacji.

### 2.2. Modele Danych

Modele danych są kluczowe dla reprezentacji stanu PCB i są zdefiniowane w katalogu `lib/models/`:
- `pcb_models.dart`: Zawiera podstawowe definicje, takie jak `Component`, `Pin`, `Net`, `ConnectionPoint`, `Position`.
- `pcb_board.dart`: Definiuje główny model `PCBBoard`, który agreguje wszystkie dane dotyczące aktualnie analizowanej płytki, w tym listę obrazów (`PCBImage`) i ich modyfikacje (`ImageModification`).
- `image_modification.dart`: Nowo dodany model przechowujący parametry modyfikacji obrazu (obrót, odwrócenie, kontrast, jasność, inwersja kolorów).

### 2.3. Serwisy

Serwisy implementują logikę aplikacji i interakcje z systemem:
- `image_processor.dart`: Odpowiedzialny za przetwarzanie obrazów, w tym ich wzmacnianie i potencjalne wyrównywanie.
- `measurement_service.dart`: Zarządza rejestrowaniem i generowaniem raportów z pomiarów elektrycznych.
- `mcp_server.dart`: Działa jako most komunikacyjny z zewnętrznym serwerem AI, wysyłając dane PCB i obrazy do analizy oraz odbierając wyniki.

### 2.4. Interfejs Użytkownika (UI)

Interfejs użytkownika jest zbudowany z komponentów Flutter i podzielony na mniejsze, reużywalne widżety:
- `main_screen.dart`: Główny ekran aplikacji, agregujący pozostałe panele.
- `widgets/component_list_panel.dart`: Wyświetla listę komponentów na PCB.
- `widgets/pcb_viewer_panel.dart`: Centralny panel do wyświetlania obrazów PCB, obsługujący przeciąganie i upuszczanie plików, nawigację między obrazami oraz kontrolki do ich modyfikacji.
- `widgets/properties_panel.dart`: Panel boczny do wyświetlania właściwości i zarządzania pomiarami.

### 2.5. Diagram Architektury

```mermaid
graph TD
    A[PCBRev App] --> B(Warstwa UI);
    B --> C{Główny Ekran};
    C --> D[Panel Listy Komponentów];
    C --> E[Panel Przeglądarki PCB];
    C --> F[Panel Właściwości];

    A --> G(Warstwa Serwisów);
    G --> H{ImageProcessor};
    G --> I{MeasurementService};
    G --> J{MCPServer};

    A --> K(Warstwa Danych);
    K --> L{PCBBoard Model};
    K --> M{Component Model};
    K --> N{Net Model};
    K --> O{ImageModification Model};
    K --> P{PCBImage Model};
    K --> Q{Pin Model};
    K --> R{Position Model};
    K --> S{Annotation Model};
    K --> T{Size Model};
    K --> U{ConnectionPoint Model};

    E --> H;
    F --> I;
    J --> V((Serwis AI));

    L --> M;
    L --> N;
    L --> P;
    L --> O;
    P --> S;
    S --> R;
    S --> T;
    M --> Q;
    M --> R;
    N --> U;
    U --> R;
```

## 3. Koncepcja Pracy i Model Danych (Workflow)

Aplikacja PCBRev jest zaprojektowana wokół interaktywnego procesu tworzenia schematu, inspirowanego standardami oprogramowania CAD, takiego jak KiCad. Poniżej opisano kluczowe koncepcje przepływu pracy oraz model danych, który leży u podstaw aplikacji.

### 3.1. Interfejs Użytkownika

Główny interfejs aplikacji jest podzielony na trzy panele, aby zapewnić efektywną organizację pracy:
- **Panel Lewy (Listy Globalne):** Zawiera listę wszystkich zidentyfikowanych komponentów oraz sieci (połączeń) w projekcie. Listy te są globalne dla całego projektu i pogrupowane według typów (np. rezystory, kondensatory).
- **Panel Centralny (Widok Roboczy):** Jest to główny obszar roboczy, który może działać w dwóch trybach:
    - **Widok Obrazu:** Wyświetla załadowane zdjęcia PCB, umożliwiając ich analizę i nakładanie adnotacji.
    - **Widok Schematu:** Działa jak edytor schematów, na którym użytkownik może umieszczać symbole komponentów i rysować połączenia.
- **Panel Prawy (Właściwości i Pomiary):** Służy do wyświetlania szczegółów zaznaczonego elementu oraz do zarządzania operacjami ogólnymi, takimi jak wprowadzanie wyników pomiarów.

### 3.2. Proces Tworzenia Schematu

Proces rekonstrukcji schematu jest iteracyjny i opiera się na poniższych krokach:

1.  **Dodawanie Obrazów:** Użytkownik rozpoczyna od załadowania zdjęć płytki PCB.
2.  **Identyfikacja Komponentów:** Na podstawie analizy wizualnej i pomiarów, użytkownik dodaje komponenty do globalnej listy w lewym panelu.
3.  **Tworzenie Schematu:** Użytkownik przełącza się na widok schematu. Komponenty z globalnej listy można przeciągać na obszar roboczy jako symbole. Każdy symbol posiada punkty połączeń (piny), które przyciągane są do siatki, co ułatwia precyzyjne rysowanie.
4.  **Definiowanie Połączeń (Netów):** Użytkownik rysuje połączenia (linie - *wires*) pomiędzy pinami komponentów lub innymi połączeniami. Każde narysowane połączenie tworzy lub aktualizuje logiczną sieć (*Net*) w globalnej netliście projektu.

### 3.3. Model Danych Inspirowany KiCad

Kluczowym elementem architektury jest rozdzielenie **modelu logicznego** od jego **reprezentacji wizualnej**.

-   **Model Logiczny (Globalny):**
    -   **Net (Sieć):** Reprezentuje logiczne połączenie między co najmniej dwoma punktami (pinami komponentów). Jest to abstrakcyjny zbiór węzłów, podobnie jak w netliście KiCad. Przykładowo, sieć `VCC` łączy wszystkie piny, które mają być podłączone do zasilania.
        ```
        (net (code 1) (name "VCC")
          (node (ref V1) (pin 1))
          (node (ref R1) (pin 1))
          (node (ref U1) (pin 1)))
        ```
    -   **Component (Komponent):** Globalna definicja komponentu, zawierająca jego ID, typ, wartość i listę pinów.

-   **Reprezentacja Wizualna (Lokalna dla Widoku):**
    -   Każdy widok (czy to schemat, czy obraz PCB) posiada własną listę elementów wizualnych, które odnoszą się do modelu logicznego. Oznacza to, że **każdy obraz ma własną listę komponentów** (będących referencjami do listy globalnej), gdzie każdy komponent ma określone, lokalne współrzędne dla swoich punktów połączeń (pinów). Podobnie, **każdy obraz posiada własną listę wizualnych reprezentacji sieci**, które odnoszą się do globalnej netlisty, ale posiadają niezależne współrzędne dla węzłów i przewodów, tworząc jedynie wizualny kształt połączenia na danym obrazie.
    -   **Symbol:** Wizualna reprezentacja komponentu na schemacie, posiadająca współrzędne (`at`), referencję (`ref`) i inne atrybuty graficzne.
    -   **Wire (Przewód):** Linia graficzna łącząca punkty na schemacie. Posiada współrzędne (`pts`) definiujące jej kształt.
    -   **Junction (Węzeł):** Punkt graficzny wskazujący na połączenie kilku przewodów.
        ```
        (symbol (lib_id "Power:VCC") (at 100 50 0) (ref "V1") ...)
        (wire (pts (xy 100 50) (xy 120 50)))
        (junction (at 120 50))
        ```
    - Taki podział pozwala na elastyczność: ta sama logiczna sieć `VCC` może być inaczej narysowana na schemacie, a inaczej reprezentowana jako adnotacja na zdjęciu PCB. Użytkownik może dodawać komponenty i sieci z globalnej listy do dowolnego widoku, a ich pozycja i wygląd będą zapisane lokalnie dla tego widoku, nie wpływając na inne.

## 4. Szczegóły Implementacji (Aktualny Stan)

Projekt jest w fazie aktywnego rozwoju, a poniżej przedstawiono kluczowe aspekty obecnej implementacji.

### 4.1. Struktura Projektu

```
pcb_rev/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── image_modification.dart
│   │   ├── pcb_board.dart
│   │   └── pcb_models.dart
│   ├── services/
│   │   ├── image_processor.dart
│   │   ├── mcp_server.dart
│   │   └── measurement_service.dart
│   └── ui/
│       ├── main_screen.dart
│       └── widgets/
│           ├── component_list_panel.dart
│           ├── pcb_viewer_panel.dart
│           ├── properties_panel.dart
│           └── schematic_painter.dart
├── pubspec.yaml
├── README.md
... (pozostałe pliki projektu Flutter)
```

### 4.2. Modele Danych (`lib/models/`)

Wszystkie modele danych posiadają implementacje metod `toJson()` oraz fabryk `fromJson()`, co umożliwia łatwą serializację i deserializację obiektów do formatu JSON, niezbędnego do zapisu/odczytu projektu oraz komunikacji z AI.

- `pcb_models.dart`:
    - `Component`: Reprezentuje komponent elektroniczny z ID, typem, wartością, numerem części, pinami, pozycją i warstwą.
    - `Pin`: Definiuje pin komponentu z ID, funkcją, nazwą sieci i pozycją.
    - `Net`: Reprezentuje sieć połączeń między pinami, z nazwą i listą punktów połączeń. Może zawierać dane pomiarowe (rezystancja, napięcie).
    - `ConnectionPoint`: Określa punkt połączenia na PCB, odwołując się do ID komponentu i pinu.
    - `Position`: Prosta klasa do przechowywania współrzędnych X i Y.
- `pcb_board.dart`:
    - `PCBBoard`: Główny kontener danych dla pojedynczej płytki PCB. Zawiera mapy komponentów i sieci, listę obrazów (`PCBImage`) oraz nowo dodaną mapę `imageModifications`, która przechowuje modyfikacje dla każdego obrazu na podstawie jego ID.
    - `PCBImage`: Reprezentuje obraz PCB z ID, ścieżką do pliku, warstwą (góra/dół), typem obrazu i listą adnotacji.
    - `ImageType` (enum): Określa typ obrazu (komponenty, ścieżki, oba).
    - `Annotation`: Definiuje adnotację na obrazie, wskazując komponent, pozycję i rozmiar.
    - `Size`: Przechowuje szerokość i wysokość.
- `image_modification.dart`:
    - `ImageModification`: Przechowuje wszystkie parametry modyfikacji wizualnych dla danego obrazu: `rotation` (stopnie), `flipHorizontal`, `flipVertical`, `contrast` (-1 do 1), `brightness` (-1 do 1), `invertColors`.

### 4.3. Serwisy (`lib/services/`)

- `image_processor.dart`:
    - `enhanceImage(String imagePath)`: Funkcja do wstępnego przetwarzania obrazów (np. regulacja kontrastu, normalizacja) w celu poprawy widoczności. Zapisuje zmodyfikowany obraz do nowego pliku z sufiksem `_enhanced`.
    - `alignImages(...)`: (Placeholder) Docelowo będzie służyć do wyrównywania obrazów górnej i dolnej strony PCB.
- `measurement_service.dart`:
    - `recordResistance(...)`, `recordVoltage(...)`, `recordContinuity(...)`: Metody do rejestrowania różnych typów pomiarów.
    - `generateReport()`: Generuje podsumowanie zarejestrowanych pomiarów.
- `mcp_server.dart`:
    - `startServer()`: Uruchamia lokalny serwer HTTP, który służy jako punkt końcowy dla komunikacji z AI.
    - `analyzeImage(...)`: Wysyła obraz i aktualny stan PCB do serwisu AI w celu analizy. Obecnie zwraca zaślepkę (dummy response).
    - `_buildAnalysisPrompt()`: Buduje prompt dla AI, zawierający aktualny stan płytki i prośbę o identyfikację komponentów, połączeń i architektury.

### 4.4. Interfejs Użytkownika (`lib/ui/`)

- `main_screen.dart`:
    - `PCBAnalyzerApp` (StatefulWidget): Główny widżet aplikacji. Zarządza globalnym stanem (`currentBoard`, `_currentIndex`) i koordynuje interakcje między panelami.
    - `_handleImageDrop()`: Obsługuje przeciąganie i upuszczanie plików graficznych na panel przeglądarki PCB. Obrazy są przetwarzane, wysyłane do AI (zaślepka), a następnie dodawane do `currentBoard.images` w aktualnej pozycji.
    - `_updateImageModification()`: Aktualizuje parametry modyfikacji obrazu dla aktualnie wyświetlanego obrazu.
    - `_saveProject()`: Umożliwia zapisanie całego stanu `currentBoard` (wraz z obrazami i ich modyfikacjami) do pliku JSON (`.pcbrev`) za pomocą `file_picker`.
    - `_openProject()`: Umożliwia wczytanie projektu z pliku `.pcbrev`, deserializując dane do `currentBoard`.
- `widgets/component_list_panel.dart`: Prosty widżet `StatelessWidget` wyświetlający listę komponentów.
- `widgets/pcb_viewer_panel.dart`:
    - `StatelessWidget` odpowiedzialny za wyświetlanie aktualnego obrazu PCB.
    - Wykorzystuje `desktop_drop` do obsługi przeciągania i upuszczania plików.
    - Implementuje nawigację `onNext`/`onPrevious` dla obrazów.
    - Stosuje transformacje (`Transform.rotate`, `Transform`) i filtry kolorów (`ColorFiltered`) na wyświetlanym obrazie zgodnie z parametrami z `ImageModification`.
    - Zawiera kontrolki UI (przyciski, suwaki) do modyfikacji obrazu.
- `widgets/properties_panel.dart`: Widżet `StatelessWidget` do wyświetlania i dodawania pomiarów.

### 4.5. Zależności

Projekt wykorzystuje następujące kluczowe zależności (zdefiniowane w `pubspec.yaml`):
- `flutter`: Podstawowy framework UI.
- `http`: Do komunikacji HTTP (np. z MCP Server).
- `image`: Biblioteka do przetwarzania obrazów.
- `desktop_drop`: Do obsługi przeciągania i upuszczania plików na platformach desktopowych.
- `file_picker`: Do wyboru i zapisu plików przez użytkownika.

## 5. Jak Uruchomić

Aby uruchomić aplikację, wykonaj następujące polecenia w katalogu głównym projektu (`pcb_rev`):

```bash
cd pcb_rev
flutter run -d linux # lub inne dostępne urządzenie, np. chrome, windows, macos
```

## 6. Dalszy Rozwój

- **Rozbudowa analizy AI:** Implementacja rzeczywistej logiki analizy w `mcp_server` i integracja z modelem AI do inkrementalnej budowy schematu na podstawie analizy połączeń między komponentami.
- **Wyrównywanie i nałożenie obrazów:** Rozwinięcie funkcji `alignImages` w `ImageProcessor` do precyzyjnego dopasowywania obrazów, w tym odwrócenia poziomego strony połączeń (dolnej) i nałożenia jej na stronę komponentów (górnej) w celu wizualizacji połączeń między warstwami płytki.
- **Interaktywne adnotacje:** Umożliwienie użytkownikowi dodawania, edytowania i usuwania adnotacji bezpośrednio na obrazie PCB.
- **Generowanie netlisty:** Rozbudowa funkcji eksportu do standardowych formatów netlist (np. SPICE, KiCad).
- **Walidacja schematu:** Implementacja narzędzi do automatycznej weryfikacji poprawności rekonstruowanego schematu.
- **Wsparcie dla wielu warstw PCB:** Rozszerzenie modelu danych i UI o obsługę wielowarstwowych płytek.
