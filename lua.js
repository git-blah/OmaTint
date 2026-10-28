.pragma library

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

function hyprAddress(value){
    const str = String(value)
    if (str === "") return "";
    if (/^0x[0-9a-f]+$/i.test(str)) return str;
    if (/^[0-9a-f]+$/i.test(str)) return "0x" + str;
    return ""
}

function setScreenShader(path){
    return 'hl.config({decoration = {screen_shader = ' + quote(path) + '}})'
}

function screenShaderActive(text){
    try {
        const str = JSON.parse(text)?.str
        return typeof str === "string" && str !== "" && str !== "[[EMPTY]]";
    } catch(e) {
        console.warn("widget.tint:bad hyprctl output:",text,e.message)
        return false
    }

}

function setClassShader(appId,path){
    if(!path){
        return 'hl.plugin.HyprWindowShade.classshader(' + quote(appId)+',' + '"clear")'
    }
    return 'hl.plugin.HyprWindowShade.classshader(' + quote(appId)+',' + quote(path) + ')'
}

function tagWindow(address, on){
    const tags = ["widget.tint", "shader_fullscreen_stack:1"]
    
    return(tags.map((tag)=>('hl.dispatch(hl.dsp.window.tag({ tag = ' + quote((on?'+':'-') + tag) + ', window = ' + quote("address:" + address) + '}))')).join(" "))
}

function windowsMarked(text){
    let marked = {}
    try{
        const windows = JSON.parse(text)
        if(!Array.isArray(windows)) return {}
        for (const win of windows){
            if(Array.isArray(win?.tags) && win.tags.includes("widget.tint")){
                marked[win.address] = true
            }
        }
        return marked

    } catch(err){
        console.warn("widget.tint: error in marked windowsTags", text, err.message)
        return {}
    }
}

function setWindowShader(addr, path){

return [
    "do", 
        "local back = hl.get_active_window()",
        `hl.dispatch(hl.dsp.focus({ window = ${quote("address:"+addr)}}))`,
        "local now = hl.get_active_window()",      
        `if now and now.address == ${quote(addr)}`, 
        "then",
            "local shade = hl.plugin.HyprWindowShade",
            "shade.togglewindowshader(\"clear\")",
            path ? `shade.togglewindowshader(${quote(path)})` : "",
        "end",        
        "if back", 
        "then hl.dispatch(hl.dsp.focus({ window = \"address:\" .. back.address }))", 
        "end",
    "end"
    ].join(" ")
}

function windowShadeLoaded(text){
    try {
        const plugins = JSON.parse(text)
        
        if(!Array.isArray(plugins)) return false 
        
        return (
            plugins.some((p)=>p?.name==="HyprWindowShade")
        )
        
    } catch (error) {
        console.warn("widget.tint: bad input in windowShadeLoaded",text,error.message)
        return false
    }

}

function notifyChanged(){
    return ('hl.dispatch(hl.dsp.event("widget.tint"))')
}

if (typeof module !== "undefined") module.exports = {
    quote,
    hyprAddress,
    setScreenShader,
    screenShaderActive,
    setClassShader,
    windowShadeLoaded,
    setWindowShader,
    tagWindow,
    windowsMarked,
    notifyChanged
}