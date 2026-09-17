import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/error_utils.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../offline_queue/presentation/offline_queue_provider.dart';
import 'providers/judge_providers.dart';
import '../domain/models.dart';

Future<void> showPenalizacionModal(
  BuildContext context,
  WidgetRef ref, {
  required String registroId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1C1815),
    builder: (_) => _PenalizacionSheet(registroId: registroId),
  );
}

class _PenalizacionSheet extends ConsumerStatefulWidget {
  const _PenalizacionSheet({required this.registroId});
  final String registroId;

  @override
  ConsumerState<_PenalizacionSheet> createState() => _PenalizacionSheetState();
}

class _PenalizacionSheetState extends ConsumerState<_PenalizacionSheet> {
  bool _modoLibre = false;
  bool _loading = false;
  int _segundos = 30;
  final _motivoCtrl = TextEditingController();
  late final _segundosCtrl = TextEditingController(text: '$_segundos');
  List<PenalizacionCatalogoItem> _catalogo = [];
  bool _catalogoLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogo();
  }

  void _setSegundos(int value) {
    setState(() => _segundos = value);
    _segundosCtrl.text = '$value';
  }

  Future<void> _loadCatalogo() async {
    final session = ref.read(sessionProvider).value!;
    try {
      final catalogo = await ref.read(timingApiProvider).catalogoPenalizaciones(session.tokenSesion);
      if (mounted) setState(() { _catalogo = catalogo; _catalogoLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _catalogoLoaded = true);
    }
  }

  Future<void> _aplicarCatalogo(PenalizacionCatalogoItem pen) async {
    final session = ref.read(sessionProvider).value!;
    setState(() => _loading = true);
    try {
      await ref.read(offlineQueueProvider).penalizarCatalogo(
            registroId: widget.registroId,
            catalogoId: pen.id,
            tokenSesion: session.tokenSesion,
          );
      ref.read(pantallaProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError(describeApiError(e, fallback: 'Error al aplicar la penalización'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _aplicarLibre() async {
    if (_motivoCtrl.text.trim().isEmpty) return _showError('El motivo es requerido');
    if (_segundos <= 0) return _showError('Segundos deben ser > 0');
    final session = ref.read(sessionProvider).value!;
    setState(() => _loading = true);
    try {
      await ref.read(offlineQueueProvider).penalizarLibre(
            registroId: widget.registroId,
            segundos: _segundos,
            motivo: _motivoCtrl.text.trim(),
            tokenSesion: session.tokenSesion,
          );
      ref.read(pantallaProvider.notifier).refresh();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showError(describeApiError(e, fallback: 'Error al aplicar la penalización'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _segundosCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
              SizedBox(width: 8),
              Text('Penalización', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ToggleButtons(
            isSelected: [!_modoLibre, _modoLibre],
            onPressed: (i) => setState(() => _modoLibre = i == 1),
            borderRadius: BorderRadius.circular(4),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('CATÁLOGO')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('LIBRE')),
            ],
          ),
          const SizedBox(height: 12),
          if (!_modoLibre) _buildCatalogo() else _buildLibre(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCatalogo() {
    if (!_catalogoLoaded) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (_catalogo.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sin penalizaciones configuradas', style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: ListView(
        shrinkWrap: true,
        children: _catalogo
            .map((pen) => ListTile(
                  onTap: _loading ? null : () => _aplicarCatalogo(pen),
                  tileColor: Colors.white10,
                  title: Text(pen.nombre, style: const TextStyle(color: Colors.white)),
                  trailing: Text('+${pen.segundosSumar}s',
                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildLibre() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [15, 30, 45, 60, 120]
              .map((s) => ChoiceChip(
                    label: Text('${s}s'),
                    selected: _segundos == s,
                    onSelected: (_) => _setSegundos(s),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _segundosCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Segundos', labelStyle: TextStyle(color: Colors.white54)),
          onChanged: (v) => _segundos = int.tryParse(v) ?? _segundos,
        ),
        TextField(
          controller: _motivoCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Motivo *', labelStyle: TextStyle(color: Colors.white54)),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loading ? null : _aplicarLibre,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 14)),
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Aplicar +${_segundos}s'),
        ),
      ],
    );
  }
}
