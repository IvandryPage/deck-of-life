import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';

/// Dinamai `UniversalSearchController` agar tidak bentrok dengan
/// `SearchController` milik Flutter Material.
class UniversalSearchController extends GetxController {
  UniversalSearchController(this._searchAll, this._items);

  final SearchAll _searchAll;
  final SavedItemRepository _items;

  final RxString query = ''.obs;
  final Rxn<SavedItemType> type = Rxn<SavedItemType>();
  final Rxn<ReviewStatus> review = Rxn<ReviewStatus>();
  final RxnString course = RxnString();
  final RxList<String> courses = <String>[].obs;

  final Rxn<SearchResults> results = Rxn<SearchResults>();
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    _loadCourses();
    debounce<String>(query, (_) => run(),
        time: const Duration(milliseconds: 250));
    everAll([type, review, course], (_) => run());
    run();
  }

  Future<void> _loadCourses() async {
    try {
      courses.assignAll(await _items.distinctCourseNames());
    } catch (e, st) {
      AppLog.error('search.courses', e, st);
    }
  }

  bool get hasFilters =>
      type.value != null || review.value != null || course.value != null;

  void clearFilters() {
    type.value = null;
    review.value = null;
    course.value = null;
  }

  Future<void> run() async {
    // Hanya hasil dari permintaan terbaru yang dipakai (hindari balapan async).
    final gen = ++_generation;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final r = await _searchAll(
        query.value,
        type: type.value,
        courseName: course.value,
        reviewStatus: review.value,
      );
      if (gen != _generation) return;
      results.value = r;
    } catch (e, st) {
      AppLog.error('search.run', e, st);
      if (gen != _generation) return;
      errorMessage.value = messageOf(e);
    } finally {
      if (gen == _generation) isLoading.value = false;
    }
  }
}
