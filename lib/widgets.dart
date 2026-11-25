import 'dart:math';
import 'package:flutter/material.dart';
import 'api.dart';

const teal = Color(0xFF0F7F6B);
const red = Color(0xFFC0443A);
const ink = Color(0xFF16302B);
const muted = Color(0xFF6B7F7A);
const bg = Color(0xFFF0F5F4);

String two(int n) => n.toString().padLeft(2, '0');
String fmtData(DateTime? d) => d == null ? 'dd/mm/aaaa' : '${two(d.day)}/${two(d.month)}/${d.year}';
String fmtPct(double? v) =>
    v == null ? '—' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1).replaceAll('.', ',')}%';

class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2EBE8)),
        ),
        child: child,
      );
}

class Kpi extends StatelessWidget {
  final String label, valor;
  final String? sub;
  final Color cor;
  const Kpi(this.label, this.valor, {super.key, this.sub, this.cor = ink});
  @override
  Widget build(BuildContext context) => Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: muted)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 28, color: cor, fontWeight: FontWeight.w500)),
          if (sub != null) Text(sub!, style: const TextStyle(fontSize: 11, color: muted)),
        ]),
      );
}

InputDecoration _dec([String? hint]) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD5E0DD))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD5E0DD))),
    );

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ink)),
    );

class Drop extends StatelessWidget {
  final String label, hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const Drop(this.label, this.value, this.items, this.onChanged, {super.key, this.hint = 'Todos'});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          decoration: _dec(),
          hint: Text(hint, style: const TextStyle(fontSize: 14)),
          items: [
            DropdownMenuItem<String>(value: null, child: Text(hint, style: const TextStyle(fontSize: 14))),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))),
          ],
          onChanged: onChanged,
        ),
      ]);
}

class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  const DateField(this.label, this.value, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) onChanged(d);
          },
          child: InputDecorator(
            decoration: _dec().copyWith(
              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: teal),
              suffixIcon: value == null ? null : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => onChanged(null)),
            ),
            child: Text(fmtData(value), style: TextStyle(fontSize: 14, color: value == null ? muted : ink)),
          ),
        ),
      ]);
}

// ================= MAPA SIMPLIFICADO DO PAMPA =================
// Contornos APROXIMADOS (lon, lat). Para maior precisão, substitua por GeoJSON real.
const _lon0 = -64.0, _lon1 = -49.5, _lat0 = -39.2, _lat1 = -29.2;
const _aspect = 1.2;

class _Pais {
  final Color cor;
  final List<List<double>> pts;
  const _Pais(this.cor, this.pts);
}

const _paises = <_Pais>[
  // Brasil (metade sul do RS)
  _Pais(Color(0xFFCFE3BC), [
    [-57.6, -30.2], [-57.0, -29.7], [-55.5, -29.2], [-53.5, -29.3], [-51.0, -29.8], [-50.2, -29.9],
    [-50.9, -31.0], [-51.8, -32.2], [-52.7, -33.3], [-53.4, -33.7], [-53.4, -33.0], [-53.9, -31.9],
    [-55.0, -31.0], [-56.0, -30.1],
  ]),
  // Uruguai
  _Pais(Color(0xFFF1DFB5), [
    [-57.6, -30.2], [-56.0, -30.1], [-55.0, -31.0], [-53.9, -31.9], [-53.4, -33.0], [-53.4, -33.7],
    [-54.2, -34.7], [-55.0, -34.9], [-56.0, -34.9], [-57.0, -34.4], [-58.4, -33.9], [-58.2, -33.0],
    [-58.0, -32.2], [-58.1, -31.5],
  ]),
  // Argentina (pampa úmida)
  _Pais(Color(0xFFBBD5E8), [
    [-57.6, -30.2], [-58.1, -31.5], [-58.0, -32.2], [-58.2, -33.0], [-58.4, -33.9], [-57.5, -34.6],
    [-57.0, -35.3], [-56.7, -36.4], [-57.5, -37.3], [-57.6, -38.1], [-59.0, -38.8], [-61.5, -38.9],
    [-62.3, -38.8], [-63.5, -38.2], [-63.5, -35.0], [-63.0, -33.0], [-62.0, -31.0], [-60.5, -30.4],
    [-59.5, -30.1], [-58.5, -30.0],
  ]),
];

Offset _proj(double lon, double lat, Size s) =>
    Offset((lon - _lon0) / (_lon1 - _lon0) * s.width, (_lat1 - lat) / (_lat1 - _lat0) * s.height);

class _PampaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _paises) {
      final path = Path();
      for (var i = 0; i < p.pts.length; i++) {
        final o = _proj(p.pts[i][0], p.pts[i][1], size);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = p.cor);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

String _norm(String s) {
  const a = 'áàâãäéèêëíìîïóòôõöúùûüçñ', b = 'aaaaaeeeeiiiiooooouuuucn';
  var r = s.toLowerCase().trim();
  for (var i = 0; i < a.length; i++) {
    r = r.replaceAll(a[i], b[i]);
  }
  return r;
}

// Coordenadas (lon, lat) de cidades do Pampa, usadas enquanto a API não envia latitude/longitude.
const _cidades = <String, (double, double)>{
  'uruguaiana': (-57.09, -29.76), 'alegrete': (-55.79, -29.78), 'quarai': (-56.45, -30.38),
  'santana do livramento': (-55.53, -30.89), 'rivera': (-55.55, -30.90), 'dom pedrito': (-54.67, -30.98),
  'bage': (-54.10, -31.33), 'sao gabriel': (-54.32, -30.34), 'santa maria': (-53.81, -29.69),
  'pelotas': (-52.34, -31.77), 'rio grande': (-52.10, -32.03), 'jaguarao': (-53.38, -32.57),
  'montevideo': (-56.19, -34.90), 'salto': (-57.96, -31.38), 'paysandu': (-58.08, -32.32),
  'melo': (-54.18, -32.37), 'tacuarembo': (-56.0, -31.72),
  'buenos aires': (-58.38, -34.60), 'la plata': (-57.95, -34.92), 'rosario': (-60.65, -32.95),
  'mar del plata': (-57.55, -38.0),
};

/// Posição (lon, lat) do local, ou null se não der para posicionar dentro da área do Pampa.
(double, double)? _pos(Bolha b) {
  (double, double)? p;
  if (b.lat != null && b.lng != null) p = (b.lng!, b.lat!);
  p ??= _cidades[_norm(b.cidade)];
  if (p == null) {
    final pais = _norm(b.pais);
    (double, double)? c = pais.contains('bras')
        ? (-53.6, -30.4)
        : pais.contains('urug')
            ? (-56.0, -32.8)
            : pais.contains('argent')
                ? (-60.5, -35.5)
                : null;
    if (c != null) {
      final h = b.cidade.hashCode;
      p = (c.$1 + ((h % 7) - 3) * 0.25, c.$2 + (((h ~/ 7) % 7) - 3) * 0.2);
    }
  }
  if (p == null || p.$1 < _lon0 || p.$1 > _lon1 || p.$2 < _lat0 || p.$2 > _lat1) return null;
  return p;
}

class PampaMap extends StatelessWidget {
  final List<Bolha> bolhas;
  final bool mostrarMortes;
  const PampaMap({super.key, required this.bolhas, this.mostrarMortes = false});

  Widget _bolha(Bolha b, Offset o, int maxOcc) {
    final r = 13 + 22 * sqrt(b.ocorrencias / maxOcc);
    return Positioned(
      left: o.dx - r,
      top: o.dy - r,
      width: r * 2,
      height: r * 2,
      child: Tooltip(
        message: '${b.cidade}\n${b.ocorrencias} ocorrências · ${b.mortes} mortes',
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: teal.withOpacity(.9),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text('${b.ocorrencias}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          if (mostrarMortes && b.mortes > 0)
            Positioned(
              right: -6,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                child: Text('${b.mortes}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final h = c.maxHeight.isFinite ? min(c.maxHeight, c.maxWidth / _aspect) : c.maxWidth / _aspect;
        final size = Size(h * _aspect, h);
        final comOcc = bolhas.where((b) => b.ocorrencias > 0).toList();
        final plot = <(Bolha, Offset)>[];
        for (final b in comOcc) {
          final p = _pos(b);
          if (p != null) plot.add((b, _proj(p.$1, p.$2, size)));
        }
        final ocultos = comOcc.length - plot.length;
        final maxOcc = plot.fold<int>(1, (m, e) => max(m, e.$1.ocorrencias));
        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: CustomPaint(painter: _PampaPainter())),
              for (final e in plot) _bolha(e.$1, e.$2, maxOcc),
              if (ocultos > 0)
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: Text('$ocultos local(is) fora do Pampa ou sem coordenadas',
                      style: const TextStyle(fontSize: 10, color: muted)),
                ),
            ]),
          ),
        );
      });
}

// ================= GRÁFICO DE BARRAS =================
class BarChart extends StatelessWidget {
  final List<Ponto> serie;
  const BarChart(this.serie, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 210,
        child: serie.isEmpty
            ? const Center(child: Text('Sem dados no período', style: TextStyle(color: muted)))
            : CustomPaint(painter: _BarPainter(serie), size: Size.infinite),
      );
}

class _BarPainter extends CustomPainter {
  final List<Ponto> s;
  _BarPainter(this.s);

  void _txt(Canvas c, String t, Offset o, {Color cor = muted, double sz = 10, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: TextStyle(color: cor, fontSize: sz, fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(o.dx - tp.width / 2, o.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0, bottom = 24.0, top = 18.0;
    final w = size.width - left, h = size.height - bottom - top;
    final maxV = max(1, s.map((e) => max(e.ocorrencias, e.mortes)).reduce(max)) * 1.15;
    final grid = Paint()..color = const Color(0xFFE6EEEB);
    for (var i = 0; i <= 4; i++) {
      final y = top + h * i / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      _txt(canvas, (maxV * (4 - i) / 4).round().toString(), Offset(10, y));
    }
    final gw = w / s.length, bw = min(26.0, gw * .28);
    for (var i = 0; i < s.length; i++) {
      final cx = left + gw * (i + .5);
      void bar(double x, int v, Color cor) {
        final bh = h * v / maxV;
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, top + h - bh, bw, bh), topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          Paint()..color = cor,
        );
        _txt(canvas, '$v', Offset(x + bw / 2, top + h - bh - 8), cor: cor, bold: true);
      }

      bar(cx - bw - 1, s[i].ocorrencias, teal);
      bar(cx + 1, s[i].mortes, red);
      _txt(canvas, s[i].rotulo, Offset(cx, size.height - 8));
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.s != s;
}
