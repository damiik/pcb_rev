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

### 3.1. Modele Danych (`lib/models/`)
Modele są zdefiniowane jako rekordy przy użyciu `typedef`. Każdy model posiada dedykowane, czyste funkcje do serializacji i deserializacji.

**Przykład (Position):**
```dart
// Definicja rekordu
typedef Position = ({double x, double y});

// Funkcje do konwersji
Map<String, dynamic> positionToJson(Position p) => {'x': p.x, 'y': p.y};
Position positionFromJson(Map<String, dynamic> json) => (x: json['x'], y: json['y']);
```

### 3.2. Serwisy (`lib/services/`)
Serwisy nie są już klasami. Zostały przekształcone w zbiory funkcji top-level. Jeśli serwis musi zarządzać stanem, stan ten jest jawnie przekazywany jako argument i zwracany jako wynik funkcji.

**Przykład (MeasurementService):**
```dart
// Rekord przechowujący stan
typedef MeasurementState = ({
  Map<String, double> resistanceMap,
  Map<String, double> voltageMap
});

// Czysta funkcja modyfikująca stan
MeasurementState recordResistance(
    MeasurementState state, String p1, String p2, double ohms) {
  final key = _getKey(p1, p2);
  // Zwróć nowy stan, nie modyfikuj starego
  return (
    ...state,
    resistanceMap: {...state.resistanceMap, key: ohms}
  );
}
```

### 3.3. Warstwa UI (`lib/ui/`)
- **Widgety pozostają klasami:** Zgodnie z naturą Fluttera, widgety (zwłaszcza `StatefulWidget`) pozostają klasami.
- **Zarządzanie stanem w UI:** Stan UI jest zarządzany wewnątrz `State` widgetu. Interakcje z logiką biznesową odbywają się poprzez wywoływanie funkcyjnych serwisów.
- **Przekazywanie danych:** Do widgetów przekazywane są niezmienne modele (rekordy).

## 4. Przepływ Pracy przy Rozwoju

1.  **Definiowanie Modeli:** Zawsze zaczynaj od zdefiniowania niezmiennych rekordów w `lib/data/`.
2.  **Tworzenie Logiki w Serwisach:** Implementuj logikę biznesową jako czyste funkcje w `lib/domain/`. Unikaj tworzenia klas-serwisów.
3.  **Integracja z UI:**
  - Widgety umieszczaj w ``lib/presetation``
  - Podłącz logikę do widgetów, zarządzając stanem wewnątrz `State` i przekazując dane w dół drzewa widgetów w sposób niezmienny.

4.  **Testowanie:** Pisz testy jednostkowe dla czystych funkcji, co jest znacznie prostsze niż testowanie klas z zależnościami.

Przestrzeganie tych zasad zapewni, że kod pozostanie prosty, łatwy do testowania i gotowy na dalszą ewolucję.

## 5. Zasady podziału projektu na mniejsze moduły

### 5.1 Logiczna spójność
Kiedy część projetku logicznie niezależna od reszty wtedy powinna tworzyć oddzielny moduł - nawet jeżeli jej rozmiar jest mnimalny, w przyszłości umożliwi to rozbudowę bez zbędnej refaktoryzacji

### 5.2 Ograniczenie kontekstu
Podział modułu na mniejsze podmoduły ułatwia analizę i edycję kodu modułu. Ograniczenie rozmiaru plików poniżej 500 linii powoduje drastyczną poprawę skupienia i wykorzystania kontekstu przez wspomagające programowanie systemy AI.
