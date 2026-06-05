import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/dio_client.dart';
import '../../../data/json_parsing.dart';
import '../domain/announcement_model.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(dioClientProvider));
});

class AnnouncementRepository {
  final Dio _dio;

  const AnnouncementRepository(this._dio);

  Future<List<AnnouncementModel>> getAnnouncements({
    String? courseId,
    bool onlyPublished = true,
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get<dynamic>(
      'announcements',
      queryParameters: <String, dynamic>{
        'skip': skip,
        'limit': limit,
        if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
        if (onlyPublished) 'published': true,
      },
    );
    return asJsonMapList(response.data).map(AnnouncementModel.fromJson).toList(growable: false);
  }

  Future<AnnouncementModel?> getAnnouncementById(String id) async {
    final response = await _dio.get<dynamic>('announcements/$id');
    if (response.data == null) {
      return null;
    }
    return AnnouncementModel.fromJson(response.data);
  }
}