// Tokenizer for S-expression parsing
final class Token {
  final TokenType type;
  final String value;
  final int position;

  const Token(this.type, this.value, this.position);

  @override
  String toString() => '$type($value)';
}

enum TokenType { openParen, closeParen, string, number, symbol, eof }

final class Tokenizer {
  final String input;
  int position = 0;

  Tokenizer(this.input);

  List<Token> tokenize() {
    final tokens = <Token>[];

    while (position < input.length) {
      _skipWhitespace();

      if (position >= input.length) break;

      final char = input[position];
      final tokenStart = position;

      switch (char) {
        case '(':
          tokens.add(Token(TokenType.openParen, char, tokenStart));
          position++;
        case ')':
          tokens.add(Token(TokenType.closeParen, char, tokenStart));
          position++;
        case '"':
          final stringValue = _readString();
          tokens.add(Token(TokenType.string, stringValue, tokenStart));
        default:
          final symbolValue = _readSymbol();
          final tokenType = _isNumber(symbolValue)
              ? TokenType.number
              : TokenType.symbol;
          tokens.add(Token(tokenType, symbolValue, tokenStart));
      }
    }

    tokens.add(Token(TokenType.eof, '', position));
    return tokens;
  }

  void _skipWhitespace() {
    while (position < input.length && _isWhitespace(input[position])) {
      position++;
    }
  }

  bool _isWhitespace(String char) => ' \t\n\r'.contains(char);

  String _readString() {
    position++; // Skip opening quote
    final buffer = StringBuffer();

    while (position < input.length && input[position] != '"') {
      if (input[position] == '\\' && position + 1 < input.length) {
        position++; // Skip escape character
        buffer.write(input[position]);
      } else {
        buffer.write(input[position]);
      }
      position++;
    }

    if (position < input.length) position++; // Skip closing quote
    return buffer.toString();
  }

  String _readSymbol() {
    final buffer = StringBuffer();

    while (position < input.length &&
        !_isWhitespace(input[position]) &&
        !'()'.contains(input[position])) {
      buffer.write(input[position]);
      position++;
    }

    return buffer.toString();
  }

  bool _isNumber(String value) {
    return double.tryParse(value) != null;
  }
}
