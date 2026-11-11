# Qualification boundaries

Experimental v0.1.0 candidate; relocated qualification is not yet complete.
No public repository/tag/release or Slyx pin has been published by this tree.

The historical integrated Slyx kit source was
`833d6ecead540fcd1dbd1d2da88985cff0552387` (2026-11-10).
Its four workloads were minimal menu, frequently updated HUD, large collection,
and screen/resource switches, on/off instrumentation, three fresh processes per
variant, warmup10/samples30. Required cycle/memory/handle comparisons under the
separately accepted B1-A1 scope were 132/132 PASS. Cold/teardown timing remained
diagnostic: 72 observations, 11 exceeding the old reference. Original B1 remains
193/204 PASS, 11 FAIL, **not** a successful latency guarantee. Cleanup/no-replay
correctness remains blocking, independent of diagnostic timing.

These results do not qualify this relocated tree or its updated codecs. All
applicable integrated tests, six physically restricted closures, native selected
fixtures, allocation-failure walks, G01–G21/C01–C08/Lab and tools gates, ru/en,
resize/scale/critical-state display cases and all four workloads must be rerun
before a final claim. Inspect real PNG separately. Agent display runs require an
explicitly selected whole verified ISD with linux-abstract-v1, own run/input/PNG,
explicit focus and stop in finally. No desktop fallback.

F8 retains app-owned model, explicit ownership/lifetime, fallible prepare before
commit, historical-reader nonauthority, fail-closed action/snapshot and explicit
recovery without replay. Partial/excluded APIs remain experimental. No physical
gamepad, WCAG, IME/bidi/shaping, other-platform or native/GPU heap guarantee.

Historical public source report (not a prerequisite for building):
https://github.com/atilla777/slyx/blob/833d6ecead540fcd1dbd1d2da88985cff0552387/docs/ui-kit/qualification.md
Private raw logs/screenshots/session data are not included here.
