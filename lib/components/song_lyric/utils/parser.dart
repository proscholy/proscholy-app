import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:zpevnik/models/song_lyric.dart';
import 'package:zpevnik/components/song_lyric/utils/converter.dart';

abstract class Token {}

class Comment extends Token {
  final String value;

  Comment(String value) : value = value.trim();

  @override
  String toString() => 'Comment($value)';
}

class Chord extends Token {
  final String value;

  Chord(String value) : value = convertAccidentals(value, 0);

  @override
  String toString() => 'Chord($value)';
}

class ChordSubstitute extends Token {
  final int index;

  ChordSubstitute(this.index);

  @override
  String toString() => 'ChordSubstitute($index)';
}

class Interlude extends Token {
  late final String value;

  Interlude(String value) {
    value = value.trim().toLowerCase();

    switch (value) {
      case 'mezihra:':
        this.value = 'M:';
        break;
      case 'dohra:':
        this.value = 'Z:';
        break;
      case 'předehra:':
        this.value = 'P:';
        break;
      default:
        this.value = value;
    }
  }

  @override
  String toString() => 'Interlude($value)';
}

class InterludeEnd extends Token {
  @override
  String toString() => 'InterludeEnd()';
}

class NewLine extends Token {
  @override
  String toString() => 'NewLine()';
}

class VerseNumber extends Token {
  final String value;

  VerseNumber(this.value);

  bool _verseHasChord = false;

  bool get verseHasChord => _verseHasChord;

  @override
  String toString() => 'VerseNumber($value)';
}

class VerseSubstitute extends Token {
  final String id;

  VerseSubstitute(this.id);

  @override
  String toString() => 'VerseSubstitute($id)';
}

class VersePart extends Token {
  final String value;

  VersePart(this.value);

  @override
  String toString() => 'VersePart($value)';
}

class VerseEnd extends Token {
  @override
  String toString() => 'VerseEnd()';
}

enum _ParserState { chord, comment, lineStart, interlude, possibleVerseNumber, verseNumber, verseSubstitute, verseLine }

class _FilledTokensBuilder {
  final List<Token> filledTokens = [];

  final Map<String, List<Token>> verseSubstitutes = {};
  final List<Token> chordSubstitutes = [];

  VerseNumber? currentVerseNumber;

  List<Token> _fillSubstitutes(List<Token> tokens) {
    log(tokens.toString());

    if (tokens.isEmpty) return [];

    // log(songLyric.lyrics);
    // log(tokens.toString());

    bool isInsideInterlude = false;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (token is VerseNumber) {
        _fillVerseEnd();

        // substitute empty verses
        final emptyVerseEnd = _substituteEmptyVerse(i + 1, token.value, tokens);

        if (emptyVerseEnd != null) {
          i = emptyVerseEnd;
        } else {
          currentVerseNumber = token;

          _fillToken(token);
        }
      } else if (token is VerseSubstitute) {
        _fillVerseEnd();

        // substitute empty verses
        final emptyVerseEnd = _substituteEmptyVerse(i + 1, token.id, tokens);

        if (emptyVerseEnd != null) {
          i = emptyVerseEnd;
        } else {
          currentVerseNumber = VerseNumber(token.id);

          _fillToken(currentVerseNumber!);
        }
      } else if (token is VerseEnd) {
        _fillVerseEnd();
      } else if (token is NewLine) {
        // remove unintentional empty lines at the start and after verse numbers
        if (filledTokens.isNotEmpty && filledTokens.last is! VerseNumber) {
          _fillToken(token);
        }
      } else if (token is Chord) {
        if (!isInsideInterlude) _fillEmptyVerseNumber();

        currentVerseNumber?._verseHasChord = true;
        chordSubstitutes.add(token);

        _fillToken(token);
      } else if (token is ChordSubstitute) {
        _fillEmptyVerseNumber();

        currentVerseNumber!._verseHasChord = true;

        if (token.index < chordSubstitutes.length) _fillToken(chordSubstitutes[token.index]);
      } else if (token is Comment) {
        // checks if comment is last part of verse, if so, it will first end the verse and then start the comment
        final index = _commentIsInVerseEnd(i, tokens);

        if (index == null) {
          _fillToken(token);
        } else {
          _fillVerseEnd();

          while (i < index) {
            _fillToken(tokens[i++]);
          }
        }
      } else if (token is Interlude) {
        isInsideInterlude = true;
        _fillToken(token);
      } else if (token is InterludeEnd) {
        isInsideInterlude = false;
        _fillToken(token);
      } else {
        _fillEmptyVerseNumber();

        // remove leading space from first string after verse number
        if (filledTokens.isNotEmpty && filledTokens.last is VerseNumber && token is VersePart) {
          final trimmedValue = token.value.trimLeft();

          if (trimmedValue.isNotEmpty) {
            final trimmedToken = VersePart(trimmedValue);

            _fillToken(trimmedToken);
          }
        } else {
          _fillToken(token);
        }
      }
    }

    _fillVerseEnd();

    return filledTokens;
  }

  void _fillToken(Token token) {
    if (currentVerseNumber != null) verseSubstitutes.putIfAbsent(currentVerseNumber!.value, () => []).add(token);
    filledTokens.add(token);
  }

  void _fillEmptyVerseNumber() {
    if (currentVerseNumber == null) {
      currentVerseNumber = VerseNumber('');
      _fillToken(currentVerseNumber!);
    }
  }

  void _fillVerseEnd() {
    if (currentVerseNumber != null) {
      // make sure that before verse end there is a new line
      if (filledTokens.last is! NewLine) _fillToken(NewLine());

      _fillToken(VerseEnd());
    }

    currentVerseNumber = null;
  }

  int? _commentIsInVerseEnd(int i, List<Token> tokens) {
    while (true) {
      if (tokens[i] is VerseEnd) {
        return i;
      } else if (tokens[i] is! Comment && tokens[i] is! NewLine) {
        return null;
      }
      i++;
    }
  }

  int? _substituteEmptyVerse(int i, String verseNumber, List<Token> tokens) {
    final List<Comment> comments = [];

    while (true) {
      final token = tokens[i];

      if (token is Chord || (token is VersePart && token.value.trim().isNotEmpty)) {
        return null;
      } else if (token is Comment) {
        comments.add(token);
      } else if (token is VerseEnd) {
        final substitutes = verseSubstitutes[verseNumber] ?? verseSubstitutes[verseNumber.replaceFirst('.', ':')] ?? [];

        filledTokens.addAll(substitutes);
        filledTokens.addAll(comments);

        return i;
      }

      i++;
    }
  }
}

class SongLyricsParser {
  final SongLyric songLyric;

  SongLyricsParser(this.songLyric);

  List<Token>? _parsedSongLyrics;

  int _currentTokenIndex = 0;

  Token? get nextToken {
    _parsedSongLyrics ??= _FilledTokensBuilder()._fillSubstitutes(_parseTokens());

    // log(_parsedSongLyrics.toString());
    // log(songLyric.lyrics.toString());

    if (_currentTokenIndex == _parsedSongLyrics!.length) {
      _currentTokenIndex = 0;
      return null;
    }

    return _parsedSongLyrics![_currentTokenIndex++];
  }

  List<Token> _parseTokens() {
    final lyrics = songLyric.lyrics ?? '';
    final List<Token> tokens = [];

    _ParserState state = _ParserState.lineStart;

    String currentString = '';
    int chordSubstituteIndex = 0;

    bool isInsideVerse = false;
    bool isInsideInterlude = false;

    for (final c in lyrics.characters) {
      // handles verse number start (digits)
      if (state == _ParserState.lineStart && int.tryParse(c) != null) {
        chordSubstituteIndex = 0;

        state = _ParserState.verseNumber;
        currentString += c;

        continue;
      }

      switch (c) {
        // handles verse number start
        case 'B':
        case 'C':
        case 'R':
          if (state == _ParserState.lineStart) {
            chordSubstituteIndex = 0;

            state = _ParserState.possibleVerseNumber;
          }

          currentString += c;
          break;
        // handles verse number end
        case ':':
        case '.':
          currentString += c;

          if (state == _ParserState.verseNumber || state == _ParserState.possibleVerseNumber) {
            if (isInsideVerse) tokens.add(VerseEnd());
            if (isInsideInterlude) tokens.add(InterludeEnd());

            tokens.add(VerseNumber(currentString));

            currentString = '';
            state = _ParserState.verseLine;

            isInsideVerse = true;
            isInsideInterlude = false;
          }

          break;
        // handles verse substitute start
        case '(':
          if (state == _ParserState.lineStart) {
            currentString = '';
            state = _ParserState.verseSubstitute;
          }
          break;
        // handles verse substitute end
        case ')':
          if (state == _ParserState.verseSubstitute) {
            if (isInsideVerse) tokens.add(VerseEnd());
            if (isInsideInterlude) tokens.add(InterludeEnd());

            tokens.add(VerseSubstitute(currentString));

            currentString = '';
            state = _ParserState.verseLine;

            isInsideVerse = true;
            isInsideInterlude = false;
          }
          break;
        // handles interlude
        case '@':
          if (state == _ParserState.lineStart) {
            if (isInsideVerse) tokens.add(VerseEnd());

            currentString = '';
            state = _ParserState.interlude;

            isInsideVerse = false;
            isInsideInterlude = true;
          } else {
            currentString += c;
          }
          break;
        // handles start of chord
        case '[':
          if (currentString.isNotEmpty) {
            if (state == _ParserState.interlude) {
              tokens.add(Interlude(currentString));
            } else {
              tokens.add(VersePart(currentString));
            }
          }

          currentString = '';
          state = _ParserState.chord;
          break;
        // handles end of chord
        case ']':
          if (currentString == '%') {
            tokens.add(ChordSubstitute(chordSubstituteIndex++));
          } else if (currentString.isNotEmpty) {
            tokens.add(Chord(currentString));
          }

          currentString = '';
          state = _ParserState.verseLine;
          break;
        // handles comments
        case '#':
          if (state == _ParserState.lineStart) {
            if (isInsideInterlude) tokens.add(InterludeEnd());

            currentString = '';
            state = _ParserState.comment;

            isInsideInterlude = false;
          } else {
            currentString += c;
          }
          break;
        // handles end of line
        case '\r\n':
        case '\n':
          if (state == _ParserState.comment) {
            tokens.add(Comment(currentString));
          } else if (currentString.isNotEmpty) {
            tokens.add(VersePart(currentString));
            tokens.add(NewLine());
          } else {
            tokens.add(NewLine());
          }

          currentString = '';
          state = _ParserState.lineStart;
          break;
        default:
          if (state == _ParserState.lineStart) {
            state = _ParserState.verseLine;
          } else if (state == _ParserState.possibleVerseNumber && int.tryParse(c) == null) {
            state = _ParserState.verseLine;
          }

          currentString += c;
      }
    }

    if (state == _ParserState.comment) {
      tokens.add(Comment(currentString));
    } else if (currentString.isNotEmpty) {
      tokens.add(VersePart(currentString));
    }

    if (isInsideVerse) tokens.add(VerseEnd());
    if (isInsideInterlude) tokens.add(InterludeEnd());

    return tokens;
  }
}
