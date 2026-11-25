import 'dart:convert';
import 'package:http/http.dart' as http;

/// Altere com: flutter run --dart-define=API_BASE=https://seu-host/api/v1
const apiBase =
    String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8000/api/v1');

// ---------- helpers de parsing (tolerantes a variações de chave) ----------
int _i(dynamic v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;
double? _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
dynamic _pick(Map m, List<String> ks) {
  for (final k in ks) {
    if (m[k] != null) return m[k];
  }
  return null;
}

int? _n(Map m, List<String> ks) {
  final v = _pick(m, ks);
  return v == null ? null : _i(v);
}

List _list(dynamic j) {
  if (j is List) return j;
  if (j is Map) {
    for (final v in j.values) {
      if (v is List) return v;
    }
  }
  return const [];
}

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

// ---------- modelos ----------
class Filtros {
  String? doenca, hospedeiro, pais, cidade; // nomes (exibição)
  int? doencaId, hospedeiroId; // a API filtra zoonose/hospedeiro por ID
  DateTime? inicio, fim;

  Filtros copy() => Filtros()
    ..doenca = doenca
    ..doencaId = doencaId
    ..hospedeiro = hospedeiro
    ..hospedeiroId = hospedeiroId
    ..pais = pais
    ..cidade = cidade
    ..inicio = inicio
    ..fim = fim;

  int get ativos => [doenca, hospedeiro, pais, cidade].where((e) => e != null).length;

  /// Datas vazias = sem limite (a API aplica uma janela padrão se não receber datas).
  Map<String, String> toQuery() {
    final h = DateTime.now();
    return {
      if (doenca != null) 'doenca': '${doencaId ?? doenca}',
      if (hospedeiro != null) 'hospedeiro': '${hospedeiroId ?? hospedeiro}',
      if (pais != null) 'pais': pais!,
      if (cidade != null) 'cidade': cidade!,
      'data_inicio': _iso(inicio ?? DateTime(2000)),
      'data_fim': _iso(fim ?? DateTime(h.year, h.month, h.day)),
    };
  }
}

class Opcao {
  final int? id;
  final String nome;
  Opcao(this.id, this.nome);
  factory Opcao.from(dynamic v) {
    if (v is Map) {
      final nome = _pick(v, ['nome', 'name', 'titulo', 'cidade', 'pais']) ?? v['id'];
      return Opcao(v['id'] is num ? (v['id'] as num).toInt() : int.tryParse('${v['id']}'), '$nome');
    }
    return Opcao(null, '$v');
  }
}

class Catalogo {
  final List<Opcao> doencas, hospedeiros, paises, cidades;
  Catalogo(this.doencas, this.hospedeiros, this.paises, this.cidades);
  factory Catalogo.vazio() => Catalogo([], [], [], []);

  int? idDe(List<Opcao> l, String? nome) {
    for (final o in l) {
      if (o.nome == nome) return o.id;
    }
    return null;
  }

  static Future<Catalogo> load() async {
    final r = await Future.wait([
      Api._get('/doencas/', {}),
      Api._get('/hospedeiros/', {}),
      Api._get('/paises/', {}),
      Api._get('/cidades/', {}),
    ]);
    List<Opcao> o(dynamic j) =>
        _list(j).map(Opcao.from).where((e) => e.nome.toLowerCase() != 'não informado').toList();
    return Catalogo(o(r[0]), o(r[1]), o(r[2]), o(r[3]));
  }
}

class Bolha {
  final String cidade, pais;
  final double? lat, lng;
  final int ocorrencias, mortes;
  Bolha(this.cidade, this.pais, this.lat, this.lng, this.ocorrencias, this.mortes);

  factory Bolha.from(Map m) {
    var occ = _n(m, ['ocorrencias', 'total_ocorrencias', 'casos']);
    var mor = _n(m, ['mortes', 'total_mortes', 'obitos']);
    final det = _pick(m, ['doencas', 'detalhes']);
    if ((occ == null || mor == null) && det is List) {
      occ ??= det.fold<int>(0, (s, e) => s + (e is Map ? _i(e['ocorrencias']) : 0));
      mor ??= det.fold<int>(0, (s, e) => s + (e is Map ? _i(e['mortes']) : 0));
    }
    return Bolha(
      '${_pick(m, ['cidade', 'local', 'nome']) ?? ''}',
      '${_pick(m, ['pais']) ?? ''}',
      _d(_pick(m, ['latitude', 'lat'])),
      _d(_pick(m, ['longitude', 'lng', 'lon'])),
      occ ?? 0,
      mor ?? 0,
    );
  }
}

class Totais {
  final int ocorrencias, mortes;
  Totais(this.ocorrencias, this.mortes);
  factory Totais.from(dynamic j) {
    if (j is Map && j['total'] is Map) j = j['total'];
    int occ(Map m) => _i(_pick(m, ['ocorrencias', 'total_ocorrencias', 'casos']));
    int mor(Map m) => _i(_pick(m, ['mortes', 'total_mortes', 'obitos']));
    if (j is Map && _pick(j, ['ocorrencias', 'total_ocorrencias']) != null) {
      return Totais(occ(j), mor(j));
    }
    final l = _list(j).whereType<Map>();
    return Totais(l.fold(0, (s, e) => s + occ(e)), l.fold(0, (s, e) => s + mor(e)));
  }
}

String _2(int n) => n.toString().padLeft(2, '0');

class Ponto {
  final String rotulo;
  final int ocorrencias, mortes;
  Ponto(this.rotulo, this.ocorrencias, this.mortes);
  factory Ponto.from(Map m, String gran) {
    var r = '${_pick(m, ['rotulo', 'label', 'periodo', 'data', 'inicio']) ?? ''}';
    final d = DateTime.tryParse(r);
    if (d != null) r = gran == 'mes' ? '${_2(d.month)}/${d.year}' : '${_2(d.day)}/${_2(d.month)}';
    return Ponto(r, _i(_pick(m, ['ocorrencias', 'casos'])), _i(_pick(m, ['mortes', 'obitos'])));
  }
}

class Crescimento {
  final int? occ, occAnt, mor, morAnt;
  final double? pctOcc, pctMor;
  final List<Ponto> serie;
  Crescimento(this.occ, this.occAnt, this.mor, this.morAnt, this.pctOcc, this.pctMor, this.serie);

  factory Crescimento.from(dynamic j, String gran) {
    final m = j is Map ? j : <String, dynamic>{};
    Map sub(dynamic v) => v is Map ? v : {};
    final t = sub(m['total']);
    final o = sub(t['ocorrencias']), mo = sub(t['mortes']);
    return Crescimento(
      _n(o, ['atual']),
      _n(o, ['anterior']),
      _n(mo, ['atual']),
      _n(mo, ['anterior']),
      _d(o['variacao_percentual']),
      _d(mo['variacao_percentual']),
      _list(m['serie_temporal']).whereType<Map>().map((e) => Ponto.from(e, gran)).toList(),
    );
  }
}

class Fonte {
  final String titulo, resumo, link, origem;
  Fonte(this.titulo, this.resumo, this.link, this.origem);
  factory Fonte.from(Map m) {
    final ds = _list(m['doencas'])
        .whereType<Map>()
        .map((e) => '${e['doenca'] ?? ''}')
        .where((e) => e.isNotEmpty)
        .join(', ');
    final d = DateTime.tryParse('${m['data_publicacao'] ?? ''}');
    final data = d == null ? '' : '${_2(d.day)}/${_2(d.month)}/${d.year}';
    return Fonte(
      '${_pick(m, ['titulo', 'title']) ?? ''}',
      '${_pick(m, ['resumo', 'resumo_ia']) ?? ''}',
      '${_pick(m, ['url', 'link', 'link_original']) ?? ''}',
      [ds, data].where((e) => e.isNotEmpty).join(' · '),
    );
  }
}

// ---------- cliente ----------
class Api {
  static Future<dynamic> _get(String path, Map<String, String> q) async {
    final uri = Uri.parse('$apiBase$path').replace(queryParameters: q.isEmpty ? null : q);
    final r = await http.get(uri, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode} em $path');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  static Future<List<Bolha>> mapa(Filtros f) async =>
      _list(await _get('/mapa/', f.toQuery())).whereType<Map>().map(Bolha.from).toList();

  static Future<Totais> totais(Filtros f) async =>
      Totais.from(await _get('/estatisticas/doencas/', f.toQuery()));

  static Future<Crescimento> crescimento(Filtros f, String granularidade) async =>
      Crescimento.from(
          await _get('/estatisticas/crescimento/', {...f.toQuery(), 'granularidade': granularidade}), granularidade);

  static Future<List<Fonte>> fontes(Filtros f, {int? doencaId, String idioma = 'pt'}) async {
    final q = {...f.toQuery(), 'idioma': idioma, 'pagina': '1', 'limite': '50'};
    final j = doencaId != null ? await _get('/doencas/$doencaId/fontes/', q) : await _get('/fontes/', q);
    return _list(j).whereType<Map>().map(Fonte.from).toList();
  }
}
