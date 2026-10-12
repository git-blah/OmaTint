import { test } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"

const src = readFileSync(new URL("../shader.js", import.meta.url), "utf8").replace(/^\.pragma library\n/, "")
const module = { exports: {} }
new Function("module", src)(module)
const Shader = module.exports

test("define goes right after #version", () => {
  const out = Shader.withIntensity("#version 320 es\nvoid main(){}\n", 0.5)
  assert.equal(out, "#version 320 es\n#define INTENSITY 0.500\nvoid main(){}\n")
})

test("intensity is clamped", () => {
  assert.match(Shader.withIntensity("#version 320 es\n", -1), /INTENSITY 0\.000/)
  assert.match(Shader.withIntensity("#version 320 es\n", 2), /INTENSITY 1\.000/)
})

test("no #version -> define at top", () => {
  assert.ok(Shader.withIntensity("void main(){}", 1).startsWith("#define INTENSITY 1.000\n"))
})

test("displayName", () => {
  assert.equal(Shader.displayName("nightlight.glsl"), "nightlight")
})
