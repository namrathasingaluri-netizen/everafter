# Set up and curate EverAfter with Codex

This guide uses Codex on a Mac to inspect the repository, register private trip
media, run the gallery editor, validate the Flutter project, and prepare an
iPhone build. Follow [`IOS_SETUP.md`](IOS_SETUP.md) for the underlying manual
workflow and Apple-specific details.

Codex can run commands and edit the local checkout, but it cannot complete
Apple account prompts, trust a development certificate for you, or prove that
an NFC automation works without a physical scan. Keep the iPhone connected,
unlocked, and available for those steps.

## 1. Prepare the Mac and open the project

Install the prerequisites in [the iPhone setup guide](IOS_SETUP.md#2-prepare-the-mac),
then install and sign in to the
[ChatGPT desktop app](https://learn.chatgpt.com/docs/app). Choose **Codex**, open
the cloned `everafter` folder, and use a local environment so commands run
against the Mac checkout and its connected devices. OpenAI documents local
projects and worktrees in
[Local environments](https://learn.chatgpt.com/docs/environments/local-environment).

A local environment describes where Codex runs commands; it is not a promise
that selected file content never leaves the computer. Only give Codex access to
personal media that you are comfortable using under your OpenAI account or
workspace data controls.

Start with an inspection-only request:

```text
Read README.md, docs/IOS_SETUP.md, and docs/PRIVATE_MEDIA.md. Inspect the current
Git status and the Flutter/Xcode toolchain. Do not edit, delete, stage, commit,
or push anything. Preserve existing changes and private media. Tell me what is
ready and what I must complete manually before installing EverAfter on iPhone.
```

Codex should check at least:

```sh
git status --short
flutter doctor -v
xcodebuild -version
flutter devices
```

Resolve Xcode licensing, Apple ID, signing-team, trust, and Developer Mode
prompts yourself before asking Codex to continue.

## 2. Ask Codex to prepare the iPhone build

Choose the NFC path from [`IOS_SETUP.md`](IOS_SETUP.md#1-choose-the-iphone-nfc-mode):

- a free Personal Team uses an iOS Shortcuts NFC automation;
- a paid Apple Developer team can use EverAfter's foreground Core NFC scanner.

For a free Personal Team, use this request:

```text
Prepare and install EverAfter on my connected iPhone using the free Personal
Team Shortcuts workflow in docs/IOS_SETUP.md. Preserve all private media,
existing trip data, and unrelated working-tree changes. Do not change or commit
public signing configuration. Stop if I need to choose a team or approve a
prompt in Xcode. Run the documented install helper only after the prerequisites
are ready, and report the exact deep link you verified. Do not claim NFC is
verified until I scan the physical magnet.
```

For a paid team, replace “free Personal Team Shortcuts workflow” with “paid-team
Core NFC workflow.” Codex may prepare the build and run repository checks, but
you still need to confirm the signing capability and scan a real tag.

## 3. Register private gallery media

First copy your original photos, videos, and video posters into the ignored
local tree described in
[`IOS_SETUP.md`](IOS_SETUP.md#6-add-private-photos-and-videos). Keep an untouched
backup outside the repository.

Then give Codex a narrow request for one destination at a time:

```text
Register the media already present under assets/memories/japan/ for the Japan
gallery. Do not rename, move, recompress, or delete any media. Preserve the
current display order unless a filename list makes the intended order clear.
Update only the required private asset declarations and Japan collection data.
Do not stage, commit, or push. Verify every registered path exists and report
videos that are missing poster images.
```

Review the resulting changes to `pubspec.yaml` and the matching
`lib/data/*_memory_collection.dart` file. Repeat with a destination-specific
prompt rather than asking Codex to rewrite all collections at once.

## 4. Curate the gallery layout

Ask Codex to start the browser editor without changing the layout itself:

```text
Start the local gallery admin exactly as documented in docs/IOS_SETUP.md. Do
not edit gallery_layouts.json. Tell me the local admin URL and leave the server
running while I arrange the gallery.
```

Open <http://127.0.0.1:8080/admin/gallery>, arrange the dates, frames, crops,
trinkets, and wall geometry, then choose **Save global** and replace
`assets/data/gallery_layouts.json`.

After saving, ask Codex to review the artifact:

```text
Inspect only the gallery layout changes I just saved. Validate the JSON, confirm
that every referenced bundled asset exists, and summarize changes by trip. Do
not rewrite the layout, alter private media, stage, commit, or push anything.
```

To make a device-only adjustment instead, open `everafter:///admin/gallery` on
the iPhone and use **Save this device**. That override remains in the iPhone's
local application preferences and is not written back to the repository.

## 5. Validate, install, and test the real workflow

Once you have reviewed the changes, ask Codex to run the documented checks and
prepare the matching iPhone build:

```text
Validate this curated EverAfter checkout using docs/IOS_SETUP.md. Preserve all
existing and private content. Run formatting only on files changed for this
curation, then run Flutter analysis, tests, and the unsigned iOS release build.
If those pass, install using the NFC workflow already selected for this iPhone.
Do not commit or push. Separate build and deep-link evidence from anything that
still requires a physical iPhone or magnet test.
```

On the iPhone, verify every item in
[`Verify a curated build`](IOS_SETUP.md#8-verify-a-curated-build). In particular,
scan each physical magnet and confirm it opens the intended trip. A passing
build or a manually opened deep link does not verify the NFC automation.

## 6. Review the privacy and Git boundary

Before any commit, ask Codex for a read-only publication review:

```text
Review this working tree against docs/PRIVATE_MEDIA.md. Do not stage, commit, or
push. Show which files are public-safe, which must remain local-only, and any
private media, dates, NFC identifiers, signing values, or absolute paths that
could enter a commit. Treat existing unrelated changes as user-owned.
```

Check the boundary yourself as well:

```sh
git status --short --ignored
git add -n .
git diff --check
```

Do not ask Codex to commit or push until you have inspected the exact diff. A
private iPhone build can include ignored media and local asset declarations
without publishing them to the public repository.
