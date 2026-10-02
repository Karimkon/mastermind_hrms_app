/// The careers side of the app: what an outside job seeker deals with.
///
/// Kept apart from the employee models on purpose. A job seeker is not a
/// User, has no employee record and no role, and nothing here should ever be
/// confused with somebody on the payroll.
library;

class JobCategoryModel {
  final int id;
  final String name;
  final String? description;

  const JobCategoryModel({required this.id, required this.name, this.description});

  factory JobCategoryModel.fromJson(Map<String, dynamic> j) => JobCategoryModel(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
      );
}

class CareerJob {
  final int id;
  final String title;
  final String? department;
  final String? category;
  final int? categoryId;
  final String? location;
  final String typeLabel;
  final int vacancies;
  final int applicants;
  final String? deadline;
  final int? closesInDays;
  final bool alreadyApplied;

  // Only present on the detail call.
  final String? description;
  final String? requirements;
  final String? benefits;

  const CareerJob({
    required this.id,
    required this.title,
    this.department,
    this.category,
    this.categoryId,
    this.location,
    this.typeLabel = '',
    this.vacancies = 1,
    this.applicants = 0,
    this.deadline,
    this.closesInDays,
    this.alreadyApplied = false,
    this.description,
    this.requirements,
    this.benefits,
  });

  factory CareerJob.fromJson(Map<String, dynamic> j) => CareerJob(
        id: j['id'] as int,
        title: (j['title'] ?? 'Untitled position') as String,
        department: j['department'] as String?,
        category: j['category'] as String?,
        categoryId: j['category_id'] as int?,
        location: j['location'] as String?,
        typeLabel: (j['type_label'] ?? '') as String,
        vacancies: (j['vacancies'] ?? 1) as int,
        applicants: (j['applicants'] ?? 0) as int,
        deadline: j['deadline'] as String?,
        closesInDays: j['closes_in_days'] as int?,
        alreadyApplied: (j['already_applied'] ?? false) as bool,
        description: j['description'] as String?,
        requirements: j['requirements'] as String?,
        benefits: j['benefits'] as String?,
      );

  /// What to show under the title. Null when there is genuinely nothing.
  String? get subtitle {
    final parts = [category, location].where((p) => p != null && p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class CategoryShare {
  final String label;
  final int count;
  final double percent;

  const CategoryShare({required this.label, required this.count, required this.percent});

  factory CategoryShare.fromJson(Map<String, dynamic> j) => CategoryShare(
        label: (j['label'] ?? '') as String,
        count: (j['count'] ?? 0) as int,
        percent: ((j['percent'] ?? 0) as num).toDouble(),
      );
}

/// One document type the application form asks for.
class DocumentSlot {
  final String type;
  final String label;
  final bool required;
  final bool multiple;

  const DocumentSlot({
    required this.type,
    required this.label,
    this.required = false,
    this.multiple = false,
  });

  factory DocumentSlot.fromJson(Map<String, dynamic> j) => DocumentSlot(
        type: (j['type'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        required: (j['required'] ?? false) as bool,
        multiple: (j['multiple'] ?? false) as bool,
      );
}

class ScreeningQuestion {
  final int id;
  final String question;
  final String type;

  /// What the question is worth. Zero for free text, which a person reads.
  final int marks;

  /// Each answer carries its own marks, so "5+ years" can be worth more
  /// than "1-2 years" on the same question.
  final List<ScreeningOption> options;

  const ScreeningQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.marks = 0,
    this.options = const [],
  });

  bool get isScored => marks > 0;

  factory ScreeningQuestion.fromJson(Map<String, dynamic> j) => ScreeningQuestion(
        id: j['id'] as int,
        question: (j['question'] ?? '') as String,
        type: (j['type'] ?? 'text') as String,
        marks: ((j['marks'] ?? 0) as num).toInt(),
        options: ((j['options'] as List?) ?? const [])
            .whereType<Map>()
            .map((o) => ScreeningOption.fromJson(Map<String, dynamic>.from(o)))
            .toList(),
      );
}

class ScreeningOption {
  final String text;
  final double marks;

  const ScreeningOption({required this.text, this.marks = 0});

  factory ScreeningOption.fromJson(Map<String, dynamic> j) => ScreeningOption(
        text: (j['text'] ?? '') as String,
        marks: ((j['marks'] ?? 0) as num).toDouble(),
      );
}

class ProgressStage {
  final String key;
  final String label;
  final String blurb;
  final String state; // done | current | pending

  const ProgressStage({
    required this.key,
    required this.label,
    required this.blurb,
    required this.state,
  });

  factory ProgressStage.fromJson(Map<String, dynamic> j) => ProgressStage(
        key: (j['key'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        blurb: (j['blurb'] ?? '') as String,
        state: (j['state'] ?? 'pending') as String,
      );
}

class ApplicationUpdate {
  final String? at;
  final String status;
  final String message;

  const ApplicationUpdate({this.at, required this.status, required this.message});

  factory ApplicationUpdate.fromJson(Map<String, dynamic> j) => ApplicationUpdate(
        at: j['at'] as String?,
        status: (j['status'] ?? '') as String,
        message: (j['message'] ?? '') as String,
      );
}

class Assessment {
  final double percentage;
  final double score;
  final double max;

  const Assessment({required this.percentage, required this.score, required this.max});

  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
        percentage: ((j['percentage'] ?? 0) as num).toDouble(),
        score: ((j['score'] ?? 0) as num).toDouble(),
        max: ((j['max'] ?? 0) as num).toDouble(),
      );
}

class JobApplication {
  final int? id;
  final String trackingCode;
  final int jobId;
  final String jobTitle;
  final String? jobLocation;
  final String? appliedAt;
  final String stage;
  final String stageLabel;
  final List<ProgressStage> progress;
  final Assessment? assessment;
  final List<ApplicationUpdate> updates;
  final List<String> documents;

  const JobApplication({
    this.id,
    required this.trackingCode,
    required this.jobId,
    required this.jobTitle,
    this.jobLocation,
    this.appliedAt,
    this.stage = 'applied',
    this.stageLabel = '',
    this.progress = const [],
    this.assessment,
    this.updates = const [],
    this.documents = const [],
  });

  factory JobApplication.fromJson(Map<String, dynamic> j) {
    final job = (j['job'] as Map?) ?? const {};
    return JobApplication(
      id: j['id'] as int?,
      trackingCode: (j['tracking_code'] ?? '') as String,
      jobId: (job['id'] ?? 0) as int,
      jobTitle: (job['title'] ?? 'Position') as String,
      jobLocation: job['location'] as String?,
      appliedAt: j['applied_at'] as String?,
      stage: (j['stage'] ?? 'applied') as String,
      stageLabel: (j['stage_label'] ?? '') as String,
      progress: ((j['progress'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => ProgressStage.fromJson(Map<String, dynamic>.from(p)))
          .toList(),
      assessment: j['assessment'] == null
          ? null
          : Assessment.fromJson(Map<String, dynamic>.from(j['assessment'] as Map)),
      updates: ((j['updates'] as List?) ?? const [])
          .whereType<Map>()
          .map((u) => ApplicationUpdate.fromJson(Map<String, dynamic>.from(u)))
          .toList(),
      documents: ((j['documents'] as List?) ?? const [])
          .whereType<Map>()
          .map((d) => (d['label'] ?? '') as String)
          .where((l) => l.isNotEmpty)
          .toList(),
    );
  }

  /// True once there is nothing further to wait for.
  bool get isDecided => stage == 'outcome';
}

class SeekerProfile {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? location;
  final String? educationLevel;
  final int? experienceYears;
  final bool notifyEmail;
  final bool notifySms;
  final List<JobCategoryModel> categories;
  final int applications;

  const SeekerProfile({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.location,
    this.educationLevel,
    this.experienceYears,
    this.notifyEmail = true,
    this.notifySms = true,
    this.categories = const [],
    this.applications = 0,
  });

  factory SeekerProfile.fromJson(Map<String, dynamic> j) => SeekerProfile(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        phone: j['phone'] as String?,
        location: j['location'] as String?,
        educationLevel: j['education_level'] as String?,
        experienceYears: j['experience_years'] as int?,
        notifyEmail: (j['notify_email'] ?? true) as bool,
        notifySms: (j['notify_sms'] ?? true) as bool,
        categories: ((j['categories'] as List?) ?? const [])
            .whereType<Map>()
            .map((c) => JobCategoryModel.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        applications: (j['applications'] ?? 0) as int,
      );
}

class SeekerNotice {
  final int id;
  final String type;
  final String title;
  final String? body;
  final bool read;
  final String? createdAt;
  final Map<String, dynamic> data;

  const SeekerNotice({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.read = false,
    this.createdAt,
    this.data = const {},
  });

  factory SeekerNotice.fromJson(Map<String, dynamic> j) => SeekerNotice(
        id: j['id'] as int,
        type: (j['type'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        body: j['body'] as String?,
        read: (j['read'] ?? false) as bool,
        createdAt: j['created_at'] as String?,
        data: j['data'] == null ? const {} : Map<String, dynamic>.from(j['data'] as Map),
      );
}
