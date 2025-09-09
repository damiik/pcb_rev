# Algorytm Connectivity i Generowanie Netlist w KiCad

Algorytm connectivity w KiCad dla przewodów, junction i pinów pracuje jako **graph traversal / union-find algorithm** z logiką **propagacji nazw netów** w obrębie *connected components*.

## Podstawowe struktury danych

```
CONNECTION_GRAPH          // globalny graf połączeń schematu
├─ CONNECTION_SUBGRAPH    // pojedynczy connected component (1 net)
├─ SCH_CONNECTION         // obiekt reprezentujący net z nazwą i właściwościami
└─ CONNECTION_ITEM        // bazowa klasa dla elementów topologicznych:
                          //   wire, junction, pin, label, port, bus entry
```

## Algorytm obliczania connectivity

### 1. **Graph Construction Phase**

```
For each schematic sheet:
  Parse all items (wire, junction, pin, label, port, bus_entry)
    - Utwórz CONNECTION_ITEM node z jego współrzędnymi
    - Oblicz punkty przecięcia (wire-wire, wire-junction, wire-pin, wire-label, wire-port)
    - Zbuduj relacje adjacency (lista sąsiadów)
```

> **Uwaga:** KiCad używa dokładnych współrzędnych całkowitoliczbowych (int) aby unikać błędów precyzji.

---

### 2. **Connectivity Resolution (Graph Traversal)**

Każdy *connected component* jest wyznaczany przez **DFS / flood-fill traversal**:

```python
for each unvisited CONNECTION_ITEM:
    subgraph = new CONNECTION_SUBGRAPH()
    stack = [current_item]
    
    while stack not empty:
        item = stack.pop()
        if item.visited: continue
        
        item.visited = true
        subgraph.add(item)
        
        for neighbor in item.connected_items():
            if not neighbor.visited:
                stack.push(neighbor)
```

---

### 3. **Geometric Connection Rules**

* **Wire ↔ Wire**: połączenie, gdy końcowe punkty się pokrywają
* **Wire ↔ Junction**: połączenie, gdy kończy się w punkcie junction
* **Wire ↔ Pin**: połączenie, gdy kończy się w pozycji pinu symbolu
* **Wire ↔ Label / Port**: połączenie, gdy label/port leży na końcu przewodu
* **Junction łączy wszystko**: junction w punkcie `(x,y)` łączy wszystkie itemy przecinające ten punkt
* **Bus / Net entry**: traktowane jako specjalne "mostki" łączące nety o zgodnej nazwie z magistralą

---

### 4. **Net Name Propagation**

Nazwa netu propaguje się przez cały *connected component* zgodnie z hierarchią priorytetów:

1. **Explicit labels** – lokalne, globalne i hierarchiczne etykiety
2. **Hierarchical pins & ports** – łączą nety pomiędzy arkuszami
3. **Power symbols** – przypisują net nazwę np. `VCC`, `GND` (implicit global)
4. **Auto-generated names** – `Net-(U1-Pad3)` lub `Net-xxx`

> Jeśli w jednym *subgraph* istnieje wiele labeli, stosowane są reguły unifikacji (konflikty oznaczane są jako błędy DRC).

---

### 5. **Netlist Generation**

Zbudowany graf przekształcany jest w netlistę:

```
For each CONNECTION_SUBGRAPH:
    net_name = resolve_net_name(subgraph)
    pins = collect_all_pins(subgraph)
    
    netlist.add_net(net_name, pins)
```

---

### 6. **Hierarchical Schematic Support**

* **Hierarchical sheets**: CONNECTIVITY\_GRAPH obejmuje wszystkie arkusze
* **Hierarchical pins**: działają jako "porty" łączące nety między parent/child sheet
* **Global labels**: dostępne we wszystkich arkuszach
* **Local labels**: ograniczone do bieżącego arkusza

---

## Kluczowe aspekty implementacyjne

* **Geometric precision**: integer coordinates → brak błędów zaokrągleń
* **Incremental updates**: connectivity przeliczana tylko dla zmodyfikowanego obszaru
* **Junction semantics**: junction segmentuje przewody dla selekcji, ale logicznie wszystkie należą do jednego netu
* **Union-Find acceleration**: KiCad stosuje indeksowanie przestrzenne + lazy evaluation, aby obsłużyć duże schematy wydajnie

