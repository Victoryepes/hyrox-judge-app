import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/error_utils.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../offline_queue/presentation/offline_queue_provider.dart';
import 'providers/judge_providers.dart';
import 'widgets/connection_indicator.dart';
import 'widgets/offline_queue_indicator.dart';
import 'widgets/heat_alert_banner.dart';
import 'widgets/en_base_card.dart';
import 'widgets/reps_por_categoria.dart';
import 'penalizacion_modal.dart';
import '../domain/models.dart';

/// Equivalente a JudgePage.tsx.
class JudgeHomeScreen extends ConsumerStatefulWidget {
  const JudgeHomeScreen({super.key});

  @override
  ConsumerState<JudgeHomeScreen> createState() => _JudgeHomeScreenState();
}

class _JudgeHomeScreenState extends ConsumerState<JudgeHomeScreen> with WidgetsBindingObserver {
  final _dorsalCtrl = TextEditingController();
  bool _marcando = false;
  String? _busyRegistroId;
  List<RepsPorCategoria> _catReps = [];

  // Modo dorsal (escribir número) vs modo lista (buscar y tocar) —
  // equivalente al toggle Dorsal/Lista de JudgePage.tsx.
  String _modo = 'dorsal';
  List<CompetidorListado> _atletas = [];
  bool _loadingLista = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCatReps();
  }

  Future<void> _loadCatReps() async {
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    try {
      final reps = await ref.read(timingApiProvider).repsPorCategoria(session.tokenSesion);
      if (mounted) setState(() => _catReps = reps);
    } catch (_) { /* panel simplemente no se muestra */ }
  }

  Future<void> _loadAtletas() async {
    final session = ref.read(sessionProvider).value;
    if (session == null) return;
    setState(() => _loadingLista = true);
    try {
      final atletas = await ref.read(timingApiProvider).competidoresJuez(session.tokenSesion);
      if (mounted) setState(() => _atletas = atletas);
    } catch (_) { /* lista queda vacía */ }
    finally { if (mounted) setState(() => _loadingLista = false); }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dorsalCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android puede congelar el proceso en background — el timer interno de
    // reconexión de socket.io-client no corre mientras tanto, así que al
    // volver forzamos reconexión + refresco explícito (ver plan sección 3.4).
    if (state == AppLifecycleState.resumed) {
      ref.read(pantallaProvider.notifier).onResumed();
    }
  }

  Future<void> _marcarDorsal([int? numeroDirecto]) async {
    final numero = numeroDirecto ?? int.tryParse(_dorsalCtrl.text);
    if (numero == null) return;
    final session = ref.read(sessionProvider).value!;
    setState(() => _marcando = true);
    try {
      // Online-first con fallback a cola offline si falla por conectividad
      // (ver plan sección 3) — result es null cuando quedó encolado.
      final result = await ref
          .read(offlineQueueProvider)
          .marcarDorsal(numeroDorsal: numero, tokenSesion: session.tokenSesion);
      _dorsalCtrl.clear();
      ref.read(pantallaProvider.notifier).refresh();
      // La lista de "modo lista" (estacionCompletadaRegistroId) no se
      // actualiza sola con el polling de pantalla — sin esto, INICIAR/
      // FINALIZAR quedaban con el estado viejo (dejaba reingresar a una
      // base recién completada) hasta salir y volver a entrar a modo lista.
      if (_modo == 'lista') _loadAtletas();
      if (mounted) {
        final msg = result == null
            ? 'Dorsal $numero guardado — se sincronizará cuando vuelva la señal'
            : result.esLlegada
                ? '🏁 ${result.competidorNombre} cruzó la META'
                : result.esSalida
                    ? '${result.competidorNombre} — SALIDA'
                    : (result.estacionDetalleRepeticiones?.isNotEmpty == true
                        ? '${result.competidorNombre} — ${result.estacionDetalleRepeticiones}'
                        : '${result.competidorNombre} registrado');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _marcando = false);
    }
  }

  Future<void> _deshacerEntrada(String registroId) async {
    final session = ref.read(sessionProvider).value!;
    setState(() => _busyRegistroId = registroId);
    try {
      await ref.read(timingApiProvider).deshacerEntrada(registroId, session.tokenSesion);
      ref.read(pantallaProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada deshecha')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _busyRegistroId = null);
    }
  }

  Future<void> _deshacerSalida(String registroEntradaId) async {
    final session = ref.read(sessionProvider).value!;
    setState(() => _busyRegistroId = registroEntradaId);
    try {
      await ref.read(timingApiProvider).deshacerSalida(registroEntradaId, session.tokenSesion);
      await _loadAtletas();
      ref.read(pantallaProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Base deshecha — quedó vacía')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _busyRegistroId = null);
    }
  }

  Future<void> _finalizar(String registroId) async {
    final session = ref.read(sessionProvider).value!;
    setState(() => _busyRegistroId = registroId);
    try {
      await ref.read(offlineQueueProvider).registrarSalida(
            registroId: registroId,
            tokenSesion: session.tokenSesion,
          );
      ref.read(pantallaProvider.notifier).refresh();
      if (_modo == 'lista') _loadAtletas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _busyRegistroId = null);
    }
  }

  Future<void> _confirmarDescalificar(String competidorId, String nombre) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1815),
        title: const Text('Descalificar', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Descalificar a $nombre? No podrá seguir compitiendo y su estado '
          'quedará como DESCALIFICADO en el ranking.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('Sí, descalificar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final session = ref.read(sessionProvider).value!;
    setState(() => _busyRegistroId = competidorId);
    try {
      await ref.read(timingApiProvider).descalificar(competidorId, null, session.tokenSesion);
      await _loadAtletas();
      ref.read(pantallaProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$nombre — DESCALIFICADO')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _busyRegistroId = null);
    }
  }

  Future<void> _confirmarDescalificarDorsal() async {
    final numero = int.tryParse(_dorsalCtrl.text);
    if (numero == null) return;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1815),
        title: const Text('Descalificar', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Descalificar al dorsal $numero? No podrá seguir compitiendo y su '
          'estado quedará como DESCALIFICADO en el ranking.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
            child: const Text('Sí, descalificar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final session = ref.read(sessionProvider).value!;
    setState(() => _marcando = true);
    try {
      await ref.read(timingApiProvider).descalificarPorDorsal(numero, null, session.tokenSesion);
      _dorsalCtrl.clear();
      await _loadAtletas();
      ref.read(pantallaProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dorsal $numero — DESCALIFICADO')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) setState(() => _marcando = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).value;
    if (session == null) return const SizedBox.shrink();

    final pantallaAsync = ref.watch(pantallaProvider);
    final notif = ref.watch(transientNotifProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF14100E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1815),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(session.nombreEstacion, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            Text(session.codigoAcceso, style: const TextStyle(fontSize: 9, color: Colors.white38)),
          ],
        ),
        actions: [
          const Padding(padding: EdgeInsets.only(right: 10), child: Center(child: OfflineQueueIndicator())),
          const Padding(padding: EdgeInsets.only(right: 12), child: Center(child: ConnectionIndicator())),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout, size: 18)),
        ],
      ),
      body: Column(
        children: [
          const HeatAlertBanner(),
          if (notif != null)
            Container(
              width: double.infinity,
              color: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(notif, style: const TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 1)),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dorsalCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      hintText: 'Dorsal',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    enabled: !_marcando,
                    onSubmitted: (_) => _marcarDorsal(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (_marcando || _dorsalCtrl.text.isEmpty) ? null : _marcarDorsal,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20)),
                  child: _marcando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('MARCAR', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                // Descalificar por dorsal — decisión de arbitraje, con
                // confirmación, disponible también en modo dorsal (antes
                // solo se podía desde modo lista).
                IconButton(
                  onPressed: (_marcando || _dorsalCtrl.text.isEmpty) ? null : _confirmarDescalificarDorsal,
                  tooltip: 'Descalificar dorsal',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white10,
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.block, color: Colors.redAccent, size: 20),
                ),
              ],
            ),
          ),
          // ── Toggle Dorsal / Lista ──────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ModoTab(
                  label: 'DORSAL', icon: Icons.tag, selected: _modo == 'dorsal',
                  onTap: () => setState(() => _modo = 'dorsal'),
                ),
              ),
              Expanded(
                child: _ModoTab(
                  label: 'LISTA', icon: Icons.list, selected: _modo == 'lista',
                  onTap: () { setState(() => _modo = 'lista'); _loadAtletas(); },
                ),
              ),
            ],
          ),
          if (_modo == 'dorsal') RepsPorCategoriaPanel(items: _catReps),
          Expanded(
            child: _modo == 'lista'
                ? _buildListaMode(pantallaAsync)
                : pantallaAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text(describeApiError(e), style: const TextStyle(color: Colors.redAccent))),
                    data: (lista) {
                      if (lista.isEmpty) {
                        return const Center(
                          child: Text('Sin competidores en base', style: TextStyle(color: Colors.white38)),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: lista.length,
                        itemBuilder: (context, i) {
                          final c = lista[i];
                          return EnBaseCard(
                            key: ValueKey(c.registroId),
                            comp: c,
                            busy: _busyRegistroId == c.registroId,
                            onPenalizar: () => showPenalizacionModal(context, ref, registroId: c.registroId),
                            onDeshacer: () => _deshacerEntrada(c.registroId),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaMode(AsyncValue<List<dynamic>> pantallaAsync) {
    if (_loadingLista) return const Center(child: CircularProgressIndicator());
    if (_atletas.isEmpty) {
      return const Center(child: Text('Sin atletas registrados', style: TextStyle(color: Colors.white38)));
    }
    final registroIdPorDorsal = <int, String>{
      for (final c in pantallaAsync.value ?? const []) c.numeroDorsal as int: c.registroId as String,
    };
    final segundosPorDorsal = <int, int>{
      for (final c in pantallaAsync.value ?? const []) c.numeroDorsal as int: c.segundosEnBase as int,
    };
    return ListView.builder(
      itemCount: _atletas.length,
      itemBuilder: (context, i) {
        final a = _atletas[i];
        final registroEnBaseId = registroIdPorDorsal[a.numeroDorsal];
        final enBase = registroEnBaseId != null;
        final completada = a.estacionCompletadaRegistroId;
        final descalificado = a.descalificado;
        final color = _parseColor(a.categoriaColorHex);
        final busy = _busyRegistroId != null &&
            (_busyRegistroId == registroEnBaseId || _busyRegistroId == completada || _busyRegistroId == a.id);
        return Opacity(
          opacity: (_marcando || busy) ? 0.5 : (descalificado ? 0.6 : 1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: enBase ? Colors.red.shade900.withValues(alpha: 0.3) : null,
              border: Border(
                bottom: const BorderSide(color: Colors.white12),
                left: BorderSide(color: color, width: 4),
              ),
            ),
            child: Row(
              children: [
                // Los 3 puntos despliegan penalización, corrección de ingreso
                // (deshacer entrada/salida por error de tipeo, según el estado
                // actual) o descalificar (con confirmación) — a la izquierda,
                // lejos de INICIAR/FINALIZAR a la derecha.
                PopupMenuButton<String>(
                  enabled: !busy && !descalificado,
                  icon: Icon(Icons.more_vert, size: 20,
                      color: descalificado ? Colors.white24 : Colors.white54),
                  color: const Color(0xFF1C1815),
                  onSelected: (value) {
                    if (value == 'penalizar' && registroEnBaseId != null) {
                      showPenalizacionModal(context, ref, registroId: registroEnBaseId);
                    }
                    if (value == 'correccion_entrada' && registroEnBaseId != null) {
                      _deshacerEntrada(registroEnBaseId);
                    }
                    if (value == 'correccion_salida' && completada != null) {
                      _deshacerSalida(completada);
                    }
                    if (value == 'descalificar') {
                      _confirmarDescalificar(a.id, a.nombre);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (enBase)
                      const PopupMenuItem(
                        value: 'penalizar',
                        child: Row(children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amberAccent),
                          SizedBox(width: 8),
                          Text('Penalizar', style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                    if (enBase)
                      const PopupMenuItem(
                        value: 'correccion_entrada',
                        child: Row(children: [
                          Icon(Icons.undo, size: 16, color: Colors.orangeAccent),
                          SizedBox(width: 8),
                          Text('Corrección de ingreso', style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                    if (completada != null)
                      const PopupMenuItem(
                        value: 'correccion_salida',
                        child: Row(children: [
                          Icon(Icons.undo, size: 16, color: Colors.orangeAccent),
                          SizedBox(width: 8),
                          Text('Corrección de ingreso', style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: 'descalificar',
                      child: Row(children: [
                        Icon(Icons.block, size: 16, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Descalificar', style: TextStyle(color: Colors.white)),
                      ]),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40, alignment: Alignment.center,
                          color: Colors.white10,
                          child: Text('${a.numeroDorsal}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              if (a.categoriaNombre.isNotEmpty)
                                Text(a.categoriaNombre, style: TextStyle(color: color, fontSize: 9, letterSpacing: 1, fontFamily: 'monospace')),
                              if (descalificado)
                                const Text('DESCALIFICADO', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontFamily: 'monospace'))
                              else if (enBase)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('EN BASE ', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontFamily: 'monospace')),
                                  _MiniChrono(segundosBase: segundosPorDorsal[a.numeroDorsal] ?? 0),
                                ])
                              else if (completada != null)
                                const Text('COMPLETADA', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontFamily: 'monospace')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // INICIAR / FINALIZAR explícitos — reemplaza el tap ambiguo
                // sobre toda la fila, que en la práctica llevaba a errores
                // de reingreso a bases ya completadas.
                if (!descalificado) ...[
                  SizedBox(
                    width: 78,
                    child: ElevatedButton(
                      onPressed: (busy || enBase || completada != null) ? null : () => _marcarDorsal(a.numeroDorsal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        disabledBackgroundColor: Colors.white10,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('INICIAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 78,
                    child: ElevatedButton(
                      onPressed: (busy || !enBase) ? null : () => _finalizar(registroEnBaseId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        disabledBackgroundColor: Colors.white10,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('FINALIZAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.white38;
    }
  }
}

class _ModoTab extends StatelessWidget {
  const _ModoTab({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        color: selected ? Colors.white10 : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: selected ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: selected ? Colors.white : Colors.white38,
              fontSize: 10, letterSpacing: 1.5, fontFamily: 'monospace',
            )),
          ],
        ),
      ),
    );
  }
}

/// Cronómetro que tickea localmente cada segundo desde segundosBase — usado
/// en la fila de modo lista para quien está actualmente en base.
class _MiniChrono extends StatefulWidget {
  const _MiniChrono({required this.segundosBase});
  final int segundosBase;

  @override
  State<_MiniChrono> createState() => _MiniChronoState();
}

class _MiniChronoState extends State<_MiniChrono> {
  late int _sec = widget.segundosBase;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _sec++));
  }

  @override
  void didUpdateWidget(covariant _MiniChrono old) {
    super.didUpdateWidget(old);
    if (old.segundosBase != widget.segundosBase) _sec = widget.segundosBase;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mm = (_sec ~/ 60).toString().padLeft(2, '0');
    final ss = (_sec % 60).toString().padLeft(2, '0');
    return Text('$mm:$ss', style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold));
  }
}
