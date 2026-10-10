import { describe, it, expect } from "vitest";
import { suggestName } from "../utils/filename.js";

describe("suggestName", () => {
  it("uses the shebang interpreter", () => {
    expect(suggestName("#!/usr/bin/env bash\necho hi")).toBe("script.sh");
    expect(suggestName("#!/usr/bin/python3\nprint(1)")).toBe("script.py");
    expect(suggestName("#!/usr/bin/env node\n")).toBe("script.js");
  });
  it("detects JSON, Markdown and HTML", () => {
    expect(suggestName('  {"a": 1}')).toBe("data.json");
    expect(suggestName("[1, 2]")).toBe("data.json");
    expect(suggestName("# Title\ntext")).toBe("notes.md");
    expect(suggestName("- item\n- item")).toBe("notes.md");
    expect(suggestName("<div>x</div>")).toBe("snippet.html");
  });
  it("falls back to snippet.txt", () => {
    expect(suggestName("just text")).toBe("snippet.txt");
    expect(suggestName("{not json")).toBe("snippet.txt");
    expect(suggestName("")).toBe("snippet.txt");
  });
});
