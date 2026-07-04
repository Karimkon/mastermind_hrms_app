class DocumentModel {
  final int id;
  final String documentType;
  final String title;
  final String? fileName;
  final String? mimeType;
  final String? expiryDate;
  final String? notes;
  final String? createdAt;

  const DocumentModel({
    required this.id,
    required this.documentType,
    required this.title,
    this.fileName,
    this.mimeType,
    this.expiryDate,
    this.notes,
    this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> j) => DocumentModel(
        id: j['id'],
        documentType: j['document_type'] ?? '',
        title: j['title'] ?? '',
        fileName: j['file_name'],
        mimeType: j['mime_type'],
        expiryDate: j['expiry_date'],
        notes: j['notes'],
        createdAt: j['created_at'],
      );
}
