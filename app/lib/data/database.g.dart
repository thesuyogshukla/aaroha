// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FlutesTable extends Flutes with TableInfo<$FlutesTable, Flute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
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
  static const VerificationMeta _pitchClassMeta = const VerificationMeta('pitchClass');
  @override
  late final GeneratedColumn<int> pitchClass = GeneratedColumn<int>(
    'pitch_class',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _calibratedSaHzMeta = const VerificationMeta('calibratedSaHz');
  @override
  late final GeneratedColumn<double> calibratedSaHz = GeneratedColumn<double>(
    'calibrated_sa_hz',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calibratedAtMeta = const VerificationMeta('calibratedAt');
  @override
  late final GeneratedColumn<DateTime> calibratedAt = GeneratedColumn<DateTime>(
    'calibrated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rangeLowMeta = const VerificationMeta('rangeLow');
  @override
  late final GeneratedColumn<String> rangeLow = GeneratedColumn<String>(
    'range_low',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('.P'),
  );
  static const VerificationMeta _rangeHighMeta = const VerificationMeta('rangeHigh');
  @override
  late final GeneratedColumn<String> rangeHigh = GeneratedColumn<String>(
    'range_high',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant("P'"),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    pitchClass,
    size,
    calibratedSaHz,
    calibratedAt,
    rangeLow,
    rangeHigh,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flutes';
  @override
  VerificationContext validateIntegrity(Insertable<Flute> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pitch_class')) {
      context.handle(
        _pitchClassMeta,
        pitchClass.isAcceptableOrUnknown(data['pitch_class']!, _pitchClassMeta),
      );
    } else if (isInserting) {
      context.missing(_pitchClassMeta);
    }
    if (data.containsKey('size')) {
      context.handle(_sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('calibrated_sa_hz')) {
      context.handle(
        _calibratedSaHzMeta,
        calibratedSaHz.isAcceptableOrUnknown(data['calibrated_sa_hz']!, _calibratedSaHzMeta),
      );
    }
    if (data.containsKey('calibrated_at')) {
      context.handle(
        _calibratedAtMeta,
        calibratedAt.isAcceptableOrUnknown(data['calibrated_at']!, _calibratedAtMeta),
      );
    }
    if (data.containsKey('range_low')) {
      context.handle(
        _rangeLowMeta,
        rangeLow.isAcceptableOrUnknown(data['range_low']!, _rangeLowMeta),
      );
    }
    if (data.containsKey('range_high')) {
      context.handle(
        _rangeHighMeta,
        rangeHigh.isAcceptableOrUnknown(data['range_high']!, _rangeHighMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Flute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Flute(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      pitchClass: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pitch_class'],
      )!,
      size: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      calibratedSaHz: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calibrated_sa_hz'],
      ),
      calibratedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}calibrated_at'],
      ),
      rangeLow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_low'],
      )!,
      rangeHigh: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_high'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
    );
  }

  @override
  $FlutesTable createAlias(String alias) {
    return $FlutesTable(attachedDatabase, alias);
  }
}

class Flute extends DataClass implements Insertable<Flute> {
  final int id;
  final String name;

  /// [PitchClass.index] of Sa.
  final int pitchClass;

  /// [FluteSize.index].
  final int size;
  final double? calibratedSaHz;
  final DateTime? calibratedAt;

  /// Playable range in ASCII notation.
  final String rangeLow;
  final String rangeHigh;
  final String notes;
  const Flute({
    required this.id,
    required this.name,
    required this.pitchClass,
    required this.size,
    this.calibratedSaHz,
    this.calibratedAt,
    required this.rangeLow,
    required this.rangeHigh,
    required this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['pitch_class'] = Variable<int>(pitchClass);
    map['size'] = Variable<int>(size);
    if (!nullToAbsent || calibratedSaHz != null) {
      map['calibrated_sa_hz'] = Variable<double>(calibratedSaHz);
    }
    if (!nullToAbsent || calibratedAt != null) {
      map['calibrated_at'] = Variable<DateTime>(calibratedAt);
    }
    map['range_low'] = Variable<String>(rangeLow);
    map['range_high'] = Variable<String>(rangeHigh);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  FlutesCompanion toCompanion(bool nullToAbsent) {
    return FlutesCompanion(
      id: Value(id),
      name: Value(name),
      pitchClass: Value(pitchClass),
      size: Value(size),
      calibratedSaHz: calibratedSaHz == null && nullToAbsent
          ? const Value.absent()
          : Value(calibratedSaHz),
      calibratedAt: calibratedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(calibratedAt),
      rangeLow: Value(rangeLow),
      rangeHigh: Value(rangeHigh),
      notes: Value(notes),
    );
  }

  factory Flute.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Flute(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      pitchClass: serializer.fromJson<int>(json['pitchClass']),
      size: serializer.fromJson<int>(json['size']),
      calibratedSaHz: serializer.fromJson<double?>(json['calibratedSaHz']),
      calibratedAt: serializer.fromJson<DateTime?>(json['calibratedAt']),
      rangeLow: serializer.fromJson<String>(json['rangeLow']),
      rangeHigh: serializer.fromJson<String>(json['rangeHigh']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'pitchClass': serializer.toJson<int>(pitchClass),
      'size': serializer.toJson<int>(size),
      'calibratedSaHz': serializer.toJson<double?>(calibratedSaHz),
      'calibratedAt': serializer.toJson<DateTime?>(calibratedAt),
      'rangeLow': serializer.toJson<String>(rangeLow),
      'rangeHigh': serializer.toJson<String>(rangeHigh),
      'notes': serializer.toJson<String>(notes),
    };
  }

  Flute copyWith({
    int? id,
    String? name,
    int? pitchClass,
    int? size,
    Value<double?> calibratedSaHz = const Value.absent(),
    Value<DateTime?> calibratedAt = const Value.absent(),
    String? rangeLow,
    String? rangeHigh,
    String? notes,
  }) => Flute(
    id: id ?? this.id,
    name: name ?? this.name,
    pitchClass: pitchClass ?? this.pitchClass,
    size: size ?? this.size,
    calibratedSaHz: calibratedSaHz.present ? calibratedSaHz.value : this.calibratedSaHz,
    calibratedAt: calibratedAt.present ? calibratedAt.value : this.calibratedAt,
    rangeLow: rangeLow ?? this.rangeLow,
    rangeHigh: rangeHigh ?? this.rangeHigh,
    notes: notes ?? this.notes,
  );
  Flute copyWithCompanion(FlutesCompanion data) {
    return Flute(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      pitchClass: data.pitchClass.present ? data.pitchClass.value : this.pitchClass,
      size: data.size.present ? data.size.value : this.size,
      calibratedSaHz: data.calibratedSaHz.present ? data.calibratedSaHz.value : this.calibratedSaHz,
      calibratedAt: data.calibratedAt.present ? data.calibratedAt.value : this.calibratedAt,
      rangeLow: data.rangeLow.present ? data.rangeLow.value : this.rangeLow,
      rangeHigh: data.rangeHigh.present ? data.rangeHigh.value : this.rangeHigh,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Flute(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pitchClass: $pitchClass, ')
          ..write('size: $size, ')
          ..write('calibratedSaHz: $calibratedSaHz, ')
          ..write('calibratedAt: $calibratedAt, ')
          ..write('rangeLow: $rangeLow, ')
          ..write('rangeHigh: $rangeHigh, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    pitchClass,
    size,
    calibratedSaHz,
    calibratedAt,
    rangeLow,
    rangeHigh,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Flute &&
          other.id == this.id &&
          other.name == this.name &&
          other.pitchClass == this.pitchClass &&
          other.size == this.size &&
          other.calibratedSaHz == this.calibratedSaHz &&
          other.calibratedAt == this.calibratedAt &&
          other.rangeLow == this.rangeLow &&
          other.rangeHigh == this.rangeHigh &&
          other.notes == this.notes);
}

class FlutesCompanion extends UpdateCompanion<Flute> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> pitchClass;
  final Value<int> size;
  final Value<double?> calibratedSaHz;
  final Value<DateTime?> calibratedAt;
  final Value<String> rangeLow;
  final Value<String> rangeHigh;
  final Value<String> notes;
  const FlutesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.pitchClass = const Value.absent(),
    this.size = const Value.absent(),
    this.calibratedSaHz = const Value.absent(),
    this.calibratedAt = const Value.absent(),
    this.rangeLow = const Value.absent(),
    this.rangeHigh = const Value.absent(),
    this.notes = const Value.absent(),
  });
  FlutesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int pitchClass,
    required int size,
    this.calibratedSaHz = const Value.absent(),
    this.calibratedAt = const Value.absent(),
    this.rangeLow = const Value.absent(),
    this.rangeHigh = const Value.absent(),
    this.notes = const Value.absent(),
  }) : name = Value(name),
       pitchClass = Value(pitchClass),
       size = Value(size);
  static Insertable<Flute> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? pitchClass,
    Expression<int>? size,
    Expression<double>? calibratedSaHz,
    Expression<DateTime>? calibratedAt,
    Expression<String>? rangeLow,
    Expression<String>? rangeHigh,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (pitchClass != null) 'pitch_class': pitchClass,
      if (size != null) 'size': size,
      if (calibratedSaHz != null) 'calibrated_sa_hz': calibratedSaHz,
      if (calibratedAt != null) 'calibrated_at': calibratedAt,
      if (rangeLow != null) 'range_low': rangeLow,
      if (rangeHigh != null) 'range_high': rangeHigh,
      if (notes != null) 'notes': notes,
    });
  }

  FlutesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? pitchClass,
    Value<int>? size,
    Value<double?>? calibratedSaHz,
    Value<DateTime?>? calibratedAt,
    Value<String>? rangeLow,
    Value<String>? rangeHigh,
    Value<String>? notes,
  }) {
    return FlutesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      pitchClass: pitchClass ?? this.pitchClass,
      size: size ?? this.size,
      calibratedSaHz: calibratedSaHz ?? this.calibratedSaHz,
      calibratedAt: calibratedAt ?? this.calibratedAt,
      rangeLow: rangeLow ?? this.rangeLow,
      rangeHigh: rangeHigh ?? this.rangeHigh,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pitchClass.present) {
      map['pitch_class'] = Variable<int>(pitchClass.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (calibratedSaHz.present) {
      map['calibrated_sa_hz'] = Variable<double>(calibratedSaHz.value);
    }
    if (calibratedAt.present) {
      map['calibrated_at'] = Variable<DateTime>(calibratedAt.value);
    }
    if (rangeLow.present) {
      map['range_low'] = Variable<String>(rangeLow.value);
    }
    if (rangeHigh.present) {
      map['range_high'] = Variable<String>(rangeHigh.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlutesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('pitchClass: $pitchClass, ')
          ..write('size: $size, ')
          ..write('calibratedSaHz: $calibratedSaHz, ')
          ..write('calibratedAt: $calibratedAt, ')
          ..write('rangeLow: $rangeLow, ')
          ..write('rangeHigh: $rangeHigh, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _fluteIdMeta = const VerificationMeta('fluteId');
  @override
  late final GeneratedColumn<int> fluteId = GeneratedColumn<int>(
    'flute_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES flutes (id)'),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingsJsonMeta = const VerificationMeta('settingsJson');
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
    'settings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saHzMeta = const VerificationMeta('saHz');
  @override
  late final GeneratedColumn<double> saHz = GeneratedColumn<double>(
    'sa_hz',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, fluteId, mode, settingsJson, saHz, startedAt, endedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('flute_id')) {
      context.handle(_fluteIdMeta, fluteId.isAcceptableOrUnknown(data['flute_id']!, _fluteIdMeta));
    } else if (isInserting) {
      context.missing(_fluteIdMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('settings_json')) {
      context.handle(
        _settingsJsonMeta,
        settingsJson.isAcceptableOrUnknown(data['settings_json']!, _settingsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_settingsJsonMeta);
    }
    if (data.containsKey('sa_hz')) {
      context.handle(_saHzMeta, saHz.isAcceptableOrUnknown(data['sa_hz']!, _saHzMeta));
    } else if (isInserting) {
      context.missing(_saHzMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta, endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fluteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flute_id'],
      )!,
      mode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      settingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}settings_json'],
      )!,
      saHz: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sa_hz'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final int fluteId;
  final String mode;

  /// The practice settings used, as JSON.
  final String settingsJson;
  final double saHz;
  final DateTime startedAt;
  final DateTime? endedAt;
  const Session({
    required this.id,
    required this.fluteId,
    required this.mode,
    required this.settingsJson,
    required this.saHz,
    required this.startedAt,
    this.endedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['flute_id'] = Variable<int>(fluteId);
    map['mode'] = Variable<String>(mode);
    map['settings_json'] = Variable<String>(settingsJson);
    map['sa_hz'] = Variable<double>(saHz);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      fluteId: Value(fluteId),
      mode: Value(mode),
      settingsJson: Value(settingsJson),
      saHz: Value(saHz),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent ? const Value.absent() : Value(endedAt),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      fluteId: serializer.fromJson<int>(json['fluteId']),
      mode: serializer.fromJson<String>(json['mode']),
      settingsJson: serializer.fromJson<String>(json['settingsJson']),
      saHz: serializer.fromJson<double>(json['saHz']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fluteId': serializer.toJson<int>(fluteId),
      'mode': serializer.toJson<String>(mode),
      'settingsJson': serializer.toJson<String>(settingsJson),
      'saHz': serializer.toJson<double>(saHz),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
    };
  }

  Session copyWith({
    int? id,
    int? fluteId,
    String? mode,
    String? settingsJson,
    double? saHz,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
  }) => Session(
    id: id ?? this.id,
    fluteId: fluteId ?? this.fluteId,
    mode: mode ?? this.mode,
    settingsJson: settingsJson ?? this.settingsJson,
    saHz: saHz ?? this.saHz,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      fluteId: data.fluteId.present ? data.fluteId.value : this.fluteId,
      mode: data.mode.present ? data.mode.value : this.mode,
      settingsJson: data.settingsJson.present ? data.settingsJson.value : this.settingsJson,
      saHz: data.saHz.present ? data.saHz.value : this.saHz,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('fluteId: $fluteId, ')
          ..write('mode: $mode, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('saHz: $saHz, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fluteId, mode, settingsJson, saHz, startedAt, endedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.fluteId == this.fluteId &&
          other.mode == this.mode &&
          other.settingsJson == this.settingsJson &&
          other.saHz == this.saHz &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<int> fluteId;
  final Value<String> mode;
  final Value<String> settingsJson;
  final Value<double> saHz;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.fluteId = const Value.absent(),
    this.mode = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.saHz = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required int fluteId,
    required String mode,
    required String settingsJson,
    required double saHz,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
  }) : fluteId = Value(fluteId),
       mode = Value(mode),
       settingsJson = Value(settingsJson),
       saHz = Value(saHz),
       startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<int>? fluteId,
    Expression<String>? mode,
    Expression<String>? settingsJson,
    Expression<double>? saHz,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fluteId != null) 'flute_id': fluteId,
      if (mode != null) 'mode': mode,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (saHz != null) 'sa_hz': saHz,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<int>? fluteId,
    Value<String>? mode,
    Value<String>? settingsJson,
    Value<double>? saHz,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      fluteId: fluteId ?? this.fluteId,
      mode: mode ?? this.mode,
      settingsJson: settingsJson ?? this.settingsJson,
      saHz: saHz ?? this.saHz,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fluteId.present) {
      map['flute_id'] = Variable<int>(fluteId.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (saHz.present) {
      map['sa_hz'] = Variable<double>(saHz.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('fluteId: $fluteId, ')
          ..write('mode: $mode, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('saHz: $saHz, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }
}

class $RoundsTable extends Rounds with TableInfo<$RoundsTable, Round> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoundsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sessionId, number, target];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rounds';
  @override
  VerificationContext validateIntegrity(Insertable<Round> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta, number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta, target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Round map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Round(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
    );
  }

  @override
  $RoundsTable createAlias(String alias) {
    return $RoundsTable(attachedDatabase, alias);
  }
}

class Round extends DataClass implements Insertable<Round> {
  final int id;
  final int sessionId;
  final int number;

  /// The target in ASCII notation.
  final String target;
  const Round({
    required this.id,
    required this.sessionId,
    required this.number,
    required this.target,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['number'] = Variable<int>(number);
    map['target'] = Variable<String>(target);
    return map;
  }

  RoundsCompanion toCompanion(bool nullToAbsent) {
    return RoundsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      number: Value(number),
      target: Value(target),
    );
  }

  factory Round.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Round(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      number: serializer.fromJson<int>(json['number']),
      target: serializer.fromJson<String>(json['target']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'number': serializer.toJson<int>(number),
      'target': serializer.toJson<String>(target),
    };
  }

  Round copyWith({int? id, int? sessionId, int? number, String? target}) => Round(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    number: number ?? this.number,
    target: target ?? this.target,
  );
  Round copyWithCompanion(RoundsCompanion data) {
    return Round(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      number: data.number.present ? data.number.value : this.number,
      target: data.target.present ? data.target.value : this.target,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Round(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('number: $number, ')
          ..write('target: $target')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, number, target);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Round &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.number == this.number &&
          other.target == this.target);
}

class RoundsCompanion extends UpdateCompanion<Round> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> number;
  final Value<String> target;
  const RoundsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.number = const Value.absent(),
    this.target = const Value.absent(),
  });
  RoundsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int number,
    required String target,
  }) : sessionId = Value(sessionId),
       number = Value(number),
       target = Value(target);
  static Insertable<Round> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? number,
    Expression<String>? target,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (number != null) 'number': number,
      if (target != null) 'target': target,
    });
  }

  RoundsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? number,
    Value<String>? target,
  }) {
    return RoundsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      number: number ?? this.number,
      target: target ?? this.target,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoundsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('number: $number, ')
          ..write('target: $target')
          ..write(')'))
        .toString();
  }
}

class $AttemptsTable extends Attempts with TableInfo<$AttemptsTable, Attempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _roundIdMeta = const VerificationMeta('roundId');
  @override
  late final GeneratedColumn<int> roundId = GeneratedColumn<int>(
    'round_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES rounds (id)'),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passedMeta = const VerificationMeta('passed');
  @override
  late final GeneratedColumn<bool> passed = GeneratedColumn<bool>(
    'passed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("passed" IN (0, 1))'),
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta('resultJson');
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, roundId, number, passed, resultJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attempts';
  @override
  VerificationContext validateIntegrity(Insertable<Attempt> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('round_id')) {
      context.handle(_roundIdMeta, roundId.isAcceptableOrUnknown(data['round_id']!, _roundIdMeta));
    } else if (isInserting) {
      context.missing(_roundIdMeta);
    }
    if (data.containsKey('number')) {
      context.handle(_numberMeta, number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('passed')) {
      context.handle(_passedMeta, passed.isAcceptableOrUnknown(data['passed']!, _passedMeta));
    } else if (isInserting) {
      context.missing(_passedMeta);
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_resultJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attempt(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      roundId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_id'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      passed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}passed'],
      )!,
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttemptsTable createAlias(String alias) {
    return $AttemptsTable(attachedDatabase, alias);
  }
}

class Attempt extends DataClass implements Insertable<Attempt> {
  final int id;
  final int roundId;
  final int number;
  final bool passed;

  /// Per-note verdicts as JSON (see AttemptRecord).
  final String resultJson;
  final DateTime createdAt;
  const Attempt({
    required this.id,
    required this.roundId,
    required this.number,
    required this.passed,
    required this.resultJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['round_id'] = Variable<int>(roundId);
    map['number'] = Variable<int>(number);
    map['passed'] = Variable<bool>(passed);
    map['result_json'] = Variable<String>(resultJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttemptsCompanion toCompanion(bool nullToAbsent) {
    return AttemptsCompanion(
      id: Value(id),
      roundId: Value(roundId),
      number: Value(number),
      passed: Value(passed),
      resultJson: Value(resultJson),
      createdAt: Value(createdAt),
    );
  }

  factory Attempt.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attempt(
      id: serializer.fromJson<int>(json['id']),
      roundId: serializer.fromJson<int>(json['roundId']),
      number: serializer.fromJson<int>(json['number']),
      passed: serializer.fromJson<bool>(json['passed']),
      resultJson: serializer.fromJson<String>(json['resultJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'roundId': serializer.toJson<int>(roundId),
      'number': serializer.toJson<int>(number),
      'passed': serializer.toJson<bool>(passed),
      'resultJson': serializer.toJson<String>(resultJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Attempt copyWith({
    int? id,
    int? roundId,
    int? number,
    bool? passed,
    String? resultJson,
    DateTime? createdAt,
  }) => Attempt(
    id: id ?? this.id,
    roundId: roundId ?? this.roundId,
    number: number ?? this.number,
    passed: passed ?? this.passed,
    resultJson: resultJson ?? this.resultJson,
    createdAt: createdAt ?? this.createdAt,
  );
  Attempt copyWithCompanion(AttemptsCompanion data) {
    return Attempt(
      id: data.id.present ? data.id.value : this.id,
      roundId: data.roundId.present ? data.roundId.value : this.roundId,
      number: data.number.present ? data.number.value : this.number,
      passed: data.passed.present ? data.passed.value : this.passed,
      resultJson: data.resultJson.present ? data.resultJson.value : this.resultJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attempt(')
          ..write('id: $id, ')
          ..write('roundId: $roundId, ')
          ..write('number: $number, ')
          ..write('passed: $passed, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, roundId, number, passed, resultJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attempt &&
          other.id == this.id &&
          other.roundId == this.roundId &&
          other.number == this.number &&
          other.passed == this.passed &&
          other.resultJson == this.resultJson &&
          other.createdAt == this.createdAt);
}

class AttemptsCompanion extends UpdateCompanion<Attempt> {
  final Value<int> id;
  final Value<int> roundId;
  final Value<int> number;
  final Value<bool> passed;
  final Value<String> resultJson;
  final Value<DateTime> createdAt;
  const AttemptsCompanion({
    this.id = const Value.absent(),
    this.roundId = const Value.absent(),
    this.number = const Value.absent(),
    this.passed = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttemptsCompanion.insert({
    this.id = const Value.absent(),
    required int roundId,
    required int number,
    required bool passed,
    required String resultJson,
    required DateTime createdAt,
  }) : roundId = Value(roundId),
       number = Value(number),
       passed = Value(passed),
       resultJson = Value(resultJson),
       createdAt = Value(createdAt);
  static Insertable<Attempt> custom({
    Expression<int>? id,
    Expression<int>? roundId,
    Expression<int>? number,
    Expression<bool>? passed,
    Expression<String>? resultJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (roundId != null) 'round_id': roundId,
      if (number != null) 'number': number,
      if (passed != null) 'passed': passed,
      if (resultJson != null) 'result_json': resultJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttemptsCompanion copyWith({
    Value<int>? id,
    Value<int>? roundId,
    Value<int>? number,
    Value<bool>? passed,
    Value<String>? resultJson,
    Value<DateTime>? createdAt,
  }) {
    return AttemptsCompanion(
      id: id ?? this.id,
      roundId: roundId ?? this.roundId,
      number: number ?? this.number,
      passed: passed ?? this.passed,
      resultJson: resultJson ?? this.resultJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (roundId.present) {
      map['round_id'] = Variable<int>(roundId.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (passed.present) {
      map['passed'] = Variable<bool>(passed.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttemptsCompanion(')
          ..write('id: $id, ')
          ..write('roundId: $roundId, ')
          ..write('number: $number, ')
          ..write('passed: $passed, ')
          ..write('resultJson: $resultJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
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
  VerificationContext validateIntegrity(Insertable<Setting> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
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

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
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

  factory Setting.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
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

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
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
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
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
  static Insertable<Setting> custom({
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

  SettingsCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
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

class $TunesTable extends Tunes with TableInfo<$TunesTable, StoredTune> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TunesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notationMeta = const VerificationMeta('notation');
  @override
  late final GeneratedColumn<String> notation = GeneratedColumn<String>(
    'notation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, notation, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tunes';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredTune> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notation')) {
      context.handle(
        _notationMeta,
        notation.isAcceptableOrUnknown(data['notation']!, _notationMeta),
      );
    } else if (isInserting) {
      context.missing(_notationMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredTune map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredTune(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notation'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TunesTable createAlias(String alias) {
    return $TunesTable(attachedDatabase, alias);
  }
}

class StoredTune extends DataClass implements Insertable<StoredTune> {
  final int id;
  final String title;

  /// The tune as typed: an optional header, then one line per row (docs/03).
  final String notation;
  final DateTime createdAt;
  final DateTime updatedAt;
  const StoredTune({
    required this.id,
    required this.title,
    required this.notation,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['notation'] = Variable<String>(notation);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TunesCompanion toCompanion(bool nullToAbsent) {
    return TunesCompanion(
      id: Value(id),
      title: Value(title),
      notation: Value(notation),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoredTune.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredTune(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notation: serializer.fromJson<String>(json['notation']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'notation': serializer.toJson<String>(notation),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  StoredTune copyWith({
    int? id,
    String? title,
    String? notation,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => StoredTune(
    id: id ?? this.id,
    title: title ?? this.title,
    notation: notation ?? this.notation,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoredTune copyWithCompanion(TunesCompanion data) {
    return StoredTune(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notation: data.notation.present ? data.notation.value : this.notation,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredTune(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notation: $notation, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, notation, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredTune &&
          other.id == this.id &&
          other.title == this.title &&
          other.notation == this.notation &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TunesCompanion extends UpdateCompanion<StoredTune> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> notation;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TunesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notation = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TunesCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String notation,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : title = Value(title),
       notation = Value(notation),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<StoredTune> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? notation,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notation != null) 'notation': notation,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TunesCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? notation,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TunesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notation: notation ?? this.notation,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notation.present) {
      map['notation'] = Variable<String>(notation.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TunesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notation: $notation, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FlutesTable flutes = $FlutesTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $RoundsTable rounds = $RoundsTable(this);
  late final $AttemptsTable attempts = $AttemptsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $TunesTable tunes = $TunesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    flutes,
    sessions,
    rounds,
    attempts,
    settings,
    tunes,
  ];
}

typedef $$FlutesTableCreateCompanionBuilder =
    FlutesCompanion Function({
      Value<int> id,
      required String name,
      required int pitchClass,
      required int size,
      Value<double?> calibratedSaHz,
      Value<DateTime?> calibratedAt,
      Value<String> rangeLow,
      Value<String> rangeHigh,
      Value<String> notes,
    });
typedef $$FlutesTableUpdateCompanionBuilder =
    FlutesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> pitchClass,
      Value<int> size,
      Value<double?> calibratedSaHz,
      Value<DateTime?> calibratedAt,
      Value<String> rangeLow,
      Value<String> rangeHigh,
      Value<String> notes,
    });

final class $$FlutesTableReferences extends BaseReferences<_$AppDatabase, $FlutesTable, Flute> {
  $$FlutesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionsTable, List<Session>> _sessionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sessions,
        aliasName: $_aliasNameGenerator(db.flutes.id, db.sessions.fluteId),
      );

  $$SessionsTableProcessedTableManager get sessionsRefs {
    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.fluteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sessionsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FlutesTableFilterComposer extends Composer<_$AppDatabase, $FlutesTable> {
  $$FlutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pitchClass =>
      $composableBuilder(column: $table.pitchClass, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get calibratedSaHz =>
      $composableBuilder(column: $table.calibratedSaHz, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get calibratedAt =>
      $composableBuilder(column: $table.calibratedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rangeLow =>
      $composableBuilder(column: $table.rangeLow, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rangeHigh =>
      $composableBuilder(column: $table.rangeHigh, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  Expression<bool> sessionsRefs(Expression<bool> Function($$SessionsTableFilterComposer f) f) {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.fluteId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlutesTableOrderingComposer extends Composer<_$AppDatabase, $FlutesTable> {
  $$FlutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pitchClass =>
      $composableBuilder(column: $table.pitchClass, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get calibratedSaHz => $composableBuilder(
    column: $table.calibratedSaHz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get calibratedAt =>
      $composableBuilder(column: $table.calibratedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rangeLow =>
      $composableBuilder(column: $table.rangeLow, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rangeHigh =>
      $composableBuilder(column: $table.rangeHigh, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$FlutesTableAnnotationComposer extends Composer<_$AppDatabase, $FlutesTable> {
  $$FlutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get pitchClass =>
      $composableBuilder(column: $table.pitchClass, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<double> get calibratedSaHz =>
      $composableBuilder(column: $table.calibratedSaHz, builder: (column) => column);

  GeneratedColumn<DateTime> get calibratedAt =>
      $composableBuilder(column: $table.calibratedAt, builder: (column) => column);

  GeneratedColumn<String> get rangeLow =>
      $composableBuilder(column: $table.rangeLow, builder: (column) => column);

  GeneratedColumn<String> get rangeHigh =>
      $composableBuilder(column: $table.rangeHigh, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> sessionsRefs<T extends Object>(
    Expression<T> Function($$SessionsTableAnnotationComposer a) f,
  ) {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.fluteId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FlutesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FlutesTable,
          Flute,
          $$FlutesTableFilterComposer,
          $$FlutesTableOrderingComposer,
          $$FlutesTableAnnotationComposer,
          $$FlutesTableCreateCompanionBuilder,
          $$FlutesTableUpdateCompanionBuilder,
          (Flute, $$FlutesTableReferences),
          Flute,
          PrefetchHooks Function({bool sessionsRefs})
        > {
  $$FlutesTableTableManager(_$AppDatabase db, $FlutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$FlutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$FlutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> pitchClass = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<double?> calibratedSaHz = const Value.absent(),
                Value<DateTime?> calibratedAt = const Value.absent(),
                Value<String> rangeLow = const Value.absent(),
                Value<String> rangeHigh = const Value.absent(),
                Value<String> notes = const Value.absent(),
              }) => FlutesCompanion(
                id: id,
                name: name,
                pitchClass: pitchClass,
                size: size,
                calibratedSaHz: calibratedSaHz,
                calibratedAt: calibratedAt,
                rangeLow: rangeLow,
                rangeHigh: rangeHigh,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int pitchClass,
                required int size,
                Value<double?> calibratedSaHz = const Value.absent(),
                Value<DateTime?> calibratedAt = const Value.absent(),
                Value<String> rangeLow = const Value.absent(),
                Value<String> rangeHigh = const Value.absent(),
                Value<String> notes = const Value.absent(),
              }) => FlutesCompanion.insert(
                id: id,
                name: name,
                pitchClass: pitchClass,
                size: size,
                calibratedSaHz: calibratedSaHz,
                calibratedAt: calibratedAt,
                rangeLow: rangeLow,
                rangeHigh: rangeHigh,
                notes: notes,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), $$FlutesTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({sessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (sessionsRefs) db.sessions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionsRefs)
                    await $_getPrefetchedData<Flute, $FlutesTable, Session>(
                      currentTable: table,
                      referencedTable: $$FlutesTableReferences._sessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FlutesTableReferences(db, table, p0).sessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.fluteId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FlutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FlutesTable,
      Flute,
      $$FlutesTableFilterComposer,
      $$FlutesTableOrderingComposer,
      $$FlutesTableAnnotationComposer,
      $$FlutesTableCreateCompanionBuilder,
      $$FlutesTableUpdateCompanionBuilder,
      (Flute, $$FlutesTableReferences),
      Flute,
      PrefetchHooks Function({bool sessionsRefs})
    >;
typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      required int fluteId,
      required String mode,
      required String settingsJson,
      required double saHz,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<int> fluteId,
      Value<String> mode,
      Value<String> settingsJson,
      Value<double> saHz,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FlutesTable _fluteIdTable(_$AppDatabase db) =>
      db.flutes.createAlias($_aliasNameGenerator(db.sessions.fluteId, db.flutes.id));

  $$FlutesTableProcessedTableManager get fluteId {
    final $_column = $_itemColumn<int>('flute_id')!;

    final manager = $$FlutesTableTableManager(
      $_db,
      $_db.flutes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fluteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$RoundsTable, List<Round>> _roundsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.rounds,
        aliasName: $_aliasNameGenerator(db.sessions.id, db.rounds.sessionId),
      );

  $$RoundsTableProcessedTableManager get roundsRefs {
    final manager = $$RoundsTableTableManager(
      $_db,
      $_db.rounds,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_roundsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableFilterComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get settingsJson =>
      $composableBuilder(column: $table.settingsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get saHz =>
      $composableBuilder(column: $table.saHz, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnFilters(column));

  $$FlutesTableFilterComposer get fluteId {
    final $$FlutesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fluteId,
      referencedTable: $db.flutes,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FlutesTableFilterComposer(
            $db: $db,
            $table: $db.flutes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> roundsRefs(Expression<bool> Function($$RoundsTableFilterComposer f) f) {
    final $$RoundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoundsTableFilterComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get settingsJson =>
      $composableBuilder(column: $table.settingsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get saHz =>
      $composableBuilder(column: $table.saHz, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  $$FlutesTableOrderingComposer get fluteId {
    final $$FlutesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fluteId,
      referencedTable: $db.flutes,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FlutesTableOrderingComposer(
            $db: $db,
            $table: $db.flutes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionsTableAnnotationComposer extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get settingsJson =>
      $composableBuilder(column: $table.settingsJson, builder: (column) => column);

  GeneratedColumn<double> get saHz =>
      $composableBuilder(column: $table.saHz, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  $$FlutesTableAnnotationComposer get fluteId {
    final $$FlutesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fluteId,
      referencedTable: $db.flutes,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FlutesTableAnnotationComposer(
            $db: $db,
            $table: $db.flutes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> roundsRefs<T extends Object>(
    Expression<T> Function($$RoundsTableAnnotationComposer a) f,
  ) {
    final $$RoundsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.sessionId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoundsTableAnnotationComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool fluteId, bool roundsRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> fluteId = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> settingsJson = const Value.absent(),
                Value<double> saHz = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                fluteId: fluteId,
                mode: mode,
                settingsJson: settingsJson,
                saHz: saHz,
                startedAt: startedAt,
                endedAt: endedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int fluteId,
                required String mode,
                required String settingsJson,
                required double saHz,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
              }) => SessionsCompanion.insert(
                id: id,
                fluteId: fluteId,
                mode: mode,
                settingsJson: settingsJson,
                saHz: saHz,
                startedAt: startedAt,
                endedAt: endedAt,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), $$SessionsTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({fluteId = false, roundsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (roundsRefs) db.rounds],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (fluteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.fluteId,
                                referencedTable: $$SessionsTableReferences._fluteIdTable(db),
                                referencedColumn: $$SessionsTableReferences._fluteIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (roundsRefs)
                    await $_getPrefetchedData<Session, $SessionsTable, Round>(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences._roundsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SessionsTableReferences(db, table, p0).roundsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool fluteId, bool roundsRefs})
    >;
typedef $$RoundsTableCreateCompanionBuilder =
    RoundsCompanion Function({
      Value<int> id,
      required int sessionId,
      required int number,
      required String target,
    });
typedef $$RoundsTableUpdateCompanionBuilder =
    RoundsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> number,
      Value<String> target,
    });

final class $$RoundsTableReferences extends BaseReferences<_$AppDatabase, $RoundsTable, Round> {
  $$RoundsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias($_aliasNameGenerator(db.rounds.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$AttemptsTable, List<Attempt>> _attemptsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.attempts,
        aliasName: $_aliasNameGenerator(db.rounds.id, db.attempts.roundId),
      );

  $$AttemptsTableProcessedTableManager get attemptsRefs {
    final manager = $$AttemptsTableTableManager(
      $_db,
      $_db.attempts,
    ).filter((f) => f.roundId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attemptsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RoundsTableFilterComposer extends Composer<_$AppDatabase, $RoundsTable> {
  $$RoundsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> attemptsRefs(Expression<bool> Function($$AttemptsTableFilterComposer f) f) {
    final $$AttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.roundId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AttemptsTableFilterComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoundsTableOrderingComposer extends Composer<_$AppDatabase, $RoundsTable> {
  $$RoundsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RoundsTableAnnotationComposer extends Composer<_$AppDatabase, $RoundsTable> {
  $$RoundsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> attemptsRefs<T extends Object>(
    Expression<T> Function($$AttemptsTableAnnotationComposer a) f,
  ) {
    final $$AttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attempts,
      getReferencedColumn: (t) => t.roundId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.attempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RoundsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoundsTable,
          Round,
          $$RoundsTableFilterComposer,
          $$RoundsTableOrderingComposer,
          $$RoundsTableAnnotationComposer,
          $$RoundsTableCreateCompanionBuilder,
          $$RoundsTableUpdateCompanionBuilder,
          (Round, $$RoundsTableReferences),
          Round,
          PrefetchHooks Function({bool sessionId, bool attemptsRefs})
        > {
  $$RoundsTableTableManager(_$AppDatabase db, $RoundsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RoundsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RoundsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoundsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<String> target = const Value.absent(),
              }) => RoundsCompanion(id: id, sessionId: sessionId, number: number, target: target),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int number,
                required String target,
              }) => RoundsCompanion.insert(
                id: id,
                sessionId: sessionId,
                number: number,
                target: target,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), $$RoundsTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({sessionId = false, attemptsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (attemptsRefs) db.attempts],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$RoundsTableReferences._sessionIdTable(db),
                                referencedColumn: $$RoundsTableReferences._sessionIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (attemptsRefs)
                    await $_getPrefetchedData<Round, $RoundsTable, Attempt>(
                      currentTable: table,
                      referencedTable: $$RoundsTableReferences._attemptsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RoundsTableReferences(db, table, p0).attemptsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.roundId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RoundsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoundsTable,
      Round,
      $$RoundsTableFilterComposer,
      $$RoundsTableOrderingComposer,
      $$RoundsTableAnnotationComposer,
      $$RoundsTableCreateCompanionBuilder,
      $$RoundsTableUpdateCompanionBuilder,
      (Round, $$RoundsTableReferences),
      Round,
      PrefetchHooks Function({bool sessionId, bool attemptsRefs})
    >;
typedef $$AttemptsTableCreateCompanionBuilder =
    AttemptsCompanion Function({
      Value<int> id,
      required int roundId,
      required int number,
      required bool passed,
      required String resultJson,
      required DateTime createdAt,
    });
typedef $$AttemptsTableUpdateCompanionBuilder =
    AttemptsCompanion Function({
      Value<int> id,
      Value<int> roundId,
      Value<int> number,
      Value<bool> passed,
      Value<String> resultJson,
      Value<DateTime> createdAt,
    });

final class $$AttemptsTableReferences
    extends BaseReferences<_$AppDatabase, $AttemptsTable, Attempt> {
  $$AttemptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoundsTable _roundIdTable(_$AppDatabase db) =>
      db.rounds.createAlias($_aliasNameGenerator(db.attempts.roundId, db.rounds.id));

  $$RoundsTableProcessedTableManager get roundId {
    final $_column = $_itemColumn<int>('round_id')!;

    final manager = $$RoundsTableTableManager(
      $_db,
      $_db.rounds,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roundIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AttemptsTableFilterComposer extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get passed =>
      $composableBuilder(column: $table.passed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultJson =>
      $composableBuilder(column: $table.resultJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$RoundsTableFilterComposer get roundId {
    final $$RoundsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roundId,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoundsTableFilterComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableOrderingComposer extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get passed =>
      $composableBuilder(column: $table.passed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultJson =>
      $composableBuilder(column: $table.resultJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$RoundsTableOrderingComposer get roundId {
    final $$RoundsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roundId,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoundsTableOrderingComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableAnnotationComposer extends Composer<_$AppDatabase, $AttemptsTable> {
  $$AttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<bool> get passed =>
      $composableBuilder(column: $table.passed, builder: (column) => column);

  GeneratedColumn<String> get resultJson =>
      $composableBuilder(column: $table.resultJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$RoundsTableAnnotationComposer get roundId {
    final $$RoundsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roundId,
      referencedTable: $db.rounds,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$RoundsTableAnnotationComposer(
            $db: $db,
            $table: $db.rounds,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttemptsTable,
          Attempt,
          $$AttemptsTableFilterComposer,
          $$AttemptsTableOrderingComposer,
          $$AttemptsTableAnnotationComposer,
          $$AttemptsTableCreateCompanionBuilder,
          $$AttemptsTableUpdateCompanionBuilder,
          (Attempt, $$AttemptsTableReferences),
          Attempt,
          PrefetchHooks Function({bool roundId})
        > {
  $$AttemptsTableTableManager(_$AppDatabase db, $AttemptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> roundId = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<bool> passed = const Value.absent(),
                Value<String> resultJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttemptsCompanion(
                id: id,
                roundId: roundId,
                number: number,
                passed: passed,
                resultJson: resultJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int roundId,
                required int number,
                required bool passed,
                required String resultJson,
                required DateTime createdAt,
              }) => AttemptsCompanion.insert(
                id: id,
                roundId: roundId,
                number: number,
                passed: passed,
                resultJson: resultJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), $$AttemptsTableReferences(db, table, e))).toList(),
          prefetchHooksCallback: ({roundId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (roundId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.roundId,
                                referencedTable: $$AttemptsTableReferences._roundIdTable(db),
                                referencedColumn: $$AttemptsTableReferences._roundIdTable(db).id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttemptsTable,
      Attempt,
      $$AttemptsTableFilterComposer,
      $$AttemptsTableOrderingComposer,
      $$AttemptsTableAnnotationComposer,
      $$AttemptsTableCreateCompanionBuilder,
      $$AttemptsTableUpdateCompanionBuilder,
      (Attempt, $$AttemptsTableReferences),
      Attempt,
      PrefetchHooks Function({bool roundId})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({required String key, required String value, Value<int> rowid});
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({Value<String> key, Value<String> value, Value<int> rowid});

class $$SettingsTableFilterComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer extends Composer<_$AppDatabase, $SettingsTable> {
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
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SettingsTableOrderingComposer($db: db, $table: table),
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
              }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$TunesTableCreateCompanionBuilder =
    TunesCompanion Function({
      Value<int> id,
      required String title,
      required String notation,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$TunesTableUpdateCompanionBuilder =
    TunesCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String> notation,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$TunesTableFilterComposer extends Composer<_$AppDatabase, $TunesTable> {
  $$TunesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notation =>
      $composableBuilder(column: $table.notation, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TunesTableOrderingComposer extends Composer<_$AppDatabase, $TunesTable> {
  $$TunesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notation =>
      $composableBuilder(column: $table.notation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TunesTableAnnotationComposer extends Composer<_$AppDatabase, $TunesTable> {
  $$TunesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notation =>
      $composableBuilder(column: $table.notation, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TunesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TunesTable,
          StoredTune,
          $$TunesTableFilterComposer,
          $$TunesTableOrderingComposer,
          $$TunesTableAnnotationComposer,
          $$TunesTableCreateCompanionBuilder,
          $$TunesTableUpdateCompanionBuilder,
          (StoredTune, BaseReferences<_$AppDatabase, $TunesTable, StoredTune>),
          StoredTune,
          PrefetchHooks Function()
        > {
  $$TunesTableTableManager(_$AppDatabase db, $TunesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TunesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TunesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TunesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> notation = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TunesCompanion(
                id: id,
                title: title,
                notation: notation,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String notation,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => TunesCompanion.insert(
                id: id,
                title: title,
                notation: notation,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) =>
              p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TunesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TunesTable,
      StoredTune,
      $$TunesTableFilterComposer,
      $$TunesTableOrderingComposer,
      $$TunesTableAnnotationComposer,
      $$TunesTableCreateCompanionBuilder,
      $$TunesTableUpdateCompanionBuilder,
      (StoredTune, BaseReferences<_$AppDatabase, $TunesTable, StoredTune>),
      StoredTune,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FlutesTableTableManager get flutes => $$FlutesTableTableManager(_db, _db.flutes);
  $$SessionsTableTableManager get sessions => $$SessionsTableTableManager(_db, _db.sessions);
  $$RoundsTableTableManager get rounds => $$RoundsTableTableManager(_db, _db.rounds);
  $$AttemptsTableTableManager get attempts => $$AttemptsTableTableManager(_db, _db.attempts);
  $$SettingsTableTableManager get settings => $$SettingsTableTableManager(_db, _db.settings);
  $$TunesTableTableManager get tunes => $$TunesTableTableManager(_db, _db.tunes);
}
