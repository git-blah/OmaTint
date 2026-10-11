import QtQuick
import qs.Ui
import Quickshell.Io
import "lua.js" as Lua

BarWidget {
  id: root
  moduleName: "widget.tint"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool globalOn: false
  readonly property string shaderPath:
    decodeURIComponent(String(Qt.resolvedUrl("shaders/nightlight.glsl")).replace(/^file:\/\//, ""))

  function toggleGlobal() {
    var next = !root.globalOn
    root.globalOn = next
    var path = next ? root.shaderPath : ""
    evalProc.command = ["hyprctl", "eval",
      Lua.setScreenShader(path)]
    evalProc.running = true
  }
  
  Process {
    id: stateProc
    command: ["hyprctl", "-j", "getoption", "decoration:screen_shader"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
          root.globalOn = Lua.screenShaderActive(text)
      }
    }
  }

  Process {
    id : evalProc
    onExited: stateProc.running = true
  }


  Component.onCompleted: {
    stateProc.running = true
    console.log("widget.tint: shader path=",root.shaderPath)
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    dimmed: !root.globalOn
    tooltipText: root.globalOn ? "Turn Tint OFF" : " Turn Tint ON"
    onPressed: function(b) { b===Qt.LeftButton ?root.toggleGlobal() : console.log("widget.tint : button pressed",b) }

  }
}
