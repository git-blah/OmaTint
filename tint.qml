import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "shader.js" as Shader

BarWidget {
    id: root

    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    readonly property bool screenTintOn: service ? service.screenTintOn : false
    readonly property int shaderIndex: service ? service.shaderIndex : 0
    readonly property var tintedWindows: service ? service.tintedWindows : ({
    })
    readonly property bool hasTintedWindows: Object.keys(tintedWindows).length > 0
    readonly property bool windowShadeLoaded: service ? service.windowShadeLoaded : false
    readonly property var shaderList: service ? service.shaderList : null
    readonly property int shaderCount: shaderList ? shaderList.count : 0
    readonly property string selectedShaderFile: service ? service.selectedShaderFile : ""
    readonly property var runningWindows: service ? service.runningWindows : []
    readonly property bool windowsEditable: windowShadeLoaded && !screenTintOn
    property bool panelOpen: false
    readonly property color foreground: bar ? bar.barForeground : Color.foreground
    readonly property color mutedForeground: Qt.darker(foreground, 1.4)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
    readonly property int rowGap: Style.space(2)
    readonly property int sectionGap: Style.space(6)
    property bool cursorActive: false
    property string cursorKind: "screen"
    property string cursorKey: ""
    property int lastCursorIndex: 0
    readonly property int cursorIndex: cursorStops.findIndex((s) => {
        return s.kind === cursorKind && s.key === cursorKey;
    })
    readonly property var cursorStops: {
        const stops = [{
            "kind": "screen",
            "key": ""
        }];
        for (let i = 0; i < root.shaderCount; i++) {
            stops.push({
                "kind": "shader",
                "key": String(i)
            });
        }
        if (root.windowsEditable) {
            if (root.hasTintedWindows)
                stops.push({
                "kind": "clear",
                "key": ""
            });

            for (const w of root.runningWindows) {
                stops.push({
                    "kind": "window",
                    "key": w.address
                });
            }
        }
        return stops;
    }
    readonly property bool opened: panelOpen

    function open() {
        root.panelOpen = true;
    }

    function close() {
        root.panelOpen = false;
    }

    function hasCursor(kind, key) {
        return root.cursorActive && root.cursorIndex >= 0 && root.cursorKind === kind && root.cursorKey === (key || "");
    }

    function setCursor(kind, key) {
        root.cursorKind = kind;
        root.cursorKey = key || "";
        root.cursorActive = true;
    }

    function setCursorAt(i) {
        const stop = root.cursorStops[Math.max(0, Math.min(root.cursorStops.length - 1, i))];
        if (stop)
            root.setCursor(stop.kind, stop.key);

    }

    function moveCursor(delta) {
        if (!root.cursorActive) {
            root.cursorActive = true;
            return ;
        }
        root.setCursorAt((root.cursorIndex >= 0 ? root.cursorIndex : root.lastCursorIndex) + delta);
    }

    function activateCursor() {
        const stop = root.cursorStops[root.cursorIndex];
        if (!root.cursorActive || !stop || !root.service)
            return ;

        if (stop.kind === "screen")
            root.service.toggleScreenTint();
        else if (stop.kind === "shader")
            root.service.selectShader(Number(stop.key));
        else if (stop.kind === "clear")
            root.service.clearWindowTints();
        else if (stop.kind === "window")
            root.service.toggleWindowTint(stop.key);
    }

    onCursorIndexChanged: {
        if (root.cursorIndex >= 0)
            root.lastCursorIndex = root.cursorIndex;

    }
    onPanelOpenChanged: {
        if (!root.panelOpen)
            return ;

        root.cursorActive = false;
        root.cursorKind = "screen";
        root.cursorKey = "";
        if (root.service)
            root.service.refreshState();

    }
    moduleName: "git-blah.omaTint"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: ""
        dimmed: !root.screenTintOn
        tooltipText: root.screenTintOn ? Shader.displayName(root.selectedShaderFile) + " · middle-click: next tint · right-click: tint windows" : "Tint off · click to turn on · right-click: tint windows"
        onPressed: function(b) {
            if (b === Qt.LeftButton)
                root.service && root.service.toggleScreenTint();
            else if (b === Qt.RightButton)
                root.panelOpen = !root.panelOpen;
            else if (b === Qt.MiddleButton)
                root.service && root.service.selectShader(root.shaderIndex + 1);
        }
    }

    KeyboardPanel {
        id: panel

        anchorItem: button
        bar: root.bar
        owner: root
        open: root.panelOpen
        focusTarget: keyCatcher
        contentHeight: panel.fittedContentHeight(list.implicitHeight)
        contentWidth: panel.fittedContentWidth(Style.space(340))

        PanelKeyCatcher {
            id: keyCatcher

            anchors.fill: parent
            onMoveRequested: function(dx, dy) {
                if (dy !== 0)
                    root.moveCursor(dy);

            }
            onActivateRequested: root.activateCursor()
            onCloseRequested: root.close()

            Column {
                id: list

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Style.space(14)

                PanelHero {
                    title: "omaTint"
                    meta: root.screenTintOn ? "Screen tint · " + Shader.displayName(root.selectedShaderFile) : "Screen tint off"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    iconComponent: heroIcon
                    trailingControl: screenSwitch
                }

                PanelSeparator {
                    foreground: root.foreground
                }

                Column {
                    width: parent.width
                    spacing: root.sectionGap

                    PanelSectionHeader {
                        text: "TINT"
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                    }

                    Text {
                        visible: root.shaderCount === 0
                        text: "No tints found. Add a .glsl file to shaders/."
                        color: root.mutedForeground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Column {
                        width: parent.width
                        spacing: root.rowGap

                        Repeater {
                            model: root.shaderList

                            delegate: TintRow {
                                required property int index
                                required property string fileName

                                label: Shader.displayName(fileName)
                                trailing: current ? "" : ""
                                trailingColor: Color.accent
                                current: root.shaderIndex === index
                                hasCursor: root.hasCursor("shader", String(index))
                                onEntered: root.setCursor("shader", String(index))
                                onActivated: root.service && root.service.selectShader(index)
                            }

                        }

                    }

                }

                PanelSeparator {
                    foreground: root.foreground
                }

                Column {
                    width: parent.width
                    spacing: root.sectionGap

                    Item {
                        width: parent.width
                        height: Math.max(windowHeader.implicitHeight, clearAllButton.visible ? clearAllButton.implicitHeight : 0)

                        PanelSectionHeader {
                            id: windowHeader

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "TINT WINDOWS"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                        }

                        Button {
                            id: clearAllButton

                            visible: root.windowShadeLoaded
                            enabled: root.hasTintedWindows && !root.screenTintOn
                            opacity: enabled ? 1 : 0.4
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear all"
                            tooltipText: root.screenTintOn ? "Turn screen tint off to clear window tints" : "Remove the tint from every window"
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            fontSize: Style.font.caption
                            horizontalPadding: Style.space(8)
                            verticalPadding: Style.space(3)
                            hasCursor: root.hasCursor("clear", "")
                            onHovered: function(h) {
                                if (h && enabled)
                                    root.setCursor("clear", "");

                            }
                            onClicked: root.service && root.service.clearWindowTints()
                        }

                    }

                    Text {
                        visible: !root.windowShadeLoaded
                        text: "Per-window tint needs the HyprWindowShade Hyprland plugin."
                        color: root.mutedForeground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Text {
                        visible: root.windowsEditable
                        text: root.runningWindows.length === 0 ? "No windows open" : "Pick a tint, then click a window."
                        color: root.mutedForeground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        textFormat: Text.PlainText
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Item {
                        visible: root.windowShadeLoaded && root.runningWindows.length > 0
                        width: parent.width
                        height: Math.max(windowColumn.implicitHeight, tintNoticeBackground.visible ? tintNotice.implicitHeight + Style.space(20) : 0)

                        Column {
                            id: windowColumn

                            width: parent.width
                            spacing: root.rowGap
                            layer.enabled: root.screenTintOn

                            Repeater {
                                model: root.windowShadeLoaded ? root.runningWindows : []

                                delegate: TintRow {
                                    required property var modelData
                                    readonly property bool tinted: modelData.address in root.tintedWindows

                                    iconSource: modelData.icon || ""
                                    label: modelData.title
                                    trailing: tinted ? Shader.displayName(root.tintedWindows[modelData.address]) : ""
                                    interactive: !root.screenTintOn
                                    current: tinted
                                    hasCursor: root.hasCursor("window", modelData.address)
                                    onEntered: root.setCursor("window", modelData.address)
                                    onActivated: root.service && root.service.toggleWindowTint(modelData.address)
                                }

                            }

                            layer.effect: MultiEffect {
                                blurEnabled: true
                                blur: 0.5
                                blurMax: 16
                            }

                        }

                        Rectangle {
                            id: tintNoticeBackground

                            visible: root.screenTintOn
                            anchors.fill: parent
                            radius: Style.cornerRadius
                            color: Qt.alpha(Color.popups.background, 0.6)

                            Text {
                                id: tintNotice

                                anchors.centerIn: parent
                                width: parent.width - Style.space(24)
                                horizontalAlignment: Text.AlignHCenter
                                text: "Whole screen is tinted. Turn it off to tint single windows. Window tints are kept."
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.bodySmall
                                wrapMode: Text.WordWrap
                            }

                        }

                    }

                }

            }

        }

    }

    Component {
        id: heroIcon

        Text {
            text: ""
            color: root.foreground
            opacity: root.screenTintOn ? 1 : 0.45
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
        }

    }

    Component {
        id: screenSwitch

        ToggleSwitch {
            checked: root.screenTintOn
            foreground: root.foreground
            hasCursor: root.hasCursor("screen", "")
            onHovered: function(h) {
                if (h)
                    root.setCursor("screen", "");

            }
            onToggled: root.service && root.service.toggleScreenTint()
        }

    }

    component TintRow: CursorSurface {
        id: row

        property string iconSource: ""
        property string label: ""
        property string trailing: ""
        property color trailingColor: root.mutedForeground
        property bool interactive: true

        signal entered()
        signal activated()

        width: parent ? parent.width : 0
        implicitHeight: Math.max(Style.font.iconLarge, rowLabel.implicitHeight) + Style.space(16)
        foreground: root.foreground

        Image {
            id: rowIcon

            visible: row.iconSource !== ""
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            width: Style.font.iconLarge
            height: Style.font.iconLarge
            fillMode: Image.PreserveAspectFit
            sourceSize.width: width * Screen.devicePixelRatio
            sourceSize.height: height * Screen.devicePixelRatio
            asynchronous: true
            source: row.iconSource
        }

        Text {
            id: rowLabel

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: rowIcon.visible ? rowIcon.right : parent.left
            anchors.right: rowTrailing.visible ? rowTrailing.left : parent.right
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            textFormat: Text.PlainText
            elide: Text.ElideRight
            text: row.label
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
        }

        Text {
            id: rowTrailing

            visible: row.trailing !== ""
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            textFormat: Text.PlainText
            text: row.trailing
            color: row.trailingColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: row.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onEntered: {
                if (row.interactive)
                    row.entered();

            }
            onClicked: {
                if (row.interactive)
                    row.activated();

            }
        }

    }

}
