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
    readonly property bool windowShadeLoaded: service ? service.windowShadeLoaded : false
    readonly property var shaderList: service ? service.shaderList : null
    readonly property int shaderCount: shaderList ? shaderList.count : 0
    readonly property string selectedShaderFile: service ? service.selectedShaderFile : ""
    readonly property var runningWindows: service ? service.runningWindows : []
    property bool panelOpen: false

    function close() {
        root.panelOpen = false;
    }

    onPanelOpenChanged: {
        if (root.panelOpen && root.service)
            root.service.refreshState();

    }
    moduleName: "omaTint"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: ""
        dimmed: !root.screenTintOn
        tooltipText: root.screenTintOn ? Shader.displayName(root.selectedShaderFile) + "\nMiddle-click: next shader" : "Turn tint on"
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
        contentHeight: panel.fittedContentHeight(list.implicitHeight)
        contentWidth: panel.fittedContentWidth(Style.space(260))

        Column {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            PanelSectionHeader {
                text: "Shader"
                foreground: root.bar ? root.bar.barForeground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
                visible: root.shaderCount === 0
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
                model: root.shaderList

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
                            onClicked: root.service && root.service.selectShader(shaderItem.index)
                        }

                    }

                }

            }

            PanelSectionHeader {
                text: "Per-Window Tint"
                foreground: root.bar ? root.bar.barForeground : Color.foreground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
                visible: !root.windowShadeLoaded
                text: "Per-window tint needs the HyprWindowShade plugin. Refer README."
                color: root.bar ? root.bar.barForeground : Color.foreground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.body
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                width: list.width
            }

            Item {
                width: list.width
                height: Math.max(windowColumn.implicitHeight, tintNoticeBackground.visible ? tintNotice.implicitHeight + Style.space(20) : 0)

                Column {
                    id: windowColumn

                    width: parent.width
                    layer.enabled: root.screenTintOn

                    Repeater {
                        model: root.windowShadeLoaded ? root.runningWindows : []

                        delegate: Item {
                            id: windowItem

                            required property var modelData

                            width: windowColumn.width
                            height: windowRow.implicitHeight

                            CursorSurface {
                                id: windowRow

                                width: parent.width
                                implicitHeight: Math.max(windowIcon.height, windowLabel.implicitHeight) + Style.space(14)
                                hasCursor: root.screenTintOn ? false : windowMouseArea.containsMouse
                                current: !!root.tintedWindows[windowItem.modelData.address]

                                Image {
                                    id: windowIcon

                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: Style.space(8)
                                    width: Style.font.iconLarge
                                    height: Style.font.iconLarge
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize.width: width * Screen.devicePixelRatio
                                    sourceSize.height: height * Screen.devicePixelRatio
                                    asynchronous: true
                                    source: windowItem.modelData.icon || ""
                                }

                                Text {
                                    id: windowLabel

                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: windowIcon.right
                                    anchors.right: parent.right
                                    anchors.leftMargin: Style.space(8)
                                    anchors.rightMargin: Style.space(8)
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    text: windowItem.modelData.title
                                    color: root.bar ? root.bar.barForeground : Color.foreground
                                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                                    font.pixelSize: Style.font.body
                                    opacity: root.screenTintOn ? 0.1 : 1
                                }

                                MouseArea {
                                    id: windowMouseArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: root.screenTintOn ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onClicked: root.service && root.service.toggleWindowTint(windowItem.modelData.address)
                                }

                            }

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
                    color: Qt.alpha(Color.popups.background, 0.5)

                    Text {
                        id: tintNotice

                        anchors.centerIn: parent
                        width: parent.width - Style.space(16)
                        horizontalAlignment: Text.AlignHCenter
                        text: "Screen tint is on: per-window tint applies when it's off"
                        color: root.bar ? root.bar.barForeground : Color.foreground
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }

                }

            }

        }

    }

}
