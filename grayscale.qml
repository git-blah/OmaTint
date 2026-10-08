import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "widget.grayscale"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Hello from my first widget"
    onPressed: function(b) { console.log("widget.grayscale: clicked, button =", b) }
  }
}
