import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deck_of_life/core/sharing/share_intake_service.dart';
import 'package:deck_of_life/domain/usecases/capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareIntakeService.parse', () {
    test('teks dan subject valid', () {
      final p = ShareIntakeService.parse({'text': ' halo https://a.id ', 'subject': ' S '});
      expect(p!.text, 'halo https://a.id');
      expect(p.subject, 'S');
    });
    test('payload aneh tidak melempar', () {
      expect(ShareIntakeService.parse(null), isNull);
      expect(ShareIntakeService.parse('x'), isNull);
      expect(ShareIntakeService.parse({'text': '   '}), isNull);
      expect(ShareIntakeService.parse({'text': 5}), isNull);
      expect(ShareIntakeService.parse({'text': 'a', 'subject': 3})!.subject, isNull);
    });
  });

  group('Channel Share Sheet (MethodChannel dipalsukan)', () {
    const channel = MethodChannel('deck_of_life/share');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('share yang membuka aplikasi dikembalikan oleh start()', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialShare') {
          return {'text': 'Lihat https://kampus.ac.id/tugas', 'subject': 'Tugas'};
        }
        return null;
      });
      final svc = ShareIntakeService();
      final initial = await svc.start();
      expect(initial!.subject, 'Tugas');
      final s = CaptureSuggester.suggest(initial.text,
          subject: initial.subject, fromShare: true);
      expect(s.url, 'https://kampus.ac.id/tugas');
      svc.dispose();
    });

    test('tanpa share awal -> null; tanpa plugin -> null (tidak crash)', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      expect(await ShareIntakeService().start(), isNull);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await ShareIntakeService().start(), isNull);
    });

    test('share saat aplikasi berjalan masuk lewat stream', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final svc = ShareIntakeService();
      await svc.start();
      final future = svc.stream.first;
      await messenger.handlePlatformMessage(
        'deck_of_life/share',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('onShare', {'text': 'baru'})),
        (_) {},
      );
      expect((await future).text, 'baru');
      svc.dispose();
    });
  });
}
