import QtQuick
import qs.Ui
import Qt.labs.folderlistmodel
import qs.Commons
import Quickshell
import Quickshell.Io
import "lua.js" as Lua
import "shader.js" as Shader

BarWidget {
  id: root
  moduleName: "widget.tint"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool globalOn: false
  property real intensity: 1.0
  property int shaderIndex: 0

  property int slot:0
  property real wheelAccumulator:0
  property string lastOut: ""

  property var evalQueue : []

  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl("."))).replace(/^file:\/\//, "").replace(/\/$/, "")

  // Generated shaders live outside the plugin dir: the shell watches that
  // dir recursively and would reload the widget on every write.
  readonly property string outDir: Quickshell.env("XDG_RUNTIME_DIR") + "/widget-tint"

  readonly property string selectedShader: shaderList.count > 0 ? shaderList.get(shaderIndex % shaderList.count, "fileName") : ""

  readonly property string shaderPath: decodeURIComponent(String(Qt.resolvedUrl("shaders/nightlight.glsl")).replace(/^file:\/\//, ""))
  
  FolderListModel {
    id : shaderList
    folder: Qt.resolvedUrl("shaders")
    nameFilters: ["*.glsl"]
    showDirs: false
  }

  function setIntensity(v) {
    root.intensity = Math.max(0, Math.min(1, v))
    root.apply()
  }

  function selectShader(i) {
    if (shaderList.count === 0) return
    root.shaderIndex = (i + shaderList.count) % shaderList.count
    root.apply()
  }
  

  function toggleGlobal() {
    var next = !root.globalOn
    root.globalOn = next
    if(root.globalOn) root.apply()
    else root.sendShader("")
  }

  function apply() {
    if (!root.globalOn || root.selectedShader === "") return
    srcFile.path = root.pluginDir + "/shaders/" + root.selectedShader
    var out = Shader.withIntensity(srcFile.text(), root.intensity)
    // FileView.setText skips identical text without emitting saved, so
    // re-send the last file directly (e.g. toggling off and back on).
    if (out === root.lastOut) {
      root.sendShader(outFile.path)
      return
    }
    root.lastOut = out
    root.slot = 1 - root.slot
    outFile.path = root.outDir + "/tint-" + (root.slot ? "b" : "a") + ".glsl"
    outFile.setText(out)
  }

  function sendShader(path) {
    root.runEval(Lua.setScreenShader(path))
  }

  function runEval(code){
    root.evalQueue.push(code)
    root.pumpEval()
  }

  function pumpEval(){
    if(evalProc.running || root.evalQueue.length === 0 ) return
    evalProc.command = ["hyprctl","eval", root.evalQueue.shift()]
    evalProc.running = true
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
          root.globalOn = Lua.screenShaderActive(text)
      }
    }
  }

  Process {
    id : evalProc
    onExited: {
      if(root.evalQueue.length !==0) root.pumpEval()
      else stateProc.running = true
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if(text) console.warn("widget.tint: hyprctl eval:", text.trim())
    }
  }


  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.outDir]
  }

  Component.onCompleted: {
    mkdirProc.running = true
    stateProc.running = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    dimmed: !root.globalOn
    tooltipText: root.globalOn ? Shader.displayName(root.selectedShader) + " · " + Math.round(root.intensity * 100) + "%" : "Turn Tint ON"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggleGlobal()
      else if (b === Qt.RightButton) root.selectShader(root.shaderIndex + 1)
    }
    onWheelMoved: function(delta) {
      var w = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = w.remainder
      if (w.steps !== 0) root.setIntensity(root.intensity + w.steps * 0.05)
    }

  }
}
