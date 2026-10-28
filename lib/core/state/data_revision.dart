import 'package:get/get.dart';

/// Penanda "data berubah". Controller mendengarkan [revision] dan memuat ulang;
/// use case memanggil [bump] setelah menulis. Menghindari controller yang saling
/// memanggil.
class DataRevision extends GetxService {
  final RxInt revision = 0.obs;

  void bump() => revision.value++;
}
