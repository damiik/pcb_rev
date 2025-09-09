
# Propozycje narzędzi MCP dla agentów AI

Aby AI mogło czytać, analizować i modyfikować schematy KiCad, serwer MCP powinien udostępniać następujące narzędzia:

## **Odczyt i analiza**

* `get_netlist()` – zwraca aktualną netlistę (lista netów + piny)
* `get_symbol_instances()` – zwraca wszystkie instancje symboli na schemacie z ich pinami i pozycją
* `get_connectivity_graph()` – surowy graf połączeń (nodes = items, edges = adjacency)
* `get_labels_and_ports()` – lista etykiet i portów z ich powiązaniami
* `get_hierarchy_tree()` – struktura arkuszy schematu i ich interfejsów (TODO: do zaimplementowania w przyszłości)

## **Edycja schematu**

* `add_wire(start, end)` – dodaje odcinek przewodu
* `add_junction(position)` – dodaje junction w punkcie `(x,y)`
* `add_symbol(library_id, position)` – dodaje instancję symbolu z biblioteki
* `connect_pin_to_net(symbol_ref, pin_name, net_name)` – wymusza połączenie pinu do netu
* `add_label(position, net_name, scope)` – dodaje label lokalny/globalny/hierarchiczny
* `delete_item(item_id)` – usuwa element (wire, symbol, junction, label)

## **Sprawdzanie i walidacja**

* `run_drc()` – uruchamia reguły projektowe (Design Rule Check)
* `check_net_conflicts()` – wykrywa konflikty nazw netów w obrębie connected component
* `validate_connectivity(expected_netlist)` – porównuje schemat z oczekiwaną netlistą

