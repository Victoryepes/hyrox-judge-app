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
  final _documentoCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  List<EstacionOption> _estaciones = [];
  List<CircuitoCategoria> _circuito = [];
  bool _modoMovil = false;
  String? _codigoFinal;
  String? _documentoFinal;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _documentoCtrl.dispose();
    super.dispose();
  }

  /// Paso 1: valida el código y decide el flujo según asignación móvil,
  /// igual que handleCodigo en JudgeAccessModal.tsx. La cédula recién se
  /// valida contra el registro de jueces al conectar (paso 2).
  Future<void> _buscarEstaciones() async {
    final codigo = _codigoCtrl.text.trim().toUpperCase();
    final documento = _documentoCtrl.text.trim();
    if (codigo.isEmpty || documento.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final circuito = await ref.read(juezApiProvider).circuitoPorCodigo(codigo);
      _documentoFinal = documento;
      if (circuito.asignacionMovilJuez) {
        setState(() { _circuito = circuito.categorias; _modoMovil = true; _codigoFinal = codigo; });
      } else {
        final estaciones = await ref.read(juezApiProvider).estacionesPorCodigo(codigo);
        setState(() { _estaciones = estaciones; _modoMovil = false; _codigoFinal = codigo; });
      }
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
            documento: _documentoFinal!,
            estacion: estacion,
          );
    } catch (e) {
      setState(() => _error = describeApiError(e, fallback: 'Error al conectar con la estación'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _conectarMovil(CircuitoCategoria categoria) async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(sessionProvider.notifier).loginMovil(
            codigoAcceso: _codigoFinal!,
            documento: _documentoFinal!,
            categoria: categoria,
          );
    } catch (e) {
      setState(() => _error = describeApiError(e, fallback: 'Error al conectar con la categoría'));
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
                if (_codigoFinal == null)
                  _buildCodigoStep()
                else if (_modoMovil)
                  _buildCategoriaStep()
                else
                  _buildEstacionStep(),
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
        const Text(
          'Ingresa tu cédula (registrada por el organizador) y el código de la competencia',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _documentoCtrl,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'Cédula',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 12),
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
          onPressed: () => setState(() { _codigoFinal = null; _estaciones = []; _codigoCtrl.clear(); _documentoCtrl.clear(); }),
          child: const Text('← Cambiar código', style: TextStyle(color: Colors.white54)),
        ),
      ],
    );
  }

  /// Modo móvil: el juez elige la categoría de la pareja que va a seguir
  /// entre bases, en vez de una estación fija (equivalente al paso
  /// 'categoria' en JudgeAccessModal.tsx).
  Widget _buildCategoriaStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
          child: Text('Código activo: $_codigoFinal',
              style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
        ),
        const SizedBox(height: 12),
        const Text(
          'Esta competencia usa asignación móvil — vas a seguir a un competidor/pareja '
          'entre bases. Elige la categoría de tu pareja:',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ..._circuito.map((cat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _conectarMovil(cat),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 6, backgroundColor: _parseColor(cat.colorHex)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.nombreCategoria, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text(
                              cat.estaciones.map((e) => e.nombreEjercicio).join(' · ').isEmpty
                                  ? 'Sin bases configuradas'
                                  : cat.estaciones.map((e) => e.nombreEjercicio).join(' · '),
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
        TextButton(
          onPressed: () => setState(() {
            _codigoFinal = null; _circuito = []; _modoMovil = false; _codigoCtrl.clear(); _documentoCtrl.clear();
          }),
          child: const Text('← Cambiar código', style: TextStyle(color: Colors.white54)),
        ),
      ],
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
