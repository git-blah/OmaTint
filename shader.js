.pragma library

function clamp(v){
    let n = Number(v)
    return isNaN(n) ? 1 : Math.max(0, Math.min(1,n))

}

function withIntensity(src,value){
    const define = "#define INTENSITY " + clamp(value).toFixed(3) + "\n"
    const m = /^[ \t]*#version[^\n]*\n/m.exec(src)
    if (!m) return define + src
    const end = m.index + m[0].length
    return src.slice(0, end) + define + src.slice(end)
}

function displayName(fileName){
    return String(fileName).replace(/\.glsl$/, "")
}

if (typeof module !== "undefined") module.exports = { withIntensity, displayName }
