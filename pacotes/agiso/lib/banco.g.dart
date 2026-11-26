// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banco.dart';

// ignore_for_file: type=lint
class $TalhoesTable extends Talhoes with TableInfo<$TalhoesTable, TalhaoSalvo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TalhoesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geometriaMeta = const VerificationMeta(
    'geometria',
  );
  @override
  late final GeneratedColumn<String> geometria = GeneratedColumn<String>(
    'geometria',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taxaPadraoMeta = const VerificationMeta(
    'taxaPadrao',
  );
  @override
  late final GeneratedColumn<int> taxaPadrao = GeneratedColumn<int>(
    'taxa_padrao',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _origemLatMeta = const VerificationMeta(
    'origemLat',
  );
  @override
  late final GeneratedColumn<double> origemLat = GeneratedColumn<double>(
    'origem_lat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _origemLonMeta = const VerificationMeta(
    'origemLon',
  );
  @override
  late final GeneratedColumn<double> origemLon = GeneratedColumn<double>(
    'origem_lon',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ativoMeta = const VerificationMeta('ativo');
  @override
  late final GeneratedColumn<bool> ativo = GeneratedColumn<bool>(
    'ativo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ativo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nome,
    geometria,
    taxaPadrao,
    origemLat,
    origemLon,
    ativo,
    criadoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'talhoes';
  @override
  VerificationContext validateIntegrity(
    Insertable<TalhaoSalvo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('geometria')) {
      context.handle(
        _geometriaMeta,
        geometria.isAcceptableOrUnknown(data['geometria']!, _geometriaMeta),
      );
    } else if (isInserting) {
      context.missing(_geometriaMeta);
    }
    if (data.containsKey('taxa_padrao')) {
      context.handle(
        _taxaPadraoMeta,
        taxaPadrao.isAcceptableOrUnknown(data['taxa_padrao']!, _taxaPadraoMeta),
      );
    } else if (isInserting) {
      context.missing(_taxaPadraoMeta);
    }
    if (data.containsKey('origem_lat')) {
      context.handle(
        _origemLatMeta,
        origemLat.isAcceptableOrUnknown(data['origem_lat']!, _origemLatMeta),
      );
    } else if (isInserting) {
      context.missing(_origemLatMeta);
    }
    if (data.containsKey('origem_lon')) {
      context.handle(
        _origemLonMeta,
        origemLon.isAcceptableOrUnknown(data['origem_lon']!, _origemLonMeta),
      );
    } else if (isInserting) {
      context.missing(_origemLonMeta);
    }
    if (data.containsKey('ativo')) {
      context.handle(
        _ativoMeta,
        ativo.isAcceptableOrUnknown(data['ativo']!, _ativoMeta),
      );
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TalhaoSalvo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TalhaoSalvo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      geometria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}geometria'],
      )!,
      taxaPadrao: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}taxa_padrao'],
      )!,
      origemLat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}origem_lat'],
      )!,
      origemLon: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}origem_lon'],
      )!,
      ativo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ativo'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
    );
  }

  @override
  $TalhoesTable createAlias(String alias) {
    return $TalhoesTable(attachedDatabase, alias);
  }
}

class TalhaoSalvo extends DataClass implements Insertable<TalhaoSalvo> {
  final int id;
  final String nome;

  /// Contorno e zonas de prescrição em graus (JSON).
  final String geometria;
  final int taxaPadrao;
  final double origemLat;
  final double origemLon;
  final bool ativo;
  final DateTime criadoEm;
  const TalhaoSalvo({
    required this.id,
    required this.nome,
    required this.geometria,
    required this.taxaPadrao,
    required this.origemLat,
    required this.origemLon,
    required this.ativo,
    required this.criadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nome'] = Variable<String>(nome);
    map['geometria'] = Variable<String>(geometria);
    map['taxa_padrao'] = Variable<int>(taxaPadrao);
    map['origem_lat'] = Variable<double>(origemLat);
    map['origem_lon'] = Variable<double>(origemLon);
    map['ativo'] = Variable<bool>(ativo);
    map['criado_em'] = Variable<DateTime>(criadoEm);
    return map;
  }

  TalhoesCompanion toCompanion(bool nullToAbsent) {
    return TalhoesCompanion(
      id: Value(id),
      nome: Value(nome),
      geometria: Value(geometria),
      taxaPadrao: Value(taxaPadrao),
      origemLat: Value(origemLat),
      origemLon: Value(origemLon),
      ativo: Value(ativo),
      criadoEm: Value(criadoEm),
    );
  }

  factory TalhaoSalvo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TalhaoSalvo(
      id: serializer.fromJson<int>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      geometria: serializer.fromJson<String>(json['geometria']),
      taxaPadrao: serializer.fromJson<int>(json['taxaPadrao']),
      origemLat: serializer.fromJson<double>(json['origemLat']),
      origemLon: serializer.fromJson<double>(json['origemLon']),
      ativo: serializer.fromJson<bool>(json['ativo']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nome': serializer.toJson<String>(nome),
      'geometria': serializer.toJson<String>(geometria),
      'taxaPadrao': serializer.toJson<int>(taxaPadrao),
      'origemLat': serializer.toJson<double>(origemLat),
      'origemLon': serializer.toJson<double>(origemLon),
      'ativo': serializer.toJson<bool>(ativo),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
    };
  }

  TalhaoSalvo copyWith({
    int? id,
    String? nome,
    String? geometria,
    int? taxaPadrao,
    double? origemLat,
    double? origemLon,
    bool? ativo,
    DateTime? criadoEm,
  }) => TalhaoSalvo(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    geometria: geometria ?? this.geometria,
    taxaPadrao: taxaPadrao ?? this.taxaPadrao,
    origemLat: origemLat ?? this.origemLat,
    origemLon: origemLon ?? this.origemLon,
    ativo: ativo ?? this.ativo,
    criadoEm: criadoEm ?? this.criadoEm,
  );
  TalhaoSalvo copyWithCompanion(TalhoesCompanion data) {
    return TalhaoSalvo(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      geometria: data.geometria.present ? data.geometria.value : this.geometria,
      taxaPadrao: data.taxaPadrao.present
          ? data.taxaPadrao.value
          : this.taxaPadrao,
      origemLat: data.origemLat.present ? data.origemLat.value : this.origemLat,
      origemLon: data.origemLon.present ? data.origemLon.value : this.origemLon,
      ativo: data.ativo.present ? data.ativo.value : this.ativo,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TalhaoSalvo(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('geometria: $geometria, ')
          ..write('taxaPadrao: $taxaPadrao, ')
          ..write('origemLat: $origemLat, ')
          ..write('origemLon: $origemLon, ')
          ..write('ativo: $ativo, ')
          ..write('criadoEm: $criadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nome,
    geometria,
    taxaPadrao,
    origemLat,
    origemLon,
    ativo,
    criadoEm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TalhaoSalvo &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.geometria == this.geometria &&
          other.taxaPadrao == this.taxaPadrao &&
          other.origemLat == this.origemLat &&
          other.origemLon == this.origemLon &&
          other.ativo == this.ativo &&
          other.criadoEm == this.criadoEm);
}

class TalhoesCompanion extends UpdateCompanion<TalhaoSalvo> {
  final Value<int> id;
  final Value<String> nome;
  final Value<String> geometria;
  final Value<int> taxaPadrao;
  final Value<double> origemLat;
  final Value<double> origemLon;
  final Value<bool> ativo;
  final Value<DateTime> criadoEm;
  const TalhoesCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.geometria = const Value.absent(),
    this.taxaPadrao = const Value.absent(),
    this.origemLat = const Value.absent(),
    this.origemLon = const Value.absent(),
    this.ativo = const Value.absent(),
    this.criadoEm = const Value.absent(),
  });
  TalhoesCompanion.insert({
    this.id = const Value.absent(),
    required String nome,
    required String geometria,
    required int taxaPadrao,
    required double origemLat,
    required double origemLon,
    this.ativo = const Value.absent(),
    this.criadoEm = const Value.absent(),
  }) : nome = Value(nome),
       geometria = Value(geometria),
       taxaPadrao = Value(taxaPadrao),
       origemLat = Value(origemLat),
       origemLon = Value(origemLon);
  static Insertable<TalhaoSalvo> custom({
    Expression<int>? id,
    Expression<String>? nome,
    Expression<String>? geometria,
    Expression<int>? taxaPadrao,
    Expression<double>? origemLat,
    Expression<double>? origemLon,
    Expression<bool>? ativo,
    Expression<DateTime>? criadoEm,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (geometria != null) 'geometria': geometria,
      if (taxaPadrao != null) 'taxa_padrao': taxaPadrao,
      if (origemLat != null) 'origem_lat': origemLat,
      if (origemLon != null) 'origem_lon': origemLon,
      if (ativo != null) 'ativo': ativo,
      if (criadoEm != null) 'criado_em': criadoEm,
    });
  }

  TalhoesCompanion copyWith({
    Value<int>? id,
    Value<String>? nome,
    Value<String>? geometria,
    Value<int>? taxaPadrao,
    Value<double>? origemLat,
    Value<double>? origemLon,
    Value<bool>? ativo,
    Value<DateTime>? criadoEm,
  }) {
    return TalhoesCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      geometria: geometria ?? this.geometria,
      taxaPadrao: taxaPadrao ?? this.taxaPadrao,
      origemLat: origemLat ?? this.origemLat,
      origemLon: origemLon ?? this.origemLon,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (geometria.present) {
      map['geometria'] = Variable<String>(geometria.value);
    }
    if (taxaPadrao.present) {
      map['taxa_padrao'] = Variable<int>(taxaPadrao.value);
    }
    if (origemLat.present) {
      map['origem_lat'] = Variable<double>(origemLat.value);
    }
    if (origemLon.present) {
      map['origem_lon'] = Variable<double>(origemLon.value);
    }
    if (ativo.present) {
      map['ativo'] = Variable<bool>(ativo.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TalhoesCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('geometria: $geometria, ')
          ..write('taxaPadrao: $taxaPadrao, ')
          ..write('origemLat: $origemLat, ')
          ..write('origemLon: $origemLon, ')
          ..write('ativo: $ativo, ')
          ..write('criadoEm: $criadoEm')
          ..write(')'))
        .toString();
  }
}

class $TrabalhosTable extends Trabalhos
    with TableInfo<$TrabalhosTable, Trabalho> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrabalhosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _talhaoIdMeta = const VerificationMeta(
    'talhaoId',
  );
  @override
  late final GeneratedColumn<int> talhaoId = GeneratedColumn<int>(
    'talhao_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES talhoes (id)',
    ),
  );
  static const VerificationMeta _inicioMeta = const VerificationMeta('inicio');
  @override
  late final GeneratedColumn<DateTime> inicio = GeneratedColumn<DateTime>(
    'inicio',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _fimMeta = const VerificationMeta('fim');
  @override
  late final GeneratedColumn<DateTime> fim = GeneratedColumn<DateTime>(
    'fim',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hectaresMeta = const VerificationMeta(
    'hectares',
  );
  @override
  late final GeneratedColumn<double> hectares = GeneratedColumn<double>(
    'hectares',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sementesMeta = const VerificationMeta(
    'sementes',
  );
  @override
  late final GeneratedColumn<double> sementes = GeneratedColumn<double>(
    'sementes',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _distanciaMMeta = const VerificationMeta(
    'distanciaM',
  );
  @override
  late final GeneratedColumn<double> distanciaM = GeneratedColumn<double>(
    'distancia_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    talhaoId,
    inicio,
    fim,
    hectares,
    sementes,
    distanciaM,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trabalhos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Trabalho> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('talhao_id')) {
      context.handle(
        _talhaoIdMeta,
        talhaoId.isAcceptableOrUnknown(data['talhao_id']!, _talhaoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_talhaoIdMeta);
    }
    if (data.containsKey('inicio')) {
      context.handle(
        _inicioMeta,
        inicio.isAcceptableOrUnknown(data['inicio']!, _inicioMeta),
      );
    }
    if (data.containsKey('fim')) {
      context.handle(
        _fimMeta,
        fim.isAcceptableOrUnknown(data['fim']!, _fimMeta),
      );
    }
    if (data.containsKey('hectares')) {
      context.handle(
        _hectaresMeta,
        hectares.isAcceptableOrUnknown(data['hectares']!, _hectaresMeta),
      );
    }
    if (data.containsKey('sementes')) {
      context.handle(
        _sementesMeta,
        sementes.isAcceptableOrUnknown(data['sementes']!, _sementesMeta),
      );
    }
    if (data.containsKey('distancia_m')) {
      context.handle(
        _distanciaMMeta,
        distanciaM.isAcceptableOrUnknown(data['distancia_m']!, _distanciaMMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trabalho map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trabalho(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      talhaoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}talhao_id'],
      )!,
      inicio: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}inicio'],
      )!,
      fim: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fim'],
      ),
      hectares: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hectares'],
      )!,
      sementes: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sementes'],
      )!,
      distanciaM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distancia_m'],
      )!,
    );
  }

  @override
  $TrabalhosTable createAlias(String alias) {
    return $TrabalhosTable(attachedDatabase, alias);
  }
}

class Trabalho extends DataClass implements Insertable<Trabalho> {
  final int id;
  final int talhaoId;
  final DateTime inicio;
  final DateTime? fim;
  final double hectares;
  final double sementes;
  final double distanciaM;
  const Trabalho({
    required this.id,
    required this.talhaoId,
    required this.inicio,
    this.fim,
    required this.hectares,
    required this.sementes,
    required this.distanciaM,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['talhao_id'] = Variable<int>(talhaoId);
    map['inicio'] = Variable<DateTime>(inicio);
    if (!nullToAbsent || fim != null) {
      map['fim'] = Variable<DateTime>(fim);
    }
    map['hectares'] = Variable<double>(hectares);
    map['sementes'] = Variable<double>(sementes);
    map['distancia_m'] = Variable<double>(distanciaM);
    return map;
  }

  TrabalhosCompanion toCompanion(bool nullToAbsent) {
    return TrabalhosCompanion(
      id: Value(id),
      talhaoId: Value(talhaoId),
      inicio: Value(inicio),
      fim: fim == null && nullToAbsent ? const Value.absent() : Value(fim),
      hectares: Value(hectares),
      sementes: Value(sementes),
      distanciaM: Value(distanciaM),
    );
  }

  factory Trabalho.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trabalho(
      id: serializer.fromJson<int>(json['id']),
      talhaoId: serializer.fromJson<int>(json['talhaoId']),
      inicio: serializer.fromJson<DateTime>(json['inicio']),
      fim: serializer.fromJson<DateTime?>(json['fim']),
      hectares: serializer.fromJson<double>(json['hectares']),
      sementes: serializer.fromJson<double>(json['sementes']),
      distanciaM: serializer.fromJson<double>(json['distanciaM']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'talhaoId': serializer.toJson<int>(talhaoId),
      'inicio': serializer.toJson<DateTime>(inicio),
      'fim': serializer.toJson<DateTime?>(fim),
      'hectares': serializer.toJson<double>(hectares),
      'sementes': serializer.toJson<double>(sementes),
      'distanciaM': serializer.toJson<double>(distanciaM),
    };
  }

  Trabalho copyWith({
    int? id,
    int? talhaoId,
    DateTime? inicio,
    Value<DateTime?> fim = const Value.absent(),
    double? hectares,
    double? sementes,
    double? distanciaM,
  }) => Trabalho(
    id: id ?? this.id,
    talhaoId: talhaoId ?? this.talhaoId,
    inicio: inicio ?? this.inicio,
    fim: fim.present ? fim.value : this.fim,
    hectares: hectares ?? this.hectares,
    sementes: sementes ?? this.sementes,
    distanciaM: distanciaM ?? this.distanciaM,
  );
  Trabalho copyWithCompanion(TrabalhosCompanion data) {
    return Trabalho(
      id: data.id.present ? data.id.value : this.id,
      talhaoId: data.talhaoId.present ? data.talhaoId.value : this.talhaoId,
      inicio: data.inicio.present ? data.inicio.value : this.inicio,
      fim: data.fim.present ? data.fim.value : this.fim,
      hectares: data.hectares.present ? data.hectares.value : this.hectares,
      sementes: data.sementes.present ? data.sementes.value : this.sementes,
      distanciaM: data.distanciaM.present
          ? data.distanciaM.value
          : this.distanciaM,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trabalho(')
          ..write('id: $id, ')
          ..write('talhaoId: $talhaoId, ')
          ..write('inicio: $inicio, ')
          ..write('fim: $fim, ')
          ..write('hectares: $hectares, ')
          ..write('sementes: $sementes, ')
          ..write('distanciaM: $distanciaM')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, talhaoId, inicio, fim, hectares, sementes, distanciaM);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trabalho &&
          other.id == this.id &&
          other.talhaoId == this.talhaoId &&
          other.inicio == this.inicio &&
          other.fim == this.fim &&
          other.hectares == this.hectares &&
          other.sementes == this.sementes &&
          other.distanciaM == this.distanciaM);
}

class TrabalhosCompanion extends UpdateCompanion<Trabalho> {
  final Value<int> id;
  final Value<int> talhaoId;
  final Value<DateTime> inicio;
  final Value<DateTime?> fim;
  final Value<double> hectares;
  final Value<double> sementes;
  final Value<double> distanciaM;
  const TrabalhosCompanion({
    this.id = const Value.absent(),
    this.talhaoId = const Value.absent(),
    this.inicio = const Value.absent(),
    this.fim = const Value.absent(),
    this.hectares = const Value.absent(),
    this.sementes = const Value.absent(),
    this.distanciaM = const Value.absent(),
  });
  TrabalhosCompanion.insert({
    this.id = const Value.absent(),
    required int talhaoId,
    this.inicio = const Value.absent(),
    this.fim = const Value.absent(),
    this.hectares = const Value.absent(),
    this.sementes = const Value.absent(),
    this.distanciaM = const Value.absent(),
  }) : talhaoId = Value(talhaoId);
  static Insertable<Trabalho> custom({
    Expression<int>? id,
    Expression<int>? talhaoId,
    Expression<DateTime>? inicio,
    Expression<DateTime>? fim,
    Expression<double>? hectares,
    Expression<double>? sementes,
    Expression<double>? distanciaM,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (talhaoId != null) 'talhao_id': talhaoId,
      if (inicio != null) 'inicio': inicio,
      if (fim != null) 'fim': fim,
      if (hectares != null) 'hectares': hectares,
      if (sementes != null) 'sementes': sementes,
      if (distanciaM != null) 'distancia_m': distanciaM,
    });
  }

  TrabalhosCompanion copyWith({
    Value<int>? id,
    Value<int>? talhaoId,
    Value<DateTime>? inicio,
    Value<DateTime?>? fim,
    Value<double>? hectares,
    Value<double>? sementes,
    Value<double>? distanciaM,
  }) {
    return TrabalhosCompanion(
      id: id ?? this.id,
      talhaoId: talhaoId ?? this.talhaoId,
      inicio: inicio ?? this.inicio,
      fim: fim ?? this.fim,
      hectares: hectares ?? this.hectares,
      sementes: sementes ?? this.sementes,
      distanciaM: distanciaM ?? this.distanciaM,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (talhaoId.present) {
      map['talhao_id'] = Variable<int>(talhaoId.value);
    }
    if (inicio.present) {
      map['inicio'] = Variable<DateTime>(inicio.value);
    }
    if (fim.present) {
      map['fim'] = Variable<DateTime>(fim.value);
    }
    if (hectares.present) {
      map['hectares'] = Variable<double>(hectares.value);
    }
    if (sementes.present) {
      map['sementes'] = Variable<double>(sementes.value);
    }
    if (distanciaM.present) {
      map['distancia_m'] = Variable<double>(distanciaM.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrabalhosCompanion(')
          ..write('id: $id, ')
          ..write('talhaoId: $talhaoId, ')
          ..write('inicio: $inicio, ')
          ..write('fim: $fim, ')
          ..write('hectares: $hectares, ')
          ..write('sementes: $sementes, ')
          ..write('distanciaM: $distanciaM')
          ..write(')'))
        .toString();
  }
}

class $MapasAplicacaoTable extends MapasAplicacao
    with TableInfo<$MapasAplicacaoTable, MapaSalvo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MapasAplicacaoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trabalhoIdMeta = const VerificationMeta(
    'trabalhoId',
  );
  @override
  late final GeneratedColumn<int> trabalhoId = GeneratedColumn<int>(
    'trabalho_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trabalhos (id)',
    ),
  );
  static const VerificationMeta _origemEMeta = const VerificationMeta(
    'origemE',
  );
  @override
  late final GeneratedColumn<double> origemE = GeneratedColumn<double>(
    'origem_e',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _origemNMeta = const VerificationMeta(
    'origemN',
  );
  @override
  late final GeneratedColumn<double> origemN = GeneratedColumn<double>(
    'origem_n',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _celulaMeta = const VerificationMeta('celula');
  @override
  late final GeneratedColumn<double> celula = GeneratedColumn<double>(
    'celula',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _larguraMeta = const VerificationMeta(
    'largura',
  );
  @override
  late final GeneratedColumn<int> largura = GeneratedColumn<int>(
    'largura',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _alturaMeta = const VerificationMeta('altura');
  @override
  late final GeneratedColumn<int> altura = GeneratedColumn<int>(
    'altura',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dadosMeta = const VerificationMeta('dados');
  @override
  late final GeneratedColumn<Uint8List> dados = GeneratedColumn<Uint8List>(
    'dados',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sobrepostasMeta = const VerificationMeta(
    'sobrepostas',
  );
  @override
  late final GeneratedColumn<Uint8List> sobrepostas =
      GeneratedColumn<Uint8List>(
        'sobrepostas',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> atualizadoEm = GeneratedColumn<DateTime>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trabalhoId,
    origemE,
    origemN,
    celula,
    largura,
    altura,
    dados,
    sobrepostas,
    atualizadoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mapas_aplicacao';
  @override
  VerificationContext validateIntegrity(
    Insertable<MapaSalvo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('trabalho_id')) {
      context.handle(
        _trabalhoIdMeta,
        trabalhoId.isAcceptableOrUnknown(data['trabalho_id']!, _trabalhoIdMeta),
      );
    }
    if (data.containsKey('origem_e')) {
      context.handle(
        _origemEMeta,
        origemE.isAcceptableOrUnknown(data['origem_e']!, _origemEMeta),
      );
    } else if (isInserting) {
      context.missing(_origemEMeta);
    }
    if (data.containsKey('origem_n')) {
      context.handle(
        _origemNMeta,
        origemN.isAcceptableOrUnknown(data['origem_n']!, _origemNMeta),
      );
    } else if (isInserting) {
      context.missing(_origemNMeta);
    }
    if (data.containsKey('celula')) {
      context.handle(
        _celulaMeta,
        celula.isAcceptableOrUnknown(data['celula']!, _celulaMeta),
      );
    } else if (isInserting) {
      context.missing(_celulaMeta);
    }
    if (data.containsKey('largura')) {
      context.handle(
        _larguraMeta,
        largura.isAcceptableOrUnknown(data['largura']!, _larguraMeta),
      );
    } else if (isInserting) {
      context.missing(_larguraMeta);
    }
    if (data.containsKey('altura')) {
      context.handle(
        _alturaMeta,
        altura.isAcceptableOrUnknown(data['altura']!, _alturaMeta),
      );
    } else if (isInserting) {
      context.missing(_alturaMeta);
    }
    if (data.containsKey('dados')) {
      context.handle(
        _dadosMeta,
        dados.isAcceptableOrUnknown(data['dados']!, _dadosMeta),
      );
    } else if (isInserting) {
      context.missing(_dadosMeta);
    }
    if (data.containsKey('sobrepostas')) {
      context.handle(
        _sobrepostasMeta,
        sobrepostas.isAcceptableOrUnknown(
          data['sobrepostas']!,
          _sobrepostasMeta,
        ),
      );
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trabalhoId};
  @override
  MapaSalvo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MapaSalvo(
      trabalhoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trabalho_id'],
      )!,
      origemE: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}origem_e'],
      )!,
      origemN: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}origem_n'],
      )!,
      celula: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}celula'],
      )!,
      largura: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}largura'],
      )!,
      altura: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}altura'],
      )!,
      dados: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}dados'],
      )!,
      sobrepostas: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}sobrepostas'],
      ),
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $MapasAplicacaoTable createAlias(String alias) {
    return $MapasAplicacaoTable(attachedDatabase, alias);
  }
}

class MapaSalvo extends DataClass implements Insertable<MapaSalvo> {
  final int trabalhoId;
  final double origemE;
  final double origemN;
  final double celula;
  final int largura;
  final int altura;
  final Uint8List dados;

  /// Onde a plantadeira passou duas vezes (zlib); null nos mapas da versão 1.
  final Uint8List? sobrepostas;
  final DateTime atualizadoEm;
  const MapaSalvo({
    required this.trabalhoId,
    required this.origemE,
    required this.origemN,
    required this.celula,
    required this.largura,
    required this.altura,
    required this.dados,
    this.sobrepostas,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['trabalho_id'] = Variable<int>(trabalhoId);
    map['origem_e'] = Variable<double>(origemE);
    map['origem_n'] = Variable<double>(origemN);
    map['celula'] = Variable<double>(celula);
    map['largura'] = Variable<int>(largura);
    map['altura'] = Variable<int>(altura);
    map['dados'] = Variable<Uint8List>(dados);
    if (!nullToAbsent || sobrepostas != null) {
      map['sobrepostas'] = Variable<Uint8List>(sobrepostas);
    }
    map['atualizado_em'] = Variable<DateTime>(atualizadoEm);
    return map;
  }

  MapasAplicacaoCompanion toCompanion(bool nullToAbsent) {
    return MapasAplicacaoCompanion(
      trabalhoId: Value(trabalhoId),
      origemE: Value(origemE),
      origemN: Value(origemN),
      celula: Value(celula),
      largura: Value(largura),
      altura: Value(altura),
      dados: Value(dados),
      sobrepostas: sobrepostas == null && nullToAbsent
          ? const Value.absent()
          : Value(sobrepostas),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory MapaSalvo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MapaSalvo(
      trabalhoId: serializer.fromJson<int>(json['trabalhoId']),
      origemE: serializer.fromJson<double>(json['origemE']),
      origemN: serializer.fromJson<double>(json['origemN']),
      celula: serializer.fromJson<double>(json['celula']),
      largura: serializer.fromJson<int>(json['largura']),
      altura: serializer.fromJson<int>(json['altura']),
      dados: serializer.fromJson<Uint8List>(json['dados']),
      sobrepostas: serializer.fromJson<Uint8List?>(json['sobrepostas']),
      atualizadoEm: serializer.fromJson<DateTime>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trabalhoId': serializer.toJson<int>(trabalhoId),
      'origemE': serializer.toJson<double>(origemE),
      'origemN': serializer.toJson<double>(origemN),
      'celula': serializer.toJson<double>(celula),
      'largura': serializer.toJson<int>(largura),
      'altura': serializer.toJson<int>(altura),
      'dados': serializer.toJson<Uint8List>(dados),
      'sobrepostas': serializer.toJson<Uint8List?>(sobrepostas),
      'atualizadoEm': serializer.toJson<DateTime>(atualizadoEm),
    };
  }

  MapaSalvo copyWith({
    int? trabalhoId,
    double? origemE,
    double? origemN,
    double? celula,
    int? largura,
    int? altura,
    Uint8List? dados,
    Value<Uint8List?> sobrepostas = const Value.absent(),
    DateTime? atualizadoEm,
  }) => MapaSalvo(
    trabalhoId: trabalhoId ?? this.trabalhoId,
    origemE: origemE ?? this.origemE,
    origemN: origemN ?? this.origemN,
    celula: celula ?? this.celula,
    largura: largura ?? this.largura,
    altura: altura ?? this.altura,
    dados: dados ?? this.dados,
    sobrepostas: sobrepostas.present ? sobrepostas.value : this.sobrepostas,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  MapaSalvo copyWithCompanion(MapasAplicacaoCompanion data) {
    return MapaSalvo(
      trabalhoId: data.trabalhoId.present
          ? data.trabalhoId.value
          : this.trabalhoId,
      origemE: data.origemE.present ? data.origemE.value : this.origemE,
      origemN: data.origemN.present ? data.origemN.value : this.origemN,
      celula: data.celula.present ? data.celula.value : this.celula,
      largura: data.largura.present ? data.largura.value : this.largura,
      altura: data.altura.present ? data.altura.value : this.altura,
      dados: data.dados.present ? data.dados.value : this.dados,
      sobrepostas: data.sobrepostas.present
          ? data.sobrepostas.value
          : this.sobrepostas,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MapaSalvo(')
          ..write('trabalhoId: $trabalhoId, ')
          ..write('origemE: $origemE, ')
          ..write('origemN: $origemN, ')
          ..write('celula: $celula, ')
          ..write('largura: $largura, ')
          ..write('altura: $altura, ')
          ..write('dados: $dados, ')
          ..write('sobrepostas: $sobrepostas, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trabalhoId,
    origemE,
    origemN,
    celula,
    largura,
    altura,
    $driftBlobEquality.hash(dados),
    $driftBlobEquality.hash(sobrepostas),
    atualizadoEm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapaSalvo &&
          other.trabalhoId == this.trabalhoId &&
          other.origemE == this.origemE &&
          other.origemN == this.origemN &&
          other.celula == this.celula &&
          other.largura == this.largura &&
          other.altura == this.altura &&
          $driftBlobEquality.equals(other.dados, this.dados) &&
          $driftBlobEquality.equals(other.sobrepostas, this.sobrepostas) &&
          other.atualizadoEm == this.atualizadoEm);
}

class MapasAplicacaoCompanion extends UpdateCompanion<MapaSalvo> {
  final Value<int> trabalhoId;
  final Value<double> origemE;
  final Value<double> origemN;
  final Value<double> celula;
  final Value<int> largura;
  final Value<int> altura;
  final Value<Uint8List> dados;
  final Value<Uint8List?> sobrepostas;
  final Value<DateTime> atualizadoEm;
  const MapasAplicacaoCompanion({
    this.trabalhoId = const Value.absent(),
    this.origemE = const Value.absent(),
    this.origemN = const Value.absent(),
    this.celula = const Value.absent(),
    this.largura = const Value.absent(),
    this.altura = const Value.absent(),
    this.dados = const Value.absent(),
    this.sobrepostas = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
  });
  MapasAplicacaoCompanion.insert({
    this.trabalhoId = const Value.absent(),
    required double origemE,
    required double origemN,
    required double celula,
    required int largura,
    required int altura,
    required Uint8List dados,
    this.sobrepostas = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
  }) : origemE = Value(origemE),
       origemN = Value(origemN),
       celula = Value(celula),
       largura = Value(largura),
       altura = Value(altura),
       dados = Value(dados);
  static Insertable<MapaSalvo> custom({
    Expression<int>? trabalhoId,
    Expression<double>? origemE,
    Expression<double>? origemN,
    Expression<double>? celula,
    Expression<int>? largura,
    Expression<int>? altura,
    Expression<Uint8List>? dados,
    Expression<Uint8List>? sobrepostas,
    Expression<DateTime>? atualizadoEm,
  }) {
    return RawValuesInsertable({
      if (trabalhoId != null) 'trabalho_id': trabalhoId,
      if (origemE != null) 'origem_e': origemE,
      if (origemN != null) 'origem_n': origemN,
      if (celula != null) 'celula': celula,
      if (largura != null) 'largura': largura,
      if (altura != null) 'altura': altura,
      if (dados != null) 'dados': dados,
      if (sobrepostas != null) 'sobrepostas': sobrepostas,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
    });
  }

  MapasAplicacaoCompanion copyWith({
    Value<int>? trabalhoId,
    Value<double>? origemE,
    Value<double>? origemN,
    Value<double>? celula,
    Value<int>? largura,
    Value<int>? altura,
    Value<Uint8List>? dados,
    Value<Uint8List?>? sobrepostas,
    Value<DateTime>? atualizadoEm,
  }) {
    return MapasAplicacaoCompanion(
      trabalhoId: trabalhoId ?? this.trabalhoId,
      origemE: origemE ?? this.origemE,
      origemN: origemN ?? this.origemN,
      celula: celula ?? this.celula,
      largura: largura ?? this.largura,
      altura: altura ?? this.altura,
      dados: dados ?? this.dados,
      sobrepostas: sobrepostas ?? this.sobrepostas,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trabalhoId.present) {
      map['trabalho_id'] = Variable<int>(trabalhoId.value);
    }
    if (origemE.present) {
      map['origem_e'] = Variable<double>(origemE.value);
    }
    if (origemN.present) {
      map['origem_n'] = Variable<double>(origemN.value);
    }
    if (celula.present) {
      map['celula'] = Variable<double>(celula.value);
    }
    if (largura.present) {
      map['largura'] = Variable<int>(largura.value);
    }
    if (altura.present) {
      map['altura'] = Variable<int>(altura.value);
    }
    if (dados.present) {
      map['dados'] = Variable<Uint8List>(dados.value);
    }
    if (sobrepostas.present) {
      map['sobrepostas'] = Variable<Uint8List>(sobrepostas.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<DateTime>(atualizadoEm.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MapasAplicacaoCompanion(')
          ..write('trabalhoId: $trabalhoId, ')
          ..write('origemE: $origemE, ')
          ..write('origemN: $origemN, ')
          ..write('celula: $celula, ')
          ..write('largura: $largura, ')
          ..write('altura: $altura, ')
          ..write('dados: $dados, ')
          ..write('sobrepostas: $sobrepostas, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }
}

abstract class _$Banco extends GeneratedDatabase {
  _$Banco(QueryExecutor e) : super(e);
  $BancoManager get managers => $BancoManager(this);
  late final $TalhoesTable talhoes = $TalhoesTable(this);
  late final $TrabalhosTable trabalhos = $TrabalhosTable(this);
  late final $MapasAplicacaoTable mapasAplicacao = $MapasAplicacaoTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    talhoes,
    trabalhos,
    mapasAplicacao,
  ];
}

typedef $$TalhoesTableCreateCompanionBuilder =
    TalhoesCompanion Function({
      Value<int> id,
      required String nome,
      required String geometria,
      required int taxaPadrao,
      required double origemLat,
      required double origemLon,
      Value<bool> ativo,
      Value<DateTime> criadoEm,
    });
typedef $$TalhoesTableUpdateCompanionBuilder =
    TalhoesCompanion Function({
      Value<int> id,
      Value<String> nome,
      Value<String> geometria,
      Value<int> taxaPadrao,
      Value<double> origemLat,
      Value<double> origemLon,
      Value<bool> ativo,
      Value<DateTime> criadoEm,
    });

final class $$TalhoesTableReferences
    extends BaseReferences<_$Banco, $TalhoesTable, TalhaoSalvo> {
  $$TalhoesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrabalhosTable, List<Trabalho>>
  _trabalhosRefsTable(_$Banco db) => MultiTypedResultKey.fromTable(
    db.trabalhos,
    aliasName: 'talhoes__id__trabalhos__talhao_id',
  );

  $$TrabalhosTableProcessedTableManager get trabalhosRefs {
    final manager = $$TrabalhosTableTableManager(
      $_db,
      $_db.trabalhos,
    ).filter((f) => f.talhaoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trabalhosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TalhoesTableFilterComposer extends Composer<_$Banco, $TalhoesTable> {
  $$TalhoesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get geometria => $composableBuilder(
    column: $table.geometria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxaPadrao => $composableBuilder(
    column: $table.taxaPadrao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get origemLat => $composableBuilder(
    column: $table.origemLat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get origemLon => $composableBuilder(
    column: $table.origemLon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ativo => $composableBuilder(
    column: $table.ativo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trabalhosRefs(
    Expression<bool> Function($$TrabalhosTableFilterComposer f) f,
  ) {
    final $$TrabalhosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trabalhos,
      getReferencedColumn: (t) => t.talhaoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrabalhosTableFilterComposer(
            $db: $db,
            $table: $db.trabalhos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TalhoesTableOrderingComposer extends Composer<_$Banco, $TalhoesTable> {
  $$TalhoesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get geometria => $composableBuilder(
    column: $table.geometria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxaPadrao => $composableBuilder(
    column: $table.taxaPadrao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get origemLat => $composableBuilder(
    column: $table.origemLat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get origemLon => $composableBuilder(
    column: $table.origemLon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ativo => $composableBuilder(
    column: $table.ativo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TalhoesTableAnnotationComposer
    extends Composer<_$Banco, $TalhoesTable> {
  $$TalhoesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get geometria =>
      $composableBuilder(column: $table.geometria, builder: (column) => column);

  GeneratedColumn<int> get taxaPadrao => $composableBuilder(
    column: $table.taxaPadrao,
    builder: (column) => column,
  );

  GeneratedColumn<double> get origemLat =>
      $composableBuilder(column: $table.origemLat, builder: (column) => column);

  GeneratedColumn<double> get origemLon =>
      $composableBuilder(column: $table.origemLon, builder: (column) => column);

  GeneratedColumn<bool> get ativo =>
      $composableBuilder(column: $table.ativo, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  Expression<T> trabalhosRefs<T extends Object>(
    Expression<T> Function($$TrabalhosTableAnnotationComposer a) f,
  ) {
    final $$TrabalhosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trabalhos,
      getReferencedColumn: (t) => t.talhaoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrabalhosTableAnnotationComposer(
            $db: $db,
            $table: $db.trabalhos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TalhoesTableTableManager
    extends
        RootTableManager<
          _$Banco,
          $TalhoesTable,
          TalhaoSalvo,
          $$TalhoesTableFilterComposer,
          $$TalhoesTableOrderingComposer,
          $$TalhoesTableAnnotationComposer,
          $$TalhoesTableCreateCompanionBuilder,
          $$TalhoesTableUpdateCompanionBuilder,
          (TalhaoSalvo, $$TalhoesTableReferences),
          TalhaoSalvo,
          PrefetchHooks Function({bool trabalhosRefs})
        > {
  $$TalhoesTableTableManager(_$Banco db, $TalhoesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TalhoesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TalhoesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TalhoesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> geometria = const Value.absent(),
                Value<int> taxaPadrao = const Value.absent(),
                Value<double> origemLat = const Value.absent(),
                Value<double> origemLon = const Value.absent(),
                Value<bool> ativo = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
              }) => TalhoesCompanion(
                id: id,
                nome: nome,
                geometria: geometria,
                taxaPadrao: taxaPadrao,
                origemLat: origemLat,
                origemLon: origemLon,
                ativo: ativo,
                criadoEm: criadoEm,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nome,
                required String geometria,
                required int taxaPadrao,
                required double origemLat,
                required double origemLon,
                Value<bool> ativo = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
              }) => TalhoesCompanion.insert(
                id: id,
                nome: nome,
                geometria: geometria,
                taxaPadrao: taxaPadrao,
                origemLat: origemLat,
                origemLon: origemLon,
                ativo: ativo,
                criadoEm: criadoEm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TalhoesTable, TalhaoSalvo>(table),
                  $$TalhoesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trabalhosRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (trabalhosRefs) db.trabalhos],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (trabalhosRefs)
                    await $_getPrefetchedDataByColumns<
                      TalhaoSalvo,
                      $TalhoesTable,
                      Trabalho,
                      $TrabalhosTable
                    >(
                      currentTable: table,
                      referencedTable: $$TalhoesTableReferences
                          ._trabalhosRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TalhoesTableReferences(db, table, p0).trabalhosRefs,
                      currentColumn: 'id',
                      referencedColumn: 'talhao_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TalhoesTableProcessedTableManager =
    ProcessedTableManager<
      _$Banco,
      $TalhoesTable,
      TalhaoSalvo,
      $$TalhoesTableFilterComposer,
      $$TalhoesTableOrderingComposer,
      $$TalhoesTableAnnotationComposer,
      $$TalhoesTableCreateCompanionBuilder,
      $$TalhoesTableUpdateCompanionBuilder,
      (TalhaoSalvo, $$TalhoesTableReferences),
      TalhaoSalvo,
      PrefetchHooks Function({bool trabalhosRefs})
    >;
typedef $$TrabalhosTableCreateCompanionBuilder =
    TrabalhosCompanion Function({
      Value<int> id,
      required int talhaoId,
      Value<DateTime> inicio,
      Value<DateTime?> fim,
      Value<double> hectares,
      Value<double> sementes,
      Value<double> distanciaM,
    });
typedef $$TrabalhosTableUpdateCompanionBuilder =
    TrabalhosCompanion Function({
      Value<int> id,
      Value<int> talhaoId,
      Value<DateTime> inicio,
      Value<DateTime?> fim,
      Value<double> hectares,
      Value<double> sementes,
      Value<double> distanciaM,
    });

final class $$TrabalhosTableReferences
    extends BaseReferences<_$Banco, $TrabalhosTable, Trabalho> {
  $$TrabalhosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TalhoesTable _talhaoIdTable(_$Banco db) =>
      db.talhoes.createAlias('trabalhos__talhao_id__talhoes__id');

  $$TalhoesTableProcessedTableManager get talhaoId {
    final $_column = $_itemColumn<int>('talhao_id')!;

    final manager = $$TalhoesTableTableManager(
      $_db,
      $_db.talhoes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_talhaoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MapasAplicacaoTable, List<MapaSalvo>>
  _mapasAplicacaoRefsTable(_$Banco db) => MultiTypedResultKey.fromTable(
    db.mapasAplicacao,
    aliasName: 'trabalhos__id__mapas_aplicacao__trabalho_id',
  );

  $$MapasAplicacaoTableProcessedTableManager get mapasAplicacaoRefs {
    final manager = $$MapasAplicacaoTableTableManager(
      $_db,
      $_db.mapasAplicacao,
    ).filter((f) => f.trabalhoId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mapasAplicacaoRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TrabalhosTableFilterComposer
    extends Composer<_$Banco, $TrabalhosTable> {
  $$TrabalhosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get inicio => $composableBuilder(
    column: $table.inicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fim => $composableBuilder(
    column: $table.fim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hectares => $composableBuilder(
    column: $table.hectares,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sementes => $composableBuilder(
    column: $table.sementes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanciaM => $composableBuilder(
    column: $table.distanciaM,
    builder: (column) => ColumnFilters(column),
  );

  $$TalhoesTableFilterComposer get talhaoId {
    final $$TalhoesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.talhaoId,
      referencedTable: $db.talhoes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TalhoesTableFilterComposer(
            $db: $db,
            $table: $db.talhoes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mapasAplicacaoRefs(
    Expression<bool> Function($$MapasAplicacaoTableFilterComposer f) f,
  ) {
    final $$MapasAplicacaoTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mapasAplicacao,
      getReferencedColumn: (t) => t.trabalhoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapasAplicacaoTableFilterComposer(
            $db: $db,
            $table: $db.mapasAplicacao,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrabalhosTableOrderingComposer
    extends Composer<_$Banco, $TrabalhosTable> {
  $$TrabalhosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get inicio => $composableBuilder(
    column: $table.inicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fim => $composableBuilder(
    column: $table.fim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hectares => $composableBuilder(
    column: $table.hectares,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sementes => $composableBuilder(
    column: $table.sementes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanciaM => $composableBuilder(
    column: $table.distanciaM,
    builder: (column) => ColumnOrderings(column),
  );

  $$TalhoesTableOrderingComposer get talhaoId {
    final $$TalhoesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.talhaoId,
      referencedTable: $db.talhoes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TalhoesTableOrderingComposer(
            $db: $db,
            $table: $db.talhoes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrabalhosTableAnnotationComposer
    extends Composer<_$Banco, $TrabalhosTable> {
  $$TrabalhosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get inicio =>
      $composableBuilder(column: $table.inicio, builder: (column) => column);

  GeneratedColumn<DateTime> get fim =>
      $composableBuilder(column: $table.fim, builder: (column) => column);

  GeneratedColumn<double> get hectares =>
      $composableBuilder(column: $table.hectares, builder: (column) => column);

  GeneratedColumn<double> get sementes =>
      $composableBuilder(column: $table.sementes, builder: (column) => column);

  GeneratedColumn<double> get distanciaM => $composableBuilder(
    column: $table.distanciaM,
    builder: (column) => column,
  );

  $$TalhoesTableAnnotationComposer get talhaoId {
    final $$TalhoesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.talhaoId,
      referencedTable: $db.talhoes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TalhoesTableAnnotationComposer(
            $db: $db,
            $table: $db.talhoes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mapasAplicacaoRefs<T extends Object>(
    Expression<T> Function($$MapasAplicacaoTableAnnotationComposer a) f,
  ) {
    final $$MapasAplicacaoTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mapasAplicacao,
      getReferencedColumn: (t) => t.trabalhoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MapasAplicacaoTableAnnotationComposer(
            $db: $db,
            $table: $db.mapasAplicacao,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrabalhosTableTableManager
    extends
        RootTableManager<
          _$Banco,
          $TrabalhosTable,
          Trabalho,
          $$TrabalhosTableFilterComposer,
          $$TrabalhosTableOrderingComposer,
          $$TrabalhosTableAnnotationComposer,
          $$TrabalhosTableCreateCompanionBuilder,
          $$TrabalhosTableUpdateCompanionBuilder,
          (Trabalho, $$TrabalhosTableReferences),
          Trabalho,
          PrefetchHooks Function({bool talhaoId, bool mapasAplicacaoRefs})
        > {
  $$TrabalhosTableTableManager(_$Banco db, $TrabalhosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrabalhosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrabalhosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrabalhosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> talhaoId = const Value.absent(),
                Value<DateTime> inicio = const Value.absent(),
                Value<DateTime?> fim = const Value.absent(),
                Value<double> hectares = const Value.absent(),
                Value<double> sementes = const Value.absent(),
                Value<double> distanciaM = const Value.absent(),
              }) => TrabalhosCompanion(
                id: id,
                talhaoId: talhaoId,
                inicio: inicio,
                fim: fim,
                hectares: hectares,
                sementes: sementes,
                distanciaM: distanciaM,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int talhaoId,
                Value<DateTime> inicio = const Value.absent(),
                Value<DateTime?> fim = const Value.absent(),
                Value<double> hectares = const Value.absent(),
                Value<double> sementes = const Value.absent(),
                Value<double> distanciaM = const Value.absent(),
              }) => TrabalhosCompanion.insert(
                id: id,
                talhaoId: talhaoId,
                inicio: inicio,
                fim: fim,
                hectares: hectares,
                sementes: sementes,
                distanciaM: distanciaM,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrabalhosTable, Trabalho>(table),
                  $$TrabalhosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({talhaoId = false, mapasAplicacaoRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mapasAplicacaoRefs) db.mapasAplicacao,
                  ],
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
                        if (talhaoId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.talhaoId,
                                    referencedTable: $$TrabalhosTableReferences
                                        ._talhaoIdTable(db),
                                    referencedColumn: $$TrabalhosTableReferences
                                        ._talhaoIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mapasAplicacaoRefs)
                        await $_getPrefetchedDataByColumns<
                          Trabalho,
                          $TrabalhosTable,
                          MapaSalvo,
                          $MapasAplicacaoTable
                        >(
                          currentTable: table,
                          referencedTable: $$TrabalhosTableReferences
                              ._mapasAplicacaoRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TrabalhosTableReferences(
                                db,
                                table,
                                p0,
                              ).mapasAplicacaoRefs,
                          currentColumn: 'id',
                          referencedColumn: 'trabalho_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TrabalhosTableProcessedTableManager =
    ProcessedTableManager<
      _$Banco,
      $TrabalhosTable,
      Trabalho,
      $$TrabalhosTableFilterComposer,
      $$TrabalhosTableOrderingComposer,
      $$TrabalhosTableAnnotationComposer,
      $$TrabalhosTableCreateCompanionBuilder,
      $$TrabalhosTableUpdateCompanionBuilder,
      (Trabalho, $$TrabalhosTableReferences),
      Trabalho,
      PrefetchHooks Function({bool talhaoId, bool mapasAplicacaoRefs})
    >;
typedef $$MapasAplicacaoTableCreateCompanionBuilder =
    MapasAplicacaoCompanion Function({
      Value<int> trabalhoId,
      required double origemE,
      required double origemN,
      required double celula,
      required int largura,
      required int altura,
      required Uint8List dados,
      Value<Uint8List?> sobrepostas,
      Value<DateTime> atualizadoEm,
    });
typedef $$MapasAplicacaoTableUpdateCompanionBuilder =
    MapasAplicacaoCompanion Function({
      Value<int> trabalhoId,
      Value<double> origemE,
      Value<double> origemN,
      Value<double> celula,
      Value<int> largura,
      Value<int> altura,
      Value<Uint8List> dados,
      Value<Uint8List?> sobrepostas,
      Value<DateTime> atualizadoEm,
    });

final class $$MapasAplicacaoTableReferences
    extends BaseReferences<_$Banco, $MapasAplicacaoTable, MapaSalvo> {
  $$MapasAplicacaoTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TrabalhosTable _trabalhoIdTable(_$Banco db) =>
      db.trabalhos.createAlias('mapas_aplicacao__trabalho_id__trabalhos__id');

  $$TrabalhosTableProcessedTableManager get trabalhoId {
    final $_column = $_itemColumn<int>('trabalho_id')!;

    final manager = $$TrabalhosTableTableManager(
      $_db,
      $_db.trabalhos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trabalhoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MapasAplicacaoTableFilterComposer
    extends Composer<_$Banco, $MapasAplicacaoTable> {
  $$MapasAplicacaoTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get origemE => $composableBuilder(
    column: $table.origemE,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get origemN => $composableBuilder(
    column: $table.origemN,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get celula => $composableBuilder(
    column: $table.celula,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get largura => $composableBuilder(
    column: $table.largura,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get altura => $composableBuilder(
    column: $table.altura,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get sobrepostas => $composableBuilder(
    column: $table.sobrepostas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );

  $$TrabalhosTableFilterComposer get trabalhoId {
    final $$TrabalhosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trabalhoId,
      referencedTable: $db.trabalhos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrabalhosTableFilterComposer(
            $db: $db,
            $table: $db.trabalhos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MapasAplicacaoTableOrderingComposer
    extends Composer<_$Banco, $MapasAplicacaoTable> {
  $$MapasAplicacaoTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get origemE => $composableBuilder(
    column: $table.origemE,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get origemN => $composableBuilder(
    column: $table.origemN,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get celula => $composableBuilder(
    column: $table.celula,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get largura => $composableBuilder(
    column: $table.largura,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get altura => $composableBuilder(
    column: $table.altura,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get dados => $composableBuilder(
    column: $table.dados,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get sobrepostas => $composableBuilder(
    column: $table.sobrepostas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  $$TrabalhosTableOrderingComposer get trabalhoId {
    final $$TrabalhosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trabalhoId,
      referencedTable: $db.trabalhos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrabalhosTableOrderingComposer(
            $db: $db,
            $table: $db.trabalhos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MapasAplicacaoTableAnnotationComposer
    extends Composer<_$Banco, $MapasAplicacaoTable> {
  $$MapasAplicacaoTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get origemE =>
      $composableBuilder(column: $table.origemE, builder: (column) => column);

  GeneratedColumn<double> get origemN =>
      $composableBuilder(column: $table.origemN, builder: (column) => column);

  GeneratedColumn<double> get celula =>
      $composableBuilder(column: $table.celula, builder: (column) => column);

  GeneratedColumn<int> get largura =>
      $composableBuilder(column: $table.largura, builder: (column) => column);

  GeneratedColumn<int> get altura =>
      $composableBuilder(column: $table.altura, builder: (column) => column);

  GeneratedColumn<Uint8List> get dados =>
      $composableBuilder(column: $table.dados, builder: (column) => column);

  GeneratedColumn<Uint8List> get sobrepostas => $composableBuilder(
    column: $table.sobrepostas,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );

  $$TrabalhosTableAnnotationComposer get trabalhoId {
    final $$TrabalhosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trabalhoId,
      referencedTable: $db.trabalhos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrabalhosTableAnnotationComposer(
            $db: $db,
            $table: $db.trabalhos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MapasAplicacaoTableTableManager
    extends
        RootTableManager<
          _$Banco,
          $MapasAplicacaoTable,
          MapaSalvo,
          $$MapasAplicacaoTableFilterComposer,
          $$MapasAplicacaoTableOrderingComposer,
          $$MapasAplicacaoTableAnnotationComposer,
          $$MapasAplicacaoTableCreateCompanionBuilder,
          $$MapasAplicacaoTableUpdateCompanionBuilder,
          (MapaSalvo, $$MapasAplicacaoTableReferences),
          MapaSalvo,
          PrefetchHooks Function({bool trabalhoId})
        > {
  $$MapasAplicacaoTableTableManager(_$Banco db, $MapasAplicacaoTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MapasAplicacaoTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MapasAplicacaoTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MapasAplicacaoTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trabalhoId = const Value.absent(),
                Value<double> origemE = const Value.absent(),
                Value<double> origemN = const Value.absent(),
                Value<double> celula = const Value.absent(),
                Value<int> largura = const Value.absent(),
                Value<int> altura = const Value.absent(),
                Value<Uint8List> dados = const Value.absent(),
                Value<Uint8List?> sobrepostas = const Value.absent(),
                Value<DateTime> atualizadoEm = const Value.absent(),
              }) => MapasAplicacaoCompanion(
                trabalhoId: trabalhoId,
                origemE: origemE,
                origemN: origemN,
                celula: celula,
                largura: largura,
                altura: altura,
                dados: dados,
                sobrepostas: sobrepostas,
                atualizadoEm: atualizadoEm,
              ),
          createCompanionCallback:
              ({
                Value<int> trabalhoId = const Value.absent(),
                required double origemE,
                required double origemN,
                required double celula,
                required int largura,
                required int altura,
                required Uint8List dados,
                Value<Uint8List?> sobrepostas = const Value.absent(),
                Value<DateTime> atualizadoEm = const Value.absent(),
              }) => MapasAplicacaoCompanion.insert(
                trabalhoId: trabalhoId,
                origemE: origemE,
                origemN: origemN,
                celula: celula,
                largura: largura,
                altura: altura,
                dados: dados,
                sobrepostas: sobrepostas,
                atualizadoEm: atualizadoEm,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MapasAplicacaoTable, MapaSalvo>(table),
                  $$MapasAplicacaoTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trabalhoId = false}) {
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
                    if (trabalhoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trabalhoId,
                                referencedTable: $$MapasAplicacaoTableReferences
                                    ._trabalhoIdTable(db),
                                referencedColumn:
                                    $$MapasAplicacaoTableReferences
                                        ._trabalhoIdTable(db)
                                        .id,
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

typedef $$MapasAplicacaoTableProcessedTableManager =
    ProcessedTableManager<
      _$Banco,
      $MapasAplicacaoTable,
      MapaSalvo,
      $$MapasAplicacaoTableFilterComposer,
      $$MapasAplicacaoTableOrderingComposer,
      $$MapasAplicacaoTableAnnotationComposer,
      $$MapasAplicacaoTableCreateCompanionBuilder,
      $$MapasAplicacaoTableUpdateCompanionBuilder,
      (MapaSalvo, $$MapasAplicacaoTableReferences),
      MapaSalvo,
      PrefetchHooks Function({bool trabalhoId})
    >;

class $BancoManager {
  final _$Banco _db;
  $BancoManager(this._db);
  $$TalhoesTableTableManager get talhoes =>
      $$TalhoesTableTableManager(_db, _db.talhoes);
  $$TrabalhosTableTableManager get trabalhos =>
      $$TrabalhosTableTableManager(_db, _db.trabalhos);
  $$MapasAplicacaoTableTableManager get mapasAplicacao =>
      $$MapasAplicacaoTableTableManager(_db, _db.mapasAplicacao);
}
