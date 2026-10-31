import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "lua.js" as Lua

Item {
    id: root

    property var shell: null
    property bool screenTintOn: false
    property int shaderIndex: 0
    property var evalQueue: []
    property var tintedWindows: ({
    })
    property bool windowShadeLoaded: false
    readonly property alias shaderList: shaderList
    readonly property string selectedShaderFile: shaderList.count > 0 ? shaderList.get(shaderIndex % shaderList.count, "fileName") : ""
    readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl("."))).replace(/^file:\/\//, "").replace(/\/$/, "")
    readonly property string selectedShaderPath: shaderPath(selectedShaderFile)
    readonly property var runningWindows: {
        ToplevelManager.toplevels.values;
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const address = Lua.normalizeAddress(t.address);
            if (address === "")
                continue;

            const title = t.title;
            const ipc = t.lastIpcObject || {
            };
            const appId = (t.wayland && t.wayland.appId) || ipc.class || "";
            const icon = iconForAppId(appId);
            out.push({
                "address": address,
                "title": title,
                "appId": appId,
                "icon": icon
            });
        }
        return out;
    }

    function resolveIcon(value) {
        const v = String(value || "");
        if (v === "")
            return "";

        if (v.startsWith("file://") || v.startsWith("image://"))
            return v;

        if (v.startsWith("/"))
            return "file://" + v;

        return Quickshell.iconPath(v, true);
    }

    function iconForAppId(appId) {
        const id = String(appId || "");
        if (id !== "") {
            const entry = DesktopEntries.heuristicLookup(id);
            const fromEntry = entry ? resolveIcon(entry.icon) : "";
            if (fromEntry !== "")
                return fromEntry;

            const direct = Quickshell.iconPath(id, true);
            if (direct !== "")
                return direct;

        }
        return Quickshell.iconPath("application-x-executable", true);
    }

    function selectShader(i) {
        if (shaderList.count === 0)
            return ;

        root.shaderIndex = (i + shaderList.count) % shaderList.count;
        root.applyScreenTint();
    }

    function shaderPath(fileName) {
        return fileName ? root.pluginDir + "/shaders/" + fileName : "";
    }

    function toggleScreenTint() {
        root.screenTintOn = !root.screenTintOn;
        if (root.screenTintOn)
            root.applyScreenTint();
        else
            root.setScreenShader("");
    }

    function applyScreenTint() {
        if (!root.screenTintOn || root.selectedShaderPath === "")
            return ;

        root.setScreenShader(root.selectedShaderPath);
    }

    function setScreenShader(path) {
        root.queueEval(Lua.setScreenShader(path));
    }

    function queueEval(code) {
        root.evalQueue.push(code);
        root.runNextEval();
    }

    function runNextEval() {
        if (evalProc.running || root.evalQueue.length === 0)
            return ;

        evalProc.command = ["hyprctl", "eval", root.evalQueue.shift()];
        evalProc.running = true;
    }

    function refreshState() {
        root.rerun(screenShaderProc);
        root.rerun(pluginListProc);
        root.rerun(clientsProc);
    }

    function setWindowTint(address, fileName) {
        const wasTinted = address in root.tintedWindows;
        let code = Lua.setWindowShader(address, root.shaderPath(fileName));
        if (wasTinted)
            code += " " + Lua.tagWindow(address, root.tintedWindows[address], false);

        if (fileName)
            code += " " + Lua.tagWindow(address, fileName, true);

        root.queueEval(code);
        const obj = Object.assign({
        }, root.tintedWindows);
        if (fileName)
            obj[address] = fileName;
        else
            delete obj[address];
        root.tintedWindows = obj;
    }

    function toggleWindowTint(address) {
        if (!root.windowShadeLoaded || root.selectedShaderFile === "")
            return ;

        if (root.screenTintOn)
            return ;

        const same = address in root.tintedWindows && root.tintedWindows[address] === root.selectedShaderFile;
        root.setWindowTint(address, same ? "" : root.selectedShaderFile);
    }

    function clearWindowTints() {
        const addresses = Object.keys(root.tintedWindows);
        if (addresses.length === 0 || root.screenTintOn)
            return ;

        root.queueEval(addresses.map((address) => {
            return Lua.setWindowShader(address, "") + " " + Lua.tagWindow(address, root.tintedWindows[address], false);
        }).join(" "));
        root.tintedWindows = ({
        });
    }

    function rerun(proc) {
        if (proc.running)
            proc.again = true;
        else
            proc.running = true;
    }

    onRunningWindowsChanged: {
        let anyClosed = false;
        const kept = ({
        });
        const alive = ({
        });
        for (const w of root.runningWindows) {
            alive[w.address] = true;
        }
        for (const address in root.tintedWindows) {
            if (address in alive)
                kept[address] = root.tintedWindows[address];
            else
                anyClosed = true;
        }
        if (anyClosed)
            root.tintedWindows = kept;

    }
    Component.onCompleted: {
        root.refreshState();
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.refreshState();

        }

        target: Hyprland
    }

    FolderListModel {
        id: shaderList

        folder: Qt.resolvedUrl("shaders")
        nameFilters: ["*.glsl"]
        showDirs: false
    }

    Process {
        id: screenShaderProc

        property bool again: false

        command: ["hyprctl", "-j", "getoption", "decoration:screen_shader"]
        onExited: {
            if (again) {
                again = false;
                running = true;
            }
        }

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.screenTintOn = Lua.parseScreenShaderActive(text);
            }
        }

    }

    Process {
        id: pluginListProc

        property bool again: false

        command: ["hyprctl", "-j", "plugin", "list"]
        onExited: {
            if (again) {
                again = false;
                running = true;
            }
        }

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.windowShadeLoaded = Lua.parseWindowShadeLoaded(text);
            }
        }

    }

    Process {
        id: clientsProc

        property bool again: false

        command: ["hyprctl", "-j", "clients"]
        onExited: {
            if (again) {
                again = false;
                running = true;
            }
        }

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.tintedWindows = Lua.parseTintedWindows(text);
            }
        }

    }

    Process {
        id: evalProc

        onExited: {
            if (root.evalQueue.length !== 0)
                root.runNextEval();
            else
                root.refreshState();
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text)
                    console.warn("omaTint: hyprctl eval:", text.trim());

            }
        }

    }

}
