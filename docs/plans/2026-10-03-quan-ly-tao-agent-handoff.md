# Handoff prompt for Codex, Claude Code, or Antigravity

Copy the following prompt into an agent working in this repository:

```text
Implement docs/plans/2026-10-03-quan-ly-tao-implementation.md.

Read the entire plan and all applicable AGENTS.md instructions first. Confirmed
product decisions are in section 2; do not ask the user to repeat them. This is
an existing Flutter repository, not a standalone mockup request. Deliver the
backend, database, Android/iOS user app, Android collector app, offline sync,
widgets, and operational documentation described in the plan.

Implement T01–T22 in dependency order without running tests or verification
builds. Prepare test code along the way, then run all checks in final T23.
Android device tests use my physical phone connected over USB; iOS tests use
the iOS Simulator on macOS. Do not substitute an Android emulator. Subagents
are not required. Record implementation progress separately from actual final
verification evidence in docs/implementation-status.md. Preserve
unrelated user changes. Record justified technical deviations in docs/decisions.md.

Remove the Linux desktop application only after extracting shared code, tools,
tests, and signing references. Do not delete keystores or .env files. Do not
reset the cloud database or drop the public schema. Build the fresh qlt schema
and an isolated test environment. Never put secrets in mobile artifacts, Git,
or logs.

Route using the full owner account, not a suffix hint or a counterparty account.
Supported banks are BIDV, VietinBank, Vietcombank, and Techcombank. MB is excluded.
Use exact registered bank/account matching. Missing actual bank fixtures must
be documented and the corresponding live parser gated; do not invent payloads
or report unverified bank support as complete.

Accept/discard must hard-delete the pending inbox event while content-free
receipts prevent replay. Acceptance still creates a ledger transaction for
reports. Dismissal has the exact durable three-second undo behavior in the plan.
Do not promise five-minute background refresh. Simulator tests do not prove
real-device WidgetKit scheduling reliability.

If macOS is unavailable, complete independent work, iOS project source, and the
Simulator runbook. State exactly which commands still require macOS; do not
mark iOS tested. Missing access or fixtures blocks only dependent tasks.

Keep plan/documentation in English. Preserve the Vietnamese application name,
UI labels, and default category/tag names specified by the plan.

At handoff, report completed and incomplete tasks, actual test results, user
and collector APK paths, backend/Supabase setup instructions, iOS Simulator
instructions, and remaining fixture/device-verification requirements. Do not
stop at scaffold or fake screens. Do not deploy to production beyond the
permissions already granted in the execution session.
```

When continuing work in another agent session, append:

```text
Read docs/implementation-status.md, inspect current code and test state, and
continue the first incomplete task. Do not repeat completed tasks without a
failure or new evidence. The plan does not replace inspection of the actual
repository state.
```


## One-line start instruction

> Implement `docs/plans/2026-10-03-quan-ly-tao-implementation.md` task by task; complete T01–T22 before running any tests, then execute final T23 using my USB-connected Android phone and the iOS Simulator, track progress in `docs/implementation-status.md`, and preserve all confirmed requirements and unrelated files.
