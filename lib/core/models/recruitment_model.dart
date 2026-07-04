class JobPostingModel {
  final int id;
  final String title;
  final String? referenceNumber;
  final String? department;
  final int? departmentId;
  final String? employmentType;
  final String? location;
  final String? description;
  final String? requirements;
  final double? salaryMin;
  final double? salaryMax;
  final int? vacancies;
  final String? deadline;
  final String status;
  final int candidatesCount;
  final bool isPublic;

  const JobPostingModel({
    required this.id,
    required this.title,
    this.referenceNumber,
    this.department,
    this.departmentId,
    this.employmentType,
    this.location,
    this.description,
    this.requirements,
    this.salaryMin,
    this.salaryMax,
    this.vacancies,
    this.deadline,
    required this.status,
    required this.candidatesCount,
    this.isPublic = false,
  });

  factory JobPostingModel.fromJson(Map<String, dynamic> j) => JobPostingModel(
        id: j['id'],
        title: j['title'] ?? '',
        referenceNumber: j['reference_number'],
        department: j['department'],
        departmentId: j['department_id'],
        employmentType: j['employment_type'],
        location: j['location'],
        description: j['description'],
        requirements: j['requirements'],
        salaryMin: (j['salary_min'] as num?)?.toDouble(),
        salaryMax: (j['salary_max'] as num?)?.toDouble(),
        vacancies: j['vacancies'],
        deadline: j['deadline'],
        status: j['status'] ?? 'open',
        candidatesCount: j['candidates_count'] ?? 0,
        isPublic: j['is_public'] ?? false,
      );
}

class CandidateModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final int? jobPostingId;
  final String? jobTitle;
  final int score;
  final String status;
  final String? notes;
  final String? resumeUrl;
  final double? offerAmount;
  final String? clientShortlistStatus;
  final String? createdAt;

  const CandidateModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.jobPostingId,
    this.jobTitle,
    required this.score,
    required this.status,
    this.notes,
    this.resumeUrl,
    this.offerAmount,
    this.clientShortlistStatus,
    this.createdAt,
  });

  factory CandidateModel.fromJson(Map<String, dynamic> j) => CandidateModel(
        id: j['id'],
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'],
        jobPostingId: j['job_posting_id'],
        jobTitle: j['job_title'],
        score: j['score'] ?? 0,
        status: j['status'] ?? 'new',
        notes: j['notes'],
        resumeUrl: j['resume_url'],
        offerAmount: (j['offer_amount'] as num?)?.toDouble(),
        clientShortlistStatus: j['client_shortlist_status'],
        createdAt: j['created_at'],
      );
}

class InterviewModel {
  final int id;
  final String? candidate;
  final String? job;
  final String type;
  final String? scheduledAt;
  final String? interviewer;
  final String status;
  final int? rating;
  final String? feedback;

  const InterviewModel({
    required this.id,
    this.candidate,
    this.job,
    required this.type,
    this.scheduledAt,
    this.interviewer,
    required this.status,
    this.rating,
    this.feedback,
  });

  factory InterviewModel.fromJson(Map<String, dynamic> j) => InterviewModel(
        id: j['id'],
        candidate: j['candidate'],
        job: j['job'],
        type: j['type'] ?? '',
        scheduledAt: j['scheduled_at'],
        interviewer: j['interviewer'],
        status: j['status'] ?? 'scheduled',
        rating: j['rating'],
        feedback: j['feedback'],
      );
}
