import {test} from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"  
import {execFileSync} from "node:child_process"



const src = readFileSync(new URL("../lua.js", import.meta.url),"utf8").replace(/^\.pragma library\n/, "")

const module = { exports: {} }
new Function("module", src)(module)
const Lua = module.exports

const HOSTILE = ["foot",'evil"); os.execute("touch /tmp/pwned"); --',"back\\slash\\","\u0000","\u007f","ünïcødé ✓","line\nbreak", "tab\there", "nul\u0000x", "del\u007f","]]==]] [[ long bracket" ]

function luaRoundTrip(literal) {
  for (const bin of ["lua", "luajit", "lua5.4", "lua5.1"]) {
    try {
      return execFileSync(bin, ["-e", "io.write(" + literal + ")"], { encoding: "utf8" })
    } catch (e) {
      if (e.code !== "ENOENT") throw e 
    }
  }
  return null                           
}

for (const s of HOSTILE) {
  test("quote is safe for " + JSON.stringify(s), () => {
    const q = Lua.quote(s)
    
    assert.ok(q.startsWith('"') && q.endsWith('"'))

    assert.doesNotMatch(q, /[\u0000-\u001f\u007f]/)

    const inner = q.slice(1, -1).replace(/\\./gs, "") 
    assert.ok(!inner.includes('"'), "unescaped quote in " + q)
    
    const back = luaRoundTrip(q)
    if (back !== null) assert.equal(back, s)
  })
}

test("ShaderUtility test",()=>{
  assert.equal(
    Lua.setScreenShader("/a/gray.glsl"),
    'hl.config({decoration = {screen_shader = "/a/gray.glsl"}})'
  )
  assert.equal(
    Lua.setScreenShader(""),
    'hl.config({decoration = {screen_shader = ""}})'
  )
  assert.equal(
    Lua.setScreenShader('/a/my"shader.glsl'),
    'hl.config({decoration = {screen_shader = "/a/my\\"shader.glsl"}})'
  )
})

test("Shader State parsing",()=>{
  assert.equal(Lua.screenShaderActive('{"str":"/a/gray.glsl"}'), true);
  assert.equal(Lua.screenShaderActive('{"str":"[[EMPTY]]"}'), false);
  assert.equal(Lua.screenShaderActive('{"str":42}'), false);
  assert.equal(Lua.screenShaderActive('{"str":null}'), false);
  assert.equal(Lua.screenShaderActive('{"other":"value"}'), false);
  assert.equal(Lua.screenShaderActive('{"str":""}'), false);
  assert.equal(Lua.screenShaderActive(""), false);
  assert.equal(Lua.screenShaderActive("not json"), false);
})

test("quote exact escapes", () => {
  assert.equal(Lua.quote(""), '""')
  assert.equal(Lua.quote("plain path/x.glsl"), '"plain path/x.glsl"')
  assert.equal(Lua.quote('a"b'), '"a\\"b"')
  assert.equal(Lua.quote("a\\b"), '"a\\\\b"')
  assert.equal(Lua.quote("\n"), '"\\010"')
  assert.equal(Lua.quote("\t"), '"\\009"')
  assert.equal(Lua.quote("\u007f"), '"\\127"')
  assert.equal(Lua.quote("ü✓"), '"ü✓"')
})

test("quote pads escapes so a following digit is not swallowed", () => {
  // "\0" + "12" must not become "\012" (newline) in Lua
  assert.equal(Lua.quote("\u000012"), '"\\00012"')
  const back = luaRoundTrip(Lua.quote("\u000012"))
  if (back !== null) assert.equal(back, "\u000012")
})

test("quote coerces non-strings", () => {
  assert.equal(Lua.quote(42), '"42"')
  assert.equal(Lua.quote(null), '"null"')
  assert.equal(Lua.quote(undefined), '"undefined"')
  assert.equal(Lua.quote(true), '"true"')
})

for (const s of HOSTILE) {
  test("setScreenShader runs as one hl.config call for " + JSON.stringify(s), () => {
    const out = luaRoundTrip(
      '(function() local n, r = 0; hl = { config = function(t) n = n + 1; r = t.decoration.screen_shader end }; '
      + Lua.setScreenShader(s) + '; assert(n == 1); return r end)()'
    )
    if (out !== null) assert.equal(out, s)
  })
}

test("setScreenShader output is a single line", () => {
  assert.doesNotMatch(Lua.setScreenShader("a\nb\r\nc"), /[\r\n]/)
})

test("screenShaderActive edge cases", () => {
  assert.equal(Lua.screenShaderActive('{"str":" "}'), true)
  assert.equal(Lua.screenShaderActive('{"str":"[[EMPTY]] "}'), true)
  assert.equal(Lua.screenShaderActive('{"str":"/a/gray.glsl","set":true}'), true)
  assert.equal(Lua.screenShaderActive('{"str":true}'), false)
  assert.equal(Lua.screenShaderActive('{"str":["/a/gray.glsl"]}'), false)
  assert.equal(Lua.screenShaderActive("[]"), false)
  assert.equal(Lua.screenShaderActive("42"), false)
  assert.equal(Lua.screenShaderActive("null"), false)
  assert.equal(Lua.screenShaderActive(undefined), false)
})

test("screenShaderActive warns only on unparseable output", (t) => {
  const warn = t.mock.method(console, "warn", () => {})
  Lua.screenShaderActive('{"str":"/a/gray.glsl"}')
  Lua.screenShaderActive('{"str":"[[EMPTY]]"}')
  assert.equal(warn.mock.callCount(), 0)
  Lua.screenShaderActive("not json")
  assert.equal(warn.mock.callCount(), 1)
  assert.equal(warn.mock.calls[0].arguments[1], "not json")
})

test("quote passes through emoji, C1 controls and single quotes", () => {
  for (const s of ["😀 path", "c1\u0085\u009f", "it's"]) {
    const q = Lua.quote(s)
    assert.equal(q, '"' + s + '"')
    const back = luaRoundTrip(q)
    if (back !== null) assert.equal(back, s)
  }
})

test("quote replaces a lone surrogate on the way to Lua", () => {
  assert.equal(Lua.quote("\uD800"), '"\uD800"')
  const back = luaRoundTrip(Lua.quote("\uD800"))
  if (back !== null) assert.equal(back, "�")
})

test("quote stringifies objects and arrays", () => {
  assert.equal(Lua.quote({}), '"[object Object]"')
  assert.equal(Lua.quote(["/a", "/b"]), '"/a,/b"')
})

test("screenShaderActive handles real hyprctl output", () => {
  assert.equal(Lua.screenShaderActive('{"option":"decoration:screen_shader","str":"/a/gray.glsl","set":true}\n'), true)
  assert.equal(Lua.screenShaderActive('{"option":"decoration:screen_shader","str":"[[EMPTY]]","set":false}\n'), false)
})

test("screenShaderActive rejects an object instead of text", () => {
  assert.equal(Lua.screenShaderActive({ str: "/a/gray.glsl" }), false)
})
