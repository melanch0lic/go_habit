import 'package:go_habit/feature/categories/domain/models/habit_category.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class RemoteHabitCategoryDatasource {
  Future<List<HabitCategory>> getHabitCategories();
}

class SupabaseHabitCategoryDataSource implements RemoteHabitCategoryDatasource {
  final SupabaseClient _supabaseClient;

  SupabaseHabitCategoryDataSource(this._supabaseClient);

  @override
  Future<List<HabitCategory>> getHabitCategories() async {
    final response = await _supabaseClient.from('category').select('id, name, color').order('sort_order');
    return response.map(HabitCategory.fromJson).toList();
  }
}
