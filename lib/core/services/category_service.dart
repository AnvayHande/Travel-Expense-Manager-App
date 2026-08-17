import '../models/category_model.dart';
import '../repositories/category_repository.dart';

class CategoryService {
  final CategoryRepository _categoryRepository;

  CategoryService({required this._categoryRepository});

  Future<void> seedDefaults(String tripId) async {
    final defaults = CategoryModel.defaultsForTrip(tripId);
    await _categoryRepository.seedDefaultCategories(defaults);
  }

  Future<void> addCategory({
    required String tripId,
    required String name,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    final category = CategoryModel(
      categoryId: '${tripId}_${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      name: name,
      iconCodePoint: iconCodePoint,
      colorValue: colorValue,
      createdAt: DateTime.now(),
    );
    await _categoryRepository.addCategory(category);
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _categoryRepository.updateCategory(category);
  }

  Future<void> archiveCategory(String categoryId) async {
    await _categoryRepository.archiveCategory(categoryId);
  }
}
