import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/error_utils.dart';
import '../data/juez_api.dart';
import 'providers/auth_provider.dart';

/// Equivalente a JudgeAccessModal.tsx: paso 1 código de acceso, paso 2 estación.
class AccessScreen extends ConsumerStatefulWidget {
  const AccessScreen({super.key});

  @override
  ConsumerState<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends ConsumerState<AccessScreen> {
  final _codigoCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<EstacionOption> _estaciones = [];
  String? _codigoFinal;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarEstaciones() async {
    final codigo = _codigoCtrl.text.trim().toUpperCase();
    if (codigo.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final estaciones = await ref.read(juezApiProvider).estacionesPorCodigo(codigo);
      setState(() { _estaciones = estaciones; _codigoFinal = codigo; });
    } catch (e) {
      setState(() => _error = describeApiError(e, fallback: 'Código inválido o competencia no activa'));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _conectar(EstacionOption estacion) async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(sessionProvider.notifier).login(
            codigoAcceso: _codigoFinal!,
            estacion: estacion,
          );
    } catch (e) {
      setState(() => _error = describeApiError(e, fallback: 'Error al conectar con la estación'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14100E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('HYROX JUDGE',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 32),
                if (_codigoFinal == null) _buildCodigoStep() else _buildEstacionStep(),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodigoStep() {
    return Column(
      children: [
        TextField(
          controller: _codigoCtrl,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 4, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'PR-02',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          onSubmitted: (_) => _buscarEstaciones(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _buscarEstaciones,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 18)),
            child: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('INGRESAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildEstacionStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
          child: Text('Código activo: $_codigoFinal',
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
        ),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft, child: Text('Selecciona tu estación', style: TextStyle(color: Colors.white70))),
        const SizedBox(height: 8),
        ..._estaciones.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _conectar(e),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 14, backgroundColor: Colors.white10,
                          child: Text('${e.numeroOrden}', style: const TextStyle(color: Colors.white))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.nombreEjercicio, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            if (e.tipo == 'LLEGADA')
                              const Text('META / LLEGADA', style: TextStyle(color: Colors.redAccent, fontSize: 10))
                            else if (e.detalleRepeticiones.isNotEmpty)
                              Text(e.detalleRepeticiones, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
        TextButton(
          onPressed: () => setState(() { _codigoFinal = null; _estaciones = []; _codigoCtrl.clear(); }),
          child: const Text('← Cambiar código', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }
}
