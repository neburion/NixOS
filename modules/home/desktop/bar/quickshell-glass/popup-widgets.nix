{ ... }:

# The four rows every bar popup is built from. Wi-Fi and Bluetooth popups are
# structurally identical — a header with a power switch, a list of things you
# can tap, an empty state, and one action at the bottom — so they share these
# instead of carrying two near-copies of the same QML.

{
  quickshell.widgets.PopupHeader = ''
    import QtQuick
    import "../Common"

    Item {
        id: root
        height: 30

        property string title: ""
        property bool   on:    false
        signal toggled()

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            font.family: Glass.fontUi
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: -0.13
            color: Glass.text
            text:  root.title
        }

        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 34; height: 19; radius: 9.5
            color: root.on ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            border.color: Glass.stroke

            Behavior on color { ColorAnimation { duration: 160 } }

            Rectangle {
                width: 13; height: 13; radius: 6.5
                y: 3
                x: root.on ? parent.width - width - 3 : 3
                color: root.on ? Glass.text : Glass.faint
                Behavior on x     { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggled()
            }
        }
    }
  '';

  quickshell.widgets.PopupRow = ''
    import QtQuick
    import "../Common"

    Rectangle {
        id: root
        height: Glass.rowHeight - 6
        radius: Glass.rowRadius

        property string glyph:    ""
        property string label:    ""
        property string trailing: ""
        property bool   active:   false
        signal activated()

        color: mouse.containsMouse ? Glass.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontIcon
                font.pixelSize: 16
                font.variableAxes: root.active ? Glass.iconActive : Glass.iconIdle
                color: root.active ? Glass.text : Glass.muted
                text:  root.glyph
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 66
                font.family: Glass.fontUi
                font.pixelSize: 13
                font.letterSpacing: -0.1
                color: root.active ? Glass.text : Glass.muted
                text:  root.label
                elide: Text.ElideRight
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.trailing !== ""
                font.family: Glass.fontIcon
                font.pixelSize: 15
                font.variableAxes: Glass.iconIdle
                color: root.active ? Glass.text : Glass.faint
                text:  root.trailing
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.activated()
        }
    }
  '';

  quickshell.widgets.PopupEmpty = ''
    import QtQuick
    import "../Common"

    Item {
        id: root
        height: visible ? 30 : 0

        property string label: ""

        Text {
            anchors.centerIn: parent
            font.family: Glass.fontUi
            font.pixelSize: 12
            color: Glass.faint
            text:  root.label
        }
    }
  '';

  quickshell.widgets.PopupAction = ''
    import QtQuick
    import "../Common"

    Rectangle {
        id: root
        height: 32
        radius: Glass.rowRadius

        property string glyph:   ""
        property string label:   ""
        property bool   enabled: true
        signal activated()

        color: mouse.containsMouse && root.enabled ? Glass.hover : Qt.rgba(1, 1, 1, 0.04)
        Behavior on color { ColorAnimation { duration: 120 } }
        opacity: root.enabled ? 1.0 : 0.45

        Row {
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontIcon
                font.pixelSize: 15
                font.variableAxes: Glass.iconIdle
                color: Glass.muted
                text:  root.glyph
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Glass.fontUi
                font.pixelSize: 12
                color: Glass.muted
                text:  root.label
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled:      root.enabled
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.activated()
        }
    }
  '';
}
