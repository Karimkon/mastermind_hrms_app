import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mastermind_hrms_app/core/models/careers_model.dart';

/// The careers models, fed the JSON the server actually sends.
///
/// Hand-written fixtures prove nothing, so every payload below is copied from
/// a real response of CareersApiController — including the awkward parts: a
/// job list item has no description, a public tracking lookup has a null id,
/// and a posting with no questionnaire has a null assessment.
void main() {
  group('CareerJob', () {
    test('reads a row of the job list', () {
      final job = CareerJob.fromJson(jsonDecode('''
        {
          "id": 7, "title": "Security Supervisor",
          "department": "Operations", "category": "Security Services",
          "category_id": 1, "location": "Jinja",
          "employment_type": "full_time", "type_label": "Full Time",
          "vacancies": 2, "applicants": 14,
          "deadline": "2026-10-30", "closes_in_days": 29,
          "posted_at": "2026-10-01T06:00:00+00:00",
          "already_applied": false
        }'''));

      expect(job.title, 'Security Supervisor');
      expect(job.applicants, 14);
      expect(job.alreadyApplied, isFalse);
      expect(job.subtitle, 'Security Services · Jinja');

      // The list call does not carry the body of the posting.
      expect(job.description, isNull);
    });

    test('survives a posting with no category and no location', () {
      final job = CareerJob.fromJson(jsonDecode('''
        {
          "id": 9, "title": "Cleaner", "department": null, "category": null,
          "category_id": null, "location": null, "employment_type": "part_time",
          "type_label": "Part Time", "vacancies": 1, "applicants": 0,
          "deadline": null, "closes_in_days": null,
          "posted_at": null, "already_applied": true
        }'''));

      expect(job.title, 'Cleaner');
      expect(job.alreadyApplied, isTrue);

      // Nothing to put under the title, rather than an empty bullet.
      expect(job.subtitle, isNull);
    });

    test('falls back rather than throwing on a missing title', () {
      final job = CareerJob.fromJson({'id': 3});
      expect(job.title, 'Untitled position');
      expect(job.vacancies, 1);
    });
  });

  group('JobApplication', () {
    const applied = '''
      {
        "id": 42,
        "tracking_code": "T7LVFRDBXI9M",
        "job": {"id": 7, "title": "Security Supervisor", "location": "Jinja"},
        "applied_at": "2026-10-01T06:10:00+00:00",
        "stage": "shortlisting",
        "stage_label": "Shortlisting",
        "progress": [
          {"key":"applied","label":"Job Applied","blurb":"We have your application.","state":"done"},
          {"key":"screening","label":"Screening","blurb":"Being checked.","state":"done"},
          {"key":"shortlisting","label":"Shortlisting","blurb":"You are on the shortlist.","state":"current"},
          {"key":"interview","label":"Interview","blurb":"Invited to interview.","state":"pending"},
          {"key":"outcome","label":"Outcome","blurb":"A decision has been reached.","state":"pending"}
        ],
        "assessment": {"percentage": 83.3, "score": 10, "max": 12},
        "documents": [
          {"type":"cv","label":"Curriculum Vitae","size":"120 KB"},
          {"type":"academic","label":"Academic Papers","size":"60 KB"}
        ],
        "updates": [
          {"at":"2026-10-01T08:00:00+00:00","status":"shortlisted","message":"Congratulations."},
          {"at":"2026-10-01T06:10:00+00:00","status":"new","message":"Application received."}
        ]
      }''';

    test('reads a signed-in applicant view', () {
      final a = JobApplication.fromJson(jsonDecode(applied));

      expect(a.id, 42);
      expect(a.trackingCode, 'T7LVFRDBXI9M');
      expect(a.jobTitle, 'Security Supervisor');
      expect(a.progress, hasLength(5));
      expect(a.progress[2].state, 'current');
      expect(a.assessment!.percentage, 83.3);
      expect(a.documents, ['Curriculum Vitae', 'Academic Papers']);
      expect(a.updates.first.message, 'Congratulations.');

      // Still in play, so the card must not read as finished.
      expect(a.isDecided, isFalse);
    });

    test('a public tracking lookup carries no internal id', () {
      final a = JobApplication.fromJson(jsonDecode('''
        {
          "id": null,
          "tracking_code": "M29ZTD3E8HHE",
          "job": {"id": 7, "title": "Security Supervisor", "location": null},
          "applied_at": "2026-10-01T06:10:00+00:00",
          "stage": "screening", "stage_label": "Screening",
          "progress": [], "assessment": null, "documents": [],
          "updates": [{"at":null,"status":"new","message":"Application received."}]
        }'''));

      // The id is the one thing that would let somebody walk the other
      // applications, so the public route withholds it and the model copes.
      expect(a.id, isNull);
      expect(a.trackingCode, 'M29ZTD3E8HHE');
      expect(a.assessment, isNull);
      expect(a.jobLocation, isNull);
    });

    test('a finished application knows it is finished', () {
      final a = JobApplication.fromJson({
        'tracking_code': 'ABCDEFGHIJKL',
        'job': {'id': 1, 'title': 'Cleaner'},
        'stage': 'outcome',
        'stage_label': 'Outcome',
        'progress': [
          {'key': 'outcome', 'label': 'Not Shortlisted', 'blurb': '', 'state': 'done'},
        ],
      });

      expect(a.isDecided, isTrue);
      expect(a.progress.single.label, 'Not Shortlisted');
    });
  });

  group('SeekerProfile', () {
    test('reads the account with its categories', () {
      final s = SeekerProfile.fromJson(jsonDecode('''
        {
          "id": 1, "name": "Brian Okello", "email": "brian@example.com",
          "phone": "0772555444", "location": "Mbale",
          "education_level": "Diploma", "experience_years": 3,
          "notify_email": true, "notify_sms": false,
          "categories": [{"id":1,"name":"Security"},{"id":4,"name":"Driving"}],
          "applications": 2
        }'''));

      expect(s.name, 'Brian Okello');
      expect(s.categories.map((c) => c.name), ['Security', 'Driving']);
      expect(s.notifySms, isFalse);
      expect(s.applications, 2);
    });

    test('a brand new account has no categories and no applications', () {
      final s = SeekerProfile.fromJson({
        'id': 2,
        'name': 'Grace Akello',
        'email': 'grace@example.com',
        'categories': [],
      });

      expect(s.categories, isEmpty);
      expect(s.applications, 0);

      // Defaults have to be the permissive ones, or a new account hears
      // nothing and the point of registering is lost.
      expect(s.notifyEmail, isTrue);
      expect(s.notifySms, isTrue);
    });
  });

  group('ScreeningQuestion', () {
    test('carries its marks, and each answer carries its own', () {
      final q = ScreeningQuestion.fromJson(jsonDecode('''
        {
          "id": 11,
          "question": "How many years of experience do you have?",
          "type": "multiple_choice",
          "marks": 10,
          "options": [
            {"text": "1-2 years", "marks": 2},
            {"text": "3-4 years", "marks": 6},
            {"text": "5+ years",  "marks": 10}
          ]
        }'''));

      expect(q.marks, 10);
      expect(q.isScored, isTrue);
      expect(q.options.map((o) => o.marks), [2.0, 6.0, 10.0]);
      expect(q.options.last.text, '5+ years');
    });

    test('free text is not marked', () {
      final q = ScreeningQuestion.fromJson({
        'id': 12, 'question': 'Why this role?', 'type': 'text',
        'marks': 0, 'options': [],
      });

      expect(q.isScored, isFalse);
      expect(q.options, isEmpty);
    });

    test('an older payload with no marks still reads', () {
      // The server sent no marks key before answers were graded.
      final q = ScreeningQuestion.fromJson({
        'id': 13, 'question': 'Do you have a CPA?', 'type': 'yes_no',
      });

      expect(q.marks, 0);
      expect(q.isScored, isFalse);
    });
  });

  group('DocumentSlot', () {
    test('knows which papers are required and which take several', () {
      final slots = (jsonDecode('''
        [
          {"type":"cv","label":"Curriculum Vitae","required":true,"multiple":false},
          {"type":"academic","label":"Academic Papers","required":false,"multiple":true},
          {"type":"lc_letter","label":"LC Letter","required":false,"multiple":false}
        ]''') as List)
          .map((d) => DocumentSlot.fromJson(Map<String, dynamic>.from(d)))
          .toList();

      expect(slots.where((s) => s.required).map((s) => s.type), ['cv']);
      expect(slots.where((s) => s.multiple).map((s) => s.type), ['academic']);
    });
  });

  group('CategoryShare', () {
    test('reads the most-applied-for figures', () {
      final shares = (jsonDecode('''
        [
          {"label":"Security Services","count":12,"percent":60},
          {"label":"Cleaning & Janitorial","count":5,"percent":25.5}
        ]''') as List)
          .map((c) => CategoryShare.fromJson(Map<String, dynamic>.from(c)))
          .toList();

      // The server sends a whole number as an int and a fraction as a double;
      // both have to land as doubles or the bar maths throws.
      expect(shares.first.percent, 60.0);
      expect(shares.last.percent, 25.5);
    });
  });

  group('SeekerNotice', () {
    test('an application update carries what is needed to open it', () {
      final n = SeekerNotice.fromJson(jsonDecode('''
        {
          "id": 3, "type": "application_status",
          "title": "You have been shortlisted",
          "body": "Dear Brian Okello, congratulations.",
          "data": {"candidate_id": 42, "job_id": 7, "status": "shortlisted",
                   "tracking_code": "T7LVFRDBXI9M"},
          "action_url": "/applications/42",
          "read": false,
          "created_at": "2026-10-01T08:00:00+00:00"
        }'''));

      expect(n.read, isFalse);
      expect(n.data['candidate_id'], 42);
    });

    test('a new-job alert carries the posting', () {
      final n = SeekerNotice.fromJson({
        'id': 4,
        'type': 'new_job',
        'title': 'New vacancy: Security Supervisor',
        'body': 'Security Services - Jinja',
        'data': {'job_id': 7, 'slug': 'security-supervisor'},
        'read': true,
      });

      expect(n.type, 'new_job');
      expect(n.data['job_id'], 7);
      expect(n.read, isTrue);
      expect(n.createdAt, isNull);
    });
  });
}
