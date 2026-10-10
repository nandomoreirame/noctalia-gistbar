import { describe, it, expect } from "vitest";
import { search, counts } from "../utils/search.js";

const gists = [
  { id: "1", description: "Docker cleanup", public: true, updatedAt: "3", files: [{ name: "clean.sh", language: "Shell" }] },
  { id: "2", description: "Notas", public: false, updatedAt: "2", files: [{ name: "a.md", language: "Markdown" }] },
  { id: "3", description: "", public: true, updatedAt: "1", files: [{ name: "main.py", language: "Python" }] }
];
const contents = {
  "2": { files: [{ content: "rodar docker compose up" }] },
  "3": { files: [{ content: "print('ação')" }] }
};

describe("search", () => {
  it("returns everything in updatedAt order for an empty query", () => {
    expect(search(gists, contents, "", "all").map((g) => g.id)).toEqual(["1", "2", "3"]);
  });
  it("ranks description/name matches before content matches", () => {
    expect(search(gists, contents, "docker", "all").map((g) => g.id)).toEqual(["1", "2"]);
  });
  it("matches language and folded content", () => {
    expect(search(gists, contents, "python", "all").map((g) => g.id)).toEqual(["3"]);
    expect(search(gists, contents, "acao", "all").map((g) => g.id)).toEqual(["3"]);
  });
  it("applies the visibility filter", () => {
    expect(search(gists, contents, "docker", "secret").map((g) => g.id)).toEqual(["2"]);
    expect(search(gists, contents, "", "public").map((g) => g.id)).toEqual(["1", "3"]);
  });
});

describe("counts", () => {
  it("counts all, public and secret", () => {
    expect(counts(gists)).toEqual({ all: 3, public: 2, secret: 1 });
  });
});
