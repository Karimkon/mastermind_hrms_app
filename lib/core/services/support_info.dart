import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

/// Who to contact for help.
///
/// App Review Guideline 1.5 expects a user to be able to reach the developer
/// easily. The previous submission had no support screen, no contact address
/// and no privacy link anywhere in the app, and was rejected for it.
///
/// Fetched from the server so a changed phone number does not need an app
/// release, but every field has a baked-in fallback: somebody who cannot
/// reach the network is precisely the person who needs the support desk, and
/// a screen that renders nothing when offline is no better than no screen.
class SupportInfo {
  final String company;
  final String? email;
  final String? phone;
  final String? address;
  final String website;
  final String? careersEmail;
  final String hours;

  const SupportInfo({
    required this.company,
    this.email,
    this.phone,
    this.address,
    required this.website,
    this.careersEmail,
    required this.hours,
  });

  /// What ships in the binary. Current as of the 1.5.3 resubmission, and
  /// what a reviewer sees if the API is unreachable.
  static const fallback = SupportInfo(
    company: 'Mastermind Consult Ltd',
    email: 'payroll@mastermindconsults.co.ug',
    phone: '+256 393 215 289',
    website: 'https://mastermindconsults.co.ug',
    hours: 'Monday to Friday, 8:00am - 5:00pm (East Africa Time)',
  );

  factory SupportInfo.fromJson(Map<String, dynamic> j) => SupportInfo(
        company: (j['company'] as String?)?.trim().isNotEmpty == true
            ? j['company'] as String
            : fallback.company,
        email: _clean(j['email']) ?? fallback.email,
        phone: _clean(j['phone']) ?? fallback.phone,
        address: _clean(j['address']),
        website: _clean(j['website']) ?? fallback.website,
        careersEmail: _clean(j['careers_email']),
        hours: _clean(j['hours']) ?? fallback.hours,
      );

  static String? _clean(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Never throws. A support screen that can fail is a support screen that
  /// is missing at the moment it matters.
  static Future<SupportInfo> load() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ));

      final resp = await dio.get('${ApiConstants.baseUrl}/support-info');

      if (resp.data is Map<String, dynamic>) {
        return SupportInfo.fromJson(resp.data as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall through to what shipped in the binary.
    }

    return fallback;
  }
}
