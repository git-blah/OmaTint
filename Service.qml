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
    readonly property string selectedShaderPath: selectedShaderFile === "" ? "" : pluginDir + "/shaders/" + selectedShaderFile
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
        root.reapplyWindowTints();
    }

    function toggleScreenTint() {
        root.screenTintOn = !root.screenTintOn;
        if (root.screenTintOn) {
            root.clearWindowTints();
            root.applyScreenTint();
        } else {
            root.setScreenShader("");
        }
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

    function setWindowTint(address, on) {
        root.queueEval(Lua.setWindowShader(address, on ? root.selectedShaderPath : "") + " " + Lua.tagWindow(address, on));
        const obj = Object.assign({
        }, root.tintedWindows);
        if (on)
            obj[address] = true;
        else
            delete obj[address];
        root.tintedWindows = obj;
    }

    function toggleWindowTint(address) {
        if (!root.windowShadeLoaded)
            return ;

        if (root.screenTintOn)
            return ;

        root.setWindowTint(address, !root.tintedWindows[address]);
    }

    function rerun(proc) {
        if (proc.running)
            proc.again = true;
        else
            proc.running = true;
    }

    function clearWindowTints() {
        if (Object.keys(root.tintedWindows).length === 0)
            return ;

        root.queueEval(Object.keys(root.tintedWindows).map((address) => {
            return Lua.setWindowShader(address, "") + " " + Lua.tagWindow(address, false);
        }).join(" "));
        root.tintedWindows = ({
        });
        return ;
    }

    function reapplyWindowTints() {
        if (Object.keys(root.tintedWindows).length === 0)
            return ;

        root.queueEval(Object.keys(root.tintedWindows).map((address) => {
            return Lua.setWindowShader(address, root.selectedShaderPath);
        }).join(" "));
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
                kept[address] = true;
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
