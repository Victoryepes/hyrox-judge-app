import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Equivalente a juez.store.ts (React) pero con almacenamiento seguro
/// en vez de sessionStorage — en Android no hay "cierre de pestaña" que
/// invalide la sesión, así que debe cerrarse explícitamente (ver JudgeSession.clear).
class JuezSession {
  final String tokenSesion;
  final String sesionId;
  final String competenciaId;
  final String estacionId;
  final String nombreEstacion;
  final String codigoAcceso;
  final String? nombreCompetencia;
  /// true si se conectó siguiendo una categoría (asignación móvil) en vez
  /// de una estación fija.
  final bool modoMovil;
  /// Cédula del juez registrado — se guarda para poder reconectar sin
  /// volver a pedirla.
  final String documento;

  const JuezSession({
    required this.tokenSesion,
    required this.sesionId,
    required this.competenciaId,
    required this.estacionId,
    required this.nombreEstacion,
    required this.codigoAcceso,
    required this.documento,
    this.nombreCompetencia,
    this.modoMovil = false,
  });

  Map<String, dynamic> toJson() => {
        'tokenSesion': tokenSesion,
        'sesionId': sesionId,
        'competenciaId': competenciaId,
        'estacionId': estacionId,
        'nombreEstacion': nombreEstacion,
        'codigoAcceso': codigoAcceso,
        'nombreCompetencia': nombreCompetencia,
        'modoMovil': modoMovil,
        'documento': documento,
      };

  factory JuezSession.fromJson(Map<String, dynamic> json) => JuezSession(
        tokenSesion: json['tokenSesion'] as String,
        sesionId: json['sesionId'] as String,
        competenciaId: json['competenciaId'] as String,
        estacionId: json['estacionId'] as String,
        nombreEstacion: json['nombreEstacion'] as String,
        codigoAcceso: json['codigoAcceso'] as String,
        nombreCompetencia: json['nombreCompetencia'] as String?,
        modoMovil: json['modoMovil'] as bool? ?? false,
        documento: json['documento'] as String? ?? '',
      );
}

class SecureSessionStore {
  static const _key = 'fh_juez_session';
  final _storage = const FlutterSecureStorage();

  Future<void> save(JuezSession session) async {
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
  }

  Future<JuezSession?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return JuezSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }
}
