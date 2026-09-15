import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

/// A deck's commander art, at thumbnail size.
///
/// A deck is its commander to most people, so a row of art is quicker to pick
/// from than a column of names. Everything here degrades to the plain glyph
/// these rows used to show: a deck with no cards, a card the cache has never
/// seen, a card with no art, and a first run with no network all land in the
/// same place rather than on a broken image.
class CommanderArt extends ConsumerWidget {
  const CommanderArt({
    super.key,
    required this.commanderIds,
    this.width = 46,
    this.height = 34,
    this.fallback = Icons.style_rounded,
    this.highlight = false,
  });

  final List<String> commanderIds;
  final double width;
  final double height;

  /// Shown whenever there is no art to show.
  final IconData fallback;

  /// Outlines the thumbnail in the accent colour — used where a row is the
  /// selected one.
  final bool highlight;

  /// What the row showed before it had art, and what it falls back to.
  Widget get _glyph => Icon(
    fallback,
    size: height * 0.5,
    color: Colors.white.withValues(alpha: 0.35),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref
        .watch(deckArtProvider(commanderIds.join(',')))
        .valueOrNull;
    final url = card?.imageArtCrop;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PodWiseColors.surfaceHigh,
        borderRadius: BorderRadius.circular(7),
        border: highlight
            ? Border.all(color: PodWiseColors.accent, width: 1.5)
            : null,
      ),
      child: url == null
          ? _glyph
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              // The glyph holds the tile until the art arrives, rather than a
              // blank box. Art is only on disk once it has been fetched, so
              // the first run after an install shows every row empty
              // otherwise — and stays that way for a table with no signal.
              placeholder: (_, _) => _glyph,
              errorWidget: (_, _, _) => _glyph,
              fadeInDuration: const Duration(milliseconds: 250),
            ),
    );
  }
}
