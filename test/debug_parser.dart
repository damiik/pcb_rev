import 'package:pcb_rev/features/symbol_library/domain/kicad_symbol_parser.dart';
import 'package:pcb_rev/features/symbol_library/domain/kicad_tokenizer.dart';
import 'package:pcb_rev/features/symbol_library/domain/kicad_sexpr_parser.dart';
import 'dart:io';

void main() async {
  final file = File(
    'lib/features/symbol_library/data/example_kicad_symbols.kicad_sym',
  );
  final content = await file.readAsString();

  print('=== TOKENIZING ===');
  final tokenizer = Tokenizer(content);
  final tokens = tokenizer.tokenize();
  print('Tokens count: ${tokens.length}');
  for (int i = 0; i < tokens.length && i < 20; i++) {
    print('Token $i: ${tokens[i]}');
  }

  print('\n=== PARSING S-EXPRESSIONS ===');
  final sexprParser = SExprParser(tokens);
  final parseResult = sexprParser.parse();

  parseResult.fold(
    (sexprs) {
      print('Parsed ${sexprs.length} S-expressions');
      for (int i = 0; i < sexprs.length; i++) {
        print('SExpr $i: ${sexprs[i]}');
      }
    },
    (error) {
      print('Parse error: $error');
    },
  );

  print('\n=== PARSING LIBRARY ===');
  final libraryResult = KiCadParser.parseLibrary(content);

  libraryResult.fold(
    (library) {
      print('Library parsed successfully:');
      print('  Version: ${library.version}');
      print('  Generator: ${library.generator}');
      print('  Symbols count: ${library.symbols.length}');
      for (final symbol in library.symbols) {
        print('  Symbol: ${symbol.name} with ${symbol.units.length} units');
      }
    },
    (error) {
      print('Library parse error: $error');
    },
  );
}
