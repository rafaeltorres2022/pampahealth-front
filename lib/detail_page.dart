import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'widgets.dart';

class DetailPage extends StatefulWidget {
  final Catalogo cat;
  final Filtros inicial;
  const DetailPage({super.key, required this.cat, required this.inicial});
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  static const intervalos = ['Últimos 7 dias', 'Últimos 30 dias', 'Últimos 90 dias', 'Personalizado'];
  static const grans = {'Por dia': 'dia', 'Por semana': 'semana', 'Por mês': 'mes'};

  late Filtros f;
  String intervalo = 'Últimos 30 dias';
  String gran = 'semana';
  List<Bolha> bolhas = [];
  Crescimento? cr;
  List<Fonte> fontes = [];
  bool loading = true;
  String? erro;

  @override
  void initState() {
    super.initState();
    f = widget.inicial.copy();
    if (f.inicio == null && f.fim == null) {
      _preset(30);
    } else {
      intervalo = 'Personalizado';
    }
    _carregar();
  }

  void _preset(int dias) {
    final h = DateTime.now();
    f.fim = DateTime(h.year, h.month, h.day);
    f.inicio = f.fim!.subtract(Duration(days: dias));
  }

  int? get _doencaId => f.doencaId ?? widget.cat.idDe(widget.cat.doencas, f.doenca);

  Future<void> _carregar() async {
    setState(() {
      loading = true;
      erro = null;
    });
    try {
      final r = await (Api.mapa(f), Api.crescimento(f, gran), Api.fontes(f, doencaId: _doencaId)).wait;
      bolhas = r.$1;
      cr = r.$2;
      fontes = r.$3;
    } catch (e) {
      erro = 'Não foi possível carregar os dados: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  List<String> _n(List<Opcao> l) => l.map((e) => e.nome).toList();

  int get _occ => cr?.occ ?? bolhas.fold(0, (s, b) => s + b.ocorrencias);
  int get _mor => cr?.mor ?? bolhas.fold(0, (s, b) => s + b.mortes);

  Widget _filtros() => Box(
        child: Wrap(spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
          SizedBox(width: 150, child: DateField('DATA DE INÍCIO', f.inicio, (d) => setState(() {
                f.inicio = d;
                intervalo = 'Personalizado';
              }))),
          SizedBox(width: 150, child: DateField('DATA DE FIM', f.fim, (d) => setState(() {
                f.fim = d;
                intervalo = 'Personalizado';
              }))),
          SizedBox(
            width: 160,
            child: Drop('INTERVALO', intervalo, intervalos, (v) => setState(() {
                  if (v == null) return;
                  intervalo = v;
                  if (v != 'Personalizado') _preset(int.parse(v.split(' ')[1]));
                }), hint: 'Personalizado'),
          ),
          SizedBox(width: 150, child: Drop('HOSPEDEIRO', f.hospedeiro, _n(widget.cat.hospedeiros), (v) => setState(() {
                f.hospedeiro = v;
                f.hospedeiroId = widget.cat.idDe(widget.cat.hospedeiros, v);
              }))),
          SizedBox(width: 180, child: Drop('REGIÃO', f.pais, _n(widget.cat.paises), (v) => setState(() => f.pais = v), hint: 'Todo o bioma Pampa')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: teal, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
            onPressed: _carregar,
            child: const Text('Aplicar período'),
          ),
        ]),
      );

  Widget _kpis() => LayoutBuilder(builder: (_, c) {
        final cards = [
          Kpi('Ocorrências confirmadas', '$_occ', sub: '${cr?.occAnt ?? '—'} no período anterior'),
          Kpi('Mortes confirmadas', '$_mor', sub: '${cr?.morAnt ?? '—'} no período anterior', cor: red),
          Kpi('Crescimento de ocorrências', fmtPct(cr?.pctOcc),
              sub: cr?.occ != null && cr?.occAnt != null ? '${(cr!.occ! - cr!.occAnt!).abs()} ocorrências a ${cr!.occ! >= cr!.occAnt! ? 'mais' : 'menos'}' : null,
              cor: red),
        ];
        return Row(children: [for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: cards[i])]]);
      });

  Widget _mapa() => Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Distribuição de ocorrências e mortes', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
          const Text('Bolhas por agrupamento geográfico · período selecionado', style: TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 10),
          SizedBox(
            height: 380,
            child: Container(
              decoration: BoxDecoration(color: const Color(0xFFE3ECEA), borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(8),
              child: PampaMap(bolhas: bolhas, mostrarMortes: true),
            ),
          ),
          const SizedBox(height: 10),
          const Row(children: [
            Icon(Icons.circle, size: 10, color: teal),
            SizedBox(width: 4),
            Text('Ocorrências', style: TextStyle(fontSize: 11, color: muted)),
            SizedBox(width: 16),
            Icon(Icons.circle, size: 10, color: red),
            SizedBox(width: 4),
            Text('Mortes', style: TextStyle(fontSize: 11, color: muted)),
            Spacer(),
            Text('Tamanho da bolha = volume de ocorrências', style: TextStyle(fontSize: 11, color: muted)),
          ]),
        ]),
      );

  Widget _evolucao() {
    final label = grans.entries.firstWhere((e) => e.value == gran).key;
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Evolução no período', style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
              Text('${fmtData(f.inicio)} a ${fmtData(f.fim)} · novos registros', style: const TextStyle(fontSize: 11, color: muted)),
            ]),
          ),
          DropdownButton<String>(
            value: label,
            underline: const SizedBox(),
            items: grans.keys.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) {
              if (v == null) return;
              gran = grans[v]!;
              _carregar();
            },
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 460, child: BarChart(cr?.serie ?? [])),
          Container(
            width: 200,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFEAF2F0), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('VS. PERÍODO ANTERIOR', style: TextStyle(fontSize: 10, color: muted)),
              const SizedBox(height: 6),
              Text(fmtPct(cr?.pctOcc), style: const TextStyle(fontSize: 24, color: red)),
              Text('Ocorrências · ${cr?.occAnt ?? '—'} → ${cr?.occ ?? '—'}', style: const TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 12),
              Text('${fmtPct(cr?.pctMor)} em mortes', style: const TextStyle(fontSize: 15, color: red)),
              Text('${cr?.morAnt ?? '—'} → ${cr?.mor ?? '—'} mortes confirmadas', style: const TextStyle(fontSize: 11, color: muted)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _card(Fonte p) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p.origem.isNotEmpty)
              Text(p.origem.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: teal)),
            const SizedBox(height: 4),
            Text(p.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFDDEFEA), borderRadius: BorderRadius.circular(6)),
              child: const Text('Resumo da IA', style: TextStyle(fontSize: 10, color: teal)),
            ),
            const SizedBox(height: 8),
            Text(p.resumo, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF3B4F4A))),
            const Divider(height: 20),
            InkWell(
              onTap: p.link.isEmpty ? null : () => launchUrl(Uri.parse(p.link), mode: LaunchMode.externalApplication),
              child: Text('${Uri.tryParse(p.link)?.host ?? ''} · Ler publicação original ↗',
                  style: const TextStyle(fontSize: 12, color: teal, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      );

  Widget _publicacoes() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Publicações relacionadas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ink))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFDDEFEA), borderRadius: BorderRadius.circular(10)),
            child: Text(two(fontes.length), style: const TextStyle(fontSize: 11, color: teal)),
          ),
        ]),
        const Text('Conhecimento para apoiar a vigilância', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 12),
        if (fontes.isEmpty && !loading) const Text('Nenhuma publicação encontrada.', style: TextStyle(color: muted)),
        ...fontes.map(_card),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE3ECEA), borderRadius: BorderRadius.circular(12)),
          child: const Text(
            'Sobre os resumos\nGerados por IA a partir das fontes originais. Consulte a publicação para contexto e orientações completas.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF3B4F4A)),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 1000;
            final esquerda = Column(children: [
              _kpis(),
              const SizedBox(height: 16),
              _mapa(),
              const SizedBox(height: 16),
              _evolucao(),
            ]);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: ink)),
                  const Text('Mapa epidemiológico / Zoonoses / Detalhes', style: TextStyle(fontSize: 11, color: muted)),
                ]),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.doenca ?? 'Zoonose', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: ink)),
                      Text('Vigilância${f.hospedeiro != null ? ' em ${f.hospedeiro!.toLowerCase()}' : ''} · Bioma Pampa · Brasil, Uruguai e Argentina',
                          style: const TextStyle(fontSize: 12, color: muted)),
                    ]),
                  ),
                  SizedBox(
                    width: 220,
                    child: Drop('ZOONOSE', f.doenca, _n(widget.cat.doencas), (v) {
                      if (v == null) return;
                      f.doenca = v;
                      f.doencaId = widget.cat.idDe(widget.cat.doencas, v);
                      _carregar();
                    }, hint: 'Zoonose'),
                  ),
                ]),
                const SizedBox(height: 16),
                _filtros(),
                const SizedBox(height: 16),
                if (erro != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(erro!, style: const TextStyle(color: red))),
                if (loading) const LinearProgressIndicator(color: teal),
                const SizedBox(height: 8),
                wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: esquerda),
                        const SizedBox(width: 20),
                        SizedBox(width: 340, child: _publicacoes()),
                      ])
                    : Column(children: [esquerda, const SizedBox(height: 20), _publicacoes()]),
              ]),
            );
          }),
        ),
      );
}
