# Avatar popup and customizable shortcut

User-requested changes: animate the profile circle on press and show photo actions in a centered dialog; add customizable hardware-button settings.

Photo flow preserves upload/change/remove behavior and stored data. Use a short scale animation respecting reduced-motion settings, centered AlertDialog and Cancel.

Shortcut scope: save Volume Up/Volume Down preference; native Android Activity detects two short releases within 600ms only while resumed, focused and unlocked. Default off. A test must succeed in the current app session before enabling. Test never emits SOS; actual shortcut starts the existing guarded countdown. Changing keys resets verification. Logout disables it. Browser offers preference selection and explicitly labels native testing unavailable. Power/background/locked-phone shortcuts and background permission setup remain unimplemented.

Validation: Dart analysis, channel test for test/enable/change behavior, profile/logout and theme regressions; web build and browser inspection. Android compile attempt hit Windows DartWorker resource failure before Kotlin app verification. No physical Android device is connected, so hardware operation is not verified.
