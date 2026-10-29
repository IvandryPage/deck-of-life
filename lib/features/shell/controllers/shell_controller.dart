import 'dart:async';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/sharing/share_intake_service.dart';
import '../../../domain/usecases/reminder_coordinator.dart';
import '../../inbox/inbox_args.dart';

class ShellController extends GetxController {
  ShellController(this._share, this._coordinator);

  final ShareIntakeService _share;
  final ReminderCoordinator _coordinator;

  static const int tabHome = 0;
  static const int tabFinance = 1;
  static const int tabTask = 2;
  static const int tabCalendar = 3;
  static const int tabInfo = 4; // Informasi (Kotak masuk)

  final RxInt tab = 0.obs;

  /// Pindah tab; bila sedang di halaman dalam (detail/form), kembali ke shell dulu.
  void goTo(int index) {
    if (index < tabHome || index > tabInfo) return;
    Get.until((r) => r.settings.name == Routes.shell || r.isFirst);
    tab.value = index;
  }
  StreamSubscription<SharePayload>? _sub;

  @override
  void onReady() {
    super.onReady();
    _start();
  }

  Future<void> _start() async {
    // Samakan jadwal notifikasi OS dengan database (TDD 6.4).
    unawaited(_coordinator.reconcileAll());

    _sub = _share.stream.listen(_openCapture);
    final initial = await _share.start();
    if (initial != null) _openCapture(initial);
  }

  void _openCapture(SharePayload payload) {
    Get.toNamed<dynamic>(
      Routes.savedItemForm,
      arguments: SavedItemFormArgs(
        text: payload.text,
        subject: payload.subject,
        fromShare: true,
      ),
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
