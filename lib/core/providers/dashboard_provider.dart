import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.dashboard);
    return res.data as Map<String, dynamic>;
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});
