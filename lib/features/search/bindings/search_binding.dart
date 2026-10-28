import 'package:get/get.dart';

import '../../../domain/repositories/repositories.dart';
import '../../../domain/usecases/usecases.dart';
import '../controllers/search_controller.dart';

class SearchBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<UniversalSearchController>(
      () => UniversalSearchController(
        Get.find<SearchAll>(),
        Get.find<SavedItemRepository>(),
      ),
    );
  }
}
