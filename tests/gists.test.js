import { describe, it, expect } from "vitest";
import { readFileSync } from "node:fs";
import { parseList, parseDetail, title, prepend, remove } from "../utils/gists.js";

const read = (f) => readFileSync(new URL(`./fixtures/${f}`, import.meta.url), "utf8");

describe("parseList", () => {
  it("flattens slurped pages, normalizes and sorts by updatedAt desc", () => {
    const r = parseList(read("gists-list.json"));
    expect(r.ok).toBe(true);
    expect(r.gists.map((g) => g.id)).toEqual(["ccc333", "aaa111", "bbb222"]);
    expect(r.gists[0]).toEqual({
      id: "ccc333", url: "https://gist.github.com/u/ccc333", description: "", public: true,
      updatedAt: "2026-10-05T08:00:00Z",
      files: [{ name: "main.py", language: "Python", size: 40 }, { name: "README.md", language: "Markdown", size: 30 }]
    });
    expect(r.gists[2].public).toBe(false);
  });
  it("accepts a single page and refuses garbage", () => {
    expect(parseList(JSON.stringify([{ id: "x", files: {}, updated_at: "2026-01-01T00:00:00Z" }])).gists.length).toBe(1);
    expect(parseList("not json")).toEqual({ ok: false, error: "parse" });
    expect(parseList("{}")).toEqual({ ok: false, error: "parse" });
  });
});

describe("parseDetail", () => {
  it("keeps file contents for the cache", () => {
    const r = parseDetail(read("gist-detail.json"));
    expect(r.ok).toBe(true);
    expect(r.entry.id).toBe("ccc333");
    expect(r.entry.updatedAt).toBe("2026-10-05T08:00:00Z");
    expect(r.entry.files[1]).toEqual({ name: "README.md", language: "Markdown", content: "# Ação rápida\n\nImprime o cwd.\n", truncated: false });
  });
});

describe("helpers", () => {
  const g = (id, d, files = [{ name: "a.txt" }]) => ({ id, description: d, files });
  it("titles by description, else first file name", () => {
    expect(title(g("1", "Docker"))).toBe("Docker");
    expect(title(g("1", "", [{ name: "main.py" }]))).toBe("main.py");
  });
  it("prepends a created gist without duplicates and removes by id", () => {
    const list = [g("1", "a"), g("2", "b")];
    expect(prepend(list, g("2", "b2")).map((x) => x.id + x.description)).toEqual(["2b2", "1a"]);
    expect(remove(list, "1").map((x) => x.id)).toEqual(["2"]);
  });
});
