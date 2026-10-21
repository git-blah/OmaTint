import Quickshell.Hyprland
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io
import "lua.js" as Lua
import qs.Commons
import qs.Ui
import "shader.js" as Shader

BarWidget {
    id: root

    property bool globalOn: false
    property real intensity: 1
    property int shaderIndex: 0
    property int slot: 0
    property real wheelAccumulator: 0
    property string lastOut: ""
    property var evalQueue: []
    property var perWindowOn : ({})
    property bool windowShadeLoaded: false
    property bool opened: false
    readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl("."))).replace(/^file:\/\//, "").replace(/\/$/, "")
    // Generated shaders live outside the plugin dir: the shell watches that
    // dir recursively and would reload the widget on every write.
    readonly property string outDir: Quickshell.env("XDG_RUNTIME_DIR") + "/widget-tint"
    readonly property string selectedShader: shaderList.count > 0 ? shaderList.get(shaderIndex % shaderList.count, "fileName") : ""
    readonly property string windowShaderPath: decodeURIComponent(String(Qt.resolvedUrl("shaders/grayscale.glsl")).replace(/^file:\/\//, ""))
    readonly property var runningWindows: {
        const out = []
        for (const t of Hyprland.toplevels.values){
            
            const address = Lua.hyprAddress(t.address)
            if (address === "") continue
            const title = t.title
            const appId = t.wayland ? t.wayland.appId : ""
            const icon = appId ? Quickshell.iconPath(appId, true) : ""
        
            out.push({
                address : address,
                title : title,
                appId : appId,
                icon : icon
            })
        }
        return out
    }
    
    function close(){
        root.opened = false
    }

    function setIntensity(v) {
        root.intensity = Math.max(0, Math.min(1, v));
        root.apply();
    }

    function selectShader(i) {
        if (shaderList.count === 0)
            return ;

        root.shaderIndex = (i + shaderList.count) % shaderList.count;
        root.apply();
    }

    function toggleGlobal() {
        var next = !root.globalOn;
        root.globalOn = next;
        if (root.globalOn)
            root.apply();
        else
            root.sendShader("");
    }

    function apply() {
        if (!root.globalOn || root.selectedShader === "")
            return ;

        srcFile.path = root.pluginDir + "/shaders/" + root.selectedShader;
        var out = Shader.withIntensity(srcFile.text(), root.intensity);
        // FileView.setText skips identical text without emitting saved, so
        // re-send the last file directly (e.g. toggling off and back on).
        if (out === root.lastOut) {
            root.sendShader(outFile.path);
            return ;
        }
        root.lastOut = out;
        root.slot = 1 - root.slot;
        outFile.path = root.outDir + "/tint-" + (root.slot ? "b" : "a") + ".glsl";
        outFile.setText(out);
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

        evalProc.command = ["hyprctl", "eval", root.evalQueue.shift()];
        evalProc.running = true;
    }

    function refreshState() {
        stateProc.running = true;
        pluginProc.running = true;
    }

    function setWindowShade(address, on) {
        // TODO: follow the selected shader + intensity like global does (see notes.md)

        root.runEval(Lua.setWindowShader(address, on ? root.windowShaderPath : ""))
        const obj = Object.assign({},root.perWindowOn)
        if(on) obj[address] = true 
        else delete obj[address]
        root.perWindowOn = obj  // assign new object so binding notice.
    }

    function toggleWindow(address){
        if(!root.windowShadeLoaded) return
        setWindowShade(address, !root.perWindowOn[address])
    }


    moduleName: "widget.tint"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    (root.runningWindows))
    Component.onCompleted: {
        mkdirProc.running = true;
        root.refreshState();
    }

    FolderListModel {
        id: shaderList

        folder: Qt.resolvedUrl("shaders")
        nameFilters: ["*.glsl"]
        showDirs: false
    }

    // blockLoading only makes the first load synchronous; after a path
    // change text() would return the previous shader. Always read sync.
    FileView {
        id: srcFile

        blockAllReads: true
    }

    FileView {
        id: outFile

        preload: false
        atomicWrites: true
        onSaved: root.sendShader(outFile.path)
    }

    Process {
        id: stateProc

        command: ["hyprctl", "-j", "getoption", "decoration:screen_shader"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.globalOn = Lua.screenShaderActive(text);
            }
        }

    }

    Process {
        id: pluginProc

        command: ["hyprctl", "-j", "plugin", "list"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.windowShadeLoaded = Lua.windowShadeLoaded(text);
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

    Process {
        id: mkdirProc

        command: ["mkdir", "-p", root.outDir]
    }

    BarIconButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: ""
        dimmed: !root.globalOn
        tooltipText: root.globalOn ? Shader.displayName(root.selectedShader) + " · " + Math.round(root.intensity * 100) + "% \nMiddle-click:change tint" : "Turn Tint ON"
        onPressed: function(b) {
            if (b === Qt.LeftButton)
                root.toggleGlobal();
            else if (b === Qt.RightButton)
                root.opened = !root.opened
            else if(b===Qt.MiddleButton)
                root.selectShader(root.shaderIndex + 1);
        }
        onWheelMoved: function(delta) {
            var w = Util.wheelSteps(root.wheelAccumulator, delta);
            root.wheelAccumulator = w.remainder;
            if (w.steps !== 0)
                root.setIntensity(root.intensity + w.steps * 0.05);

        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.opened
        contentHeight: panel.fittedContentHeight(list.implicitHeight)
        contentWidth: panel.fittedContentWidth(Style.space(260))

        Column {
            id: list
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            
            PanelSectionHeader {
                text: "Per Window Shade"
                foreground: root.bar ? root.bar.barForeground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
                visible:!root.windowShadeLoaded
                text: "Per-window tint needs the HyprWindowShade plugin. Refer README."
            }

            Repeater {
                model : root.windowShadeLoaded ? root.runningWindows : []

                delegate: Item {
                    id: rowItem
                    width: list.width
                    height: row.implicitHeight
                    required property var modelData
                    CursorSurface {
                        id: row
                        width: parent.width
                        implicitHeight: Math.max(appIcon.height, label.implicitHeight)+ Style.space(14)
                        hasCursor: mouseArea.containsMouse
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
