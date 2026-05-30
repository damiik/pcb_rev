import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'kicad_symbol_models.dart';
import '../domain/kicad_symbol_parser.dart';
import '../../../debug/log_service.dart';

/// Service for loading and caching KiCad symbol definitions
class KiCadLibrarySymbolLoader {
  final Map<String, LibrarySymbol> _symbolCache = {};
  final String? _libraryPath;
  KiCadLibrary? _library;

  /// Create a loader from a file path.
  KiCadLibrarySymbolLoader(this._libraryPath) : _library = null;

  /// Create a loader from an already parsed library.
  KiCadLibrarySymbolLoader.fromLibrary(KiCadLibrary library)
    : _library = library,
      _libraryPath = null {
    for (final symbol in library.librarySymbols) {
      _symbolCache[symbol.name] = symbol;
    }
  }

  /// Load a specific symbol by name
  Future<LibrarySymbol> loadLibrarySymbol(String symbolName) async {
    // Check cache first
    if (_symbolCache.containsKey(symbolName)) {
      return _symbolCache[symbolName]!;
    }

    // If not cached, load the full library
    final library = await _loadLibrary();

    // Find the symbol
    final symbol = library.librarySymbols.firstWhere(
      (symbol) => symbol.name == symbolName,
      orElse: () =>
          throw Exception('Library symbol "$symbolName" not found in library'),
    );

    // Cache and return
    _symbolCache[symbolName] = symbol;
    return symbol;
  }

  /// Load all symbols from the library
  Future<Map<String, LibrarySymbol>> loadAllLibrarySymbols() async {
    if (_symbolCache.isNotEmpty) {
      return _symbolCache;
    }

    final library = await _loadLibrary();

    // Cache all symbols
    for (final symbol in library.librarySymbols) {
      print('Default symbol library - Caching symbol: ${symbol.name}');
      _symbolCache[symbol.name] = symbol;
    }

    return _symbolCache;
  }

  /// Create a loader from raw content (web-compatible).
  factory KiCadLibrarySymbolLoader.fromContent(String content) {
    LogService.instance.info('Parsing symbol library from content...');
    final parseResult = KiCadParser.parseLibrary(content);
    return parseResult.fold(
      (library) {
        LogService.instance
            .success('Symbol library loaded with ${library.librarySymbols.length} symbols');
        return KiCadLibrarySymbolLoader.fromLibrary(library);
      },
      (error) {
        LogService.instance.error('Failed to parse symbol library: $error');
        throw Exception('Failed to parse KiCad library: $error');
      },
    );
  }

  /// Load the KiCad library file or return the in-memory one.
  Future<KiCadLibrary> _loadLibrary() async {
    if (_library != null) return _library!;
    if (_libraryPath == null) {
      throw Exception('No library path provided to KiCadSymbolLoader');
    }

    try {
      if (kIsWeb) {
        throw Exception(
            'Cannot load from file path on web. Use KiCadLibrarySymbolLoader.fromContent() instead.');
      }

      final file = File(_libraryPath!);
      if (!file.existsSync()) {
        throw Exception('Symbol library file not found at: $_libraryPath');
      }

      LogService.instance.info('Loading symbol library from: $_libraryPath');
      final content = await file.readAsString();
      final parseResult = KiCadParser.parseLibrary(content);

      return parseResult.fold((library) {
        _library = library;
        LogService.instance
            .success('Symbol library loaded with ${library.librarySymbols.length} symbols');
        return library;
      }, (error) {
        LogService.instance.error('Failed to parse KiCad library: $error');
        throw Exception('Failed to parse KiCad library: $error');
      });
    } catch (e) {
      LogService.instance.error('Error loading KiCad library: $e');
      throw Exception('Error loading KiCad library: $e');
    }
  }

  /// Clear the symbol cache
  void clearCache() {
    _symbolCache.clear();
  }

  /// Get cached symbol names
  List<String> get cachedSymbolNames => _symbolCache.keys.toList();

  /// Check if a symbol is cached
  bool isSymbolCached(String symbolName) =>
      _symbolCache.containsKey(symbolName);

  LibrarySymbol? getSymbolByName(String symbolName) {
    return _symbolCache[symbolName];
  }

  List<LibrarySymbol> getSymbols() {
    return _symbolCache.values.toList();
  }
}
