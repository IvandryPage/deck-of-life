import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/state/data_revision.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/state/data_mutations.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/logic.dart';
import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/capture.dart';
import '../../../domain/usecases/usecases.dart';

class HomeController extends GetxController with DataMutations {
  HomeController(
    this._getDashboard,
    this._revision,
    this._saveItem,
    this._savedItems,
    this._changeStatus,
    this._reschedule,
  );

  final SaveSavedItem _saveItem;
  final SavedItemRepository _savedItems;
  final ChangeTaskStatus _changeStatus;
  final RescheduleTask _reschedule;

  final GetDashboard _getDashboard;
  final DataRevision _revision;

  final Rxn<DashboardData> data = Rxn<DashboardData>();
  final RxList<SavedItem> recentNotes = <SavedItem>[].obs;
  final RxString notesQuery = ''.obs;
  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
    ever<int>(_revision.revision, (_) => load());
    debounce<String>(
      notesQuery,
      (query) => searchRecentNotes(query),
      time: const Duration(milliseconds: 250),
    );
  }

  Future<void> load() async {
    // Tidak menampilkan spinner saat memuat ulang agar beranda tidak berkedip.
    if (data.value == null) isLoading.value = true;
    errorMessage.value = null;
    try {
      data.value = await _getDashboard();
      await searchRecentNotes(notesQuery.value);
    } catch (e, st) {
      AppLog.error('home.load', e, st);
      errorMessage.value = messageOf(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchRecentNotes(String query) async {
    try {
      recentNotes.assignAll(await _savedItems.search(query, limit: 3));
    } catch (e, st) {
      AppLog.error('home.search_notes', e, st);
      errorMessage.value = messageOf(e);
      AppToast.show(messageOf(e), isError: true);
    }
  }

  /// Satu ketukan: simpan teks apa adanya ke Kotak Masuk (bukan tugas).
  /// Duplikat (URL/isi sama) tidak disimpan ulang.
  Future<bool> quickCapture(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return false;
    final sug = CaptureSuggester.suggest(text);
    final dup = await _savedItems.findDuplicate(url: sug.url, content: text);
    if (dup != null) {
      AppToast.show('Sudah tersimpan: "${dup.title}"');
      return true;
    }
    final now = DateTime.now();
    return mutate(() async {
      await _saveItem(
        SavedItem(
          id: const Uuid().v4(),
          title: sug.title,
          contentText: text,
          itemType: sug.type,
          sourceUrl: sug.url,
          reviewStatus: ReviewStatus.needsReview,
          isFavorite: false,
          createdAt: now,
          updatedAt: now,
        ),
        isNew: true,
      );
    }, success: 'Tersimpan ke Kotak Masuk');
  }

  Future<void> completeTask(String id) async {
    Task? spawned;
    final ok = await mutate(() async {
      spawned = await _changeStatus(id, TaskStatus.done);
    });
    if (!ok) return;
    AppToast.undoable('Tugas selesai', () async {
      await mutate(() => _changeStatus.undoDone(id, spawnedId: spawned?.id));
    });
  }

  Future<bool> moveTask(String id, int days) =>
      mutate(() => _reschedule(id, days), success: 'Tenggat digeser');

  Future<bool> dropTask(String id) => mutate(
    () => _changeStatus(id, TaskStatus.cancelled),
    success: 'Tugas dibatalkan',
  );
}
