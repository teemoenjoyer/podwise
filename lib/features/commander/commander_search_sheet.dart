import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/card_repository.dart';
import '../../domain/commander.dart';
import '../../state/providers.dart';

/// Colours used for the small identity pips. Deliberately muted approximations
/// of Magic's five colours rather than copies of any official asset.
const _pipColors = {
  ManaColor.white: Color(0xFFE8E3D3),
  ManaColor.blue: Color(0xFF6BA5D6),
  ManaColor.black: Color(0xFF6E6A76),
  ManaColor.red: Color(0xFFD97D6B),
  ManaColor.green: Color(0xFF76B080),
};

/// Full-screen commander picker.
///
/// Returns the chosen [CommanderSet], or null if dismissed. Supports multiple
/// cards in the command zone, since partners and backgrounds are common.
class CommanderSearchScreen extends ConsumerStatefulWidget {
  const CommanderSearchScreen({
    super.key,
    required this.playerName,
    this.initial = const CommanderSet.empty(),
  });

  final String playerName;
  final CommanderSet initial;

  @override
  ConsumerState<CommanderSearchScreen> createState() =>
      _CommanderSearchScreenState();
}

class _CommanderSearchScreenState extends ConsumerState<CommanderSearchScreen> {
  final _controller = TextEditingController();
  late CommanderSet _selected = widget.initial;

  @override
  void initState() {
    super.initState();
    // Clear any query left over from the previous player.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commanderSearchProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(MagicCard card) {
    setState(() {
      _selected = _selected.cards.any((c) => c.id == card.id)
          ? _selected.withoutCard(card.id)
          : _selected.withCard(card);
    });
    // Promotes this card in offline search next time.
    ref.read(cardRepositoryProvider).markUsed(card);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(commanderSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.playerName}’s commander'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('DONE'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search commanders, e.g. atra',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _controller.clear();
                            ref.read(commanderSearchProvider.notifier).clear();
                            setState(() {});
                          },
                        ),
                ),
                onChanged: (v) {
                  ref.read(commanderSearchProvider.notifier).search(v);
                  setState(() {});
                },
              ),
            ),
            if (_selected.isNotEmpty)
              _SelectedStrip(
                set: _selected,
                onRemove: (id) =>
                    setState(() => _selected = _selected.withoutCard(id)),
              ),
            Expanded(
              child: switch (search) {
                AsyncData(:final value) => _Results(
                  result: value,
                  query: _controller.text,
                  selectedIds: _selected.cards.map((c) => c.id).toSet(),
                  onTap: _toggle,
                ),
                AsyncLoading(:final value?) => Stack(
                  children: [
                    _Results(
                      result: value,
                      query: _controller.text,
                      selectedIds: _selected.cards.map((c) => c.id).toSet(),
                      onTap: _toggle,
                    ),
                    const LinearProgressIndicator(minHeight: 2),
                  ],
                ),
                AsyncError(:final error) => _Message(
                  icon: Icons.cloud_off_rounded,
                  // Section 28: never strand the user on an error screen.
                  title: 'Card search unavailable',
                  body:
                      'You can still play without picking a commander.\n'
                      '($error)',
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(const CommanderSet.empty()),
                      child: const Text('NO COMMANDER'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_selected),
                      child: Text(
                        _selected.isEmpty
                            ? 'DONE'
                            : 'CONFIRM  ·  ${_selected.cards.length}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.result,
    required this.query,
    required this.selectedIds,
    required this.onTap,
  });

  final CardSearchResult result;
  final String query;
  final Set<String> selectedIds;
  final void Function(MagicCard) onTap;

  @override
  Widget build(BuildContext context) {
    if (query.trim().length < 2) {
      return const _Message(
        icon: Icons.auto_awesome_rounded,
        title: 'Find a commander',
        body:
            'Type at least two letters.\n'
            'Partners and backgrounds can both be added.',
      );
    }

    if (result.cards.isEmpty) {
      return _Message(
        icon: result.source == CardSearchSource.cacheAfterFailure
            ? Icons.cloud_off_rounded
            : Icons.search_off_rounded,
        title: result.source == CardSearchSource.cacheAfterFailure
            ? 'Offline, and not cached'
            : 'No commanders found',
        body: result.source == CardSearchSource.cacheAfterFailure
            ? 'Scryfall is unreachable. Only commanders you have used '
                  'before are available offline.'
            : 'Nothing matches “$query”.',
      );
    }

    return Column(
      children: [
        if (result.isOffline) const _OfflineBanner(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: result.cards.length,
            itemBuilder: (_, i) {
              final card = result.cards[i];
              return _CardTile(
                card: card,
                selected: selectedIds.contains(card.id),
                onTap: () => onTap(card),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: PodWiseColors.caution.withValues(alpha: 0.15),
    child: Row(
      children: [
        Icon(Icons.cloud_off_rounded, size: 16, color: PodWiseColors.caution),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Showing cached commanders — Scryfall is unreachable',
            style: TextStyle(
              fontSize: 12,
              color: PodWiseColors.caution.withValues(alpha: 0.95),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final MagicCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? PodWiseColors.accent.withValues(alpha: 0.18)
            : PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 54,
                    child: card.imageArtCrop == null
                        ? Container(
                            color: PodWiseColors.surfaceHigh,
                            child: const Icon(
                              Icons.image_not_supported_rounded,
                              size: 18,
                              color: Colors.white24,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: card.imageArtCrop!,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                Container(color: PodWiseColors.surfaceHigh),
                            // A missing image must never break the row.
                            errorWidget: (_, _, _) => Container(
                              color: PodWiseColors.surfaceHigh,
                              child: const Icon(
                                Icons.broken_image_rounded,
                                size: 18,
                                color: Colors.white24,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.typeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _ColorPips(colors: card.colorIdentity),
                          // Silver-bordered and other unsanctioned cards are
                          // offered — Rule 0 decides at the table — but the
                          // table should know what it is agreeing to.
                          if (!card.commanderLegal) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: PodWiseColors.caution.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NOT LEGAL',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: PodWiseColors.caution,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: PodWiseColors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPips extends StatelessWidget {
  const _ColorPips({required this.colors});
  final Set<ManaColor> colors;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return Text(
        'COLOURLESS',
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 1.2,
          color: Colors.white.withValues(alpha: 0.4),
        ),
      );
    }
    return Row(
      children: [
        // WUBRG order, as players read it.
        for (final c in ManaColor.values.where(colors.contains))
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _pipColors[c],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26),
            ),
          ),
      ],
    );
  }
}

class _SelectedStrip extends StatelessWidget {
  const _SelectedStrip({required this.set, required this.onRemove});

  final CommanderSet set;
  final void Function(String cardId) onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final card in set.cards)
            Chip(
              label: Text(card.name, style: const TextStyle(fontSize: 12)),
              backgroundColor: PodWiseColors.accent.withValues(alpha: 0.2),
              side: BorderSide.none,
              onDeleted: () => onRemove(card.id),
              deleteIcon: const Icon(Icons.close_rounded, size: 16),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.white.withValues(alpha: 0.22)),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ),
  );
}
