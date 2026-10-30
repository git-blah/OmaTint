import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "lua.js" as Lua
import qs.Commons
import qs.Ui
import "shader.js" as Shader

BarWidget {
    id: root

    property bool globalOn: false
    property int shaderIndex: 0
    property var evalQueue: []
    property var perWindowOn: ({
    })
    property bool windowShaderLoaded: false
    property bool openedToggle: false
    readonly property string selectedShader: shaderList.count > 0 ? shaderList.get(shaderIndex % shaderList.count, "fileName") : ""
    readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl("."))).replace(/^file:\/\//, "").replace(/\/$/, "")
    readonly property string selectedShaderPath: selectedShader === "" ? "" : pluginDir + "/shaders/" + selectedShader
    readonly property var runningWindows: {
        // Touching ToplevelManager starts the wayland toplevel protocol, which
        // is what fills in t.wayland; it also re-runs this binding as it does.
        ToplevelManager.toplevels.values;
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const address = Lua.hyprAddress(t.address);
            if (address === "")
                continue;

            const title = t.title;
            const ipc = t.lastIpcObject || {};
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

    function close() {
        root.openedToggle = false;
    }

    // A desktop entry's Icon= may be a theme name or an absolute path.
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

    // Desktop entry icon first, then the appId as a theme icon name, then a
    // generic app icon so every row has something.
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
        root.apply();
        root.reshadeAllWindows();
    }

    function toggleGlobal() {
        var next = !root.globalOn;
        root.globalOn = next;
        if (root.globalOn) {
            root.clearAllWindows();
            root.apply();
        } else {
            root.sendShader("");
        }
    }

    function apply() {
        if (!root.globalOn || root.selectedShaderPath === "")
            return ;

        root.sendShader(root.selectedShaderPath);
    }

    function sendShader(path) {
        root.runEval(Lua.setScreenShader(path));
    }

    function runEval(code) {
        root.evalQueue.push(code);
        root.pumpEval();
    }

    function pumpEval() {
        if (evalProc.running || root.evalQueue.length === 0)
            return ;

        let code = root.evalQueue.shift();
        if (root.evalQueue.length === 0)
            code += " " + Lua.notifyChanged();

        evalProc.command = ["hyprctl", "eval", code];
        evalProc.running = true;
    }

    function refreshState() {
        root.rerun(stateProc);
        root.rerun(pluginProc);
        root.rerun(clientsProc);
    }

    function setWindowShade(address, on) {
        root.runEval(Lua.setWindowShader(address, on ? root.selectedShaderPath : "") + " " + Lua.tagWindow(address, on));
        const obj = Object.assign({
        }, root.perWindowOn);
        if (on)
            obj[address] = true;
        else
            delete obj[address];
        root.perWindowOn = obj;
    }

    function toggleWindow(address) {
        if (!root.windowShaderLoaded)
            return ;

        if (root.globalOn)
            return ;

        setWindowShade(address, !root.perWindowOn[address]);
    }

    function rerun(proc) {
        if (proc.running)
            proc.again = true;
        else
            proc.running = true;
    }

    function clearAllWindows() {
        if (Object.keys(root.perWindowOn).length === 0)
            return ;

        root.runEval(Object.keys(root.perWindowOn).map((addr) => {
            return Lua.setWindowShader(addr, "") + " " + Lua.tagWindow(addr, false);
        }).join(" "));
        root.perWindowOn = ({
        });
        return ;
    }

    function reshadeAllWindows() {
        if (Object.keys(root.perWindowOn).length === 0)
            return ;

        root.runEval(Object.keys(root.perWindowOn).map((addr) => {
            return Lua.setWindowShader(addr, root.selectedShaderPath);
        }).join(" "));
    }

    onRunningWindowsChanged: {
        var reassignFlag = false;
        var kept = ({
        });
        var alive = ({
        });
        for (const a of root.runningWindows) {
            alive[a.address] = true;
        }
        for (const addr in root.perWindowOn) {
            if (addr in alive)
                kept[addr] = true;
            else
                reassignFlag = true;
        }
        if (reassignFlag)
            root.perWindowOn = kept;

    }
    onOpenedToggleChanged: {
        if (root.openedToggle)
            root.refreshState();

    }
    moduleName: "widget.tint"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    Component.onCompleted: {
        root.refreshState();
    }

    Connections {
        function onRawEvent(event) {
            if (["configreloaded"].includes(event.name))
                root.refreshState();

            if (event.name === "custom" && event.data === "widget.tint")
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
        id: stateProc

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
                root.globalOn = Lua.screenShaderActive(text);
            }
        }

    }

    Process {
        id: pluginProc

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
                root.windowShaderLoaded = Lua.windowShadeLoaded(text);
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
                root.perWindowOn = Lua.windowsMarked(text);
            }
        }

    }

    Process {
        id: evalProc

        onExited: {
            if (root.evalQueue.length !== 0)
                root.pumpEval();
            else
                root.refreshState();
        }

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text)
                    console.warn("widget.tint: hyprctl eval:", text.trim());

            }
        }

    }

    BarIconButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: ""
        dimmed: !root.globalOn
        tooltipText: root.globalOn ? Shader.displayName(root.selectedShader) + "\nMiddle-click:change tint" : "Turn Tint ON"
        onPressed: function(b) {
            if (b === Qt.LeftButton)
                root.toggleGlobal();
            else if (b === Qt.RightButton)
                root.openedToggle = !root.openedToggle;
            else if (b === Qt.MiddleButton)
                root.selectShader(root.shaderIndex + 1);
        }
    }

    KeyboardPanel {
        id: panel

        anchorItem: button
        bar: root.bar
        owner: root
        open: root.openedToggle
        contentHeight: panel.fittedContentHeight(list.implicitHeight)
        contentWidth: panel.fittedContentWidth(Style.space(260))

        Column {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            PanelSectionHeader {
                text: "Shader Selection"
                foreground: root.bar ? root.bar.barForeground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
                visible: shaderList.count === 0
                text: "No shader available in shaders/."
                color: root.bar ? root.bar.barForeground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                font.italic: true
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                width: list.width
            }

            Repeater {
                model: shaderList

                delegate: Item {
                    id: shaderItem

                    required property int index
                    required property string fileName

                    width: list.width
                    height: shaderRow.implicitHeight

                    CursorSurface {
                        id: shaderRow

                        width: parent.width
                        implicitHeight: shaderLabel.implicitHeight + Style.space(14)
                        hasCursor: shaderMouseArea.containsMouse
                        current: root.shaderIndex === shaderItem.index

                        Text {
                            id: shaderLabel

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Style.space(8)
                            anchors.rightMargin: Style.space(8)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: Shader.displayName(shaderItem.fileName)
                            color: root.bar ? root.bar.barForeground : Color.foreground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.body
                        }

                        MouseArea {
                            id: shaderMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectShader(shaderItem.index)
                        }

                    }

                }

            }

            PanelSectionHeader {
                text: "Per Window Shade"
                foreground: root.bar ? root.bar.barForeground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
                visible: !root.windowShaderLoaded
                text: "Per-window tint needs the HyprWindowShade plugin. Refer README."
                color: root.bar ? root.bar.barForeground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                width: list.width
            }

            Text {
                visible: root.globalOn
                text: "Global tint is on: per-window tint applies when its off"
                color: root.bar ? root.bar.barForeground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                font.italic: true
                wrapMode: Text.WordWrap
                width: list.width
            }

            Repeater {
                model: root.windowShaderLoaded ? root.runningWindows : []

                delegate: Item {
                    id: rowItem

                    required property var modelData

                    width: list.width
                    height: row.implicitHeight

                    CursorSurface {
                        id: row

                        width: parent.width
                        implicitHeight: Math.max(appIcon.height, label.implicitHeight) + Style.space(14)
                        hasCursor: root.globalOn ? false : mouseArea.containsMouse
                        current: !!root.perWindowOn[rowItem.modelData.address]

                        Image {
                            id: appIcon

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: Style.space(8)
                            width: Style.font.iconLarge
                            height: Style.font.iconLarge
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: width * Screen.devicePixelRatio
                            sourceSize.height: height * Screen.devicePixelRatio
                            asynchronous: true
                            source: rowItem.modelData.icon || ""
                        }

                        Text {
                            id: label

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: appIcon.right
                            anchors.right: parent.right
                            anchors.leftMargin: Style.space(8)
                            anchors.rightMargin: Style.space(8)
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            text: rowItem.modelData.title
                            color: root.bar ? root.bar.barForeground : Color.foreground
                            font.family: root.bar ? root.bar.fontFamily : Style.font.family
                            font.pixelSize: Style.font.body
                            opacity: root.globalOn ? 0.5 : 1
                        }

                        MouseArea {
                            id: mouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleWindow(rowItem.modelData.address)
                        }

                    }

                }

            }

        }

    }

}
