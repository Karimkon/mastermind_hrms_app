import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../constants/api_constants.dart';
import '../models/document_model.dart';

// Fetch all my documents
final documentsProvider = FutureProvider<List<DocumentModel>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.myDocuments);
    final body = res.data as Map<String, dynamic>;
    final list = body['data'] as List? ?? [];
    return list.map((j) => DocumentModel.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

// Actions: upload and delete
class DocumentsActionsNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<String> uploadDocument({
    required String filePath,
    required String fileName,
    required String documentType,
    String? title,
    String? expiryDate,
    String? notes,
  }) async {
    final formData = FormData.fromMap({
      'document_type': documentType,
      if (title != null && title.isNotEmpty) 'title': title,
      if (expiryDate != null && expiryDate.isNotEmpty) 'expiry_date': expiryDate,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });

    final res = await ApiService.postForm(ApiConstants.myDocuments, formData);
    final body = res.data as Map<String, dynamic>;
    return body['message'] ?? 'Document uploaded.';
  }

  Future<void> deleteDocument(int documentId) async {
    await ApiService.delete('${ApiConstants.myDocuments}/$documentId');
  }

  Future<void> updateNok({
    String? nextOfKinName,
    String? nextOfKinRelation,
    String? nextOfKinPhone,
    String? nextOfKinEmail,
    String? passportNumber,
  }) async {
    final payload = <String, dynamic>{};
    if (nextOfKinName != null)     payload['next_of_kin_name']     = nextOfKinName;
    if (nextOfKinRelation != null) payload['next_of_kin_relation'] = nextOfKinRelation;
    if (nextOfKinPhone != null)    payload['next_of_kin_phone']    = nextOfKinPhone;
    if (nextOfKinEmail != null)    payload['next_of_kin_email']    = nextOfKinEmail;
    if (passportNumber != null)    payload['passport_number']      = passportNumber;
    await ApiService.put(ApiConstants.myNok, data: payload);
  }
}

final documentsActionsProvider =
    NotifierProvider<DocumentsActionsNotifier, void>(DocumentsActionsNotifier.new);
