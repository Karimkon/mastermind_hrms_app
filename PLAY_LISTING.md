# Play Console submission — Mastermind HRMS

Everything the console will ask for, drafted from what the app actually does.
Kept in the repo so the answers change when the app does, rather than being
re-invented at each release.

Package: `com.mastermind.consultants.hrms`
Version at time of writing: **1.3.0 (17)**

---

## 1. Store listing

### App name (max 30)

```
Mastermind HRMS
```

### Short description (max 80)

```
Attendance, payslips and HR approvals for Mastermind Consult staff.
```

*66 characters.*

### Full description (max 4000)

```
Mastermind HRMS is the staff app for Mastermind Consult Limited, a human
resources consultancy in Uganda. It is used by our employees and by the teams we
manage on client sites.

You need an account issued by your HR team to sign in. Accounts are not created
in the app.

WHAT YOU CAN DO

Attendance
Clock in and out for the day, or for a site visit, and see your own attendance
history. Your location is recorded at the moment you tap so that attendance can
be confirmed against the site you are assigned to.

Payslips
Open and download your payslips as PDFs, and see how your pay was made up —
basic, allowances, PAYE and NSSF.

Leave
Request leave, check what you have left, and track whether a request has been
approved.

Appraisals
Read your appraisal, add your own comments and sign it off. Managers and
appraisers can score, confirm and return appraisal cards.

Onboarding
Work through your joining checklist and tick items off as you complete them.

For HR, payroll and management
Approve leave and overtime, move payroll through HR, Finance and MD approval,
record who worked a public holiday, maintain shifts, salary grades and salary
components, and manage the public holiday calendar.

PERMISSIONS

Location — recorded only when you tap to clock in, clock out, or start and end a
site visit. The app never collects your location in the background or while it is
closed.

Photos — used only if you choose a profile picture.

PRIVACY

Your data is held by Mastermind Consult Limited and is not shared with any third
party. The app contains no advertising and no analytics or tracking software.
Read the full policy at https://mastermind.autos/privacy

SUPPORT

Contact your HR team, or email info@mastermind.autos
```

### Graphics still needed

| Asset | Spec | Notes |
| --- | --- | --- |
| App icon | 512 × 512 PNG, 32-bit, no alpha | The launcher icon already in the app can be exported at this size |
| Feature graphic | 1024 × 500 PNG or JPG | No transparency. Shown at the top of the listing |
| Phone screenshots | 2 minimum, 8 maximum, 16:9 or 9:16, 320–3840 px | Suggested: dashboard, clock-in, payslip, appraisal, leave |
| Tablet screenshots | Only if tablet support is declared | The app runs on tablets; omit the declaration if you do not want to supply these |

### Category and contact

- **App category:** Business
- **Tags:** leave the defaults
- **Email:** `info@mastermind.autos`
- **Website:** `https://mastermind.autos`
- **Privacy policy:** `https://mastermind.autos/privacy` *(live, verified)*

---

## 2. App access

**This is the one that fails reviews.** The whole app is behind a login, and a
reviewer who cannot sign in will reject it without reading further.

Select **All or some functionality is restricted** and provide:

- Username: a dedicated demo account, e.g. `playreview@mastermind.autos`
- Password: set one and record it here when created
- Instructions: *"Sign in with the email and password above. The account has an
  employee role with sample attendance, payslip and leave data."*

Create the account with a real role and harmless data. Do **not** give a reviewer
a live HR admin login — it can see 906 real employees' salaries.

---

## 3. Data safety

No analytics, no crash reporting, no advertising and no third-party SDKs that
receive user data. Everything goes to `https://mastermind.autos` and nowhere
else, which makes most of this form short.

### Does your app collect or share any of the required user data types?

**Yes.**

### Is all of the user data collected by your app encrypted in transit?

**Yes.** The API base URL is `https://mastermind.autos/api` — TLS on every call.

### Do you provide a way for users to request that their data is deleted?

**Yes — via a web request.** Point it at `https://mastermind.autos/privacy`.

> Note: Play's account-deletion requirement applies to apps that let users
> *create* accounts. This one does not — HR provisions them — so the in-app
> deletion path is not strictly required. Reviewers still ask, so the policy page
> needs to state plainly how an employee requests deletion and who to contact.
> Check that it does before submitting.

### Data types to declare

| Category | Type | Collected | Shared | Purpose | Optional? |
| --- | --- | --- | --- | --- | --- |
| Location | **Precise location** | Yes | No | App functionality | Required |
| Personal info | **Name** | Yes | No | App functionality, Account management | Required |
| Personal info | **Email address** | Yes | No | App functionality, Account management | Required |
| Personal info | **User IDs** | Yes | No | App functionality, Account management | Required |
| Photos and videos | **Photos** | Yes | No | App functionality | Optional |
| Files and docs | **Files and docs** | Yes | No | App functionality | Optional |
| Financial info | **Other financial info** | Yes | No | App functionality | Required |

**Where each comes from:**

- **Precise location** — `attendance/clock-in`, `attendance/clock-out`,
  `office-attendance/*`, `am-visits/clock-in`, `am-visits/clock-out`. Captured at
  the moment of the tap only. Mark as **Required**, because clocking in is the
  point of the feature.
- **Name, Email address** — sign-in and `PUT /profile`.
- **User IDs** — the employee number and user id the app sends with requests.
- **Photos** — `POST /profile/avatar`, only if somebody sets a profile picture.
  **Optional**, since the app works without one.
- **Files and docs** — employee document upload via the file picker. **Optional**
  for the same reason.
- **Other financial info** — HR and payroll users enter salary figures: grades,
  salary components, amounts. That is transmitted, so it is collected.

**Deliberately not declared, and why:**

- **Payslip contents.** The app *displays* payroll data received from the server;
  it does not send it. Play defines collection as data transmitted off the
  device. (Salary data entered by HR *is* declared, above.)
- **Device or other IDs.** No advertising ID, no device identifier is read or
  sent.
- **Crash logs / diagnostics.** No crash reporting or analytics SDK is present —
  verified against `pubspec.yaml`.
- **Approximate location.** `ACCESS_COARSE_LOCATION` is declared because Android
  requires it alongside fine location; the app only ever requests a high-accuracy
  fix. Declaring precise location alone is the accurate answer.

> **Password:** not listed above. Play has no password data type and credentials
> used solely to authenticate are generally not declared. If in doubt, declaring
> it under *Personal info → Other info* is the conservative choice and costs
> nothing.

---

## 4. Content rating

Run the IARC questionnaire. For a business tool the honest answers are "no" to
every content question — no violence, no sexual content, no gambling, no user-to-
user communication that is unmoderated. Expected result: **Everyone / PEGI 3**.

The app does let staff and managers exchange comments on appraisals and leave
requests. That is workplace correspondence between named colleagues inside one
company, not open user-generated content, so the social-features question is
answered **no**. Be ready to explain that if asked.

---

## 5. Target audience and content

- **Target age group:** 18 and over
- **Appeal to children:** No
- **Ads:** No

---

## 6. Other declarations

| Declaration | Answer |
| --- | --- |
| Contains ads | No |
| In-app purchases | No |
| Government app | No |
| Financial features | **No** — the app shows payslips and records approvals. It does not move money, process payments, lend, or handle transactions |
| News app | No |
| COVID-19 contact tracing | No |
| Data safety — third-party sharing | None |

---

## 7. Before you upload

- [ ] **Developer verification** — account-level, due **30 September 2026**.
      Applies to every app under Ehsan Developers.
- [ ] Confirm whether the developer account is **organisation** or **personal**.
      A personal account created after November 2023 needs **12 testers for 14
      continuous days** before the production track opens. Organisation accounts
      are exempt. This is a two-week gate worth discovering now.
- [ ] Enrol in **Play App Signing** when creating the app. The existing
      `android/mastermind-release.jks` becomes the upload key.
- [ ] Decide the track. **Production** gives a public listing anyone can install
      — reasonable here, since the app is login-gated and 906 staff on personal
      phones would otherwise need a closed-testing list maintained by hand.
- [ ] Install the APK on one real phone and walk clock-in, a payslip and an
      appraisal. Nothing in 1.3.0 has run on hardware.

---

## 8. Release notes for 1.3.0

```
Appraisals, holiday pay, onboarding checklists, improvement plans, shifts,
salary structure and the public holiday calendar are now all in the app.

Payroll approval now follows the same three stages as the web system — HR,
Finance, then MD — so the app shows only the stage that is actually yours to
approve.
```
