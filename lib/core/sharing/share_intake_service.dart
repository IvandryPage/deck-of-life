import 'dart:async';

import 'package:flutter/services.dart';

import '../errors/app_exception.dart';

/// Isi yang benar-benar dikirim aplikasi sumber lewat Share Sheet.
class SharePayload {
  const SharePayload({required this.text, this.subject});

  final String text;
  final String? subject;
}

/// Menerima teks/tautan dari Android Share Sheet lewat MethodChannel
/// (`MainActivity.kt`). Untuk MVP hanya `text/plain` (TDD bagian 8); file
/// ditunda sampai izin dan persistensi URI diuji di perangkat nyata.
class ShareIntakeService {
  static const MethodChannel _channel =
      MethodChannel('deck_of_life/share');

  final StreamController<SharePayload> _controller =
      StreamController<SharePayload>.broadcast();
  bool _started = false;

  /// Share yang masuk saat aplikasi sudah berjalan.
  Stream<SharePayload> get stream => _controller.stream;

  /// Mulai mendengarkan dan mengembalikan share yang membuka aplikasi (bila ada).
  Future<SharePayload?> start() async {
    if (_started) return null;
    _started = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final payload = parse(call.arguments);
        if (payload != null) _controller.add(payload);
      }
      return null;
    });

    try {
      final initial = await _channel.invokeMethod<Object?>('getInitialShare');
      return parse(initial);
    } on MissingPluginException {
      return null; // mis. saat test / platform non-Android
    } on PlatformException catch (e, st) {
      AppLog.error('share.initial', e, st);
      return null;
    }
  }

  /// Memvalidasi payload mentah. Mengembalikan null bila tidak ada teks.
  /// Tidak melempar: payload aneh tidak boleh membuat aplikasi crash.
  static SharePayload? parse(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String || text.trim().isEmpty) return null;
    final subject = raw['subject'];
    final cleanSubject =
        subject is String && subject.trim().isNotEmpty ? subject.trim() : null;
    return SharePayload(text: text.trim(), subject: cleanSubject);
  }

  void dispose() {
    _controller.close();
  }
}
