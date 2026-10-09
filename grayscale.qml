import QtQuick
import qs.Ui
import Quickshell.Io


BarWidget {
  id: root
  moduleName: "widget.grayscale"

  property bool globalOn: false
  readonly property string shaderPath:
    decodeURIComponent(String(Qt.resolvedUrl("grayscale.glsl")).replace(/^file:\/\//, ""))

  function toggleGlobal() {
    var next = !root.globalOn
    root.globalOn = next
    var path = next ? root.shaderPath : ""
    evalProc.command = ["hyprctl", "eval",
      'hl.config({decoration = {screen_shader = "' + path + '"}})']
    evalProc.running = true
  }
  
  Process {
    id: stateProc
    command: ["hyprctl", "-j", "getoption", "decoration:screen_shader"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try{
          var curr = JSON.parse(text).str
          root.globalOn = !["[[EMPTY]]", ""].includes(curr)
        }
        catch(e){
          console.warn("widget.grayscale:bad hyprctl output:",text,e)
        }
      }
    }
  }

  Process {
    id : evalProc
    onExited: stateProc.running = true
  }


  Component.onCompleted: {
    stateProc.running = true
    console.log("widget.grayscale: shader path=",root.shaderPath)
  }



  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    dimmed: !root.globalOn
    tooltipText: root.globalOn ? "Turn Grayscale OFF" : " Turn Grayscale ON"
    onPressed: function(b) { b===Qt.LeftButton ?root.toggleGlobal() : console.log("widget.grayscale : button pressed",b) }

  }
}
