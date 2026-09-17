import 'package:dio/dio.dart';
import '../config/env.dart';

/// Cliente HTTP compartido — equivalente a services/api.ts (axios) del frontend web.
/// El header X-Token-Sesion se agrega explícitamente por cada llamada (no vía
/// interceptor global) para evitar depender de un estado de sesión implícito
/// que pueda quedar obsoleto tras reconectar.
class ApiClient {
  ApiClient._internal()
      : dio = Dio(
          BaseOptions(
            baseUrl: Env.apiBaseUrl,
            // Render free tier puede tardar >10s en "despertar" tras estar
            // inactivo (cold start) — con 10s ese tiempo normal se
            // clasificaba como fallo de red y la acción se encolaba en vez
            // de ejecutarse al instante, dando la falsa impresión de que
            // "no registró" hasta que la cola reintentaba más tarde.
            connectTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 25),
          ),
        );

  static final ApiClient instance = ApiClient._internal();

  final Dio dio;

  Options withTokenSesion(String tokenSesion) =>
      Options(headers: {'X-Token-Sesion': tokenSesion});
}
