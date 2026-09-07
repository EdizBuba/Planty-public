import assert from "node:assert/strict";
import test from "node:test";
import {notificationMinute, parisMinute, runWhenEnabled} from "./schedule";

test("notification timing and midnight wrap", () => {
  assert.equal(notificationMinute("12:30", 30), 12 * 60);
  assert.equal(notificationMinute("00:10", 30), 23 * 60 + 40);
  assert.equal(notificationMinute("02:00", "120"), 0);
  assert.equal(notificationMinute("08:00", undefined), 7 * 60 + 30);
  assert.equal(notificationMinute("08:00", 0), 8 * 60);
});

test("malformed times and delays do not send notifications", () => {
  for (const time of [null, undefined, "", "24:00", "12:60", "9:00", "12:00extra", 1200]) {
    assert.equal(notificationMinute(time, 30), null);
  }
  for (const delay of ["", "30minutes", "-1", "1.5", -1, 1440, Infinity, NaN, false, {}, []]) {
    assert.equal(notificationMinute("12:00", delay), null);
  }
});

test("Paris time follows winter and summer offsets", () => {
  assert.equal(parisMinute(new Date("2026-01-15T12:30:00Z")), 13 * 60 + 30);
  assert.equal(parisMinute(new Date("2026-07-15T12:30:00Z")), 14 * 60 + 30);
  assert.equal(parisMinute(new Date("2026-07-15T22:00:00Z")), 0);
});

test("notifications disabled: callback is not invoked", async () => {
  await runWhenEnabled(false, async () => { assert.fail("No backend access expected"); });
});

test("explicit opt-in runs the task once", async () => {
  let calls = 0;
  await runWhenEnabled(true, async () => { calls += 1; });
  assert.equal(calls, 1);
});
