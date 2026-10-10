import { describe, it, expect } from "vitest";
import { listArgs, detailArgs, createArgs, patchArgs, patchBody, deleteArgs, createdId, classify } from "../utils/gh.js";

describe("argv", () => {
  it("builds list, detail and delete commands", () => {
    expect(listArgs()).toEqual(["gh", "api", "gists?per_page=100", "--paginate", "--slurp"]);
    expect(detailArgs("abc")).toEqual(["gh", "api", "gists/abc"]);
    expect(deleteArgs("abc")).toEqual(["gh", "gist", "delete", "abc", "--yes"]);
  });
  it("reads create content from stdin and is secret unless asked", () => {
    expect(createArgs("a.sh", "desc", false)).toEqual(["gh", "gist", "create", "--filename", "a.sh", "--desc", "desc", "-"]);
    expect(createArgs("a.sh", "", true)).toEqual(["gh", "gist", "create", "--filename", "a.sh", "--desc", "", "--public", "-"]);
  });
  it("refuses ids that are not hex-like", () => {
    expect(() => detailArgs("../x")).toThrow();
    expect(() => patchArgs("a b")).toThrow();
  });
  it("patches through stdin with a JSON body", () => {
    expect(patchArgs("abc")).toEqual(["gh", "api", "--method", "PATCH", "gists/abc", "--input", "-"]);
    expect(JSON.parse(patchBody("d", "main.py", "x=1"))).toEqual({ description: "d", files: { "main.py": { content: "x=1" } } });
  });
});

describe("results", () => {
  it("extracts the id from the created gist URL", () => {
    expect(createdId("https://gist.github.com/u/0123abcd\n")).toBe("0123abcd");
    expect(createdId("oops")).toBe("");
  });
  it("classifies failures", () => {
    expect(classify(0, "")).toBe("");
    expect(classify(4, "To get started with GitHub CLI, please run:  gh auth login")).toBe("gh-login");
    expect(classify(1, "HTTP 401: Bad credentials")).toBe("gh-login");
    expect(classify(127, "")).toBe("gh-missing");
    expect(classify(1, "error connecting to api.github.com")).toBe("network");
    expect(classify(1, "HTTP 422")).toBe("failed");
  });
});
