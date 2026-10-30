.pragma library

function displayName(fileName){
    var string = fileName.charAt(0).toUpperCase() + fileName.slice(1)
    
    return String(string).replace(/\.glsl$/, "")
}

if (typeof module !== "undefined") module.exports = {displayName }
