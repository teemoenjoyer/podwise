// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PlayerProfilesTable extends PlayerProfiles
    with TableInfo<$PlayerProfilesTable, PlayerProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayerProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    colorIndex,
    createdAt,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'player_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayerProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayerProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayerProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
    );
  }

  @override
  $PlayerProfilesTable createAlias(String alias) {
    return $PlayerProfilesTable(attachedDatabase, alias);
  }
}

class PlayerProfileRow extends DataClass
    implements Insertable<PlayerProfileRow> {
  final String id;
  final String name;
  final int colorIndex;
  final DateTime createdAt;
  final DateTime? lastPlayedAt;
  const PlayerProfileRow({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdAt,
    this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color_index'] = Variable<int>(colorIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    return map;
  }

  PlayerProfilesCompanion toCompanion(bool nullToAbsent) {
    return PlayerProfilesCompanion(
      id: Value(id),
      name: Value(name),
      colorIndex: Value(colorIndex),
      createdAt: Value(createdAt),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
    );
  }

  factory PlayerProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayerProfileRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
    };
  }

  PlayerProfileRow copyWith({
    String? id,
    String? name,
    int? colorIndex,
    DateTime? createdAt,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
  }) => PlayerProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    createdAt: createdAt ?? this.createdAt,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
  );
  PlayerProfileRow copyWithCompanion(PlayerProfilesCompanion data) {
    return PlayerProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayerProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, colorIndex, createdAt, lastPlayedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayerProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorIndex == this.colorIndex &&
          other.createdAt == this.createdAt &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class PlayerProfilesCompanion extends UpdateCompanion<PlayerProfileRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> colorIndex;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> rowid;
  const PlayerProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayerProfilesCompanion.insert({
    required String id,
    required String name,
    this.colorIndex = const Value.absent(),
    required DateTime createdAt,
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<PlayerProfileRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? colorIndex,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorIndex != null) 'color_index': colorIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayerProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? colorIndex,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return PlayerProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorIndex: colorIndex ?? this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayerProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GamesTable extends Games with TableInfo<$GamesTable, GameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startingLifeMeta = const VerificationMeta(
    'startingLife',
  );
  @override
  late final GeneratedColumn<int> startingLife = GeneratedColumn<int>(
    'starting_life',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _winnerProfileIdMeta = const VerificationMeta(
    'winnerProfileId',
  );
  @override
  late final GeneratedColumn<String> winnerProfileId = GeneratedColumn<String>(
    'winner_profile_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deckRouletteMeta = const VerificationMeta(
    'deckRoulette',
  );
  @override
  late final GeneratedColumn<bool> deckRoulette = GeneratedColumn<bool>(
    'deck_roulette',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deck_roulette" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    finishedAt,
    startingLife,
    winnerProfileId,
    deckRoulette,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('starting_life')) {
      context.handle(
        _startingLifeMeta,
        startingLife.isAcceptableOrUnknown(
          data['starting_life']!,
          _startingLifeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingLifeMeta);
    }
    if (data.containsKey('winner_profile_id')) {
      context.handle(
        _winnerProfileIdMeta,
        winnerProfileId.isAcceptableOrUnknown(
          data['winner_profile_id']!,
          _winnerProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('deck_roulette')) {
      context.handle(
        _deckRouletteMeta,
        deckRoulette.isAcceptableOrUnknown(
          data['deck_roulette']!,
          _deckRouletteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      startingLife: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_life'],
      )!,
      winnerProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}winner_profile_id'],
      ),
      deckRoulette: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deck_roulette'],
      )!,
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }
}

class GameRow extends DataClass implements Insertable<GameRow> {
  final String id;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int startingLife;
  final String? winnerProfileId;

  /// True when everybody was playing somebody else's deck.
  ///
  /// These games count for the players but never for the decks: a deck's
  /// power rating is about how the deck plays in its owner's hands, and a
  /// stranger piloting it says nothing about that either way.
  final bool deckRoulette;
  const GameRow({
    required this.id,
    required this.startedAt,
    this.finishedAt,
    required this.startingLife,
    this.winnerProfileId,
    required this.deckRoulette,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    map['starting_life'] = Variable<int>(startingLife);
    if (!nullToAbsent || winnerProfileId != null) {
      map['winner_profile_id'] = Variable<String>(winnerProfileId);
    }
    map['deck_roulette'] = Variable<bool>(deckRoulette);
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      startingLife: Value(startingLife),
      winnerProfileId: winnerProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(winnerProfileId),
      deckRoulette: Value(deckRoulette),
    );
  }

  factory GameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      startingLife: serializer.fromJson<int>(json['startingLife']),
      winnerProfileId: serializer.fromJson<String?>(json['winnerProfileId']),
      deckRoulette: serializer.fromJson<bool>(json['deckRoulette']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'startingLife': serializer.toJson<int>(startingLife),
      'winnerProfileId': serializer.toJson<String?>(winnerProfileId),
      'deckRoulette': serializer.toJson<bool>(deckRoulette),
    };
  }

  GameRow copyWith({
    String? id,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    int? startingLife,
    Value<String?> winnerProfileId = const Value.absent(),
    bool? deckRoulette,
  }) => GameRow(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    startingLife: startingLife ?? this.startingLife,
    winnerProfileId: winnerProfileId.present
        ? winnerProfileId.value
        : this.winnerProfileId,
    deckRoulette: deckRoulette ?? this.deckRoulette,
  );
  GameRow copyWithCompanion(GamesCompanion data) {
    return GameRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      startingLife: data.startingLife.present
          ? data.startingLife.value
          : this.startingLife,
      winnerProfileId: data.winnerProfileId.present
          ? data.winnerProfileId.value
          : this.winnerProfileId,
      deckRoulette: data.deckRoulette.present
          ? data.deckRoulette.value
          : this.deckRoulette,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('startingLife: $startingLife, ')
          ..write('winnerProfileId: $winnerProfileId, ')
          ..write('deckRoulette: $deckRoulette')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    finishedAt,
    startingLife,
    winnerProfileId,
    deckRoulette,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.startingLife == this.startingLife &&
          other.winnerProfileId == this.winnerProfileId &&
          other.deckRoulette == this.deckRoulette);
}

class GamesCompanion extends UpdateCompanion<GameRow> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<int> startingLife;
  final Value<String?> winnerProfileId;
  final Value<bool> deckRoulette;
  final Value<int> rowid;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.startingLife = const Value.absent(),
    this.winnerProfileId = const Value.absent(),
    this.deckRoulette = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GamesCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    required int startingLife,
    this.winnerProfileId = const Value.absent(),
    this.deckRoulette = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt),
       startingLife = Value(startingLife);
  static Insertable<GameRow> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<int>? startingLife,
    Expression<String>? winnerProfileId,
    Expression<bool>? deckRoulette,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (startingLife != null) 'starting_life': startingLife,
      if (winnerProfileId != null) 'winner_profile_id': winnerProfileId,
      if (deckRoulette != null) 'deck_roulette': deckRoulette,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GamesCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<int>? startingLife,
    Value<String?>? winnerProfileId,
    Value<bool>? deckRoulette,
    Value<int>? rowid,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      startingLife: startingLife ?? this.startingLife,
      winnerProfileId: winnerProfileId ?? this.winnerProfileId,
      deckRoulette: deckRoulette ?? this.deckRoulette,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (startingLife.present) {
      map['starting_life'] = Variable<int>(startingLife.value);
    }
    if (winnerProfileId.present) {
      map['winner_profile_id'] = Variable<String>(winnerProfileId.value);
    }
    if (deckRoulette.present) {
      map['deck_roulette'] = Variable<bool>(deckRoulette.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('startingLife: $startingLife, ')
          ..write('winnerProfileId: $winnerProfileId, ')
          ..write('deckRoulette: $deckRoulette, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameParticipantsTable extends GameParticipants
    with TableInfo<$GameParticipantsTable, GameParticipantRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameParticipantsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<String> gameId = GeneratedColumn<String>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _profileIdMeta = const VerificationMeta(
    'profileId',
  );
  @override
  late final GeneratedColumn<String> profileId = GeneratedColumn<String>(
    'profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seatIndexMeta = const VerificationMeta(
    'seatIndex',
  );
  @override
  late final GeneratedColumn<int> seatIndex = GeneratedColumn<int>(
    'seat_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIndexMeta = const VerificationMeta(
    'colorIndex',
  );
  @override
  late final GeneratedColumn<int> colorIndex = GeneratedColumn<int>(
    'color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalLifeMeta = const VerificationMeta(
    'finalLife',
  );
  @override
  late final GeneratedColumn<int> finalLife = GeneratedColumn<int>(
    'final_life',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eliminatedMeta = const VerificationMeta(
    'eliminated',
  );
  @override
  late final GeneratedColumn<bool> eliminated = GeneratedColumn<bool>(
    'eliminated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("eliminated" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    rowId,
    gameId,
    profileId,
    name,
    seatIndex,
    colorIndex,
    finalLife,
    deckId,
    position,
    eliminated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_participants';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameParticipantRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    } else if (isInserting) {
      context.missing(_gameIdMeta);
    }
    if (data.containsKey('profile_id')) {
      context.handle(
        _profileIdMeta,
        profileId.isAcceptableOrUnknown(data['profile_id']!, _profileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_profileIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('seat_index')) {
      context.handle(
        _seatIndexMeta,
        seatIndex.isAcceptableOrUnknown(data['seat_index']!, _seatIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_seatIndexMeta);
    }
    if (data.containsKey('color_index')) {
      context.handle(
        _colorIndexMeta,
        colorIndex.isAcceptableOrUnknown(data['color_index']!, _colorIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorIndexMeta);
    }
    if (data.containsKey('final_life')) {
      context.handle(
        _finalLifeMeta,
        finalLife.isAcceptableOrUnknown(data['final_life']!, _finalLifeMeta),
      );
    } else if (isInserting) {
      context.missing(_finalLifeMeta);
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('eliminated')) {
      context.handle(
        _eliminatedMeta,
        eliminated.isAcceptableOrUnknown(data['eliminated']!, _eliminatedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  GameParticipantRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameParticipantRow(
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_id'],
      )!,
      profileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      seatIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seat_index'],
      )!,
      colorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_index'],
      )!,
      finalLife: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}final_life'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      ),
      eliminated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}eliminated'],
      )!,
    );
  }

  @override
  $GameParticipantsTable createAlias(String alias) {
    return $GameParticipantsTable(attachedDatabase, alias);
  }
}

class GameParticipantRow extends DataClass
    implements Insertable<GameParticipantRow> {
  final int rowId;
  final String gameId;
  final String profileId;

  /// Denormalised so history stays readable if a profile is later renamed.
  final String name;
  final int seatIndex;
  final int colorIndex;
  final int finalLife;

  /// Which of the player's decks was brought. Null for games recorded before
  /// decks existed, or for a game started without picking a commander.
  final String? deckId;

  /// 1 = won. Null until the game finishes.
  final int? position;
  final bool eliminated;
  const GameParticipantRow({
    required this.rowId,
    required this.gameId,
    required this.profileId,
    required this.name,
    required this.seatIndex,
    required this.colorIndex,
    required this.finalLife,
    this.deckId,
    this.position,
    required this.eliminated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    map['game_id'] = Variable<String>(gameId);
    map['profile_id'] = Variable<String>(profileId);
    map['name'] = Variable<String>(name);
    map['seat_index'] = Variable<int>(seatIndex);
    map['color_index'] = Variable<int>(colorIndex);
    map['final_life'] = Variable<int>(finalLife);
    if (!nullToAbsent || deckId != null) {
      map['deck_id'] = Variable<String>(deckId);
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    map['eliminated'] = Variable<bool>(eliminated);
    return map;
  }

  GameParticipantsCompanion toCompanion(bool nullToAbsent) {
    return GameParticipantsCompanion(
      rowId: Value(rowId),
      gameId: Value(gameId),
      profileId: Value(profileId),
      name: Value(name),
      seatIndex: Value(seatIndex),
      colorIndex: Value(colorIndex),
      finalLife: Value(finalLife),
      deckId: deckId == null && nullToAbsent
          ? const Value.absent()
          : Value(deckId),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      eliminated: Value(eliminated),
    );
  }

  factory GameParticipantRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameParticipantRow(
      rowId: serializer.fromJson<int>(json['rowId']),
      gameId: serializer.fromJson<String>(json['gameId']),
      profileId: serializer.fromJson<String>(json['profileId']),
      name: serializer.fromJson<String>(json['name']),
      seatIndex: serializer.fromJson<int>(json['seatIndex']),
      colorIndex: serializer.fromJson<int>(json['colorIndex']),
      finalLife: serializer.fromJson<int>(json['finalLife']),
      deckId: serializer.fromJson<String?>(json['deckId']),
      position: serializer.fromJson<int?>(json['position']),
      eliminated: serializer.fromJson<bool>(json['eliminated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'gameId': serializer.toJson<String>(gameId),
      'profileId': serializer.toJson<String>(profileId),
      'name': serializer.toJson<String>(name),
      'seatIndex': serializer.toJson<int>(seatIndex),
      'colorIndex': serializer.toJson<int>(colorIndex),
      'finalLife': serializer.toJson<int>(finalLife),
      'deckId': serializer.toJson<String?>(deckId),
      'position': serializer.toJson<int?>(position),
      'eliminated': serializer.toJson<bool>(eliminated),
    };
  }

  GameParticipantRow copyWith({
    int? rowId,
    String? gameId,
    String? profileId,
    String? name,
    int? seatIndex,
    int? colorIndex,
    int? finalLife,
    Value<String?> deckId = const Value.absent(),
    Value<int?> position = const Value.absent(),
    bool? eliminated,
  }) => GameParticipantRow(
    rowId: rowId ?? this.rowId,
    gameId: gameId ?? this.gameId,
    profileId: profileId ?? this.profileId,
    name: name ?? this.name,
    seatIndex: seatIndex ?? this.seatIndex,
    colorIndex: colorIndex ?? this.colorIndex,
    finalLife: finalLife ?? this.finalLife,
    deckId: deckId.present ? deckId.value : this.deckId,
    position: position.present ? position.value : this.position,
    eliminated: eliminated ?? this.eliminated,
  );
  GameParticipantRow copyWithCompanion(GameParticipantsCompanion data) {
    return GameParticipantRow(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      profileId: data.profileId.present ? data.profileId.value : this.profileId,
      name: data.name.present ? data.name.value : this.name,
      seatIndex: data.seatIndex.present ? data.seatIndex.value : this.seatIndex,
      colorIndex: data.colorIndex.present
          ? data.colorIndex.value
          : this.colorIndex,
      finalLife: data.finalLife.present ? data.finalLife.value : this.finalLife,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      position: data.position.present ? data.position.value : this.position,
      eliminated: data.eliminated.present
          ? data.eliminated.value
          : this.eliminated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameParticipantRow(')
          ..write('rowId: $rowId, ')
          ..write('gameId: $gameId, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('seatIndex: $seatIndex, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('finalLife: $finalLife, ')
          ..write('deckId: $deckId, ')
          ..write('position: $position, ')
          ..write('eliminated: $eliminated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rowId,
    gameId,
    profileId,
    name,
    seatIndex,
    colorIndex,
    finalLife,
    deckId,
    position,
    eliminated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameParticipantRow &&
          other.rowId == this.rowId &&
          other.gameId == this.gameId &&
          other.profileId == this.profileId &&
          other.name == this.name &&
          other.seatIndex == this.seatIndex &&
          other.colorIndex == this.colorIndex &&
          other.finalLife == this.finalLife &&
          other.deckId == this.deckId &&
          other.position == this.position &&
          other.eliminated == this.eliminated);
}

class GameParticipantsCompanion extends UpdateCompanion<GameParticipantRow> {
  final Value<int> rowId;
  final Value<String> gameId;
  final Value<String> profileId;
  final Value<String> name;
  final Value<int> seatIndex;
  final Value<int> colorIndex;
  final Value<int> finalLife;
  final Value<String?> deckId;
  final Value<int?> position;
  final Value<bool> eliminated;
  const GameParticipantsCompanion({
    this.rowId = const Value.absent(),
    this.gameId = const Value.absent(),
    this.profileId = const Value.absent(),
    this.name = const Value.absent(),
    this.seatIndex = const Value.absent(),
    this.colorIndex = const Value.absent(),
    this.finalLife = const Value.absent(),
    this.deckId = const Value.absent(),
    this.position = const Value.absent(),
    this.eliminated = const Value.absent(),
  });
  GameParticipantsCompanion.insert({
    this.rowId = const Value.absent(),
    required String gameId,
    required String profileId,
    required String name,
    required int seatIndex,
    required int colorIndex,
    required int finalLife,
    this.deckId = const Value.absent(),
    this.position = const Value.absent(),
    this.eliminated = const Value.absent(),
  }) : gameId = Value(gameId),
       profileId = Value(profileId),
       name = Value(name),
       seatIndex = Value(seatIndex),
       colorIndex = Value(colorIndex),
       finalLife = Value(finalLife);
  static Insertable<GameParticipantRow> custom({
    Expression<int>? rowId,
    Expression<String>? gameId,
    Expression<String>? profileId,
    Expression<String>? name,
    Expression<int>? seatIndex,
    Expression<int>? colorIndex,
    Expression<int>? finalLife,
    Expression<String>? deckId,
    Expression<int>? position,
    Expression<bool>? eliminated,
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (gameId != null) 'game_id': gameId,
      if (profileId != null) 'profile_id': profileId,
      if (name != null) 'name': name,
      if (seatIndex != null) 'seat_index': seatIndex,
      if (colorIndex != null) 'color_index': colorIndex,
      if (finalLife != null) 'final_life': finalLife,
      if (deckId != null) 'deck_id': deckId,
      if (position != null) 'position': position,
      if (eliminated != null) 'eliminated': eliminated,
    });
  }

  GameParticipantsCompanion copyWith({
    Value<int>? rowId,
    Value<String>? gameId,
    Value<String>? profileId,
    Value<String>? name,
    Value<int>? seatIndex,
    Value<int>? colorIndex,
    Value<int>? finalLife,
    Value<String?>? deckId,
    Value<int?>? position,
    Value<bool>? eliminated,
  }) {
    return GameParticipantsCompanion(
      rowId: rowId ?? this.rowId,
      gameId: gameId ?? this.gameId,
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      seatIndex: seatIndex ?? this.seatIndex,
      colorIndex: colorIndex ?? this.colorIndex,
      finalLife: finalLife ?? this.finalLife,
      deckId: deckId ?? this.deckId,
      position: position ?? this.position,
      eliminated: eliminated ?? this.eliminated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<String>(gameId.value);
    }
    if (profileId.present) {
      map['profile_id'] = Variable<String>(profileId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (seatIndex.present) {
      map['seat_index'] = Variable<int>(seatIndex.value);
    }
    if (colorIndex.present) {
      map['color_index'] = Variable<int>(colorIndex.value);
    }
    if (finalLife.present) {
      map['final_life'] = Variable<int>(finalLife.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (eliminated.present) {
      map['eliminated'] = Variable<bool>(eliminated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameParticipantsCompanion(')
          ..write('rowId: $rowId, ')
          ..write('gameId: $gameId, ')
          ..write('profileId: $profileId, ')
          ..write('name: $name, ')
          ..write('seatIndex: $seatIndex, ')
          ..write('colorIndex: $colorIndex, ')
          ..write('finalLife: $finalLife, ')
          ..write('deckId: $deckId, ')
          ..write('position: $position, ')
          ..write('eliminated: $eliminated')
          ..write(')'))
        .toString();
  }
}

class $CachedCardsTable extends CachedCards
    with TableInfo<$CachedCardsTable, CachedCardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _searchNameMeta = const VerificationMeta(
    'searchName',
  );
  @override
  late final GeneratedColumn<String> searchName = GeneratedColumn<String>(
    'search_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeLineMeta = const VerificationMeta(
    'typeLine',
  );
  @override
  late final GeneratedColumn<String> typeLine = GeneratedColumn<String>(
    'type_line',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorIdentityMeta = const VerificationMeta(
    'colorIdentity',
  );
  @override
  late final GeneratedColumn<String> colorIdentity = GeneratedColumn<String>(
    'color_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _oracleTextMeta = const VerificationMeta(
    'oracleText',
  );
  @override
  late final GeneratedColumn<String> oracleText = GeneratedColumn<String>(
    'oracle_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manaCostMeta = const VerificationMeta(
    'manaCost',
  );
  @override
  late final GeneratedColumn<String> manaCost = GeneratedColumn<String>(
    'mana_cost',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageSmallMeta = const VerificationMeta(
    'imageSmall',
  );
  @override
  late final GeneratedColumn<String> imageSmall = GeneratedColumn<String>(
    'image_small',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageNormalMeta = const VerificationMeta(
    'imageNormal',
  );
  @override
  late final GeneratedColumn<String> imageNormal = GeneratedColumn<String>(
    'image_normal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageArtCropMeta = const VerificationMeta(
    'imageArtCrop',
  );
  @override
  late final GeneratedColumn<String> imageArtCrop = GeneratedColumn<String>(
    'image_art_crop',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scryfallUriMeta = const VerificationMeta(
    'scryfallUri',
  );
  @override
  late final GeneratedColumn<String> scryfallUri = GeneratedColumn<String>(
    'scryfall_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _useCountMeta = const VerificationMeta(
    'useCount',
  );
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
    'use_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _commanderLegalMeta = const VerificationMeta(
    'commanderLegal',
  );
  @override
  late final GeneratedColumn<bool> commanderLegal = GeneratedColumn<bool>(
    'commander_legal',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("commander_legal" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    searchName,
    typeLine,
    colorIdentity,
    oracleText,
    manaCost,
    imageSmall,
    imageNormal,
    imageArtCrop,
    scryfallUri,
    artist,
    cachedAt,
    useCount,
    commanderLegal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedCardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('search_name')) {
      context.handle(
        _searchNameMeta,
        searchName.isAcceptableOrUnknown(data['search_name']!, _searchNameMeta),
      );
    } else if (isInserting) {
      context.missing(_searchNameMeta);
    }
    if (data.containsKey('type_line')) {
      context.handle(
        _typeLineMeta,
        typeLine.isAcceptableOrUnknown(data['type_line']!, _typeLineMeta),
      );
    } else if (isInserting) {
      context.missing(_typeLineMeta);
    }
    if (data.containsKey('color_identity')) {
      context.handle(
        _colorIdentityMeta,
        colorIdentity.isAcceptableOrUnknown(
          data['color_identity']!,
          _colorIdentityMeta,
        ),
      );
    }
    if (data.containsKey('oracle_text')) {
      context.handle(
        _oracleTextMeta,
        oracleText.isAcceptableOrUnknown(data['oracle_text']!, _oracleTextMeta),
      );
    }
    if (data.containsKey('mana_cost')) {
      context.handle(
        _manaCostMeta,
        manaCost.isAcceptableOrUnknown(data['mana_cost']!, _manaCostMeta),
      );
    }
    if (data.containsKey('image_small')) {
      context.handle(
        _imageSmallMeta,
        imageSmall.isAcceptableOrUnknown(data['image_small']!, _imageSmallMeta),
      );
    }
    if (data.containsKey('image_normal')) {
      context.handle(
        _imageNormalMeta,
        imageNormal.isAcceptableOrUnknown(
          data['image_normal']!,
          _imageNormalMeta,
        ),
      );
    }
    if (data.containsKey('image_art_crop')) {
      context.handle(
        _imageArtCropMeta,
        imageArtCrop.isAcceptableOrUnknown(
          data['image_art_crop']!,
          _imageArtCropMeta,
        ),
      );
    }
    if (data.containsKey('scryfall_uri')) {
      context.handle(
        _scryfallUriMeta,
        scryfallUri.isAcceptableOrUnknown(
          data['scryfall_uri']!,
          _scryfallUriMeta,
        ),
      );
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    if (data.containsKey('use_count')) {
      context.handle(
        _useCountMeta,
        useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta),
      );
    }
    if (data.containsKey('commander_legal')) {
      context.handle(
        _commanderLegalMeta,
        commanderLegal.isAcceptableOrUnknown(
          data['commander_legal']!,
          _commanderLegalMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedCardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedCardRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      searchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_name'],
      )!,
      typeLine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_line'],
      )!,
      colorIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_identity'],
      )!,
      oracleText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}oracle_text'],
      ),
      manaCost: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mana_cost'],
      ),
      imageSmall: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_small'],
      ),
      imageNormal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_normal'],
      ),
      imageArtCrop: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_art_crop'],
      ),
      scryfallUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scryfall_uri'],
      ),
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
      useCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use_count'],
      )!,
      commanderLegal: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}commander_legal'],
      )!,
    );
  }

  @override
  $CachedCardsTable createAlias(String alias) {
    return $CachedCardsTable(attachedDatabase, alias);
  }
}

class CachedCardRow extends DataClass implements Insertable<CachedCardRow> {
  final String id;
  final String name;

  /// Lowercased name, so offline search can do a cheap LIKE without
  /// per-row case conversion.
  final String searchName;
  final String typeLine;

  /// Colour identity as WUBRG letters, e.g. "WUBG". Empty means colourless.
  final String colorIdentity;
  final String? oracleText;
  final String? manaCost;
  final String? imageSmall;
  final String? imageNormal;
  final String? imageArtCrop;
  final String? scryfallUri;

  /// Credited wherever the art is shown.
  final String? artist;
  final DateTime cachedAt;

  /// Bumped whenever the card is chosen, so the most-used commanders sort
  /// first offline.
  final int useCount;

  /// False for silver-bordered and other non-sanctioned cards.
  final bool commanderLegal;
  const CachedCardRow({
    required this.id,
    required this.name,
    required this.searchName,
    required this.typeLine,
    required this.colorIdentity,
    this.oracleText,
    this.manaCost,
    this.imageSmall,
    this.imageNormal,
    this.imageArtCrop,
    this.scryfallUri,
    this.artist,
    required this.cachedAt,
    required this.useCount,
    required this.commanderLegal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['search_name'] = Variable<String>(searchName);
    map['type_line'] = Variable<String>(typeLine);
    map['color_identity'] = Variable<String>(colorIdentity);
    if (!nullToAbsent || oracleText != null) {
      map['oracle_text'] = Variable<String>(oracleText);
    }
    if (!nullToAbsent || manaCost != null) {
      map['mana_cost'] = Variable<String>(manaCost);
    }
    if (!nullToAbsent || imageSmall != null) {
      map['image_small'] = Variable<String>(imageSmall);
    }
    if (!nullToAbsent || imageNormal != null) {
      map['image_normal'] = Variable<String>(imageNormal);
    }
    if (!nullToAbsent || imageArtCrop != null) {
      map['image_art_crop'] = Variable<String>(imageArtCrop);
    }
    if (!nullToAbsent || scryfallUri != null) {
      map['scryfall_uri'] = Variable<String>(scryfallUri);
    }
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    map['use_count'] = Variable<int>(useCount);
    map['commander_legal'] = Variable<bool>(commanderLegal);
    return map;
  }

  CachedCardsCompanion toCompanion(bool nullToAbsent) {
    return CachedCardsCompanion(
      id: Value(id),
      name: Value(name),
      searchName: Value(searchName),
      typeLine: Value(typeLine),
      colorIdentity: Value(colorIdentity),
      oracleText: oracleText == null && nullToAbsent
          ? const Value.absent()
          : Value(oracleText),
      manaCost: manaCost == null && nullToAbsent
          ? const Value.absent()
          : Value(manaCost),
      imageSmall: imageSmall == null && nullToAbsent
          ? const Value.absent()
          : Value(imageSmall),
      imageNormal: imageNormal == null && nullToAbsent
          ? const Value.absent()
          : Value(imageNormal),
      imageArtCrop: imageArtCrop == null && nullToAbsent
          ? const Value.absent()
          : Value(imageArtCrop),
      scryfallUri: scryfallUri == null && nullToAbsent
          ? const Value.absent()
          : Value(scryfallUri),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      cachedAt: Value(cachedAt),
      useCount: Value(useCount),
      commanderLegal: Value(commanderLegal),
    );
  }

  factory CachedCardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedCardRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      searchName: serializer.fromJson<String>(json['searchName']),
      typeLine: serializer.fromJson<String>(json['typeLine']),
      colorIdentity: serializer.fromJson<String>(json['colorIdentity']),
      oracleText: serializer.fromJson<String?>(json['oracleText']),
      manaCost: serializer.fromJson<String?>(json['manaCost']),
      imageSmall: serializer.fromJson<String?>(json['imageSmall']),
      imageNormal: serializer.fromJson<String?>(json['imageNormal']),
      imageArtCrop: serializer.fromJson<String?>(json['imageArtCrop']),
      scryfallUri: serializer.fromJson<String?>(json['scryfallUri']),
      artist: serializer.fromJson<String?>(json['artist']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
      useCount: serializer.fromJson<int>(json['useCount']),
      commanderLegal: serializer.fromJson<bool>(json['commanderLegal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'searchName': serializer.toJson<String>(searchName),
      'typeLine': serializer.toJson<String>(typeLine),
      'colorIdentity': serializer.toJson<String>(colorIdentity),
      'oracleText': serializer.toJson<String?>(oracleText),
      'manaCost': serializer.toJson<String?>(manaCost),
      'imageSmall': serializer.toJson<String?>(imageSmall),
      'imageNormal': serializer.toJson<String?>(imageNormal),
      'imageArtCrop': serializer.toJson<String?>(imageArtCrop),
      'scryfallUri': serializer.toJson<String?>(scryfallUri),
      'artist': serializer.toJson<String?>(artist),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
      'useCount': serializer.toJson<int>(useCount),
      'commanderLegal': serializer.toJson<bool>(commanderLegal),
    };
  }

  CachedCardRow copyWith({
    String? id,
    String? name,
    String? searchName,
    String? typeLine,
    String? colorIdentity,
    Value<String?> oracleText = const Value.absent(),
    Value<String?> manaCost = const Value.absent(),
    Value<String?> imageSmall = const Value.absent(),
    Value<String?> imageNormal = const Value.absent(),
    Value<String?> imageArtCrop = const Value.absent(),
    Value<String?> scryfallUri = const Value.absent(),
    Value<String?> artist = const Value.absent(),
    DateTime? cachedAt,
    int? useCount,
    bool? commanderLegal,
  }) => CachedCardRow(
    id: id ?? this.id,
    name: name ?? this.name,
    searchName: searchName ?? this.searchName,
    typeLine: typeLine ?? this.typeLine,
    colorIdentity: colorIdentity ?? this.colorIdentity,
    oracleText: oracleText.present ? oracleText.value : this.oracleText,
    manaCost: manaCost.present ? manaCost.value : this.manaCost,
    imageSmall: imageSmall.present ? imageSmall.value : this.imageSmall,
    imageNormal: imageNormal.present ? imageNormal.value : this.imageNormal,
    imageArtCrop: imageArtCrop.present ? imageArtCrop.value : this.imageArtCrop,
    scryfallUri: scryfallUri.present ? scryfallUri.value : this.scryfallUri,
    artist: artist.present ? artist.value : this.artist,
    cachedAt: cachedAt ?? this.cachedAt,
    useCount: useCount ?? this.useCount,
    commanderLegal: commanderLegal ?? this.commanderLegal,
  );
  CachedCardRow copyWithCompanion(CachedCardsCompanion data) {
    return CachedCardRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      searchName: data.searchName.present
          ? data.searchName.value
          : this.searchName,
      typeLine: data.typeLine.present ? data.typeLine.value : this.typeLine,
      colorIdentity: data.colorIdentity.present
          ? data.colorIdentity.value
          : this.colorIdentity,
      oracleText: data.oracleText.present
          ? data.oracleText.value
          : this.oracleText,
      manaCost: data.manaCost.present ? data.manaCost.value : this.manaCost,
      imageSmall: data.imageSmall.present
          ? data.imageSmall.value
          : this.imageSmall,
      imageNormal: data.imageNormal.present
          ? data.imageNormal.value
          : this.imageNormal,
      imageArtCrop: data.imageArtCrop.present
          ? data.imageArtCrop.value
          : this.imageArtCrop,
      scryfallUri: data.scryfallUri.present
          ? data.scryfallUri.value
          : this.scryfallUri,
      artist: data.artist.present ? data.artist.value : this.artist,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
      commanderLegal: data.commanderLegal.present
          ? data.commanderLegal.value
          : this.commanderLegal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedCardRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('typeLine: $typeLine, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('oracleText: $oracleText, ')
          ..write('manaCost: $manaCost, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageNormal: $imageNormal, ')
          ..write('imageArtCrop: $imageArtCrop, ')
          ..write('scryfallUri: $scryfallUri, ')
          ..write('artist: $artist, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('useCount: $useCount, ')
          ..write('commanderLegal: $commanderLegal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    searchName,
    typeLine,
    colorIdentity,
    oracleText,
    manaCost,
    imageSmall,
    imageNormal,
    imageArtCrop,
    scryfallUri,
    artist,
    cachedAt,
    useCount,
    commanderLegal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedCardRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.searchName == this.searchName &&
          other.typeLine == this.typeLine &&
          other.colorIdentity == this.colorIdentity &&
          other.oracleText == this.oracleText &&
          other.manaCost == this.manaCost &&
          other.imageSmall == this.imageSmall &&
          other.imageNormal == this.imageNormal &&
          other.imageArtCrop == this.imageArtCrop &&
          other.scryfallUri == this.scryfallUri &&
          other.artist == this.artist &&
          other.cachedAt == this.cachedAt &&
          other.useCount == this.useCount &&
          other.commanderLegal == this.commanderLegal);
}

class CachedCardsCompanion extends UpdateCompanion<CachedCardRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> searchName;
  final Value<String> typeLine;
  final Value<String> colorIdentity;
  final Value<String?> oracleText;
  final Value<String?> manaCost;
  final Value<String?> imageSmall;
  final Value<String?> imageNormal;
  final Value<String?> imageArtCrop;
  final Value<String?> scryfallUri;
  final Value<String?> artist;
  final Value<DateTime> cachedAt;
  final Value<int> useCount;
  final Value<bool> commanderLegal;
  final Value<int> rowid;
  const CachedCardsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.searchName = const Value.absent(),
    this.typeLine = const Value.absent(),
    this.colorIdentity = const Value.absent(),
    this.oracleText = const Value.absent(),
    this.manaCost = const Value.absent(),
    this.imageSmall = const Value.absent(),
    this.imageNormal = const Value.absent(),
    this.imageArtCrop = const Value.absent(),
    this.scryfallUri = const Value.absent(),
    this.artist = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.useCount = const Value.absent(),
    this.commanderLegal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedCardsCompanion.insert({
    required String id,
    required String name,
    required String searchName,
    required String typeLine,
    this.colorIdentity = const Value.absent(),
    this.oracleText = const Value.absent(),
    this.manaCost = const Value.absent(),
    this.imageSmall = const Value.absent(),
    this.imageNormal = const Value.absent(),
    this.imageArtCrop = const Value.absent(),
    this.scryfallUri = const Value.absent(),
    this.artist = const Value.absent(),
    required DateTime cachedAt,
    this.useCount = const Value.absent(),
    this.commanderLegal = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       searchName = Value(searchName),
       typeLine = Value(typeLine),
       cachedAt = Value(cachedAt);
  static Insertable<CachedCardRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? searchName,
    Expression<String>? typeLine,
    Expression<String>? colorIdentity,
    Expression<String>? oracleText,
    Expression<String>? manaCost,
    Expression<String>? imageSmall,
    Expression<String>? imageNormal,
    Expression<String>? imageArtCrop,
    Expression<String>? scryfallUri,
    Expression<String>? artist,
    Expression<DateTime>? cachedAt,
    Expression<int>? useCount,
    Expression<bool>? commanderLegal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (searchName != null) 'search_name': searchName,
      if (typeLine != null) 'type_line': typeLine,
      if (colorIdentity != null) 'color_identity': colorIdentity,
      if (oracleText != null) 'oracle_text': oracleText,
      if (manaCost != null) 'mana_cost': manaCost,
      if (imageSmall != null) 'image_small': imageSmall,
      if (imageNormal != null) 'image_normal': imageNormal,
      if (imageArtCrop != null) 'image_art_crop': imageArtCrop,
      if (scryfallUri != null) 'scryfall_uri': scryfallUri,
      if (artist != null) 'artist': artist,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (useCount != null) 'use_count': useCount,
      if (commanderLegal != null) 'commander_legal': commanderLegal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedCardsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? searchName,
    Value<String>? typeLine,
    Value<String>? colorIdentity,
    Value<String?>? oracleText,
    Value<String?>? manaCost,
    Value<String?>? imageSmall,
    Value<String?>? imageNormal,
    Value<String?>? imageArtCrop,
    Value<String?>? scryfallUri,
    Value<String?>? artist,
    Value<DateTime>? cachedAt,
    Value<int>? useCount,
    Value<bool>? commanderLegal,
    Value<int>? rowid,
  }) {
    return CachedCardsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      searchName: searchName ?? this.searchName,
      typeLine: typeLine ?? this.typeLine,
      colorIdentity: colorIdentity ?? this.colorIdentity,
      oracleText: oracleText ?? this.oracleText,
      manaCost: manaCost ?? this.manaCost,
      imageSmall: imageSmall ?? this.imageSmall,
      imageNormal: imageNormal ?? this.imageNormal,
      imageArtCrop: imageArtCrop ?? this.imageArtCrop,
      scryfallUri: scryfallUri ?? this.scryfallUri,
      artist: artist ?? this.artist,
      cachedAt: cachedAt ?? this.cachedAt,
      useCount: useCount ?? this.useCount,
      commanderLegal: commanderLegal ?? this.commanderLegal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (searchName.present) {
      map['search_name'] = Variable<String>(searchName.value);
    }
    if (typeLine.present) {
      map['type_line'] = Variable<String>(typeLine.value);
    }
    if (colorIdentity.present) {
      map['color_identity'] = Variable<String>(colorIdentity.value);
    }
    if (oracleText.present) {
      map['oracle_text'] = Variable<String>(oracleText.value);
    }
    if (manaCost.present) {
      map['mana_cost'] = Variable<String>(manaCost.value);
    }
    if (imageSmall.present) {
      map['image_small'] = Variable<String>(imageSmall.value);
    }
    if (imageNormal.present) {
      map['image_normal'] = Variable<String>(imageNormal.value);
    }
    if (imageArtCrop.present) {
      map['image_art_crop'] = Variable<String>(imageArtCrop.value);
    }
    if (scryfallUri.present) {
      map['scryfall_uri'] = Variable<String>(scryfallUri.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    if (commanderLegal.present) {
      map['commander_legal'] = Variable<bool>(commanderLegal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedCardsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('searchName: $searchName, ')
          ..write('typeLine: $typeLine, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('oracleText: $oracleText, ')
          ..write('manaCost: $manaCost, ')
          ..write('imageSmall: $imageSmall, ')
          ..write('imageNormal: $imageNormal, ')
          ..write('imageArtCrop: $imageArtCrop, ')
          ..write('scryfallUri: $scryfallUri, ')
          ..write('artist: $artist, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('useCount: $useCount, ')
          ..write('commanderLegal: $commanderLegal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DecksTable extends Decks with TableInfo<$DecksTable, DeckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _commanderNameMeta = const VerificationMeta(
    'commanderName',
  );
  @override
  late final GeneratedColumn<String> commanderName = GeneratedColumn<String>(
    'commander_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _commanderIdsMeta = const VerificationMeta(
    'commanderIds',
  );
  @override
  late final GeneratedColumn<String> commanderIds = GeneratedColumn<String>(
    'commander_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _colorIdentityMeta = const VerificationMeta(
    'colorIdentity',
  );
  @override
  late final GeneratedColumn<String> colorIdentity = GeneratedColumn<String>(
    'color_identity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _powerMeta = const VerificationMeta('power');
  @override
  late final GeneratedColumn<int> power = GeneratedColumn<int>(
    'power',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _archetypesMeta = const VerificationMeta(
    'archetypes',
  );
  @override
  late final GeneratedColumn<String> archetypes = GeneratedColumn<String>(
    'archetypes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _interactionMeta = const VerificationMeta(
    'interaction',
  );
  @override
  late final GeneratedColumn<String> interaction = GeneratedColumn<String>(
    'interaction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playerId,
    name,
    commanderName,
    commanderIds,
    colorIdentity,
    power,
    archetypes,
    interaction,
    createdAt,
    updatedAt,
    lastPlayedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('commander_name')) {
      context.handle(
        _commanderNameMeta,
        commanderName.isAcceptableOrUnknown(
          data['commander_name']!,
          _commanderNameMeta,
        ),
      );
    }
    if (data.containsKey('commander_ids')) {
      context.handle(
        _commanderIdsMeta,
        commanderIds.isAcceptableOrUnknown(
          data['commander_ids']!,
          _commanderIdsMeta,
        ),
      );
    }
    if (data.containsKey('color_identity')) {
      context.handle(
        _colorIdentityMeta,
        colorIdentity.isAcceptableOrUnknown(
          data['color_identity']!,
          _colorIdentityMeta,
        ),
      );
    }
    if (data.containsKey('power')) {
      context.handle(
        _powerMeta,
        power.isAcceptableOrUnknown(data['power']!, _powerMeta),
      );
    }
    if (data.containsKey('archetypes')) {
      context.handle(
        _archetypesMeta,
        archetypes.isAcceptableOrUnknown(data['archetypes']!, _archetypesMeta),
      );
    }
    if (data.containsKey('interaction')) {
      context.handle(
        _interactionMeta,
        interaction.isAcceptableOrUnknown(
          data['interaction']!,
          _interactionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      commanderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_name'],
      )!,
      commanderIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}commander_ids'],
      )!,
      colorIdentity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_identity'],
      )!,
      power: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}power'],
      )!,
      archetypes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archetypes'],
      )!,
      interaction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}interaction'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
    );
  }

  @override
  $DecksTable createAlias(String alias) {
    return $DecksTable(attachedDatabase, alias);
  }
}

class DeckRow extends DataClass implements Insertable<DeckRow> {
  final String id;
  final String playerId;

  /// Optional nickname. Empty means the deck goes by its commander, which is
  /// how most players refer to their decks anyway.
  final String name;
  final String commanderName;

  /// Comma-separated Scryfall ids for the command zone, so the cards can be
  /// rehydrated from the offline cache when this deck is brought to a game.
  /// Commander damage is tracked per card, so the names alone are not enough.
  final String commanderIds;

  /// WUBRG letters, empty for colourless.
  final String colorIdentity;

  /// 1-10 as judged by the group.
  final int power;

  /// Comma-separated [DeckArchetype] names.
  final String archetypes;

  /// Comma-separated [InteractionType] names.
  final String interaction;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Used to pick the deck a player most likely wants next.
  final DateTime? lastPlayedAt;
  const DeckRow({
    required this.id,
    required this.playerId,
    required this.name,
    required this.commanderName,
    required this.commanderIds,
    required this.colorIdentity,
    required this.power,
    required this.archetypes,
    required this.interaction,
    required this.createdAt,
    required this.updatedAt,
    this.lastPlayedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['player_id'] = Variable<String>(playerId);
    map['name'] = Variable<String>(name);
    map['commander_name'] = Variable<String>(commanderName);
    map['commander_ids'] = Variable<String>(commanderIds);
    map['color_identity'] = Variable<String>(colorIdentity);
    map['power'] = Variable<int>(power);
    map['archetypes'] = Variable<String>(archetypes);
    map['interaction'] = Variable<String>(interaction);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    return map;
  }

  DecksCompanion toCompanion(bool nullToAbsent) {
    return DecksCompanion(
      id: Value(id),
      playerId: Value(playerId),
      name: Value(name),
      commanderName: Value(commanderName),
      commanderIds: Value(commanderIds),
      colorIdentity: Value(colorIdentity),
      power: Value(power),
      archetypes: Value(archetypes),
      interaction: Value(interaction),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
    );
  }

  factory DeckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckRow(
      id: serializer.fromJson<String>(json['id']),
      playerId: serializer.fromJson<String>(json['playerId']),
      name: serializer.fromJson<String>(json['name']),
      commanderName: serializer.fromJson<String>(json['commanderName']),
      commanderIds: serializer.fromJson<String>(json['commanderIds']),
      colorIdentity: serializer.fromJson<String>(json['colorIdentity']),
      power: serializer.fromJson<int>(json['power']),
      archetypes: serializer.fromJson<String>(json['archetypes']),
      interaction: serializer.fromJson<String>(json['interaction']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'playerId': serializer.toJson<String>(playerId),
      'name': serializer.toJson<String>(name),
      'commanderName': serializer.toJson<String>(commanderName),
      'commanderIds': serializer.toJson<String>(commanderIds),
      'colorIdentity': serializer.toJson<String>(colorIdentity),
      'power': serializer.toJson<int>(power),
      'archetypes': serializer.toJson<String>(archetypes),
      'interaction': serializer.toJson<String>(interaction),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
    };
  }

  DeckRow copyWith({
    String? id,
    String? playerId,
    String? name,
    String? commanderName,
    String? commanderIds,
    String? colorIdentity,
    int? power,
    String? archetypes,
    String? interaction,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
  }) => DeckRow(
    id: id ?? this.id,
    playerId: playerId ?? this.playerId,
    name: name ?? this.name,
    commanderName: commanderName ?? this.commanderName,
    commanderIds: commanderIds ?? this.commanderIds,
    colorIdentity: colorIdentity ?? this.colorIdentity,
    power: power ?? this.power,
    archetypes: archetypes ?? this.archetypes,
    interaction: interaction ?? this.interaction,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
  );
  DeckRow copyWithCompanion(DecksCompanion data) {
    return DeckRow(
      id: data.id.present ? data.id.value : this.id,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      name: data.name.present ? data.name.value : this.name,
      commanderName: data.commanderName.present
          ? data.commanderName.value
          : this.commanderName,
      commanderIds: data.commanderIds.present
          ? data.commanderIds.value
          : this.commanderIds,
      colorIdentity: data.colorIdentity.present
          ? data.colorIdentity.value
          : this.colorIdentity,
      power: data.power.present ? data.power.value : this.power,
      archetypes: data.archetypes.present
          ? data.archetypes.value
          : this.archetypes,
      interaction: data.interaction.present
          ? data.interaction.value
          : this.interaction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckRow(')
          ..write('id: $id, ')
          ..write('playerId: $playerId, ')
          ..write('name: $name, ')
          ..write('commanderName: $commanderName, ')
          ..write('commanderIds: $commanderIds, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('power: $power, ')
          ..write('archetypes: $archetypes, ')
          ..write('interaction: $interaction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playerId,
    name,
    commanderName,
    commanderIds,
    colorIdentity,
    power,
    archetypes,
    interaction,
    createdAt,
    updatedAt,
    lastPlayedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckRow &&
          other.id == this.id &&
          other.playerId == this.playerId &&
          other.name == this.name &&
          other.commanderName == this.commanderName &&
          other.commanderIds == this.commanderIds &&
          other.colorIdentity == this.colorIdentity &&
          other.power == this.power &&
          other.archetypes == this.archetypes &&
          other.interaction == this.interaction &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastPlayedAt == this.lastPlayedAt);
}

class DecksCompanion extends UpdateCompanion<DeckRow> {
  final Value<String> id;
  final Value<String> playerId;
  final Value<String> name;
  final Value<String> commanderName;
  final Value<String> commanderIds;
  final Value<String> colorIdentity;
  final Value<int> power;
  final Value<String> archetypes;
  final Value<String> interaction;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastPlayedAt;
  final Value<int> rowid;
  const DecksCompanion({
    this.id = const Value.absent(),
    this.playerId = const Value.absent(),
    this.name = const Value.absent(),
    this.commanderName = const Value.absent(),
    this.commanderIds = const Value.absent(),
    this.colorIdentity = const Value.absent(),
    this.power = const Value.absent(),
    this.archetypes = const Value.absent(),
    this.interaction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecksCompanion.insert({
    required String id,
    required String playerId,
    this.name = const Value.absent(),
    this.commanderName = const Value.absent(),
    this.commanderIds = const Value.absent(),
    this.colorIdentity = const Value.absent(),
    this.power = const Value.absent(),
    this.archetypes = const Value.absent(),
    this.interaction = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.lastPlayedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       playerId = Value(playerId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DeckRow> custom({
    Expression<String>? id,
    Expression<String>? playerId,
    Expression<String>? name,
    Expression<String>? commanderName,
    Expression<String>? commanderIds,
    Expression<String>? colorIdentity,
    Expression<int>? power,
    Expression<String>? archetypes,
    Expression<String>? interaction,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastPlayedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playerId != null) 'player_id': playerId,
      if (name != null) 'name': name,
      if (commanderName != null) 'commander_name': commanderName,
      if (commanderIds != null) 'commander_ids': commanderIds,
      if (colorIdentity != null) 'color_identity': colorIdentity,
      if (power != null) 'power': power,
      if (archetypes != null) 'archetypes': archetypes,
      if (interaction != null) 'interaction': interaction,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecksCompanion copyWith({
    Value<String>? id,
    Value<String>? playerId,
    Value<String>? name,
    Value<String>? commanderName,
    Value<String>? commanderIds,
    Value<String>? colorIdentity,
    Value<int>? power,
    Value<String>? archetypes,
    Value<String>? interaction,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastPlayedAt,
    Value<int>? rowid,
  }) {
    return DecksCompanion(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      commanderName: commanderName ?? this.commanderName,
      commanderIds: commanderIds ?? this.commanderIds,
      colorIdentity: colorIdentity ?? this.colorIdentity,
      power: power ?? this.power,
      archetypes: archetypes ?? this.archetypes,
      interaction: interaction ?? this.interaction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (commanderName.present) {
      map['commander_name'] = Variable<String>(commanderName.value);
    }
    if (commanderIds.present) {
      map['commander_ids'] = Variable<String>(commanderIds.value);
    }
    if (colorIdentity.present) {
      map['color_identity'] = Variable<String>(colorIdentity.value);
    }
    if (power.present) {
      map['power'] = Variable<int>(power.value);
    }
    if (archetypes.present) {
      map['archetypes'] = Variable<String>(archetypes.value);
    }
    if (interaction.present) {
      map['interaction'] = Variable<String>(interaction.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecksCompanion(')
          ..write('id: $id, ')
          ..write('playerId: $playerId, ')
          ..write('name: $name, ')
          ..write('commanderName: $commanderName, ')
          ..write('commanderIds: $commanderIds, ')
          ..write('colorIdentity: $colorIdentity, ')
          ..write('power: $power, ')
          ..write('archetypes: $archetypes, ')
          ..write('interaction: $interaction, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$PodWiseDatabase extends GeneratedDatabase {
  _$PodWiseDatabase(QueryExecutor e) : super(e);
  $PodWiseDatabaseManager get managers => $PodWiseDatabaseManager(this);
  late final $PlayerProfilesTable playerProfiles = $PlayerProfilesTable(this);
  late final $GamesTable games = $GamesTable(this);
  late final $GameParticipantsTable gameParticipants = $GameParticipantsTable(
    this,
  );
  late final $CachedCardsTable cachedCards = $CachedCardsTable(this);
  late final $DecksTable decks = $DecksTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    playerProfiles,
    games,
    gameParticipants,
    cachedCards,
    decks,
    settings,
  ];
}

typedef $$PlayerProfilesTableCreateCompanionBuilder =
    PlayerProfilesCompanion Function({
      required String id,
      required String name,
      Value<int> colorIndex,
      required DateTime createdAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });
typedef $$PlayerProfilesTableUpdateCompanionBuilder =
    PlayerProfilesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> colorIndex,
      Value<DateTime> createdAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });

class $$PlayerProfilesTableFilterComposer
    extends Composer<_$PodWiseDatabase, $PlayerProfilesTable> {
  $$PlayerProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayerProfilesTableOrderingComposer
    extends Composer<_$PodWiseDatabase, $PlayerProfilesTable> {
  $$PlayerProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayerProfilesTableAnnotationComposer
    extends Composer<_$PodWiseDatabase, $PlayerProfilesTable> {
  $$PlayerProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$PlayerProfilesTableTableManager
    extends
        RootTableManager<
          _$PodWiseDatabase,
          $PlayerProfilesTable,
          PlayerProfileRow,
          $$PlayerProfilesTableFilterComposer,
          $$PlayerProfilesTableOrderingComposer,
          $$PlayerProfilesTableAnnotationComposer,
          $$PlayerProfilesTableCreateCompanionBuilder,
          $$PlayerProfilesTableUpdateCompanionBuilder,
          (
            PlayerProfileRow,
            BaseReferences<
              _$PodWiseDatabase,
              $PlayerProfilesTable,
              PlayerProfileRow
            >,
          ),
          PlayerProfileRow,
          PrefetchHooks Function()
        > {
  $$PlayerProfilesTableTableManager(
    _$PodWiseDatabase db,
    $PlayerProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayerProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayerProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayerProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerProfilesCompanion(
                id: id,
                name: name,
                colorIndex: colorIndex,
                createdAt: createdAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<int> colorIndex = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayerProfilesCompanion.insert(
                id: id,
                name: name,
                colorIndex: colorIndex,
                createdAt: createdAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayerProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$PodWiseDatabase,
      $PlayerProfilesTable,
      PlayerProfileRow,
      $$PlayerProfilesTableFilterComposer,
      $$PlayerProfilesTableOrderingComposer,
      $$PlayerProfilesTableAnnotationComposer,
      $$PlayerProfilesTableCreateCompanionBuilder,
      $$PlayerProfilesTableUpdateCompanionBuilder,
      (
        PlayerProfileRow,
        BaseReferences<
          _$PodWiseDatabase,
          $PlayerProfilesTable,
          PlayerProfileRow
        >,
      ),
      PlayerProfileRow,
      PrefetchHooks Function()
    >;
typedef $$GamesTableCreateCompanionBuilder =
    GamesCompanion Function({
      required String id,
      required DateTime startedAt,
      Value<DateTime?> finishedAt,
      required int startingLife,
      Value<String?> winnerProfileId,
      Value<bool> deckRoulette,
      Value<int> rowid,
    });
typedef $$GamesTableUpdateCompanionBuilder =
    GamesCompanion Function({
      Value<String> id,
      Value<DateTime> startedAt,
      Value<DateTime?> finishedAt,
      Value<int> startingLife,
      Value<String?> winnerProfileId,
      Value<bool> deckRoulette,
      Value<int> rowid,
    });

class $$GamesTableFilterComposer
    extends Composer<_$PodWiseDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get winnerProfileId => $composableBuilder(
    column: $table.winnerProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deckRoulette => $composableBuilder(
    column: $table.deckRoulette,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GamesTableOrderingComposer
    extends Composer<_$PodWiseDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get winnerProfileId => $composableBuilder(
    column: $table.winnerProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deckRoulette => $composableBuilder(
    column: $table.deckRoulette,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamesTableAnnotationComposer
    extends Composer<_$PodWiseDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startingLife => $composableBuilder(
    column: $table.startingLife,
    builder: (column) => column,
  );

  GeneratedColumn<String> get winnerProfileId => $composableBuilder(
    column: $table.winnerProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deckRoulette => $composableBuilder(
    column: $table.deckRoulette,
    builder: (column) => column,
  );
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$PodWiseDatabase,
          $GamesTable,
          GameRow,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (GameRow, BaseReferences<_$PodWiseDatabase, $GamesTable, GameRow>),
          GameRow,
          PrefetchHooks Function()
        > {
  $$GamesTableTableManager(_$PodWiseDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> startingLife = const Value.absent(),
                Value<String?> winnerProfileId = const Value.absent(),
                Value<bool> deckRoulette = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                startingLife: startingLife,
                winnerProfileId: winnerProfileId,
                deckRoulette: deckRoulette,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                required int startingLife,
                Value<String?> winnerProfileId = const Value.absent(),
                Value<bool> deckRoulette = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GamesCompanion.insert(
                id: id,
                startedAt: startedAt,
                finishedAt: finishedAt,
                startingLife: startingLife,
                winnerProfileId: winnerProfileId,
                deckRoulette: deckRoulette,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$PodWiseDatabase,
      $GamesTable,
      GameRow,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (GameRow, BaseReferences<_$PodWiseDatabase, $GamesTable, GameRow>),
      GameRow,
      PrefetchHooks Function()
    >;
typedef $$GameParticipantsTableCreateCompanionBuilder =
    GameParticipantsCompanion Function({
      Value<int> rowId,
      required String gameId,
      required String profileId,
      required String name,
      required int seatIndex,
      required int colorIndex,
      required int finalLife,
      Value<String?> deckId,
      Value<int?> position,
      Value<bool> eliminated,
    });
typedef $$GameParticipantsTableUpdateCompanionBuilder =
    GameParticipantsCompanion Function({
      Value<int> rowId,
      Value<String> gameId,
      Value<String> profileId,
      Value<String> name,
      Value<int> seatIndex,
      Value<int> colorIndex,
      Value<int> finalLife,
      Value<String?> deckId,
      Value<int?> position,
      Value<bool> eliminated,
    });

class $$GameParticipantsTableFilterComposer
    extends Composer<_$PodWiseDatabase, $GameParticipantsTable> {
  $$GameParticipantsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seatIndex => $composableBuilder(
    column: $table.seatIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get finalLife => $composableBuilder(
    column: $table.finalLife,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get eliminated => $composableBuilder(
    column: $table.eliminated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameParticipantsTableOrderingComposer
    extends Composer<_$PodWiseDatabase, $GameParticipantsTable> {
  $$GameParticipantsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileId => $composableBuilder(
    column: $table.profileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seatIndex => $composableBuilder(
    column: $table.seatIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finalLife => $composableBuilder(
    column: $table.finalLife,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get eliminated => $composableBuilder(
    column: $table.eliminated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameParticipantsTableAnnotationComposer
    extends Composer<_$PodWiseDatabase, $GameParticipantsTable> {
  $$GameParticipantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get profileId =>
      $composableBuilder(column: $table.profileId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get seatIndex =>
      $composableBuilder(column: $table.seatIndex, builder: (column) => column);

  GeneratedColumn<int> get colorIndex => $composableBuilder(
    column: $table.colorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get finalLife =>
      $composableBuilder(column: $table.finalLife, builder: (column) => column);

  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<bool> get eliminated => $composableBuilder(
    column: $table.eliminated,
    builder: (column) => column,
  );
}

class $$GameParticipantsTableTableManager
    extends
        RootTableManager<
          _$PodWiseDatabase,
          $GameParticipantsTable,
          GameParticipantRow,
          $$GameParticipantsTableFilterComposer,
          $$GameParticipantsTableOrderingComposer,
          $$GameParticipantsTableAnnotationComposer,
          $$GameParticipantsTableCreateCompanionBuilder,
          $$GameParticipantsTableUpdateCompanionBuilder,
          (
            GameParticipantRow,
            BaseReferences<
              _$PodWiseDatabase,
              $GameParticipantsTable,
              GameParticipantRow
            >,
          ),
          GameParticipantRow,
          PrefetchHooks Function()
        > {
  $$GameParticipantsTableTableManager(
    _$PodWiseDatabase db,
    $GameParticipantsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameParticipantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameParticipantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameParticipantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                Value<String> gameId = const Value.absent(),
                Value<String> profileId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> seatIndex = const Value.absent(),
                Value<int> colorIndex = const Value.absent(),
                Value<int> finalLife = const Value.absent(),
                Value<String?> deckId = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<bool> eliminated = const Value.absent(),
              }) => GameParticipantsCompanion(
                rowId: rowId,
                gameId: gameId,
                profileId: profileId,
                name: name,
                seatIndex: seatIndex,
                colorIndex: colorIndex,
                finalLife: finalLife,
                deckId: deckId,
                position: position,
                eliminated: eliminated,
              ),
          createCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                required String gameId,
                required String profileId,
                required String name,
                required int seatIndex,
                required int colorIndex,
                required int finalLife,
                Value<String?> deckId = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<bool> eliminated = const Value.absent(),
              }) => GameParticipantsCompanion.insert(
                rowId: rowId,
                gameId: gameId,
                profileId: profileId,
                name: name,
                seatIndex: seatIndex,
                colorIndex: colorIndex,
                finalLife: finalLife,
                deckId: deckId,
                position: position,
                eliminated: eliminated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameParticipantsTableProcessedTableManager =
    ProcessedTableManager<
      _$PodWiseDatabase,
      $GameParticipantsTable,
      GameParticipantRow,
      $$GameParticipantsTableFilterComposer,
      $$GameParticipantsTableOrderingComposer,
      $$GameParticipantsTableAnnotationComposer,
      $$GameParticipantsTableCreateCompanionBuilder,
      $$GameParticipantsTableUpdateCompanionBuilder,
      (
        GameParticipantRow,
        BaseReferences<
          _$PodWiseDatabase,
          $GameParticipantsTable,
          GameParticipantRow
        >,
      ),
      GameParticipantRow,
      PrefetchHooks Function()
    >;
typedef $$CachedCardsTableCreateCompanionBuilder =
    CachedCardsCompanion Function({
      required String id,
      required String name,
      required String searchName,
      required String typeLine,
      Value<String> colorIdentity,
      Value<String?> oracleText,
      Value<String?> manaCost,
      Value<String?> imageSmall,
      Value<String?> imageNormal,
      Value<String?> imageArtCrop,
      Value<String?> scryfallUri,
      Value<String?> artist,
      required DateTime cachedAt,
      Value<int> useCount,
      Value<bool> commanderLegal,
      Value<int> rowid,
    });
typedef $$CachedCardsTableUpdateCompanionBuilder =
    CachedCardsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> searchName,
      Value<String> typeLine,
      Value<String> colorIdentity,
      Value<String?> oracleText,
      Value<String?> manaCost,
      Value<String?> imageSmall,
      Value<String?> imageNormal,
      Value<String?> imageArtCrop,
      Value<String?> scryfallUri,
      Value<String?> artist,
      Value<DateTime> cachedAt,
      Value<int> useCount,
      Value<bool> commanderLegal,
      Value<int> rowid,
    });

class $$CachedCardsTableFilterComposer
    extends Composer<_$PodWiseDatabase, $CachedCardsTable> {
  $$CachedCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeLine => $composableBuilder(
    column: $table.typeLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manaCost => $composableBuilder(
    column: $table.manaCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageNormal => $composableBuilder(
    column: $table.imageNormal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageArtCrop => $composableBuilder(
    column: $table.imageArtCrop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scryfallUri => $composableBuilder(
    column: $table.scryfallUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get commanderLegal => $composableBuilder(
    column: $table.commanderLegal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedCardsTableOrderingComposer
    extends Composer<_$PodWiseDatabase, $CachedCardsTable> {
  $$CachedCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeLine => $composableBuilder(
    column: $table.typeLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manaCost => $composableBuilder(
    column: $table.manaCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageNormal => $composableBuilder(
    column: $table.imageNormal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageArtCrop => $composableBuilder(
    column: $table.imageArtCrop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scryfallUri => $composableBuilder(
    column: $table.scryfallUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get commanderLegal => $composableBuilder(
    column: $table.commanderLegal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedCardsTableAnnotationComposer
    extends Composer<_$PodWiseDatabase, $CachedCardsTable> {
  $$CachedCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get searchName => $composableBuilder(
    column: $table.searchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get typeLine =>
      $composableBuilder(column: $table.typeLine, builder: (column) => column);

  GeneratedColumn<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oracleText => $composableBuilder(
    column: $table.oracleText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manaCost =>
      $composableBuilder(column: $table.manaCost, builder: (column) => column);

  GeneratedColumn<String> get imageSmall => $composableBuilder(
    column: $table.imageSmall,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageNormal => $composableBuilder(
    column: $table.imageNormal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageArtCrop => $composableBuilder(
    column: $table.imageArtCrop,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scryfallUri => $composableBuilder(
    column: $table.scryfallUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);

  GeneratedColumn<bool> get commanderLegal => $composableBuilder(
    column: $table.commanderLegal,
    builder: (column) => column,
  );
}

class $$CachedCardsTableTableManager
    extends
        RootTableManager<
          _$PodWiseDatabase,
          $CachedCardsTable,
          CachedCardRow,
          $$CachedCardsTableFilterComposer,
          $$CachedCardsTableOrderingComposer,
          $$CachedCardsTableAnnotationComposer,
          $$CachedCardsTableCreateCompanionBuilder,
          $$CachedCardsTableUpdateCompanionBuilder,
          (
            CachedCardRow,
            BaseReferences<_$PodWiseDatabase, $CachedCardsTable, CachedCardRow>,
          ),
          CachedCardRow,
          PrefetchHooks Function()
        > {
  $$CachedCardsTableTableManager(_$PodWiseDatabase db, $CachedCardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> searchName = const Value.absent(),
                Value<String> typeLine = const Value.absent(),
                Value<String> colorIdentity = const Value.absent(),
                Value<String?> oracleText = const Value.absent(),
                Value<String?> manaCost = const Value.absent(),
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageNormal = const Value.absent(),
                Value<String?> imageArtCrop = const Value.absent(),
                Value<String?> scryfallUri = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> useCount = const Value.absent(),
                Value<bool> commanderLegal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCardsCompanion(
                id: id,
                name: name,
                searchName: searchName,
                typeLine: typeLine,
                colorIdentity: colorIdentity,
                oracleText: oracleText,
                manaCost: manaCost,
                imageSmall: imageSmall,
                imageNormal: imageNormal,
                imageArtCrop: imageArtCrop,
                scryfallUri: scryfallUri,
                artist: artist,
                cachedAt: cachedAt,
                useCount: useCount,
                commanderLegal: commanderLegal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String searchName,
                required String typeLine,
                Value<String> colorIdentity = const Value.absent(),
                Value<String?> oracleText = const Value.absent(),
                Value<String?> manaCost = const Value.absent(),
                Value<String?> imageSmall = const Value.absent(),
                Value<String?> imageNormal = const Value.absent(),
                Value<String?> imageArtCrop = const Value.absent(),
                Value<String?> scryfallUri = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                required DateTime cachedAt,
                Value<int> useCount = const Value.absent(),
                Value<bool> commanderLegal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedCardsCompanion.insert(
                id: id,
                name: name,
                searchName: searchName,
                typeLine: typeLine,
                colorIdentity: colorIdentity,
                oracleText: oracleText,
                manaCost: manaCost,
                imageSmall: imageSmall,
                imageNormal: imageNormal,
                imageArtCrop: imageArtCrop,
                scryfallUri: scryfallUri,
                artist: artist,
                cachedAt: cachedAt,
                useCount: useCount,
                commanderLegal: commanderLegal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedCardsTableProcessedTableManager =
    ProcessedTableManager<
      _$PodWiseDatabase,
      $CachedCardsTable,
      CachedCardRow,
      $$CachedCardsTableFilterComposer,
      $$CachedCardsTableOrderingComposer,
      $$CachedCardsTableAnnotationComposer,
      $$CachedCardsTableCreateCompanionBuilder,
      $$CachedCardsTableUpdateCompanionBuilder,
      (
        CachedCardRow,
        BaseReferences<_$PodWiseDatabase, $CachedCardsTable, CachedCardRow>,
      ),
      CachedCardRow,
      PrefetchHooks Function()
    >;
typedef $$DecksTableCreateCompanionBuilder =
    DecksCompanion Function({
      required String id,
      required String playerId,
      Value<String> name,
      Value<String> commanderName,
      Value<String> commanderIds,
      Value<String> colorIdentity,
      Value<int> power,
      Value<String> archetypes,
      Value<String> interaction,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });
typedef $$DecksTableUpdateCompanionBuilder =
    DecksCompanion Function({
      Value<String> id,
      Value<String> playerId,
      Value<String> name,
      Value<String> commanderName,
      Value<String> commanderIds,
      Value<String> colorIdentity,
      Value<int> power,
      Value<String> archetypes,
      Value<String> interaction,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastPlayedAt,
      Value<int> rowid,
    });

class $$DecksTableFilterComposer
    extends Composer<_$PodWiseDatabase, $DecksTable> {
  $$DecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commanderIds => $composableBuilder(
    column: $table.commanderIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archetypes => $composableBuilder(
    column: $table.archetypes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get interaction => $composableBuilder(
    column: $table.interaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DecksTableOrderingComposer
    extends Composer<_$PodWiseDatabase, $DecksTable> {
  $$DecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commanderIds => $composableBuilder(
    column: $table.commanderIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get power => $composableBuilder(
    column: $table.power,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archetypes => $composableBuilder(
    column: $table.archetypes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get interaction => $composableBuilder(
    column: $table.interaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DecksTableAnnotationComposer
    extends Composer<_$PodWiseDatabase, $DecksTable> {
  $$DecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get playerId =>
      $composableBuilder(column: $table.playerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get commanderName => $composableBuilder(
    column: $table.commanderName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get commanderIds => $composableBuilder(
    column: $table.commanderIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorIdentity => $composableBuilder(
    column: $table.colorIdentity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get power =>
      $composableBuilder(column: $table.power, builder: (column) => column);

  GeneratedColumn<String> get archetypes => $composableBuilder(
    column: $table.archetypes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get interaction => $composableBuilder(
    column: $table.interaction,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );
}

class $$DecksTableTableManager
    extends
        RootTableManager<
          _$PodWiseDatabase,
          $DecksTable,
          DeckRow,
          $$DecksTableFilterComposer,
          $$DecksTableOrderingComposer,
          $$DecksTableAnnotationComposer,
          $$DecksTableCreateCompanionBuilder,
          $$DecksTableUpdateCompanionBuilder,
          (DeckRow, BaseReferences<_$PodWiseDatabase, $DecksTable, DeckRow>),
          DeckRow,
          PrefetchHooks Function()
        > {
  $$DecksTableTableManager(_$PodWiseDatabase db, $DecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> playerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> commanderName = const Value.absent(),
                Value<String> commanderIds = const Value.absent(),
                Value<String> colorIdentity = const Value.absent(),
                Value<int> power = const Value.absent(),
                Value<String> archetypes = const Value.absent(),
                Value<String> interaction = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion(
                id: id,
                playerId: playerId,
                name: name,
                commanderName: commanderName,
                commanderIds: commanderIds,
                colorIdentity: colorIdentity,
                power: power,
                archetypes: archetypes,
                interaction: interaction,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String playerId,
                Value<String> name = const Value.absent(),
                Value<String> commanderName = const Value.absent(),
                Value<String> commanderIds = const Value.absent(),
                Value<String> colorIdentity = const Value.absent(),
                Value<int> power = const Value.absent(),
                Value<String> archetypes = const Value.absent(),
                Value<String> interaction = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion.insert(
                id: id,
                playerId: playerId,
                name: name,
                commanderName: commanderName,
                commanderIds: commanderIds,
                colorIdentity: colorIdentity,
                power: power,
                archetypes: archetypes,
                interaction: interaction,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastPlayedAt: lastPlayedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DecksTableProcessedTableManager =
    ProcessedTableManager<
      _$PodWiseDatabase,
      $DecksTable,
      DeckRow,
      $$DecksTableFilterComposer,
      $$DecksTableOrderingComposer,
      $$DecksTableAnnotationComposer,
      $$DecksTableCreateCompanionBuilder,
      $$DecksTableUpdateCompanionBuilder,
      (DeckRow, BaseReferences<_$PodWiseDatabase, $DecksTable, DeckRow>),
      DeckRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$PodWiseDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$PodWiseDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$PodWiseDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$PodWiseDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$PodWiseDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$PodWiseDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$PodWiseDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (
        SettingRow,
        BaseReferences<_$PodWiseDatabase, $SettingsTable, SettingRow>,
      ),
      SettingRow,
      PrefetchHooks Function()
    >;

class $PodWiseDatabaseManager {
  final _$PodWiseDatabase _db;
  $PodWiseDatabaseManager(this._db);
  $$PlayerProfilesTableTableManager get playerProfiles =>
      $$PlayerProfilesTableTableManager(_db, _db.playerProfiles);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$GameParticipantsTableTableManager get gameParticipants =>
      $$GameParticipantsTableTableManager(_db, _db.gameParticipants);
  $$CachedCardsTableTableManager get cachedCards =>
      $$CachedCardsTableTableManager(_db, _db.cachedCards);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db, _db.decks);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
