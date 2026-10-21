# SafeHer — Session Notes (2026-10-21)

Is session mein kya hua, aur aage kya karna hai. (Saved so the session can be compacted without losing context.)

---

## 1. Git / repo
- Branch: `feature/firebase-integration`, pushed to `hammadansar49-prog/women-safety-and-emergency-app`.
- Commits is session ke: Firebase deps + deny-all rules + cloud identity test (`5fe89b5`), firebase.json/gitignore cleanup (`b05ff4b`), background SOS trigger + Firebase Android wiring (`bf0193a`).
- **Un-committed** (is session ka UI redesign + auth flow + logout fix): abhi commit NAHI hua — issues fix hone ke baad commit karenge.

## 2. Firebase
- Android connect ho gaya: `lib/firebase_options.dart` (project `safeher-cfb5a`), `main.dart` init (Android-only guard; web local chalta hai), `google-services` gradle plugin, minSdk 23.
- **Rules abhi deny-all** (jaan-boojh kar). Real rules user ke saath baad mein — `backend-tests/rules.test.mjs` tab tak fail rahega (ye expected hai).
- Auth abhi **asli nahi** — simulate ho raha hai.

## 3. Background SOS trigger (Phase 1 — code done, device test baaki)
- `android/.../SosTriggerService.kt` — foreground service, MediaSession+VolumeProvider se locked/background mein volume-key pattern pakadta hai.
- `MainActivity.kt` channel methods, `sos_shortcut.dart` background arm/disarm, `main.dart` secret-cancel gesture.
- Volume-key trigger (power button Android par mumkin nahi). App-lock = SafeHer overlay (Device Admin nahi). Live location LAZMI continuous + "ended here" marker (Phase 2).

## 4. UI Redesign (tastemaker skill)
- Direction: **dark aurora-glass**, violet→magenta neon, Space Grotesk + Inter, full juicy motion.
- Contract locked: `.tastemaker/style-lock.md`, `.tastemaker/reference-board.md`.
- Naye files: `lib/theme/{tokens,app_theme}.dart`, `lib/ui/{aurora_background,glass,motion,sos_button}.dart`, `lib/auth_screens.dart`.
- Done screens: welcome (responsive, no-scroll FittedBox), home/SOS button (idle breath → countdown ring → active pulse), glass floating nav (bottom-fixed), username, login + register.
- `google_fonts` added.

## 5. Auth flow (local/simulated)
- welcome → login → register; Google → username screen → app. Logout ab username clear karta hai (`social.signOut()`), to re-login par purana naam reuse nahi hota.

## 6. Dev machine
- 8 GB RAM. C: drive ~12 GB saaf kiya (mostly `.gradle/caches`), ab ~18.6 GB free.
- **localhost chalane ka tareeqa:** `flutter build web --release` → `cd build/web; python -m http.server 8080 --bind 127.0.0.1`. User `http://127.0.0.1:8080` khole. **Hot reload nahi** — har change par rebuild (~100s) + browser refresh.

---

## ISSUES TO FIX NEXT (user ne list kiye — user ke kehne par hi karna)
1. **Login ("Welcome back") screen content center (mid) mein ho** — abhi left-aligned. (chhota UI fix: `lib/auth_screens.dart`)
2. **"Continue with Google"** par asli Google account-picker khule (sab logged-in accounts ki list), user chune — abhi seedha purane account mein le jaata hai. (needs real Google Sign-In)
3. **Login par asli validation** — galat username/password par error ("incorrect") dikhaye; jo account bana hi nahi usay andar na aane de. (abhi koi bhi creds se andar le jaata hai)
4. **Firebase proper:** har username **unique** (ek naam dobara use na ho — atomic Firestore reservation); password **salted hash** (same password → alag hash; plaintext kabhi nahi). Firebase Auth khud scrypt+salt karta hai.

> Issues 2, 3, 4 = ek hi kaam: asli Firebase Auth (email/password + Google) + Firestore username reservation + rules. Issue 1 alag chhota fix.

**Open decision (user se poochna):** login **username** se ho ya **email** se? (Firebase Auth email/password par chalta hai.)
