# Profile and appearance

User-requested design: avatar opens a separate Profile route with saved username, Google email status and logout. Settings remains on the Settings tab with SOS countdown and appearance. Default ThemeMode.system follows platform brightness (including OS schedules); explicit Light/Dark override it. Do not infer appearance from time of day.

Implementation: keep theme state above MaterialApp so every route updates, supply a dark color scheme, replace fixed low-contrast text/banner colors, and separate profile navigation from settings. Logout returns the local session to onboarding and is disabled during an SOS so the owner keeps access to emergency controls. No Google auth/email/sign-out is fabricated; Firebase remains a separate integration. Settings choices and local account data are session-only.

Validation: widget tests for profile navigation, username/email status, logout, OS brightness changes, and manual overrides; full regression suite, analyzer, web build and browser screenshots.
