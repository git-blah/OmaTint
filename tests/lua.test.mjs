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