import { describe, it, expect } from "vitest";
import { plan, createQueue, enqueue, nextJobs, finish } from "../utils/cachesync.js";

const list = [{ id: "a", updatedAt: "2" }, { id: "b", updatedAt: "1" }, { id: "c", updatedAt: "5" }];

describe("plan", () => {
  it("fetches missing or changed entries and drops unlisted ones", () => {
    const cached = { a: "2", b: "0", z: "9" };
    expect(plan(list, cached)).toEqual({ fetch: ["b", "c"], drop: ["z"] });
  });
});

describe("queue", () => {
  it("runs at most two jobs and dedupes ids", () => {
    let q = enqueue(createQueue(), ["a", "b", "c", "a"]);
    const r = nextJobs(q, 2);
    expect(r.start).toEqual(["a", "b"]);
    q = r.queue;
    expect(nextJobs(q, 2).start).toEqual([]);
    q = finish(q, "a");
    expect(nextJobs(q, 2).start).toEqual(["c"]);
  });
  it("does not re-enqueue a running id", () => {
    let q = nextJobs(enqueue(createQueue(), ["a"]), 2).queue;
    q = enqueue(q, ["a"]);
    expect(q.pending).toEqual([]);
  });
});
