import 'package:get/get.dart';

import '../errors/app_exception.dart';
import '../widgets/common_widgets.dart';
import 'data_revision.dart';

/// Pola penulisan data yang seragam untuk controller:
///  - menjalankan operasi, lalu memberi tahu controller lain lewat [DataRevision],
///  - menampilkan pesan sukses / error yang aman (tanpa SQL mentah).
mixin DataMutations on GetxController {
  /// Mengembalikan true bila operasi berhasil.
  Future<bool> mutate(
    Future<void> Function() operation, {
    String? success,
  }) async {
    try {
      await operation();
      Get.find<DataRevision>().bump();
      if (success != null) AppToast.show(success);
      return true;
    } catch (e, st) {
      AppLog.error('mutate', e, st);
      AppToast.show(messageOf(e), isError: true);
      return false;
    }
  }
}
