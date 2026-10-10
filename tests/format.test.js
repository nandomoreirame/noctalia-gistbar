import { describe, it, expect } from "vitest";
import { relative } from "../utils/format.js";

const NOW = Date.parse("2026-10-10T12:00:00Z");

describe("relative", () => {
  it("returns an i18n key and n", () => {
    expect(relative("2026-10-10T11:59:40Z", NOW)).toEqual({ key: "time.now", n: 0 });
    expect(relative("2026-10-10T11:15:00Z", NOW)).toEqual({ key: "time.minutes", n: 45 });
    expect(relative("2026-10-10T07:00:00Z", NOW)).toEqual({ key: "time.hours", n: 5 });
    expect(relative("2026-10-01T12:00:00Z", NOW)).toEqual({ key: "time.days", n: 9 });
  });
});
