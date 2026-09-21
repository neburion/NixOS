{ ... }:

# Widgets/Dial.qml — concentric arcs, outermost first.
#
# One widget for both sizes: the bar draws a single 24px dial carrying three
# rings, the menu draws three 44px dials carrying one ring each. Nothing about
# it knows what a battery is.
#
# QtQuick.Shapes rather than Canvas. An arc that animates its sweep and its
# colour is four lines of declarative binding here and a repaint loop there,
# and at 24px the curve renderer is the difference between a ring and a
# smudge — geometry tessellation quantises a 1.7px stroke badly at that size.
#
# Absence is drawn as an empty track, not a missing ring: a headset that goes
# to sleep should leave its groove behind, or the remaining rings shift their
# meaning and the dial lies about which is which.

{
  quickshell.widgets.Dial = ''
    import QtQuick
    import QtQuick.Shapes
    import "../Common"

    Item {
        id: root

        property real size:      26
        property real thickness: 1.9
        property real spacing:   1.3   // bare track between one ring and the next

        // [{ value: 0-100, color: <color>, present: bool, burning: bool }]
        property var rings: []

        implicitWidth:  size
        implicitHeight: size

        // Performance mode. One triangle wave would pulse like a heartbeat,
        // which reads as a notification rather than a flame; two of them at
        // durations that do not divide into each other drift in and out of
        // phase for about nine seconds before repeating, and that irregularity
        // is the whole effect. Everything else is one hot colour over a dull
        // one, so there is nothing here to go wrong at 24px.
        property real emberA: 0
        property real emberB: 0
        readonly property real ember: 0.16 + 0.32 * emberA + 0.24 * emberB

        SequentialAnimation on emberA {
            running: true; loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1; duration: 430; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: 0; duration: 430; easing.type: Easing.InOutSine }
        }
        SequentialAnimation on emberB {
            running: true; loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1; duration: 670; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: 0; duration: 670; easing.type: Easing.InOutSine }
        }

        Repeater {
            model: root.rings

            delegate: Shape {
                id: ring

                required property var modelData
                required property int index

                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer

                readonly property real mid:   root.size / 2
                readonly property real radius: root.size / 2 - root.thickness / 2
                                             - index * (root.thickness + root.spacing)

                readonly property bool drawn: modelData.present && modelData.value > 0
                readonly property real sweep: drawn
                    ? 3.6 * Math.max(0, Math.min(100, modelData.value)) : 0

                // The groove. Flat caps, because a round cap on a full turn
                // puts a bulge where the two ends meet.
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.11)
                    strokeWidth: root.thickness
                    fillColor:   "transparent"
                    capStyle:    ShapePath.FlatCap
                    PathAngleArc {
                        centerX: ring.mid; centerY: ring.mid
                        radiusX: ring.radius; radiusY: ring.radius
                        startAngle: -90; sweepAngle: 360
                    }
                }

                ShapePath {
                    strokeColor: ring.drawn ? ring.modelData.color : "transparent"
                    strokeWidth: root.thickness
                    fillColor:   "transparent"
                    // A full ring closes on itself; a round cap there puts a
                    // lump where the two ends meet.
                    capStyle: ring.sweep >= 359 ? ShapePath.FlatCap : ShapePath.RoundCap
                    PathAngleArc {
                        id: arc
                        centerX: ring.mid; centerY: ring.mid
                        radiusX: ring.radius; radiusY: ring.radius
                        startAngle: -90
                        sweepAngle: ring.sweep
                        Behavior on sweepAngle {
                            NumberAnimation { duration: 460; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // The ember, laid over the ring it belongs to and nowhere
                // else. Its width breathes with it, so the arc swells rather
                // than just brightening.
                ShapePath {
                    strokeColor: ring.drawn && ring.modelData.burning
                        ? Qt.rgba(1, 0.76, 0.38, root.ember) : "transparent"
                    strokeWidth: root.thickness + 0.45 * root.ember
                    fillColor:   "transparent"
                    capStyle: ring.sweep >= 359 ? ShapePath.FlatCap : ShapePath.RoundCap
                    PathAngleArc {
                        centerX: ring.mid; centerY: ring.mid
                        radiusX: ring.radius; radiusY: ring.radius
                        startAngle: -90
                        sweepAngle: arc.sweepAngle
                    }
                }
            }
        }
    }
  '';
}
