import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../sim/components.dart';
import '../sim/engine.dart';
import '../sim/templates.dart';
import '../theme/tokens.dart';
import '../widgets/icons.dart';
import '../widgets/logo.dart';
import '../widgets/templates_ui.dart';
import '../widgets/ui.dart';

const _toc = [
  ('como-funciona', 'Cómo funciona'),
  ('componentes', 'Componentes'),
  ('metricas', 'Métricas y colores'),
  ('fallos', 'Fallos'),
  ('plantillas', 'Plantillas'),
  ('retos', 'Retos'),
  ('atajos', 'Atajos y uso'),
  ('proyectos', 'Proyectos e imágenes'),
  ('glosario', 'Glosario'),
];

const _retos = [
  (
    '200 pet/s sin errores',
    'Partiendo de «Lo esencial», llega a 200 pet/s con 0 % de errores y p95 por debajo de 200 ms.',
    'Más servidores detrás del balanceador… y luego mira quién es el siguiente cuello de botella.',
  ),
  (
    'Sobrevive al caos',
    'Con «Caos» activado durante un minuto, mantén los errores por debajo del 2 %.',
    'Redundancia en cada capa, reintentos moderados (1–2) y chequeos de salud más frecuentes.',
  ),
  (
    'Para la tormenta',
    'En «Tormenta de reintentos», sube a 60 pet/s sin que el sistema colapse y sin quitar los reintentos.',
    'Un API Gateway con límite delante del servidor convierte la avalancha en rechazos rápidos.',
  ),
  (
    'El catálogo lento',
    'En «Microservicios», degrada el Servicio Catálogo y consigue que la p95 vuelva por debajo de 250 ms.',
    'Más aciertos en su caché, o una segunda instancia del servicio tras un balanceador.',
  ),
  (
    'Que los pedidos no se pierdan',
    'En «Trabajo en segundo plano», tumba la base de datos 20 s y comprueba que no se pierde ningún trabajo.',
    'Fíjate en la cola: los mensajes que fallan vuelven a ella (entrega al menos una vez).',
  ),
  (
    'Al otro lado del océano',
    'Añade 80 ms de latencia a la línea Cliente → primer componente y mantén la p95 por debajo de 300 ms.',
    'Lo que no viaja no tarda: una CDN con muchos aciertos responde antes de cruzar el océano.',
  ),
];

const _glosario = [
  ('Cuello de botella', 'El componente que se satura primero y limita a todo el sistema.'),
  ('Punto único de fallo', 'Pieza sin copia: si cae, cae todo. Se evita con redundancia.'),
  ('Redundancia', 'Tener varias copias de un componente para que la caída de una no se note.'),
  ('Chequeo de salud', 'Consulta periódica del balanceador para saber qué destinos responden.'),
  ('Round-robin', 'Repartir por turnos: uno a cada destino, en orden.'),
  (
    'Latencia p95',
    'El 95 % de las peticiones tarda menos que este valor. Muestra lo que sufren los usuarios peor atendidos.',
  ),
  ('Rendimiento', 'Peticiones atendidas con éxito por segundo.'),
  ('Limitación de ritmo', 'Rechazar a propósito lo que pasa de un umbral para proteger lo de detrás (HTTP 429).'),
  ('Tormenta de reintentos', 'Los reintentos de muchos clientes multiplican la carga justo cuando el sistema está peor.'),
  ('Espera exponencial', 'Esperar cada vez el doble antes de reintentar, para no empeorar una saturación.'),
  ('Fan-out', 'Una petición que se convierte en varias en paralelo; tarda lo que la más lenta.'),
  ('Entrega al menos una vez', 'Una cola reentrega los mensajes que fallan; el consumidor debe tolerar duplicados.'),
  ('Partición de red', 'Dos partes del sistema dejan de verse entre sí aunque ambas sigan vivas.'),
  ('Degradación', 'Un componente que sigue vivo pero responde mucho más lento: a veces peor que caído.'),
];

/// Guía de DistiNode. `anchor`: sección o componente al que saltar al abrir.
class GuideScreen extends StatefulWidget {
  final String? anchor;
  const GuideScreen({super.key, this.anchor});
  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _keys = <String, GlobalKey>{};
  final _scroll = ScrollController();

  GlobalKey _k(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    if (widget.anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jump(widget.anchor!, animate: false));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jump(String id, {bool animate = true}) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.of(context).size.width >= 1024;
    final content = _content(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.linea))),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.grisTexto, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Volver',
                  ),
                  const SizedBox(width: 8),
                  const Logo(size: 30),
                  const Spacer(),
                  RoundIconButton(
                    icon: ThemeIcon(color: c.grisTexto),
                    tooltip: 'Modo claro / oscuro',
                    onPressed: () => AppScope.of(context).toggleTheme(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 32, 8, 0),
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.only(left: 16),
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: c.verde, width: 5))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final (id, label) in _toc)
                              HoverTile(
                                onTap: () => _jump(id),
                                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                                child: Text(label, style: TextStyle(fontSize: 14, color: c.grisTexto)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
                        child: Align(
                          alignment: wide ? Alignment.topLeft : Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 768),
                            child: SelectionArea(child: content),
                          ),
                        ),
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

  Widget _content(BuildContext context) {
    final c = context.c;
    final muted = TextStyle(color: c.grisTexto);
    final narrow = MediaQuery.of(context).size.width < 640;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Guía de DistiNode', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1.1)),
        const SizedBox(height: 12),
        Text(
          'Todo lo que necesitas para diseñar, romper y arreglar sistemas distribuidos en el lienzo.',
          style: TextStyle(fontSize: 18, color: c.grisTexto),
        ),
        _Section(
          key: _k('como-funciona'),
          title: 'Cómo funciona',
          children: [
            const _Rich([
              ('Cada sistema es un ', false),
              ('mapa de metro', true),
              (
                ': los componentes son estaciones y las conexiones, líneas. Las peticiones viajan como trenes en el sentido de la flecha y la respuesta vuelve por la misma línea.',
                false,
              ),
            ]),
            Grid(
              columns: narrow ? 1 : 2,
              gap: 8,
              children: [
                _Legend(kind: 0, fill: c.papel, stroke: c.tinta, text: 'Petición de un cliente'),
                _Legend(kind: 0, fill: c.grisTren, text: 'Respuesta correcta'),
                _Legend(kind: 0, fill: c.rojo, text: 'Error que vuelve al cliente'),
                _Legend(kind: 1, fill: c.tinta, stroke: c.papel, text: 'Mensaje de una cola hacia un worker'),
              ],
            ),
            const _Rich([
              ('Dos relojes. ', true),
              (
                'Los trenes van a cámara lenta para que se vean (unas décimas de segundo por línea). Las métricas usan el tiempo simulado: lo que tardan de verdad la espera en colas, el proceso y la latencia de red. Por eso un sistema sano marca ~100 ms aunque el tren tarde más en volver.',
                false,
              ),
            ]),
            const _Rich([
              ('Todo ocurre en tu equipo. ', true),
              (
                'Esta versión no necesita cuenta ni conexión: el motor de simulación es el mismo que el de la web y tus proyectos se guardan en archivos locales.',
                false,
              ),
            ]),
          ],
        ),
        _Section(
          key: _k('componentes'),
          title: 'Componentes',
          children: [
            Text(
              'Hay ${componentOrder.length} componentes, en tres familias. Pulsa el «?» del panel de propiedades para llegar aquí desde el lienzo.',
            ),
            for (final group in groups) ...[
              const SizedBox(height: 12),
              Text(group.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.grisTexto)),
              for (final kind in componentOrder.where((k) => specOf(k).group == group))
                Padding(
                  key: _k(kind.name),
                  padding: const EdgeInsets.only(top: 18),
                  child: _ComponentDoc(kind: kind, narrow: narrow),
                ),
            ],
          ],
        ),
        _Section(
          key: _k('metricas'),
          title: 'Métricas y colores',
          children: [
            _Defs(narrow: narrow, rows: const [
              ('Completadas', 'Respuestas correctas que llegan a los clientes por segundo (últimos 2 s).'),
              (
                'Latencia p95',
                'El 95 % de las respuestas tarda menos. La media está en el tooltip; la p95 enseña mejor los problemas.',
              ),
              (
                'Errores',
                'Peticiones que fallaron: rechazadas, nodo caído, línea cortada o tiempo de espera agotado. Con reintentos, solo cuenta si fallan todos los intentos.',
              ),
              ('Reintentos', 'Aparece cuando algún cliente reintenta. Si crece mucho: tormenta.'),
              ('En segundo plano', 'Mensajes procesados por los workers y mensajes esperando en las colas.'),
            ]),
            const Text('El borde de cada estación indica su estado mientras la simulación corre:'),
            _StateRow(color: c.verde, label: 'Verde', text: 'carga por debajo del ${fmt(Thresholds.warnRho * 100)} %.'),
            _StateRow(
              color: c.ambar,
              label: 'Ámbar',
              text:
                  'carga a partir del ${fmt(Thresholds.warnRho * 100)} %, cola por encima del ${fmt(Thresholds.warnQueue * 100)} %, o degradado.',
            ),
            _StateRow(
              color: c.rojo,
              label: 'Rojo',
              text:
                  'saturado: carga del 100 % o más, cola por encima del ${fmt(Thresholds.hotQueue * 100)} %, o rechazando peticiones.',
            ),
            _StateRow(
              color: c.gris,
              label: 'Gris discontinuo',
              text: 'caído. Si se cayó solo, muestra la cuenta atrás del reinicio.',
              dashed: true,
            ),
          ],
        ),
        _Section(
          key: _k('fallos'),
          title: 'Fallos',
          children: [
            const Text('Los sistemas reales fallan de muchas maneras. Puedes provocar cada una a mano o dejar que pasen solas.'),
            _Defs(narrow: narrow, rows: const [
              (
                'Tumbar',
                'El componente deja de responder y lo que tenía dentro falla. Sigue caído hasta que lo revives.',
              ),
              (
                'Degradar (lento)',
                'Sigue vivo pero procesa 4 veces más lento (o añade 150 ms si no hace cola). El balanceador no lo detecta: su chequeo solo mira si responde.',
              ),
              ('Cortar conexión', 'Selecciona una línea y córtala: es una partición de red. Lo que viaja por ella falla.'),
              ('Latencia de red', 'Añade milisegundos a una línea (ida y vuelta): distancia o red congestionada.'),
              (
                'Caos',
                'Interruptor de la barra inferior. Cada segundo hay una probabilidad de que algo se caiga, se vuelva lento o se corte una línea; todo vuelve solo a los pocos segundos. Como Chaos Monkey de Netflix.',
              ),
              (
                'Sobrecarga tumba',
                'Un componente saturado más de 5 s se cae y tarda unos segundos en reiniciar. Sin redundancia, su caída arrastra a los demás: la cascada típica de un pico de tráfico.',
              ),
            ]),
          ],
        ),
        _Section(
          key: _k('plantillas'),
          title: 'Plantillas',
          children: [
            Text(
              'Hay ${templates.length}: patrones que enseñan una idea cada uno y sistemas reales simplificados. Se cargan desde un lienzo vacío, con el botón «Plantillas…» de la barra lateral, con el + en pantallas estrechas, o al crear un proyecto nuevo. Cargar una plantilla sustituye el diagrama.',
            ),
            for (final cat in templateCategories) ...[
              const SizedBox(height: 8),
              Text(cat.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.grisTexto)),
              for (final t in templates.where((t) => t.category == cat))
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.papel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.linea),
                  ),
                  child: () {
                    final preview = Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: c.fondo, borderRadius: BorderRadius.circular(8)),
                      child: TemplatePreview(template: t, width: 160, height: 72),
                    );
                    final info = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(t.summary, style: muted),
                        const SizedBox(height: 8),
                        _Rich([('Prueba esto: ', true), (t.tryThis, false)], size: 15),
                      ],
                    );
                    return narrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [preview, const SizedBox(height: 12), info],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [preview, const SizedBox(width: 14), Expanded(child: info)],
                          );
                  }(),
                ),
            ],
          ],
        ),
        _Section(
          key: _k('retos'),
          title: 'Retos',
          children: [
            const Text('Para clase o para practicar en equipo. Cada uno se resuelve con piezas de la barra lateral.'),
            for (var i = 0; i < _retos.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.papel,
                        border: Border.all(color: c.tinta, width: 4),
                      ),
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _Reto(title: _retos[i].$1, goal: _retos[i].$2, hint: _retos[i].$3)),
                  ],
                ),
              ),
          ],
        ),
        _Section(
          key: _k('atajos'),
          title: 'Atajos y uso',
          children: const [
            _Bullet([
              ('Espacio', true),
              (' pone en marcha o pausa · ', false),
              ('Supr', true),
              (' o ', false),
              ('Retroceso', true),
              (' borra lo seleccionado · ', false),
              ('Esc', true),
              (' quita la selección.', false),
            ]),
            _Bullet([
              ('Ctrl+A', true),
              (' selecciona todos los componentes · ', false),
              ('Mayús', true),
              (' + clic añade a la selección · ', false),
              ('Mayús', true),
              (' + arrastrar en el fondo dibuja un rectángulo de selección.', false),
            ]),
            _Bullet([
              ('Arrastra el fondo para moverte y usa la rueda para acercar. ', false),
              ('+', true),
              (' / ', false),
              ('−', true),
              (' acercan y alejan; ', false),
              ('0', true),
              (' encuadra todo el diagrama.', false),
            ]),
            _Bullet([
              ('Ctrl+S', true),
              (' guarda el proyecto como archivo · ', false),
              ('Ctrl+E', true),
              (' exporta la imagen · ', false),
              ('Ctrl+O', true),
              (' importa un proyecto.', false),
            ]),
            _Bullet([
              ('En el móvil', true),
              (
                ' también se diseña: el botón + añade componentes y plantillas, tocar una estación abre sus propiedades y «Conectar con…» une estaciones sin arrastrar. Pellizca para acercar y arrastra con un dedo para moverte.',
                false,
              ),
            ]),
          ],
        ),
        _Section(
          key: _k('proyectos'),
          title: 'Proyectos e imágenes',
          children: [
            const Text(
              'Cada proyecto se guarda solo, en un archivo de tu equipo, mientras trabajas. Desde «Mis proyectos» puedes crearlos, abrirlos, renombrarlos, duplicarlos y borrarlos. Desde el menú «Proyecto» del editor:',
            ),
            _Defs(narrow: narrow, rows: const [
              (
                'Exportar imagen',
                'Un PNG del diagrama completo (aunque no quepa en pantalla), con el nombre y la fecha. Para trabajos, apuntes o presentaciones.',
              ),
              (
                'Guardar como archivo',
                'Un archivo .distinode.json con componentes, ajustes, conexiones y tráfico. Es el mismo formato que la versión web: puedes abrirlo allí y al revés. Las caídas temporales del caos no se guardan; las manuales sí.',
              ),
              (
                'Importar proyecto',
                'Abre un archivo guardado y sustituye el diagrama. Para importarlo como proyecto nuevo, usa «Importar archivo» en «Mis proyectos».',
              ),
            ]),
          ],
        ),
        _Section(
          key: _k('glosario'),
          title: 'Glosario',
          children: [_Defs(narrow: narrow, rows: _glosario, termWidth: 210)],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 56),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        const SizedBox(height: 12),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );
}

class _Rich extends StatelessWidget {
  final List<(String, bool)> parts;
  final double size;
  const _Rich(this.parts, {this.size = 16});
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final (t, bold) in parts) TextSpan(text: t, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
      ],
    ),
    style: TextStyle(fontSize: size, height: 1.55),
  );
}

class _Bullet extends StatelessWidget {
  final List<(String, bool)> parts;
  const _Bullet(this.parts);
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(padding: EdgeInsets.only(top: 1, right: 10, left: 4), child: Text('•')),
      Expanded(child: _Rich(parts)),
    ],
  );
}

class _Defs extends StatelessWidget {
  final List<(String, String)> rows;
  final bool narrow;
  final double termWidth;
  const _Defs({required this.rows, required this.narrow, this.termWidth = 170});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (term, def) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(term, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(def, style: TextStyle(color: c.grisTexto, height: 1.5)),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: termWidth, child: Text(term, style: const TextStyle(fontWeight: FontWeight.w600))),
                      const SizedBox(width: 16),
                      Expanded(child: Text(def, style: TextStyle(color: c.grisTexto, height: 1.5))),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _ComponentDoc extends StatelessWidget {
  final ComponentKind kind;
  final bool narrow;
  const _ComponentDoc({required this.kind, required this.narrow});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = specOf(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HexIcon(kind: kind, size: 40, color: c.verde, fg: c.sobreVerde),
            const SizedBox(width: 12),
            Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        Text(s.docs.what, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 10),
        _Defs(
          narrow: narrow,
          termWidth: 140,
          rows: [
            ('Cuándo usarlo', s.docs.when),
            ('En la simulación', s.docs.model),
            if (s.params.isNotEmpty)
              (
                'Ajustes',
                s.params
                    .map(
                      (p) =>
                          '${p.label}${p.options != null ? ' (${p.options!.map((o) => o.label).join(' / ')})' : ''}: ${p.help}',
                    )
                    .join('\n'),
              ),
          ],
        ),
        Flex(
          direction: narrow ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(
              width: 140,
              child: Text('En el mundo real', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: narrow ? 0 : 16, height: narrow ? 6 : 0),
            Flexible(
              fit: FlexFit.loose,
              flex: narrow ? 0 : 1,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in s.docs.realWorld)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: c.verdeSuave, borderRadius: BorderRadius.circular(6)),
                      child: Text(r, style: TextStyle(fontSize: 14, color: c.verde)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final int kind; // 0 píldora, 1 rombo
  final Color fill;
  final Color? stroke;
  final String text;
  const _Legend({required this.kind, required this.fill, this.stroke, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CustomPaint(size: const Size(40, 16), painter: _LegendPainter(kind, fill, stroke, context.c.verde)),
      const SizedBox(width: 12),
      Expanded(child: Text(text)),
    ],
  );
}

class _LegendPainter extends CustomPainter {
  final int kind;
  final Color fill;
  final Color? stroke;
  final Color line;
  _LegendPainter(this.kind, this.fill, this.stroke, this.line);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(0, 8),
      const Offset(40, 8),
      Paint()
        ..color = line
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    final sp = Paint()
      ..color = stroke ?? Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (kind == 0) {
      final r = RRect.fromRectAndRadius(const Rect.fromLTWH(12, 4, 16, 8), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = fill);
      if (stroke != null) canvas.drawRRect(r, sp);
    } else {
      final p = Path()
        ..moveTo(20, 2)
        ..lineTo(26, 8)
        ..lineTo(20, 14)
        ..lineTo(14, 8)
        ..close();
      canvas.drawPath(p, Paint()..color = fill);
      canvas.drawPath(p, sp);
    }
  }

  @override
  bool shouldRepaint(_LegendPainter old) => true;
}

class _StateRow extends StatelessWidget {
  final Color color;
  final String label;
  final String text;
  final bool dashed;
  const _StateRow({required this.color, required this.label, required this.text, this.dashed = false});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Container(
          width: 40,
          height: 20,
          decoration: BoxDecoration(
            color: c.papel,
            borderRadius: BorderRadius.circular(999),
            border: dashed ? null : Border.all(color: color, width: 3.5),
          ),
          child: dashed ? CustomPaint(painter: _DashedPill(color)) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: _Rich([('$label: ', true), (text, false)])),
      ],
    );
  }
}

class _DashedPill extends CustomPainter {
  final Color color;
  _DashedPill(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius((Offset.zero & size).deflate(1.75), const Radius.circular(10));
    final metric = (Path()..addRRect(r)).computeMetrics().first;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    for (var d = 0.0; d < metric.length; d += 9) {
      canvas.drawPath(metric.extractPath(d, d + 5), p);
    }
  }

  @override
  bool shouldRepaint(_DashedPill old) => old.color != color;
}

class _Reto extends StatefulWidget {
  final String title;
  final String goal;
  final String hint;
  const _Reto({required this.title, required this.goal, required this.hint});
  @override
  State<_Reto> createState() => _RetoState();
}

class _RetoState extends State<_Reto> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(widget.goal, style: const TextStyle(height: 1.5)),
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_open ? Icons.arrow_drop_down : Icons.arrow_right, color: c.verde, size: 20),
                  Text('Pista', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.verde)),
                ],
              ),
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(widget.hint, style: TextStyle(color: c.grisTexto, height: 1.5)),
          ),
      ],
    );
  }
}
