import 'dart:io';
import 'dart:convert';
import '../data/kicad_symbol_models.dart';

import 'kicad_tokenizer.dart';

final class SExprParser {
  final List<Token> tokens;
  int position = 0;

  SExprParser(this.tokens);

  ParseResult<List<SExpr>> parse() {
    try {
      final expressions = <SExpr>[];

      while (!_isAtEnd()) {
        final expr = _parseExpression();
        if (expr != null) expressions.add(expr);
      }

      return ParseResult.success(expressions);
    } catch (e) {
      return ParseResult.failure('Parse error: $e');
    }
  }

  SExpr? _parseExpression() {
    if (_isAtEnd()) return null;

    return switch (_current().type) {
      TokenType.openParen => _parseList(),
      TokenType.string || TokenType.number || TokenType.symbol => _parseAtom(),
      _ => throw Exception('Unexpected token: ${_current()}'),
    };
  }

  SList _parseList() {
    _consume(TokenType.openParen);
    final elements = <SExpr>[];

    while (!_check(TokenType.closeParen) && !_isAtEnd()) {
      final expr = _parseExpression();
      if (expr != null) elements.add(expr);
    }

    _consume(TokenType.closeParen);
    return SList(elements);
  }

  SAtom _parseAtom() {
    final token = _advance();
    return SAtom(token.value);
  }

  Token _current() => tokens[position];
  bool _isAtEnd() =>
      position >= tokens.length || _current().type == TokenType.eof;
  bool _check(TokenType type) => !_isAtEnd() && _current().type == type;
  Token _advance() => tokens[position++];
  void _consume(TokenType type) {
    if (!_check(type))
      throw Exception('Expected $type, got ${_current().type}');
    _advance();
  }
}
