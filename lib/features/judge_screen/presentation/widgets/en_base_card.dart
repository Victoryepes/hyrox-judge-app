import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models.dart';

class EnBaseCard extends StatefulWidget {
  const EnBaseCard({
    super.key,
    required this.comp,
    required this.busy,
    required this.onPenalizar,
    required this.onDeshacer,
    required this.onDescalificar,
  });

  final CompetidorEnBase comp;
  final bool busy;
  final VoidCallback onPenalizar;
  final VoidCallback onDeshacer;
  final VoidCallback onDescalificar;

  @override
  State<EnBaseCard> createState() => _EnBaseCardState();
}

class _EnBaseCardState extends State<EnBaseCard> {
  late int _sec = widget.comp.segundosEnBase;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _sec++));
  }

  @override
  void didUpdateWidget(covariant EnBaseCard old) {
    super.didUpdateWidget(old);
    if (old.comp.registroId != widget.comp.registroId) {
      _sec = widget.comp.segundosEnBase;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _confirmarDeshacer(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1815),
        title: const Text('Deshacer entrada', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿#${widget.comp.numeroDorsal} — ${widget.comp.nombre} fue un error de tipeo? '
          'Se eliminará de esta base y su tiempo quedará en 0 si se vuelve a marcar bien.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade800),
            child: const Text('Sí, fue un error'),
          ),
        ],
      ),
    );
    if (confirmado == true) widget.onDeshacer();
  }

  Future<void> _confirmarDescalificar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1815),
        title: const Text('Descalificar', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Descalificar a #${widget.comp.numeroDorsal} — ${widget.comp.nombre}? No podrá seguir '
          'compitiendo y su estado quedará como DESCALIFICADO en el ranking.',
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
    if (confirmado == true) widget.onDescalificar();
  }

  /// dd:hh:mm:ss — recortando los tramos en cero por la izquierda, para que
  /// una entrada vieja/abandonada (horas o días) se lea correctamente en vez
  /// de mostrar siempre minutos:segundos (ver caso VICTOR, +3800h atascado).
  String _formatDuration(int totalSeconds) {
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (days > 0) return '${days}d ${hours.toString().padLeft(2, '0')}:$mm:$ss';
    if (hours > 0) return '$hours:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: widget.busy ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white10, border: Border.all(color: Colors.white24)),
        child: Row(
          children: [
            // Penalizar y Deshacer quedan detrás de un menú a la IZQUIERDA,
            // lejos de "Salida" a la derecha — evita el error de fat-finger
            // que denunció el usuario (penalizar y salida quedaban pegados).
            PopupMenuButton<String>(
              enabled: !widget.busy,
              icon: const Icon(Icons.more_vert, size: 20, color: Colors.white54),
              color: const Color(0xFF1C1815),
              onSelected: (value) {
                if (value == 'penalizar') widget.onPenalizar();
                if (value == 'deshacer') _confirmarDeshacer(context);
                if (value == 'descalificar') _confirmarDescalificar(context);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'penalizar',
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amberAccent),
                    SizedBox(width: 8),
                    Text('Penalizar', style: TextStyle(color: Colors.white)),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'deshacer',
                  child: Row(children: [
                    Icon(Icons.undo, size: 16, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text('Deshacer (error de tipeo)', style: TextStyle(color: Colors.white)),
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
            Container(
              width: 44, height: 44,
              alignment: Alignment.center,
              color: Colors.white12,
              child: Text('${widget.comp.numeroDorsal}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.comp.nombre,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  if (widget.comp.nombreEjercicio.isNotEmpty)
                    Text(widget.comp.nombreEjercicio,
                        style: const TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 0.5),
                        overflow: TextOverflow.ellipsis),
                  Text(_formatDuration(_sec),
                      style: const TextStyle(color: Colors.redAccent, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (widget.busy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
