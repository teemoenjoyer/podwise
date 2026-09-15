import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/commander.dart';
import '../../domain/models.dart';
import '../../domain/pod.dart';
import '../commander/commander_art.dart';
import '../commander/commander_search_sheet.dart';
import '../players/player_dialogs.dart';
import 'starting_life_field.dart';
import '../../state/pod_providers.dart';
import '../../state/providers.dart';
import '../game/game_screen.dart';

class NewGameScreen extends ConsumerStatefulWidget {
  const NewGameScreen({
    super.key,
    this.initialPlayers = const [],
    this.initialDecks = const {},
    this.deckRoulette = false,
  });

  /// Seats to start with, in order. Set when arriving from the Pod Builder,
  /// which has already decided who is at this table.
  final List<PlayerProfile> initialPlayers;

  /// The deck each of those players is bringing, by profile id.
  final Map<String, DeckProfile> initialDecks;

  /// Everyone is playing somebody else's deck, so the result must not touch
  /// anybody's deck power.
  final bool deckRoulette;

  @override
  ConsumerState<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends ConsumerState<NewGameScreen> {
  final List<PlayerProfile> _selected = [];

  /// Chosen commanders, by profile id. Kept separate from [_selected] so
  /// deselecting and reselecting a player doesn't lose their pick.
  final Map<String, CommanderSet> _commanders = {};

  /// Which saved deck each player is bringing, by profile id. Resolved when
  /// the commander is picked rather than at kick-off, so the tile can show
  /// the deck's name and the game can be attributed to it.
  final Map<String, DeckProfile> _decks = {};

  int _startingLife = commanderStartingLife;

  /// Ten at one table is a lot, but a kitchen-table game night sometimes is.
  /// The Pod Builder is the thing that splits people up; this screen just
  /// tracks whoever actually sat down.
  static const maxSeats = 10;

  bool get _canStart => _selected.length >= 2 && _selected.length <= maxSeats;

  @override
  void initState() {
    super.initState();
    // A pod arrives fully decided, so the screen opens ready to start rather
    // than asking the same questions the Pod Builder just answered.
    _selected.addAll(widget.initialPlayers.take(maxSeats));
    _decks.addAll(widget.initialDecks);
    if (_decks.isNotEmpty) _restoreCommanders();
  }

  /// Rebuilds the command zone for each pre-chosen deck.
  ///
  /// The deck stores card ids rather than the cards, and commander damage is
  /// tracked per card, so the cards have to come back out of the cache before
  /// the game starts.
  Future<void> _restoreCommanders() async {
    final repository = ref.read(cardRepositoryProvider);
    final restored = <String, CommanderSet>{};

    for (final entry in _decks.entries) {
      final commanders = await repository.commanderSet(
        entry.value.commanderIds,
      );
      if (commanders.isNotEmpty) restored[entry.key] = commanders;
    }

    if (!mounted || restored.isEmpty) return;
    setState(() => _commanders.addAll(restored));
  }

  void _toggle(PlayerProfile profile) {
    setState(() {
      final index = _selected.indexWhere((p) => p.id == profile.id);
      if (index >= 0) {
        _selected.removeAt(index);
      } else if (_selected.length < maxSeats) {
        _selected.add(profile);
      }
    });
  }

  /// Decks this player has saved, most recently played first.
  List<DeckProfile> _savedDecks(PlayerProfile profile) {
    final roster = ref.read(playerDecksProvider).valueOrNull ?? const [];
    final entry = roster.where((e) => e.player.id == profile.id).firstOrNull;
    return [
      for (final deck in entry?.decks ?? const <DeckProfile>[])
        if (deck.isSaved) deck,
    ];
  }

  /// Asks what this player is bringing: one of their saved decks, or a
  /// commander they haven't played before.
  Future<void> _pickCommander(PlayerProfile profile) async {
    final saved = _savedDecks(profile);

    // Nothing saved yet, so there is nothing to choose between — go straight
    // to the search rather than showing a list of one option.
    if (saved.isEmpty) {
      await _searchCommander(profile);
      return;
    }

    // Empty string means "a different commander"; null means cancelled.
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      builder: (_) => _DeckPicker(
        profile: profile,
        decks: saved,
        selectedDeckId: _decks[profile.id]?.deckId,
      ),
    );

    if (chosen == null || !mounted) return;
    if (chosen.isEmpty) {
      await _searchCommander(profile);
      return;
    }

    final deck = saved.firstWhere((d) => d.deckId == chosen);
    // Commander damage is tracked per card, so the command zone has to be
    // rebuilt from the cache, not just named.
    final commanders = await ref
        .read(cardRepositoryProvider)
        .commanderSet(deck.commanderIds);

    if (!mounted) return;
    setState(() {
      _decks[profile.id] = deck;
      if (commanders.isEmpty) {
        _commanders.remove(profile.id);
      } else {
        _commanders[profile.id] = commanders;
      }
    });
  }

  Future<void> _searchCommander(PlayerProfile profile) async {
    final result = await Navigator.of(context).push<CommanderSet>(
      MaterialPageRoute(
        builder: (_) => CommanderSearchScreen(
          playerName: profile.name,
          initial: _commanders[profile.id] ?? const CommanderSet.empty(),
        ),
      ),
    );
    if (result == null || !mounted) return;

    if (result.isEmpty) {
      setState(() {
        _commanders.remove(profile.id);
        _decks.remove(profile.id);
      });
      return;
    }

    // Finds the matching deck or creates one, so a commander picked here is
    // in the player's library from now on.
    final deck = await ref
        .read(deckEditorProvider)
        .deckForCommanders(profile, result);

    if (!mounted) return;
    setState(() {
      _commanders[profile.id] = result;
      if (deck != null) _decks[profile.id] = deck;
    });
  }

  /// Confirms before removing, because this also takes their saved decks and
  /// the power ratings on them.
  Future<void> _removePlayer(
    PlayerProfile player,
    List<DeckProfile> decks,
  ) async {
    await showRemovePlayerDialog(
      context,
      ref,
      player,
      deckCount: decks.where((d) => d.isSaved).length,
    );
  }

  Future<void> _addPlayer() async {
    final profile = await showAddPlayerDialog(context, ref);
    if (profile == null || !mounted) return;
    // Straight into the game, since that is why they were added here.
    if (_selected.length < maxSeats) {
      setState(() => _selected.add(profile));
    }
  }

  void _start() {
    final deckIds = {
      for (final player in _selected)
        if (_decks[player.id] case final deck?) player.id: deck.deckId,
    };

    ref
        .read(activeGameProvider.notifier)
        .start(
          players: _selected,
          startingLife: _startingLife,
          commanders: _commanders,
          // Covers a deck that names its commander without the app holding
          // the card — decks carried over from before card ids existed.
          commanderLabels: {
            for (final player in _selected)
              if (_decks[player.id]?.commanderName case final name?
                  when name.isNotEmpty)
                player.id: name,
          },
          deckIds: deckIds,
          deckRoulette: widget.deckRoulette,
        );

    // Marks these decks as the ones currently being played, so they lead
    // their owners' lists next time. Skipped on a roulette night: the owner
    // is not the one playing it, so it should not become their default.
    if (!widget.deckRoulette) {
      ref
          .read(deckEditorProvider)
          .markPlayed(deckIds.values.toList(), DateTime.now());
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The roster rather than the bare player list, so each player's decks are
    // already loaded by the time they tap to choose one.
    final roster = ref.watch(playerDecksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New game')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const _SectionLabel('STARTING LIFE'),
                  const SizedBox(height: 12),
                  StartingLifeField(
                    value: _startingLife,
                    onChanged: (v) => setState(() => _startingLife = v),
                  ),
                  const SizedBox(height: 32),
                  _SectionLabel(
                    'PLAYERS  ·  ${_selected.length} OF 2–$maxSeats',
                  ),
                  const SizedBox(height: 12),
                  switch (roster) {
                    AsyncData(:final value) when value.isEmpty =>
                      const _EmptyPlayers(),
                    AsyncData(:final value) => Column(
                      children: [
                        for (final (:player, :decks) in value)
                          _PlayerTile(
                            profile: player,
                            order: _selected.indexWhere(
                              (s) => s.id == player.id,
                            ),
                            commanders: _commanders[player.id],
                            deck: _decks[player.id],
                            onTap: () => _toggle(player),
                            onPickCommander: () => _pickCommander(player),
                            onDelete: () => _removePlayer(player, decks),
                          ),
                      ],
                    ),
                    AsyncError(:final error) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Could not load players: $error'),
                    ),
                    _ => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  },
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _addPlayer,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('ADD PLAYER'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: _canStart ? _start : null,
                child: Text(
                  _canStart
                      ? 'START GAME  ·  ${_selected.length} PLAYERS'
                      : 'SELECT AT LEAST 2 PLAYERS',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: Colors.white.withValues(alpha: 0.45),
    ),
  );
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    required this.profile,
    required this.order,
    required this.commanders,
    required this.deck,
    required this.onTap,
    required this.onPickCommander,
    required this.onDelete,
  });

  final PlayerProfile profile;

  /// Position in the selection, or -1 when unselected.
  final int order;

  /// Null when this player has not chosen a commander — which stays valid,
  /// since the brief allows starting a game without one.
  final CommanderSet? commanders;

  /// The saved deck being brought, when one has been chosen. Carries the
  /// nickname, which the command zone alone does not.
  final DeckProfile? deck;

  final VoidCallback onTap;

  final VoidCallback onPickCommander;
  final VoidCallback onDelete;

  bool get _chosen => commanders != null || deck != null;

  /// A deck whose command zone could not be rebuilt — decks saved before the
  /// app stored card ids, or a card since evicted from the cache.
  ///
  /// Worth saying out loud rather than letting it pass: without the actual
  /// cards there is nothing to track commander damage against, and the tile
  /// would otherwise look identical to a deck that is ready to play.
  bool get _needsCommander => deck != null && commanders == null;

  /// The deck's own name wins where it has one, since that is what its owner
  /// calls it; otherwise the command zone speaks for itself.
  String get _deckLabel {
    if (_needsCommander) {
      return '${deck!.displayName}  ·  tap to set commander';
    }
    if (deck != null && deck!.deckName.isNotEmpty) return deck!.deckName;
    if (commanders != null) return commanders!.displayName;
    return 'Add deck or commander';
  }

  Color get _deckLabelColor => switch (this) {
    _ when _needsCommander => PodWiseColors.caution,
    _ when _chosen => PodWiseColors.accent,
    _ => Colors.white.withValues(alpha: 0.4),
  };

  @override
  Widget build(BuildContext context) {
    final selected = order >= 0;
    final color =
        PodWiseColors.seats[profile.colorIndex % PodWiseColors.seats.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.18)
            : PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: selected ? color : PodWiseColors.surfaceHigh,
                  child: Text(
                    profile.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      // The commander affordance only appears once a player is
                      // in the game — it is meaningless for unselected rows.
                      if (selected)
                        GestureDetector(
                          onTap: onPickCommander,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Icon(
                                  switch (this) {
                                    _ when _needsCommander =>
                                      Icons.error_outline_rounded,
                                    _ when _chosen =>
                                      Icons.auto_awesome_rounded,
                                    _ => Icons.add_circle_outline_rounded,
                                  },
                                  size: 13,
                                  color: _deckLabelColor,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _deckLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _deckLabelColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${order + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.white24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks which of a player's saved decks they are bringing.
class _DeckPicker extends StatelessWidget {
  const _DeckPicker({
    required this.profile,
    required this.decks,
    required this.selectedDeckId,
  });

  final PlayerProfile profile;
  final List<DeckProfile> decks;
  final String? selectedDeckId;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              'What is ${profile.name} playing?',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          for (final deck in decks)
            ListTile(
              leading: CommanderArt(
                commanderIds: deck.commanderIds,
                highlight: deck.deckId == selectedDeckId,
              ),
              // The art took the leading slot, so the tick moves opposite it
              // rather than the selected deck losing its marker.
              trailing: deck.deckId == selectedDeckId
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: PodWiseColors.accent,
                      size: 20,
                    )
                  : null,
              title: Text(deck.displayName),
              subtitle: Text(
                'Power ${deck.power}'
                '${deck.gamesPlayed == 0 ? '' : '  ·  '
                          '${(deck.winRate * 100).round()}% over '
                          '${deck.gamesPlayed}'}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => Navigator.of(context).pop(deck.deckId),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.search_rounded),
            title: const Text('A different commander'),
            subtitle: const Text(
              'Saved as a new deck for this player',
              style: TextStyle(fontSize: 12),
            ),
            // The empty string is the "not one of these" signal; null is
            // reserved for dismissing the sheet.
            onTap: () => Navigator.of(context).pop(''),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _EmptyPlayers extends StatelessWidget {
  const _EmptyPlayers();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    decoration: BoxDecoration(
      color: PodWiseColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(
          Icons.groups_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.25),
        ),
        const SizedBox(height: 12),
        Text(
          'No saved players yet.\nAdd your playgroup once and reuse them.',
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    ),
  );
}
