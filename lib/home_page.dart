import 'package:flutter/material.dart';
import 'api.dart';
import 'detail_page.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Catalogo cat = Catalogo.vazio();
  final Filtros f = Filtros(); // em edição
  Filtros ap = Filtros(); // aplicado
  List<Bolha> bolhas = [];
  Totais? tot;
  Crescimento? cr;
  bool loading = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      cat = await Catalogo.load();
    } catch (e) {
      erro = '$e';
    }
    await _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      loading = true;
      erro = null;
    });
    try {
      // crescimento exige período: sem datas, usa últimos 30 dias
      final g = ap.copy();
      if (g.inicio == null || g.fim == null) {
        final h = DateTime.now();
        g.fim = DateTime(h.year, h.month, h.day);
        g.inicio = g.fim!.subtract(const Duration(days: 30));
      }
      final r = await (Api.mapa(ap), Api.totais(ap), Api.crescimento(g, 'mes')).wait;
      bolhas = r.$1;
      tot = r.$2;
      cr = r.$3;
    } catch (e) {
      erro = 'Não foi possível carregar os dados: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  void _aplicar() {
    ap = f.copy();
    _carregar();
  }

  void _verDetalhes() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailPage(cat: cat, inicial: f.copy())),
      );

  void _limpar() {
    setState(() {
      f
        ..doenca = null
        ..doencaId = null
        ..hospedeiro = null
        ..hospedeiroId = null
        ..pais = null
        ..cidade = null
        ..inicio = null
        ..fim = null;
    });
    ap = Filtros();
    _carregar();
  }

  List<String> _n(List<Opcao> l) => l.map((e) => e.nome).toList();

  Widget _sidebar() => Box(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Filtros do bioma', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ink)),
          const SizedBox(height: 4),
          const Text('Combine os critérios para refinar as ocorrências no bioma Pampa.', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 16),
          Drop('Animal hospedeiro', f.hospedeiro, _n(cat.hospedeiros), (v) => setState(() {
            f.hospedeiro = v;
            f.hospedeiroId = cat.idDe(cat.hospedeiros, v);
          })),
          const SizedBox(height: 12),
          Drop('Zoonose', f.doenca, _n(cat.doencas), (v) => setState(() {
            f.doenca = v;
            f.doencaId = cat.idDe(cat.doencas, v);
          })),
          const SizedBox(height: 12),
          Drop('País', f.pais, _n(cat.paises), (v) => setState(() => f.pais = v)),
          const SizedBox(height: 12),
          Drop('Cidade', f.cidade, _n(cat.cidades), (v) => setState(() => f.cidade = v)),
          const SizedBox(height: 12),
          DateField('Data de início', f.inicio, (d) => setState(() => f.inicio = d)),
          const SizedBox(height: 12),
          DateField('Data de fim', f.fim, (d) => setState(() => f.fim = d)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE3F1ED), borderRadius: BorderRadius.circular(10)),
            child: Text(
              '${f.ativos} filtro${f.ativos == 1 ? '' : 's'} combinado${f.ativos == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: teal),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: teal, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _aplicar,
              child: const Text('Aplicar filtros'),
            ),
          ),
          if (f.doenca != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: teal,
                  side: const BorderSide(color: teal),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _verDetalhes,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Ver detalhes da zoonose'),
              ),
            ),
          ],
          Center(child: TextButton(onPressed: _limpar, child: const Text('Limpar todos', style: TextStyle(color: muted)))),
        ]),
      );

  String get _subtitulo {
    final p = [ap.doenca, ap.hospedeiro, ap.cidade, ap.pais].whereType<String>().toList();
    return p.isEmpty ? 'Todas as zoonoses · Brasil, Uruguai e Argentina' : p.join(' · ');
  }

  Widget _centro() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ocorrências no bioma Pampa', style: TextStyle(fontSize: 26, color: ink)),
        const SizedBox(height: 4),
        Text(_subtitulo, style: const TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 360),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFE3ECEA), borderRadius: BorderRadius.circular(16)),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : erro != null
                    ? Center(child: Text(erro!, textAlign: TextAlign.center, style: const TextStyle(color: red)))
                    : PampaMap(bolhas: bolhas),
          ),
        ),
      ]);

  Widget _visao() => Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('VISÃO GERAL', style: TextStyle(fontSize: 10, letterSpacing: .6, color: muted)),
          const SizedBox(height: 8),
          Text('${tot?.ocorrencias ?? cr?.occ ?? '—'}', style: const TextStyle(fontSize: 30, color: red)),
          const Text('ocorrências confirmadas', style: TextStyle(fontSize: 11, color: muted)),
          const Divider(height: 24),
          Text(fmtPct(cr?.pctOcc), style: const TextStyle(fontSize: 22, color: Color(0xFFE08A2B))),
          const Text('ocorrências no período', style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 16),
          Text('${tot?.mortes ?? cr?.mor ?? '—'}', style: const TextStyle(fontSize: 30, color: ink)),
          const Text('mortes confirmadas', style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 16),
          Text(fmtPct(cr?.pctMor), style: const TextStyle(fontSize: 22, color: Color(0xFFE08A2B))),
          const Text('mortes no período', style: TextStyle(fontSize: 11, color: muted)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            return Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: teal, borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.eco_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('VigiaPampa', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                    Text('Monitoramento epidemiológico do bioma Pampa', style: TextStyle(fontSize: 10, color: muted)),
                  ]),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(width: 280, child: SingleChildScrollView(child: _sidebar())),
                          const SizedBox(width: 20),
                          Expanded(child: _centro()),
                          const SizedBox(width: 20),
                          SizedBox(width: 220, child: _visao()),
                        ])
                      : ListView(children: [
                          _sidebar(),
                          const SizedBox(height: 16),
                          _visao(),
                          const SizedBox(height: 16),
                          SizedBox(height: 520, child: _centro()),
                        ]),
                ),
              ),
            ]);
          }),
        ),
      );
}
