# QA checklist (phase 7)

Run on an Android emulator. Tick everything; fix and re-run `flutter analyze` after each fix.

## Offline / storage
- [ ] Turn on airplane mode: every screen still works.
- [ ] `pubspec.yaml` has no `http`/`dio`/firebase; `android/app/src/main/AndroidManifest.xml` has no `INTERNET` permission.
- [ ] Create data, kill the app from recents, relaunch: data is still there; app opens directly on Home (session kept).
- [ ] Photos still display after relaunch (only file names are stored, resolved against the documents directory).
- [ ] Deleting a vehicle/incident deletes its photo files from disk (no orphans).

## Authentication
- [ ] Wrong password → error message, stays on Login.
- [ ] Register a new account → back on Login with the email filled → login works.
- [ ] Forgot password resets the password locally; old password no longer works.
- [ ] Profile: edit name/email, change password (current password required); Drawer header updates.
- [ ] Users module: add, edit, delete another account; the last account cannot be deleted; deleting your own account logs you out.

## Navigation
- [ ] Cold start: Splash → Login (no session) or Home (session).
- [ ] Login success replaces Login (Back from Home exits the app, never returns to Login).
- [ ] Logout clears the whole stack; Back from Login does not reopen Home.
- [ ] Back on a non-Accueil bottom tab returns to Accueil first; Back on Accueil exits.
- [ ] Drawer: opens from the hamburger and by edge swipe; closes before navigating; every item opens its page and Back returns to Home.
- [ ] Every form/detail route receives its arguments; opening a route with missing/invalid arguments shows the error screen instead of crashing.
- [ ] After saving/deleting in a pushed screen, the previous list refreshes (pop result `true`).
- [ ] Cross-module links work: vehicle detail → "Louer" (vehicle preselected), → "Historique d'entretien", rental detail → "Déclarer un incident" (vehicle + rental preselected).
- [ ] Unknown route shows the Not found screen.
- [ ] Without a session, no protected route can be opened (guard sends to Login).

## Forms and validation
- [ ] Empty required fields show errors under each field; email format; password ≥ 6 chars.
- [ ] Duplicate email / immatriculation shows a friendly error.
- [ ] Date pickers prevent end date before start date.
- [ ] Overlapping rental on the same vehicle is refused with a clear message.
- [ ] Keyboard never hides the Save button (forms scroll).

## Quality
- [ ] No overflow stripes (RenderFlex) on a small phone size and in landscape.
- [ ] Empty lists show an empty state with a call to action.
- [ ] Destructive actions ask for confirmation.
- [ ] `flutter analyze` clean; no unused files; no TODOs left in code.
