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

function setScreenShader(path){
    return 'hl.config({decoration = {screen_shader = ' + quote(path) + '}})'
}

function screenShaderActive(text){
    try {
        const str = JSON.parse(text).str
        return typeof str === "string" && str !== "" && str !== "[[EMPTY]]";
    } catch(e) {
        console.warn("widget.tint:bad hyprctl output:",text,e)
        return false
    }

}
if (typeof module !== "undefined") module.exports = {
    quote,
    setScreenShader,
    screenShaderActive
}