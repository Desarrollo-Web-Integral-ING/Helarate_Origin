import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DiceBearStyle {
  final String id;
  final String label;
  const DiceBearStyle(this.id, this.label);
}

/// Acceso a DiceBear pensado para que NO falle en producción:
///  - descarga el PNG UNA vez y la app lo guarda en el perfil (base de datos),
///    así mostrar el avatar ya no depende de DiceBear;
///  - caché en memoria, reintentos con espera y límite de peticiones a la vez
///    (la API pública limita las ráfagas);
///  - si DiceBear no responde, quien lo use muestra un avatar local de respaldo.
class AvatarService {
  AvatarService._();

  static const String apiVersion = '10.x';
  static const String _host = 'api.dicebear.com';

  /// Los 61 estilos de https://www.dicebear.com/styles/
  static const List<DiceBearStyle> styles = [
    DiceBearStyle('adventurer', 'Adventurer'),
    DiceBearStyle('adventurer-neutral', 'Adventurer Neutral'),
    DiceBearStyle('avataaars', 'Avataaars'),
    DiceBearStyle('avataaars-neutral', 'Avataaars Neutral'),
    DiceBearStyle('big-ears', 'Big Ears'),
    DiceBearStyle('big-ears-neutral', 'Big Ears Neutral'),
    DiceBearStyle('big-smile', 'Big Smile'),
    DiceBearStyle('blobs', 'Blobs'),
    DiceBearStyle('bottts', 'Bottts'),
    DiceBearStyle('bottts-neutral', 'Bottts Neutral'),
    DiceBearStyle('cameo', 'Cameo'),
    DiceBearStyle('clay', 'Clay'),
    DiceBearStyle('constellation', 'Constellation'),
    DiceBearStyle('critters', 'Critters'),
    DiceBearStyle('croodles', 'Croodles'),
    DiceBearStyle('croodles-neutral', 'Croodles Neutral'),
    DiceBearStyle('cutouts', 'Cutouts'),
    DiceBearStyle('disco', 'Disco'),
    DiceBearStyle('dylan', 'Dylan'),
    DiceBearStyle('fun-emoji', 'Fun Emoji'),
    DiceBearStyle('gaze', 'Gaze'),
    DiceBearStyle('glass', 'Glass'),
    DiceBearStyle('glyphs', 'Glyphs'),
    DiceBearStyle('icons', 'Icons'),
    DiceBearStyle('identicon', 'Identicon'),
    DiceBearStyle('initial-face', 'Initial Face'),
    DiceBearStyle('initials', 'Initials'),
    DiceBearStyle('landscape', 'Landscape'),
    DiceBearStyle('line-face', 'Line Face'),
    DiceBearStyle('loops', 'Loops'),
    DiceBearStyle('lorelei', 'Lorelei'),
    DiceBearStyle('lorelei-neutral', 'Lorelei Neutral'),
    DiceBearStyle('marbles', 'Marbles'),
    DiceBearStyle('micah', 'Micah'),
    DiceBearStyle('miniavs', 'Miniavs'),
    DiceBearStyle('moods', 'Moods'),
    DiceBearStyle('notionists', 'Notionists'),
    DiceBearStyle('notionists-neutral', 'Notionists Neutral'),
    DiceBearStyle('open-peeps', 'Open Peeps'),
    DiceBearStyle('patchwork', 'Patchwork'),
    DiceBearStyle('personas', 'Personas'),
    DiceBearStyle('pixel-art', 'Pixel Art'),
    DiceBearStyle('pixel-art-neutral', 'Pixel Art Neutral'),
    DiceBearStyle('pixelbot', 'Pixelbot'),
    DiceBearStyle('planets', 'Planets'),
    DiceBearStyle('rings', 'Rings'),
    DiceBearStyle('shadows', 'Shadows'),
    DiceBearStyle('shape-grid', 'Shape Grid'),
    DiceBearStyle('shapes', 'Shapes'),
    DiceBearStyle('slice', 'Slice'),
    DiceBearStyle('sprouts', 'Sprouts'),
    DiceBearStyle('squircles', 'Squircles'),
    DiceBearStyle('stack', 'Stack'),
    DiceBearStyle('stripes', 'Stripes'),
    DiceBearStyle('thumbs', 'Thumbs'),
    DiceBearStyle('toon-head', 'Toon Head'),
    DiceBearStyle('triangles', 'Triangles'),
    DiceBearStyle('voxel-art', 'Voxel Art'),
    DiceBearStyle('voxel-bot', 'Voxel Bot'),
    DiceBearStyle('waves', 'Waves'),
    DiceBearStyle('weave', 'Weave'),
  ];

  static final Set<String> _ids = styles.map((e) => e.id).toSet();

  static bool isDiceBear(String? id) => id != null && _ids.contains(id);

  static Uri url(String style, String seed, {int size = 192}) => Uri.https(
        _host,
        '/$apiVersion/$style/png',
        {'seed': seed, 'size': '$size'},
      );

  // ---- caché en memoria (LRU) ----
  static const int _maxCache = 150;
  static final LinkedHashMap<String, Uint8List> _cache = LinkedHashMap();
  static final Map<String, Future<Uint8List?>> _inflight = {};

  /// Cuántas veces falló seguidas (para no insistir sin parar si está bloqueado).
  static int _consecutiveFailures = 0;
  static DateTime? _pausedUntil;

  static String _key(String style, String seed, int size) => '$style|$seed|$size';

  static Uint8List? cached(String style, String seed, {int size = 192}) {
    final k = _key(style, seed, size);
    final v = _cache.remove(k);
    if (v != null) _cache[k] = v; // marcar como reciente
    return v;
  }

  /// Guarda en caché un PNG ya conocido (p. ej. el que viene de la base de datos).
  static void prime(String style, String seed, Uint8List bytes, {int size = 192}) {
    _put(_key(style, seed, size), bytes);
  }

  static void _put(String k, Uint8List v) {
    _cache.remove(k);
    _cache[k] = v;
    while (_cache.length > _maxCache) {
      _cache.remove(_cache.keys.first);
    }
  }

  // ---- límite de peticiones simultáneas ----
  static const int _maxParallel = 4;
  static int _running = 0;
  static final Queue<Completer<void>> _waiting = Queue();

  static Future<void> _acquire() async {
    if (_running < _maxParallel) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  static void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }

  static bool _isPng(Uint8List b) =>
      b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47;

  /// Descarga el PNG del avatar. Devuelve null si DiceBear no responde
  /// (sin internet, bloqueado por la red o por una extensión, límite de uso).
  static Future<Uint8List?> fetch(String style, String seed, {int size = 192}) {
    final k = _key(style, seed, size);
    final hit = cached(style, seed, size: size);
    if (hit != null) return Future.value(hit);

    // Tras varios fallos seguidos se pausa un rato para no saturar.
    if (_pausedUntil != null && DateTime.now().isBefore(_pausedUntil!)) {
      return Future.value(null);
    }
    return _inflight.putIfAbsent(k, () async {
      try {
        return await _download(style, seed, size, k);
      } finally {
        _inflight.remove(k);
      }
    });
  }

  static Future<Uint8List?> _download(String style, String seed, int size, String k) async {
    await _acquire();
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final res = await http
              .get(url(style, seed, size: size))
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200 && _isPng(res.bodyBytes)) {
            _consecutiveFailures = 0;
            _put(k, res.bodyBytes);
            return res.bodyBytes;
          }
          // 429 = demasiadas peticiones: esperar más antes de reintentar.
          if (res.statusCode == 429) {
            await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
            continue;
          }
          if (res.statusCode >= 400 && res.statusCode < 500) break; // no insistir
        } catch (_) {
          // sin red / bloqueado / tiempo agotado: reintentar
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
      _consecutiveFailures++;
      if (_consecutiveFailures >= 6) {
        _pausedUntil = DateTime.now().add(const Duration(seconds: 30));
        _consecutiveFailures = 0;
      }
      return null;
    } finally {
      _release();
    }
  }

  static String toBase64(Uint8List bytes) => base64Encode(bytes);

  static Uint8List? fromBase64(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      final b = base64Decode(b64);
      return _isPng(b) ? b : null;
    } catch (_) {
      return null;
    }
  }
}
