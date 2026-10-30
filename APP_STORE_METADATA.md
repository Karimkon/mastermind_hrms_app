# 2.3.3 Accurate Metadata — what to put

Guideline 2.3.3 covers two things: the **screenshots** and the **description**.
Both must show what the app actually does.

The wording Apple uses most often is:

> Screenshots should show the app in use, and not merely the title art, login
> page, or splash screen.

Both evidence files Apple attached to this rejection were login screens. If the
screenshots on the listing are also login or splash screens, that is the
rejection, and it is a ten-minute fix.

---

## IMPORTANT: capture screenshots with the demo account

Sign in as `appreview@mastermind.autos` (credentials in
`APP_REVIEW_CREDENTIALS.txt`) before taking any screenshot.

That account has **no client, no payslips and no team**, so nothing you capture
contains a real employee's name, salary, or phone number. Screenshots on a
public App Store listing are published to the world — a screenshot taken from
Brenda's account would expose real staff records for 610 people.

---

## Six screenshots, in this order

Lead with what the app is for. The first two are the ones most people ever see.

| # | Screen | Route | Why this one |
|---|--------|-------|--------------|
| 1 | Clock in / attendance | `/attendance` | The thing the app is actually for. Shows the location check in use. |
| 2 | Dashboard | `/dashboard` | Proves there is a real app behind the login. |
| 3 | Apply for leave | `/leaves` | A complete, recognisable task. |
| 4 | Payslips | `/my-payslips` | Demo account shows the empty state — that is fine and honest. |
| 5 | Careers / job board | `/careers` | This is what the app OPENS on. If no screenshot shows it, the listing does not match the app. |
| 6 | Appraisal or training | `/appraisals` or `/training` | Shows depth beyond clocking in. |

**Do not include:** the login screen, the splash screen, the logo on its own,
or any screen showing another person's data.

---

## Captions

Short, factual, and true of the app. Nothing here claims a feature that does
not exist.

1. Clock in and out at your work site
2. Your attendance, leave and payslips in one place
3. Apply for leave and track approval
4. Payslips, available as soon as payroll is approved
5. Browse and apply for vacancies
6. Appraisals, goals and training records

---

## Description

Must describe only what the app does. Anything aspirational is a 2.3.1 problem.

```
Mastermind HRMS is the staff app for Mastermind Consult Ltd.

Clock in and out at your work site, with your location recorded so your
attendance can be confirmed. Apply for leave and follow it through approval.
Read your payslips as soon as payroll is approved. Keep up with appraisals,
goals, training and company documents.

Looking for work instead? Browse current vacancies, apply, and track your
application from the same app — no staff account needed.

FOR MASTERMIND STAFF
- Clock in and out at client sites and at head office
- Apply for leave and see where a request has reached
- Payslips, appraisals, goals, training and meetings
- Company documents and announcements

FOR JOB SEEKERS
- Browse vacancies by category
- Apply and upload a CV
- Track your application

Location is used only when you clock in or out, to confirm you were at the
work site. It is never collected while the app is closed.

Support: https://mastermindconsults.co.ug/support
Privacy: https://mastermindconsults.co.ug/privacy
```

---

## Before you submit, check every one of these

- [ ] New IPA built — the Support screen and the e-mail placeholder fix only
      exist in source until you rebuild
- [ ] Sign-In Information replaced with the careers demo account
      (see `APP_REVIEW_CREDENTIALS.txt`)
- [ ] Notes field filled in, explaining the two sign-ins
- [ ] App Information → Support URL → `https://mastermindconsults.co.ug/support`
- [ ] App Information → Privacy Policy URL → `https://mastermindconsults.co.ug/privacy`
- [ ] Screenshots replaced, none of them a login screen
- [ ] Screenshots taken on the demo account, no real staff data visible
- [ ] Description updated
- [ ] App Privacy answers declare Location, collected and linked to the user,
      used for App Functionality

App Store Connect shows the exact screenshot sizes it wants in the Media
Manager; take them at whatever it lists for iPhone and let it scale the rest.
