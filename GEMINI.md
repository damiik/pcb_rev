# Wytyczne Stylu i Architektury dla Projektu PCBRev (GEMINI.md)

Ten dokument opisuje kluczowe zasady programowania, architekturę i konwencje stosowane w projekcie PCBRev. Jego celem jest zapewnienie spójności kodu i ułatwienie dalszego rozwoju.

## 1. Główne Założenia Projektu

PCBRev to aplikacja Flutter wspierająca inżynierię odwrotną urządzeń elektronicznych. Umożliwia tworzenie schematów na podstawie pomiarów, analizy wizualnej PCB oraz wsparcia AI.

## 2. Kluczowe Zasady Stylu Programowania

Projekt odchodzi od nadmiernie rozbudowanego programowania obiektowego na rzecz **minimalistycznego i funkcyjnego podejścia**. Ma to na celu uproszczenie kodu, zwiększenie jego przewidywalności i przygotowanie podłoża pod docelowy model danych.

### 2.1. Podejście Funkcyjne ponad Obiektowe
- **Preferuj funkcje top-level:** Zamiast tworzyć klasy z metodami, grupuj logikę w postaci czystych funkcji na najwyższym poziomie. Klasy powinny być używane głównie tam, gdzie jest to wymagane przez framework (np. Widgety w Flutter).
- **Separacja danych i logiki:** Modele danych są pasywnymi strukturami, a operacje na nich są realizowane przez zewnętrzne funkcje (np. w warstwie serwisów).

### 2.2. Niezmienność (Immutability)
- **Niezmienne modele danych:** Wszystkie struktury przechowujące dane (modele) są niezmienne. Zamiast modyfikować obiekt, twórz jego nową instancję z zaktualizowanymi wartościami.
- **Wykorzystanie Rekordów (Records):** Modele danych są definiowane jako rekordy (`typedef RecordName = (...)`). Zapewnia to prostą i lekką składnię oraz gwarantuje niezmienność.
- **Wzorce `copyWith`:** W przypadku potrzeby "modyfikacji" rekordu, stosuj funkcje lub rozszerzenia (`extension`), które tworzą nową kopię rekordu z podmienionymi polami.

### 2.3. Zarządzanie Stanem
- **Stan jako rekord:** Stan komponentu lub serwisu jest reprezentowany przez pojedynczy, niezmienny rekord.
- **Przejścia stanowe jako funkcje:** Zmiany stanu są realizowane przez czyste funkcje, które przyjmują stary stan jako argument i zwracają nowy, zaktualizowany stan. Unikaj bezpośredniej mutacji stanu.

### 2.4. Wykorzystanie Pattern Matching do Destrukturyzacji Danych

Zamiast ręcznych sprawdzeń typów i kaskadowych `if-else`, projekt preferuje użycie nowoczesnego **pattern matching** w instrukcjach `switch` do dekonstrukcji złożonych, niezmiennych obiektów danych. Zapewnia to bardziej deklaratywny, bezpieczny i czytelny kod.

**Przykład (z `kicad_parser.dart`):**

Poniższy kod parsuje listę S-wyrażeń. Zamiast ręcznie sprawdzać typ i długość listy, a następnie rzutować jej elementy, `switch` z pattern matchingiem robi to w jednym, deklaratywnym kroku.

```dart
// `element` jest obiektem typu SExpr (np. SList lub SAtom)
switch (element) {
  // Wzorzec dopasowuje SList, którego lista `elements`
  // zaczyna się od SAtom z wartością 'version'.
  // Wartość drugiego atomu jest przypisywana do zmiennej `v`.
  case SList(
    elements: [SAtom(value: 'version'), SAtom(value: final v), ...],
  ):
    version = v;

  // Wzorzec dopasowuje SList zaczynający się od SAtom 'symbol'.
  // Wartość drugiego atomu jest przypisywana do `name`,
  // a reszta listy do zmiennej `rest`.
  case SList(
    elements: [
      SAtom(value: 'symbol'),
      SAtom(value: final name),
      ...final rest, // Wzorzec "rest"
    ],
  ):
    symbols.add(_parseSymbol(name, rest));

  // Domyślny przypadek dla elementów, które nie pasują do wzorców.
  default:
    break;
}
```

**Korzyści:**
- **Bezpieczeństwo typów:** Dopasowanie wzorca gwarantuje, że obiekt ma oczekiwaną strukturę przed próbą dostępu do jego pól.
- **Zwięzłość:** Eliminuje potrzebę pisania zagnieżdżonych warunków i rzutowania typów.
- **Czytelność:** Struktura wzorca wizualnie odzwierciedla strukturę danych, którą ma dopasować.

## 3. Architektura Funkcyjna

### 3.1. Struktura Modułowa (`lib/features/`)
Projekt jest zorganizowany w moduły funkcjonalne, gdzie każdy moduł odpowiada za konkretny obszar funkcjonalności. Struktura opiera się na podejściu **feature-first**, gdzie każdy feature jest samodzielną jednostką z własną architekturą wewnętrzną.

**Struktura modułu funkcjonalnego:**
```
features/
├── feature_name/
│   ├── data/           # Modele danych i źródła danych
│   ├── domain/         # Logika biznesowa (jeśli potrzebna)
│   ├── presentation/   # Widgety i zarządzanie stanem UI
│   └── api/           # Interfejsy API (opcjonalne)
```

### 3.2. Modele Danych (`lib/features/*/data/`)
Modele są zdefiniowane jako rekordy przy użyciu `typedef`. Każdy model posiada dedykowane, czyste funkcje do serializacji i deserializacji. Modele danych są niezmienne i znajdują się w podkatalogach `data/` poszczególnych modułów.

**Przykład (z modułu connectivity):**
```dart
// lib/features/connectivity/models/point.dart
typedef Point = ({double x, double y});

// Funkcje do konwersji
Map<String, dynamic> pointToJson(Point p) => {'x': p.x, 'y': p.y};
Point pointFromJson(Map<String, dynamic> json) => (x: json['x'], y: json['y']);
```

### 3.3. Logika Domenowa (`lib/features/*/domain/`)
Logika biznesowa jest implementowana jako czyste funkcje w podkatalogach `domain/` poszczególnych modułów. Funkcje te operują na niezmiennych modelach danych i nie zarządzają stanem bezpośrednio.

**Przykład (z modułu kicad):**
```dart
// lib/features/kicad/domain/kicad_schematic_parser.dart
Schematic parseSchematic(List<SExpr> expressions) {
  // Czysta funkcja parsująca S-wyrażenia na model Schematic
  return switch (expressions) {
    // Pattern matching dla różnych struktur danych
    [SList(elements: [SAtom(value: 'kicad_sch'), ...final rest])] =>
      _parseSchematicRest(rest),
    _ => throw FormatException('Invalid schematic format')
  };
}
```

### 3.4. Warstwa Prezentacji (`lib/features/*/presentation/`)
- **Widgety pozostają klasami:** Zgodnie z naturą Fluttera, widgety (zwłaszcza `StatefulWidget`) pozostają klasami.
- **Zarządzanie stanem w UI:** Stan UI jest zarządzany wewnątrz `State` widgetu. Interakcje z logiką biznesową odbywają się poprzez wywoływanie funkcji z warstwy domenowej.
- **Przekazywanie danych:** Do widgetów przekazywane są niezmienne modele (rekordy).

**Przykład (z modułu pcb_viewer):**
```dart
// lib/features/pcb_viewer/presentation/pcb_viewer_panel.dart
class PCBViewerPanel extends StatefulWidget {
  final ImageProcessor processor;

  const PCBViewerPanel({super.key, required this.processor});

  @override
  State<PCBViewerPanel> createState() => _PCBViewerPanelState();
}

class _PCBViewerPanelState extends State<PCBViewerPanel> {
  // Stan jako niezmienne rekordy
  late ImageState _imageState;

  void _updateImage(ImageModification modification) {
    setState(() {
      // Tworzenie nowego stanu zamiast mutacji
      _imageState = applyModification(_imageState, modification);
    });
  }
}
```

## 4. Przepływ Pracy przy Rozwoju

1.  **Analiza Modułu:** Zidentyfikuj, który moduł funkcjonalny w `lib/features/` odpowiada za wymaganą funkcjonalność.
2.  **Definiowanie Modeli:** Zawsze zaczynaj od zdefiniowania niezmiennych rekordów w odpowiednim podkatalogu `lib/features/[nazwa_modułu]/data/`.
3.  **Tworzenie Logiki Domenowej:** Implementuj logikę biznesową jako czyste funkcje w `lib/features/[nazwa_modułu]/domain/`. Unikaj tworzenia klas-serwisów.
4.  **Integracja z UI:**
  - Widgety umieszczaj w `lib/features/[nazwa_modułu]/presentation/`
  - Podłącz logikę do widgetów, zarządzając stanem wewnątrz `State` i przekazując dane w dół drzewa widgetów w sposób niezmienny.
  - Jeśli potrzebny, zdefiniuj interfejs API w `lib/features/[nazwa_modułu]/api/`

5.  **Testowanie:** Pisz testy jednostkowe dla czystych funkcji, co jest znacznie prostsze niż testowanie klas z zależnościami.

**Przykład przepływu dla dodania nowej funkcjonalności:**
```bash
# 1. Utworzenie struktury nowego modułu
mkdir -p lib/features/new_feature/{data,domain,presentation}

# 2. Definicja modeli w data/
touch lib/features/new_feature/data/new_models.dart

# 3. Implementacja logiki w domain/
touch lib/features/new_feature/domain/new_logic.dart

# 4. Widgety w presentation/
touch lib/features/new_feature/presentation/new_widget.dart
```

Przestrzeganie tych zasad zapewni, że kod pozostanie prosty, łatwy do testowania i gotowy na dalszą ewolucję.

## 5. Zasady podziału projektu na mniejsze moduły

### 5.1 Logiczna spójność
Kiedy część projetku logicznie niezależna od reszty wtedy powinna tworzyć oddzielny moduł - nawet jeżeli jej rozmiar jest mnimalny, w przyszłości umożliwi to rozbudowę bez zbędnej refaktoryzacji

### 5.2 Ograniczenie kontekstu
Podział modułu na mniejsze podmoduły ułatwia analizę i edycję kodu modułu. Ograniczenie rozmiaru plików poniżej 500 linii powoduje drastyczną poprawę skupienia i wykorzystania kontekstu przez wspomagające programowanie systemy AI.
