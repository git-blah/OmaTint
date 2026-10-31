.pragma library

const TINT_TAG = "window_tint"

function tintTag(fileName){
    return fileName ? TINT_TAG + ":" + fileName : TINT_TAG
}

function quote(value){
    const s = String(value)
    let out = ""
    for (let i = 0; i < s.length; i++) {
        const ch = s[i];
        const code = s.charCodeAt(i);

        if (ch === "\\") {
        out += "\\\\";
        } else if (ch === '"') {
        out += '\\"';
        } else if (code < 32 || code === 127) {
        out += "\\" + ("00" + code).slice(-3);
        } else {
        out += ch;
        }
    }
    return '"' + out + '"';
}

function normalizeAddress(value){
    const str = String(value)
    if (str === "") return "";
    if (/^0x[0-9a-f]+$/i.test(str)) return str;
    if (/^[0-9a-f]+$/i.test(str)) return "0x" + str;
    return ""
}

function setScreenShader(path){
    return 'hl.config({decoration = {screen_shader = ' + quote(path) + '}})'
}

function parseScreenShaderActive(text){
    try {
        const str = JSON.parse(text)?.str
        return typeof str === "string" && str !== "" && str !== "[[EMPTY]]";
    } catch(e) {
        console.warn("omaTint: bad getoption output:", text, e.message)
        return false
    }

}

function setClassShader(appId,path){
    if(!path){
        return 'hl.plugin.HyprWindowShade.classshader(' + quote(appId)+',' + '"clear")'
    }
    return 'hl.plugin.HyprWindowShade.classshader(' + quote(appId)+',' + quote(path) + ')'
}

function tagWindow(address, fileName, on){
    const tags = [tintTag(fileName), "shader_fullscreen_stack:1"]
    
    return(tags.map((tag)=>('hl.dispatch(hl.dsp.window.tag({ tag = ' + quote((on?'+':'-') + tag) + ', window = ' + quote("address:" + address) + '}))')).join(" "))
}

function parseTintedWindows(text){
    let tinted = {}
    try{
        const windows = JSON.parse(text)
        if(!Array.isArray(windows)) return {}
        for (const win of windows){
            if(!Array.isArray(win?.tags)) continue
            for (const tag of win.tags){
                if(typeof tag !== "string" || tag.endsWith("*")) continue
                if(tag === TINT_TAG) tinted[win.address] = ""
                else if(tag.startsWith(TINT_TAG + ":")) tinted[win.address] = tag.slice(TINT_TAG.length + 1)
            }
        }
        return tinted

    } catch(err){
        console.warn("omaTint: bad clients output:", text, err.message)
        return {}
    }
}

function setWindowShader(address, path){

return [
    "do", 
        "local back = hl.get_active_window()",
        "local cursor = hl.get_cursor_pos()",
        `hl.dispatch(hl.dsp.focus({ window = ${quote("address:" + address)}}))`,
        "local now = hl.get_active_window()",      
        `if now and now.address == ${quote(address)}`, 
        "then",
            "local shade = hl.plugin.HyprWindowShade",
            "shade.togglewindowshader(\"clear\")",
            path ? `shade.togglewindowshader(${quote(path)})` : "",
        "end",        
        "if back", 
        "then", 
            "hl.dispatch(hl.dsp.focus({ window = \"address:\" .. back.address }))",
            "hl.dispatch(hl.dsp.cursor.move({ x = cursor.x, y = cursor.y }))", 
        "end",
    "end"
    ].join(" ")
}

function parseWindowShadeLoaded(text){
    try {
        const plugins = JSON.parse(text)
        
        if(!Array.isArray(plugins)) return false 
        
        return (
            plugins.some((p)=>p?.name==="HyprWindowShade")
        )
        
    } catch (error) {
        console.warn("omaTint: bad plugin list output:", text, error.message)
        return false
    }

}

if (typeof module !== "undefined") module.exports = {
    TINT_TAG,
    quote,
    normalizeAddress,
    setScreenShader,
    parseScreenShaderActive,
    setClassShader,
    parseWindowShadeLoaded,
    setWindowShader,
    tagWindow,
    parseTintedWindows
}