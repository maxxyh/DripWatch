# Engineering process and learnings

These are durable process lessons from introducing cloud sync into an existing local-first iOS
app. Apply them to future work rather than repeating the discovery cost.

## Start from the actual repository contract

- Read `AGENTS.md` completely before acting; `CLAUDE.md` points to the same canonical file.
- Inspect the current worktree and preserve unrelated/untracked user files.
- Compare an inherited plan against current code, SDK constraints, and failure modes before
  implementing it. A plausible plan is not evidence that its concurrency or migration behavior
  is safe.

## Design around interruption and the only-copy problem

- Mobile processes die, networks fail, and sideloaded builds are replaced. Pending writes must be
  durable, not an in-memory dirty set.
- Acknowledgement needs a generation/token; otherwise an old response can clear a newer edit.
- Serialize sync cycles and revalidate local state after every `await`. A snapshot taken before
  network I/O is stale by definition.
- Explicitly distinguish an existing installation from a fresh install. When local data may be
  the only copy, seed/push before pulling server state.
- Prefer idempotent operations: stable UUIDs, upserts, and content-addressed objects make retries
  routine instead of dangerous.

## Verify boundaries, not just units

- Pin dependencies and commit their lockfiles. Select a version compatible with the repository's
  actual Xcode/Swift toolchain, not merely the newest release.
- Verify generated artifacts. Here, build settings showed Supabase values while the generated
  Info.plist omitted them; only inspecting the built plist and observing zero network traffic
  exposed the problem.
- Test the real migration path on the real device when safe. Simulator sample data cannot prove
  that an existing phone store survives and seeds correctly.
- Verify external state directly: table/policy/bucket counts, row/object integrity, logs, and
  platform advisors. “Request returned success” is not end-to-end proof.
- Keep pure tests fast and deterministic, but supplement them with proportional integration and
  operational checks. Record known harness limitations instead of normalizing unexplained hangs.

## Use independent review for complex stateful work

An independent high-effort review caught three issues after the first implementation: a pull race
that could overwrite a concurrent local edit, missing foreground refresh, and a faulty timestamp
test. The useful pattern is:

1. Ask the reviewer for concrete, severity-ranked findings with file/line references.
2. Require explicit assessment of data loss, bootstrap direction, concurrency, pagination,
   security, and object integrity.
3. Fix findings, rerun focused verification, then inspect the final diff again.

Review should challenge the architecture, not just style.

## Make security decisions explicit

- A publishable key is not a secret; RLS is the authorization boundary.
- “No auth” means public shared access to anyone with client configuration. Document that plainly,
  constrain grants, prohibit hard delete, and identify the milestone that requires auth.
- Protect conflict mechanisms from hostile or broken clocks. Last-writer-wins without timestamp
  bounds can be permanently captured by one far-future write.
- Cloud replication and backups solve different problems. A backup plan needs separate database
  dumps, object copies, retention, and a tested restore path.

## Finish work as an operational handoff

Before declaring a change complete:

1. Build and run relevant tests.
2. Exercise the user path and inspect runtime diagnostics.
3. Verify any changed external system directly.
4. Run security/performance advisors where applicable.
5. Review staged scope and keep secrets/unrelated files out.
6. Update `AGENTS.md` and relevant `docs/` pages in the same work.
7. Commit with an intentional message and report remaining operational steps honestly.

Documentation is part of the implementation. If code, deployed state, and guidance disagree, the
work is not finished.
