.pragma library

function displayName(fileName){
    const name = String(fileName)

    return (name.charAt(0).toUpperCase() + name.slice(1)).replace(/\.glsl$/, "")
}

if (typeof module !== "undefined") module.exports = {displayName }
