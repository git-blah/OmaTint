import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

const src = readFileSync(new URL("../lua.js", import.meta.url), "utf8").replace(
  /^\.pragma library\n/,
  "",
);

const module = { exports: {} };
new Function("module", src)(module);
const Lua = module.exports;

const HOSTILE = [
  "foot",
  'evil"); os.execute("touch /tmp/pwned"); --',
  "back\\slash\\",
  "\u0000",
  "\u007f",
  "ünïcødé ✓",
  "line\nbreak",
  "tab\there",
  "nul\u0000x",
  "del\u007f",
  "]]==]] [[ long bracket",
];

function luaRoundTrip(literal) {
  for (const bin of ["lua", "luajit", "lua5.4", "lua5.1"]) {
    try {
      return execFileSync(bin, ["-e", "io.write(" + literal + ")"], {
        encoding: "utf8",
      });
    } catch (e) {
      if (e.code !== "ENOENT") throw e;
    }
  }
  return null;
}

function fakeHyprland(active, alive) {
  return (
    "local active, calls = " +
    Lua.quote(active) +
    ", {}; " +
    "local alive = {}; for _, a in ipairs({" +
    alive.map(Lua.quote).join(",") +
    "}) do alive[a] = true end; " +
    "hl = { " +
    "  get_active_window = function() return active and { address = active } or nil end, " +
    "  get_cursor_pos = function() return { x = 1, y = 2 } end, " +
    "  dsp = { focus = function(t) return t.window end, " +
    '    cursor = { move = function(t) return "cursor:" .. t.x .. "," .. t.y end } }, ' +
    '  dispatch = function(sel) local a = sel:match("^address:(.*)$"); if a and alive[a] then active = a end end, ' +
    "  plugin = { HyprWindowShade = { togglewindowshader = function(p) calls[#calls + 1] = p end } } " +
    "}; "
  );
}

function runTag(address, on) {
  return luaRoundTrip(
    "(function() local got = {};" +
      "hl = { dsp = { window = { tag = function(t) return t end } }, " +
      ' dispatch = function(t) got[#got + 1] = t.tag .. "@" .. t.window end }; ' +
      Lua.tagWindow(address, on) +
      ' return table.concat(got,"|") end)()',
  );
}

for (const s of HOSTILE) {
  test("quote is safe for " + JSON.stringify(s), () => {
    const q = Lua.quote(s);

    assert.ok(q.startsWith('"') && q.endsWith('"'));
    assert.doesNotMatch(q, /[\u0000-\u001f\u007f]/);

    const inner = q.slice(1, -1).replace(/\\./gs, "");
    assert.ok(!inner.includes('"'), "unescaped quote in " + q);

    const back = luaRoundTrip(q);
    if (back !== null) assert.equal(back, s);
  });
}

test("setScreenShader exact output", () => {
  assert.equal(
    Lua.setScreenShader("/a/gray.glsl"),
    'hl.config({decoration = {screen_shader = "/a/gray.glsl"}})',
  );
  assert.equal(
    Lua.setScreenShader(""),
    'hl.config({decoration = {screen_shader = ""}})',
  );
  assert.equal(
    Lua.setScreenShader('/a/my"shader.glsl'),
    'hl.config({decoration = {screen_shader = "/a/my\\"shader.glsl"}})',
  );
});

test("parseScreenShaderActive basic cases", () => {
  assert.equal(Lua.parseScreenShaderActive('{"str":"/a/gray.glsl"}'), true);
  assert.equal(Lua.parseScreenShaderActive('{"str":"[[EMPTY]]"}'), false);
  assert.equal(Lua.parseScreenShaderActive('{"str":42}'), false);
  assert.equal(Lua.parseScreenShaderActive('{"str":null}'), false);
  assert.equal(Lua.parseScreenShaderActive('{"other":"value"}'), false);
  assert.equal(Lua.parseScreenShaderActive('{"str":""}'), false);
  assert.equal(Lua.parseScreenShaderActive(""), false);
  assert.equal(Lua.parseScreenShaderActive("not json"), false);
});

test("quote exact escapes", () => {
  assert.equal(Lua.quote(""), '""');
  assert.equal(Lua.quote("plain path/x.glsl"), '"plain path/x.glsl"');
  assert.equal(Lua.quote('a"b'), '"a\\"b"');
  assert.equal(Lua.quote("a\\b"), '"a\\\\b"');
  assert.equal(Lua.quote("\n"), '"\\010"');
  assert.equal(Lua.quote("\t"), '"\\009"');
  assert.equal(Lua.quote("\u007f"), '"\\127"');
  assert.equal(Lua.quote("ü✓"), '"ü✓"');
});

test("quote pads escapes so a following digit is not swallowed", () => {
  // "\0" + "12" must not become "\012" (newline) in Lua
  assert.equal(Lua.quote("\u000012"), '"\\00012"');
  const back = luaRoundTrip(Lua.quote("\u000012"));
  if (back !== null) assert.equal(back, "\u000012");
});

test("quote coerces non-strings", () => {
  assert.equal(Lua.quote(42), '"42"');
  assert.equal(Lua.quote(null), '"null"');
  assert.equal(Lua.quote(undefined), '"undefined"');
  assert.equal(Lua.quote(true), '"true"');
});

for (const s of HOSTILE) {
  test(
    "setScreenShader runs as one hl.config call for " + JSON.stringify(s),
    () => {
      const out = luaRoundTrip(
        "(function() local n, r = 0; hl = { config = function(t) n = n + 1; r = t.decoration.screen_shader end }; " +
          Lua.setScreenShader(s) +
          "; assert(n == 1); return r end)()",
      );
      if (out !== null) assert.equal(out, s);
    },
  );
}

test("setScreenShader output is a single line", () => {
  assert.doesNotMatch(Lua.setScreenShader("a\nb\r\nc"), /[\r\n]/);
});

test("parseScreenShaderActive edge cases", (t) => {
  const warn = t.mock.method(console, "warn", () => {});
  assert.equal(Lua.parseScreenShaderActive('{"str":" "}'), true);
  assert.equal(Lua.parseScreenShaderActive('{"str":"[[EMPTY]] "}'), true);
  assert.equal(
    Lua.parseScreenShaderActive('{"str":"/a/gray.glsl","set":true}'),
    true,
  );
  assert.equal(Lua.parseScreenShaderActive('{"str":true}'), false);
  assert.equal(Lua.parseScreenShaderActive('{"str":["/a/gray.glsl"]}'), false);
  assert.equal(Lua.parseScreenShaderActive("[]"), false);
  assert.equal(Lua.parseScreenShaderActive("42"), false);
  assert.equal(Lua.parseScreenShaderActive("null"), false);
  assert.equal(Lua.parseScreenShaderActive(undefined), false);
});

test("parseScreenShaderActive warns only on unparseable output", (t) => {
  const warn = t.mock.method(console, "warn", () => {});
  Lua.parseScreenShaderActive('{"str":"/a/gray.glsl"}');
  Lua.parseScreenShaderActive('{"str":"[[EMPTY]]"}');
  assert.equal(warn.mock.callCount(), 0);
  Lua.parseScreenShaderActive("not json");
  assert.equal(warn.mock.callCount(), 1);
  assert.equal(warn.mock.calls[0].arguments[1], "not json");
});

test("quote passes through emoji, C1 controls and single quotes", () => {
  for (const s of ["😀 path", "c1\u0085\u009f", "it's"]) {
    const q = Lua.quote(s);
    assert.equal(q, '"' + s + '"');
    const back = luaRoundTrip(q);
    if (back !== null) assert.equal(back, s);
  }
});

test("quote replaces a lone surrogate on the way to Lua", () => {
  assert.equal(Lua.quote("\uD800"), '"\uD800"');
  const back = luaRoundTrip(Lua.quote("\uD800"));
  if (back !== null) assert.equal(back, "�");
});

test("quote stringifies objects and arrays", () => {
  assert.equal(Lua.quote({}), '"[object Object]"');
  assert.equal(Lua.quote(["/a", "/b"]), '"/a,/b"');
});

test("parseScreenShaderActive handles real hyprctl output", () => {
  assert.equal(
    Lua.parseScreenShaderActive(
      '{"option":"decoration:screen_shader","str":"/a/gray.glsl","set":true}\n',
    ),
    true,
  );
  assert.equal(
    Lua.parseScreenShaderActive(
      '{"option":"decoration:screen_shader","str":"[[EMPTY]]","set":false}\n',
    ),
    false,
  );
});

test("parseScreenShaderActive rejects an object instead of text", () => {
  assert.equal(Lua.parseScreenShaderActive({ str: "/a/gray.glsl" }), false);
});

const parseWindowShadeLoadedCases = [
  ['[{"name":"HyprWindowShade"}]', true],
  ["", false],
  ["[]", false],
  ['[{"name":"someOtherPlugin"}]', false],
  ['[null,{"name":"HyprWindowShade"}]', true],
  ["not json", false],
  ["{}", false],
  ["null", false],
];
for (const [input, expected] of parseWindowShadeLoadedCases) {
  test("parseWindowShadeLoaded(" + JSON.stringify(input) + ")", (t) => {
    t.mock.method(console, "warn", () => {});
    assert.equal(Lua.parseWindowShadeLoaded(input), expected);
  });
}

test("setClassShader exact output", () => {
  assert.equal(
    Lua.setClassShader("foot", "/a/g.glsl"),
    'hl.plugin.HyprWindowShade.classshader("foot","/a/g.glsl")',
  );
  assert.equal(
    Lua.setClassShader("foot", ""),
    'hl.plugin.HyprWindowShade.classshader("foot","clear")',
  );
  assert.equal(
    Lua.setClassShader("foot", null),
    'hl.plugin.HyprWindowShade.classshader("foot","clear")',
  );
  assert.equal(
    Lua.setClassShader("foot", undefined),
    'hl.plugin.HyprWindowShade.classshader("foot","clear")',
  );
});

for (const s of HOSTILE) {
  test("setClassShader runs for appId " + JSON.stringify(s), () => {
    const out = luaRoundTrip(
      "(function() local n, r = 0; hl = { plugin = { HyprWindowShade = { classshader = function(id, path) n=n+1; r = id end } } }; " +
        Lua.setClassShader(s, "/a/g.glsl") +
        "; assert(n == 1); return r end)()",
    );
    if (out !== null) assert.equal(out, s);
  });
  test("setClassShader runs for path " + JSON.stringify(s), () => {
    const out = luaRoundTrip(
      "(function() local n, r = 0; hl = { plugin = { HyprWindowShade = { classshader = function(id, path) n=n+1; r = path end } } }; " +
        Lua.setClassShader("foot", s) +
        "; assert(n == 1); return r end)()",
    );
    if (out !== null) assert.equal(out, s);
  });
}

test('setClassShader runs for path "clear"', () => {
  const out = luaRoundTrip(
    "(function() local n, r = 0; hl = { plugin = { HyprWindowShade = { classshader = function(id, path) n=n+1; r = path end } } }; " +
      Lua.setClassShader("foot", "") +
      "; assert(n == 1); return r end)()",
  );
  if (out !== null) assert.equal(out, "clear");
});

test("setWindowShader does nothing when the target window is gone", () => {
  const out = luaRoundTrip(
    "(function() " +
      fakeHyprland("0x1", ["0x1"]) +
      Lua.setWindowShader("0x2", "/a/g.glsl") +
      ' return table.concat(calls, "|") .. "#" .. active end)()',
  );
  if (out !== null) assert.equal(out, "#0x1");
});

test("setWindowShader turns a present window on and refocuses", () => {
  const out = luaRoundTrip(
    `(function()` +
      fakeHyprland("0x1", ["0x1", "0x2"]) +
      Lua.setWindowShader("0x2", "/a/g.glsl") +
      ` return table.concat(calls, "|") .. "#" .. active end)()`,
  );
  if (out !== null) assert.equal(out, "clear|/a/g.glsl#0x1");
});

test("setWindowShader turns a present window off and refocuses", () => {
  const out = luaRoundTrip(
    `(function()` +
      fakeHyprland("0x1", ["0x1", "0x2"]) +
      Lua.setWindowShader("0x2", "") +
      ` return table.concat(calls, "|") .. "#" .. active end)()`,
  );
  if (out !== null) assert.equal(out, "clear#0x1");
});

for (const s of HOSTILE) {
  test("setWindowShader handles hostile address " + JSON.stringify(s), () => {
    const out = luaRoundTrip(
      `(function()` +
        fakeHyprland("0x1", ["0x1", s]) +
        Lua.setWindowShader(s, "/a/g.glsl") +
        ` return table.concat(calls, "|") .. "#" .. active end)()`,
    );
    if (out !== null) assert.equal(out, "clear|/a/g.glsl#0x1");
  });
}

for (const s of HOSTILE) {
  test("setWindowShader handles hostile path " + JSON.stringify(s), () => {
    const out = luaRoundTrip(
      `(function()` +
        fakeHyprland("0x1", ["0x1", "0x2"]) +
        Lua.setWindowShader("0x2", s) +
        ` return calls[2] end)()`,
    );
    if (out !== null) assert.equal(out, s);
  });
}

const normalizeAddressCases = [
  ["", ""],
  ["563e8f5eae30", "0x563e8f5eae30"],
  ["0x563e8f5eae30", "0x563e8f5eae30"],
  ["ABC", "0xABC"],
  ["xyz", ""],
  ["null", ""],
  ["0x", ""],
];

for (const [s, ans] of normalizeAddressCases) {
  test("normalizeAddress " + JSON.stringify(s), () => {
    assert.equal(Lua.normalizeAddress(s), ans);
  });
}

test("tagWindow adds both tags", () => {
  assert.equal(
    runTag("0x2", true),
    "+window_tint@address:0x2|+shader_fullscreen_stack:1@address:0x2",
  );
});
test("tagWindow removes both tags", () => {
  assert.equal(
    runTag("0x2", false),
    "-window_tint@address:0x2|-shader_fullscreen_stack:1@address:0x2",
  );
});

for (const s of HOSTILE) {
  test("tagWindow handles hostile address " + JSON.stringify(s), () => {
    assert.equal(
      runTag(s, true),
      "+window_tint@address:" + s + "|+shader_fullscreen_stack:1@address:" + s,
    );
  });
}

const parseTintedWindowsCases = [
  ['[{"address":"0x1","tags":["window_tint"]}]', { "0x1": true }],
  ['[{"address":"0x1","tags":["default-opacity*"]}]', {}],
  ['[{"address":"0x1","tags":["window_tint*"]}]', {}],
  [
    '[{"address":"0x1","tags":["window_tint"]},{"address":"0x2","tags":[]}]',
    { "0x1": true },
  ],
  ["[]", {}],
  ["not json", {}],
  ['[{"address":"0x1"}]', {}],
];

for (const [windows, ans] of parseTintedWindowsCases) {
  test("parseTintedWindows(" + JSON.stringify(windows) + ")", () => {
    assert.deepEqual(Lua.parseTintedWindows(windows), ans);
  });
}
