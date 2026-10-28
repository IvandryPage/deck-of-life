import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/usecases/usecases.dart';

enum InboxFilter { all, needsReview, archived }

class InboxController extends GetxController {
  InboxController(this._search, this._revision);

  final SearchSavedItems _search;
  final DataRevision _revision;

  final RxList<SavedItem> items = <SavedItem>[].obs;
  final Rx<InboxFilter> filter = InboxFilter.all.obs;
  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
    ever<int>(_revision.revision, (_) => load());
    ever<InboxFilter>(filter, (_) => load());
  }

  void setFilter(InboxFilter value) => filter.value = value;

  Future<void> load() async {
    errorMessage.value = null;
    try {
      final f = filter.value;
      items.assignAll(await _search(
        '',
        reviewStatus: switch (f) {
          InboxFilter.needsReview => ReviewStatus.needsReview,
          InboxFilter.archived => ReviewStatus.archived,
          InboxFilter.all => null,
        },
        limit: 200,
      ));
    } catch (e, st) {
      AppLog.error('inbox.load', e, st);
      errorMessage.value = messageOf(e);
    } finally {
      isLoading.value = false;
    }
  }
}
