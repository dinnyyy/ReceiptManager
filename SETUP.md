# Setup guide

This app is a native iPhone app (not a website), so there's no server to
"host" and no link that just opens in a browser. Getting it in front of a
tester takes two phases:

- **Part 1** - a one-time technical setup, done once by whoever is
  comfortable with Xcode (probably you, the founder reading this first).
  This produces a build on Apple's **TestFlight** service.
- **Part 2** - what a tester with zero technical background does: install
  the free **TestFlight** app from the App Store, tap an invite link, and
  use the app. That's it - no Xcode, no code, no terminal.

If you're setting this up for the first time, read Part 1. Once a
TestFlight build exists, send your tester only the **Part 2** section
(or just this file - it's short).

---

## Why you can't just "run it somewhere" and share a link

A website can be hosted on a server and opened from any browser. An iPhone
app can't - it has to be *installed* on each person's phone, either:

1. **Through TestFlight** (Apple's official beta system) - the only
   practical way to get it onto someone else's iPhone remotely, or
2. **Cabled directly to a Mac** - works for one device you have physically
   in hand, expires after 7 days, and cannot use "Sign in with Apple" (a
   free Apple ID's "Personal Team" isn't allowed that capability). Not a
   real option for a remote tester.

Running the app in Xcode's Simulator, or on a rented Mac (e.g. MacInCloud),
only shows it on that Mac's own screen. A tester would only see it if they
were remotely viewing that exact Mac session with you - not by opening
anything on their own phone. So renting a Mac to *build* on is fine (see
Part 1); it doesn't change how the *tester* gets the app, which is always
TestFlight.

**Cost**: TestFlight requires an Apple Developer Program membership,
currently **US$99/year**. There is no free way around this for getting a
real build onto someone else's iPhone.

---

## Part 1 - One-time setup (technical)

**Shortcut for a first "just let him look at it" build**: the app
currently runs in a local-only mode (no sign-in, no Supabase project
needed - see `README.md`) that works fine for a TestFlight build too. You
can skip step 5 (Supabase) entirely for your very first upload if you just
want your partner poking around the UI; come back and do it once you want
his test data actually backed up / synced.

### 1. Get a Mac with Xcode

Xcode only runs on macOS. If you don't own a Mac, a rental service like
MacInCloud works fine for this step - everything below runs the same way.

Install **Xcode** from the Mac App Store (free, several GB, start the
download early).

### 2. Enrol in the Apple Developer Program

Go to [developer.apple.com/programs](https://developer.apple.com/programs/)
and enrol (~US$99/year). You need this for two things: the "Sign in with
Apple" capability, and TestFlight distribution. This can take up to 48
hours for Apple to approve, so do it first.

### 3. Install command-line tools

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install xcodegen
```

### 4. Get the code

```
git clone https://github.com/dinnyyy/ReceiptManager.git
cd ReceiptManager
git checkout main
```

### 5. Set up the backend (Supabase, free tier)

1. Create a free project at [supabase.com](https://supabase.com).
2. In the dashboard, open **SQL Editor** and run every file in
   `supabase/migrations/` in order (they're numbered by filename).
   Then run `supabase/seed/seed.sql` if you want demo data.
3. Deploy the account-deletion function (needs the
   [Supabase CLI](https://supabase.com/docs/guides/cli)):
   `supabase functions deploy delete-account`.
4. From Settings -> API, copy the **Project URL** and **anon public key**.

### 6. Configure the app with your Supabase details

Edit `Config/Secrets.xcconfig` (already exists in the repo with placeholder
values - just replace them) and paste in the URL and anon key from step 5.

You'll also need to switch `ReceiptVaultApp.swift` from
`AppEnvironment.localOnly()` to `AppEnvironment.live()` - it's a one-line
change at the top of that file, currently set to local-only so the app can
be built and tested without any backend at all.

### 7. Generate and open the Xcode project

```
xcodegen generate
open ReceiptVault.xcodeproj
```

### 8. Fix the first build

This codebase was written without access to a Mac/Xcode, so **this is its
first real compile**. Expect small, mechanical errors (a Supabase SDK
method name, a SwiftUI API detail) rather than deep bugs - the business
logic itself has an independent test suite. `CLAUDE.md` section 4a in the
repo lists exactly where to look first. Budget real but bounded time here.

### 9. Add the Sign in with Apple capability

In Xcode: select the `ReceiptVault` target -> **Signing & Capabilities**
-> set your Team (from step 2) -> **+ Capability** -> add
"Sign in with Apple". Also register the App ID / capability in the
[Apple Developer portal](https://developer.apple.com/account) if Xcode
doesn't do it automatically.

### 10. Archive and upload to TestFlight

In Xcode: **Product -> Archive** (pick "Any iOS Device" as the build
target first, not a simulator). Once archived, the Organizer window opens
- click **Distribute App -> TestFlight & App Store**, and follow the
prompts. First upload can take a few minutes to process on Apple's side.

### 11. Invite your tester

In [App Store Connect](https://appstoreconnect.apple.com) -> your app ->
**TestFlight** tab -> add your business partner's email as an **internal**
or **external** tester (internal is instant; external needs one quick
Apple review, usually under a day for the first build). They'll get an
email invite.

---

## Part 2 - For your tester (no technical background needed)

1. Check email for a **TestFlight invite** from App Store Connect.
2. On your iPhone, install **TestFlight** from the App Store (free, made
   by Apple).
3. Open the invite email on your iPhone and tap **View in TestFlight**
   (or **Redeem**, if it's a code).
4. Tap **Install**. The app appears on your home screen like any other app.
5. Use it normally - scan a receipt, try search, generate an export, etc.
6. **To give feedback**: inside TestFlight, open this app's entry and tap
   **Send Beta Feedback** - you can attach a screenshot and a note
   directly from there, and it goes straight back to the developer. You
   can also just message/email the founder directly if that's easier.

New builds show up automatically as updates inside TestFlight - no need
to reinstall anything each time.
