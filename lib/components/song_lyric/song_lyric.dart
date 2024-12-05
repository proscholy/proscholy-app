import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zpevnik/components/song_lyric/song_lyric_chips.dart';
import 'package:zpevnik/components/song_lyric/utils/active_player_controller.dart';
import 'package:zpevnik/components/song_lyric/utils/auto_scroll.dart';
import 'package:zpevnik/constants.dart';
import 'package:zpevnik/models/song_lyric.dart';
import 'package:zpevnik/providers/display_screen_status.dart';
import 'package:zpevnik/providers/presentation.dart';
import 'package:zpevnik/providers/settings.dart';
import 'package:zpevnik/components/song_lyric/utils/converter.dart';
import 'package:zpevnik/components/song_lyric/utils/lyrics_controller.dart';
import 'package:zpevnik/components/song_lyric/utils/parser.dart';
import 'package:zpevnik/utils/extensions.dart';

class SongLyricWidget extends ConsumerStatefulWidget {
  final SongLyric songLyric;
  final AutoScrollController autoScrollController;

  const SongLyricWidget({super.key, required this.songLyric, required this.autoScrollController});

  @override
  ConsumerState<SongLyricWidget> createState() => _SongLyricWidgetState();
}

class _SongLyricWidgetState extends ConsumerState<SongLyricWidget> {
  late final controller = LyricsController(widget.songLyric, context);

  final _presentationPartGlobalKeysMap = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();

    // listen for changes in presented verse and make sure it is visible
    context.providers.listen(
        presentationProvider.select((presentation) =>
            presentation.isPresenting && presentation.songLyric == widget.songLyric ? presentation.part : -1),
        (_, presentationPart) {
      final context = _presentationPartGlobalKeysMap[presentationPart]?.currentContext;

      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.05,
          duration: kDefaultAnimationDuration,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fontSizeScale = MediaQuery.textScaleFactorOf(context);

    final showLilypond = ref.watch(songLyricSettingsProvider(widget.songLyric.id)
        .select((songLyricSettings) => songLyricSettings.showMusicalNotes));

    return SingleChildScrollView(
      controller: widget.autoScrollController,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2 * kDefaultPadding),
              child: Text(widget.songLyric.name, style: theme.textTheme.titleLarge),
            ),
            SizedBox(height: fontSizeScale * kDefaultPadding / 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2 * kDefaultPadding),
              child: Text(widget.songLyric.authorsText, style: theme.textTheme.labelSmall),
            ),
            SizedBox(height: fontSizeScale * kDefaultPadding / 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2 * kDefaultPadding),
              child: SongLyricChips(songLyric: widget.songLyric),
            ),
            if (controller.hasLilypond && showLilypond)
              LayoutBuilder(
                builder: (_, constraints) => SvgPicture.string(
                  alignment: Alignment.centerLeft,
                  controller.lilypond,
                  theme: SvgTheme(currentColor: theme.colorScheme.onBackground),
                  width: min(constraints.maxWidth, fontSizeScale * controller.lilypondWidth),
                ),
              ),
            SizedBox(height: kDefaultPadding * fontSizeScale),
            MediaQuery(
              // double the text scale factor for lyrics as they look wrong with text scale factor < 1 and minimum is 0.5
              // font size is changed according to it
              data: MediaQuery.of(context).copyWith(textScaleFactor: 2 * MediaQuery.textScaleFactorOf(context)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2 * kDefaultPadding),
                child: _buildLyrics(context),
              ),
            ),
            SizedBox(height: kDefaultPadding * fontSizeScale),
            // make sure lyrics are visible with bottom sheet
            SizedBox(
                height: (ref.watch(presentationProvider.select((presentation) => presentation.isPresenting)) ||
                        ref.watch(activePlayerProvider.select((activePlayer) => activePlayer != null)))
                    ? (4 * kDefaultPadding +
                        (ref.watch(displayScreenStatusProvider.select((status) => status.fullScreen))
                            ? MediaQuery.of(context).padding.bottom
                            : 0))
                    : 0),
          ],
        ),
      ),
    );
  }

  Widget _buildLyrics(BuildContext context) {
    if (!widget.songLyric.hasLyrics) return Text('Text písně připravujeme.', style: _textStyle(context, false));

    final List<Widget> children = [];

    Token? currentToken = controller.parser.nextToken;
    int presentationPart = 0;

    while (currentToken != null) {
      if (currentToken is Comment) {
        children.add(_buildComment(context, currentToken, false));
      } else if (currentToken is Interlude) {
        if (ref.watch(songLyricSettingsProvider(widget.songLyric.id)
            .select((songLyricSettings) => songLyricSettings.showChords))) {
          children.add(_buildInterlude(context, currentToken));
        } else {
          while (currentToken != null && currentToken is! InterludeEnd) {
            currentToken = controller.parser.nextToken;
          }
        }
      } else if (currentToken is VerseNumber) {
        children.add(_buildVerse(context, currentToken, presentationPart));
      } else if (currentToken is NewLine) {
        children.add(SizedBox(height: kDefaultPadding * MediaQuery.textScaleFactorOf(context) * 3));
      } else if (currentToken is PresentationBreakpoint) {
        _presentationPartGlobalKeysMap.putIfAbsent(currentToken.part, () => GlobalKey());
        presentationPart = currentToken.part;
      }

      currentToken = controller.parser.nextToken;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildInterlude(BuildContext context, Interlude interlude) {
    final List<Widget> children = [];

    Token? currentToken = controller.parser.nextToken;

    while (currentToken != null && currentToken is! InterludeEnd) {
      if (currentToken is Chord) {
        children.add(
          _buildLine(context, currentToken, _textStyle(context, false), isInterlude: true),
        );
      } else if (currentToken is NewLine) {
        children.add(SizedBox(height: kDefaultPadding * MediaQuery.textScaleFactorOf(context) * 3));
      }

      currentToken = controller.parser.nextToken;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: kDefaultPadding / 2),
          child: Text(interlude.value, style: _textStyle(context, false)),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ],
    );
  }

  Widget _buildVerse(BuildContext context, VerseNumber number, int presentationPart) {
    final textStyle = _textStyle(context, number.verseHasChord);

    final List<Widget> children = [];
    final originalPresentationPart = presentationPart;

    Token? currentToken = controller.parser.nextToken;
    bool isFirstLine = true;

    while (currentToken != null && currentToken is! VerseEnd) {
      if (currentToken is VersePart || currentToken is Chord) {
        children.add(
          _buildLine(context, currentToken, textStyle, presentationPart: presentationPart, isFirst: isFirstLine),
        );
        isFirstLine = false;
      } else if (currentToken is Comment) {
        children.add(_buildComment(context, currentToken, number.verseHasChord));
      } else if (currentToken is NewLine) {
        children.add(SizedBox(height: kDefaultPadding * MediaQuery.textScaleFactorOf(context) * 3));
      } else if (currentToken is PresentationBreakpoint) {
        _presentationPartGlobalKeysMap.putIfAbsent(currentToken.part, () => GlobalKey());
        presentationPart = currentToken.part;
        isFirstLine = true;
      }

      currentToken = controller.parser.nextToken;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (number.value.isNotEmpty)
          Container(
            color: ref.watch(presentationProvider.select(
                    (presentation) => presentation.isPresenting && presentation.part == originalPresentationPart))
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            padding: const EdgeInsets.only(right: kDefaultPadding / 2),
            child: Text(number.value, style: textStyle),
          ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      ],
    );
  }

  Widget _buildLine(
    BuildContext context,
    Token token,
    TextStyle? textStyle, {
    int? presentationPart,
    bool? isFirst,
    bool isInterlude = false,
  }) {
    final List<InlineSpan> children = [];

    final hideChords = ref.watch(
        songLyricSettingsProvider(widget.songLyric.id).select((songLyricSettings) => !songLyricSettings.showChords));

    Token? currentToken = token;
    Chord? currentChord;
    while (currentToken != null && currentToken is! NewLine) {
      if (currentToken is VersePart) {
        if (currentChord == null || hideChords) {
          String text = currentToken.value;

          // merge followed `VersePart`s if not showing chords for better looks
          while (controller.parser.peekToken is VersePart || (hideChords && controller.parser.peekToken is Chord)) {
            currentToken = controller.parser.nextToken;

            if (currentToken is VersePart) text += currentToken.value;
          }

          children.add(WidgetSpan(child: Text(text, style: textStyle)));
        } else {
          children.add(_buildChord(context, currentChord, textStyle, versePart: currentToken));
          currentChord = null;
        }
      } else if (currentToken is Chord &&
          ref.watch(songLyricSettingsProvider(widget.songLyric.id)
              .select((songLyricSettings) => songLyricSettings.showChords))) {
        if (isInterlude) {
          children.add(_buildChord(context, currentToken, textStyle, isInterlude: true));
        } else if (currentChord != null) {
          children.add(_buildChord(context, currentChord, textStyle));
        }

        currentChord = currentToken;
      }

      currentToken = controller.parser.nextToken;
    }

    if (!isInterlude &&
        currentChord != null &&
        ref.watch(songLyricSettingsProvider(widget.songLyric.id)
            .select((songLyricSettings) => songLyricSettings.showChords))) {
      children.add(_buildChord(context, currentChord, textStyle));
    }

    return GestureDetector(
      onTap: ref.watch(presentationProvider.select((presentation) => presentation.isPresenting))
          ? () => ref.read(presentationProvider.notifier).changePart(presentationPart!)
          : null,
      child: Container(
        color: ref.watch(presentationProvider
                .select((presentation) => presentation.isPresenting && presentation.part == presentationPart))
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        child: RichText(
          key: (!isInterlude && isFirst!) ? _presentationPartGlobalKeysMap[presentationPart] : null,
          text: TextSpan(style: textStyle, children: children),
        ),
      ),
    );
  }

  Widget _buildComment(BuildContext context, Comment comment, bool hasChords) {
    final showChords = hasChords &&
        ref.watch(
            songLyricSettingsProvider(widget.songLyric.id).select((songLyricSettings) => songLyricSettings.showChords));
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 8,
          fontStyle: FontStyle.italic,
          height: showChords ? 2.5 : 1.5,
        );

    return Text(comment.value, style: textStyle);
  }

  WidgetSpan _buildChord(
    BuildContext context,
    Chord chord,
    TextStyle? textStyle, {
    VersePart? versePart,
    bool isInterlude = false,
  }) {
    final chordOffset = isInterlude ? 0.0 : -(textStyle?.fontSize ?? 0) * 2 * MediaQuery.textScaleFactorOf(context);

    String chordText = convertAccidentals(
        transpose(
            chord.value,
            ref.watch(songLyricSettingsProvider(widget.songLyric.id)
                .select((songLyricSettings) => songLyricSettings.transposition))),
        ref.watch(songLyricSettingsProvider(widget.songLyric.id)
            .select((songLyricSettings) => songLyricSettings.accidentals ?? widget.songLyric.defaultAccidentals)));

    int chordNumberIndex = chordText.indexOf('maj');
    if (chordNumberIndex == -1) {
      for (int i = 0; i < chordText.length; i++) {
        if (int.tryParse(chordText[i]) != null) {
          chordNumberIndex = i;
          break;
        }
      }
    }

    final chordColor = Theme.of(context).brightness.isLight ? const Color(0xff3961ad) : const Color(0xff4dc0b5);

    return WidgetSpan(
      child: Stack(children: [
        Container(
          transform: Matrix4.translationValues(0, chordOffset, 0),
          padding: EdgeInsets.only(right: MediaQuery.textScaleFactorOf(context) * kDefaultPadding / 2),
          child: chordNumberIndex == -1
              ? Text(chordText, style: textStyle?.copyWith(color: chordColor))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chordText.substring(0, chordNumberIndex),
                      style: textStyle?.copyWith(color: chordColor),
                    ),
                    Text(
                      chordText.substring(chordNumberIndex),
                      style: textStyle?.copyWith(
                        color: chordColor,
                        fontSize: (textStyle.fontSize ?? 17) * 0.8,
                      ),
                    ),
                  ],
                ),
        ),
        if (versePart != null) Text(versePart.value, style: textStyle),
      ]),
    );
  }

  TextStyle? _textStyle(BuildContext context, bool hasChords) {
    final showChords = hasChords &&
        ref.watch(
            songLyricSettingsProvider(widget.songLyric.id).select((songLyricSettings) => songLyricSettings.showChords));

    return Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 8,
          height: showChords ? 2.25 : 1.5,
        );
  }
}
