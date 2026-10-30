import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(
  new URL("../shader.js", import.meta.url),
  "utf8",
).replace(/^\.pragma library\n/, "");
const module = { exports: {} };
new Function("module", src)(module);
const Shader = module.exports;

test("displayName", () => {
  assert.equal(Shader.displayName("nightlight.glsl"), "Nightlight");
});
