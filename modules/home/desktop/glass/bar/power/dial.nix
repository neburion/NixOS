{ ... }:

# Widgets/Dial.qml — concentric gauges, outermost first. Knows nothing about
# batteries; it is handed a list of rings and draws them.
#
# Open at the bottom, 270 degrees of travel. A closed ring has no beginning,
# so a value near 100 and a value near 0 land in the same place and the eye
# cannot tell a full gauge from an empty one at 26px. The gap gives the scale
# ends, and the fire behind comes up through it.
#
# The dial grows with the list. Each ring is drawn at a fixed thickness and
# spacing outward from a small empty core, so one source is a small ring and
# four is a wider one — the width of the thing in the bar is itself a reading.
# Past `maxSize` the rings compress instead, because the bar panel is 34px and
# a dial that outgrows it would be clipped rather than informative.
#
# QtQuick.Shapes rather than Canvas: an arc that animates its sweep is an
# ordinary binding here and a repaint loop there. Two details only show up at
# this size — `Shape.CurveRenderer`, because geometry tessellation quantises a
# 2px stroke into a smudge, and round caps, which stop a short arc from
# reading as a chip of dust.

{
  quickshell.widgets.Dial = ''
    import QtQuick
    import QtQuick.Shapes
    import "../Common"

    Item {
        id: root

        // [{ value: 0-100, color: <color> }] — outermost first.
        property var rings: []

        property real core:      4.0    // the hole left in the middle
        property real thickness: 2.0
        property real gap:       1.4
        property real maxSize:   28
        property real outer:     0      // fixed width; 0 lets the list decide

        // Open at the bottom: 135 degrees is 7:30, sweeping clockwise to 4:30.
        property real startAngle: 135
        property real travel:     270

        // Drawn under each ring, a little wider, when something is burning
        // behind the dial. Without it the fire and the arcs are the same
        // orange at the same brightness and the gauge disappears into the
        // flame — the reference this copies solves the same problem by
        // outlining its battery. Dark rather than light, because the glass
        // behind is dark.
        property bool knockout: false

        readonly property int  count: rings.length
        readonly property real step:  thickness + gap
        readonly property real ideal: 2 * (core + count * step)
        readonly property real size:  outer > 0 ? outer : Math.min(ideal, maxSize)
        // Only bites once the dial has hit its ceiling.
        readonly property real squeeze: outer > 0 || ideal <= maxSize ? 1 : maxSize / ideal

        implicitWidth:  size
        implicitHeight: size

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
                readonly property real width_: root.thickness * root.squeeze
                readonly property real radius: root.size / 2 - width_ / 2
                                             - index * root.step * root.squeeze

                readonly property real sweep:
                    root.travel * Math.max(0, Math.min(100, modelData.value)) / 100

                ShapePath {
                    strokeColor: root.knockout ? Qt.rgba(0.02, 0.025, 0.04, 0.92) : "transparent"
                    strokeWidth: ring.width_ + 2.6
                    fillColor:   "transparent"
                    capStyle:    ShapePath.RoundCap
                    PathAngleArc {
                        centerX: ring.mid; centerY: ring.mid
                        radiusX: ring.radius; radiusY: ring.radius
                        startAngle: root.startAngle; sweepAngle: root.travel
                    }
                }

                // The groove, always the full travel, so an empty gauge still
                // says where full would be.
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.12)
                    strokeWidth: ring.width_
                    fillColor:   "transparent"
                    capStyle:    ShapePath.RoundCap
                    PathAngleArc {
                        centerX: ring.mid; centerY: ring.mid
                        radiusX: ring.radius; radiusY: ring.radius
                        startAngle: root.startAngle; sweepAngle: root.travel
                    }
                }

                ShapePath {
                    strokeColor: ring.modelData.color
                    strokeWidth: ring.width_
                    fillColor:   "transparent"
                    capStyle:    ShapePath.RoundCap
                    PathAngleArc {
                        centerX: ring.mid; centerY: ring.mid
                        radiusX: ring.radius; radiusY: ring.radius
                        startAngle: root.startAngle
                        sweepAngle: ring.sweep
                        Behavior on sweepAngle {
                            NumberAnimation { duration: 460; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
  '';
}
