.pragma library

function displayName(fileName){
    return String(fileName).replace(/\.glsl$/, "")
}

if (typeof module !== "undefined") module.exports = {displayName }
