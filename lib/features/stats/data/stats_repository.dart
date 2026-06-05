import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/dio_client.dart';
import '../domain/stats_model.dart';

import 'package:stratos_app/features/auth/presentation/controllers/auth_controller.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  // Watch auth state to ensure repository is recreated on logout/login
  ref.watch(authControllerProvider);
  return StatsRepository(ref.watch(dioClientProvider));
});

class StatsRepository {
  final Dio _dio;

  const StatsRepository(this._dio);

  Future<StatsMeModel> getMeStats() async {
    final response = await _dio.get<dynamic>('stats/me');
    return StatsMeModel.fromJson(response.data);
  }
}