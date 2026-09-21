{ ... }:

# Widgets/Flame.qml — one connected silhouette with several tongues.
#
# Separate tongues were the first attempt and they do not survive the bar: at
# 26px each one is three pixels wide and the group reads as a comb. A single
# closed outline with pinched valleys keeps its shape all the way down,
# because what you recognise at that size is the silhouette, not the parts.
#
# The path is built in JS through PathSvg rather than declared as a fixed run
# of PathCubic elements, so the tongue count is a property rather than a
# rewrite, and everything animates by recomputing one string.
#
# The curve is the whole trick, and it is easy to get wrong: both control
# points on the straight line from base to tip give a triangle, which is what
# the first three attempts drew. The low control has to sit OUTSIDE the base
# so the flank bulges, and the high one tucks under the tip so it pulls back
# in. That pair is the difference between a flame and a mountain range.
#
# One phase drives everything. Each tongue reads it through its own frequency
# and offset, so they breathe out of step without a timer each, and the mass
# never repeats on a period you can see.

{
  quickshell.widgets.Flame = ''
    import QtQuick
    import QtQuick.Shapes

    Item {
        id: root

        property int  tongues: 3
        property bool burning: false

        property real reach:    0.94   // the tallest tongue, as a fraction of height
        property real shoulder: 0.46   // the outer ones, relative to that
        property real valley:   0.30   // where the outline dips between them
        property real flare:    0.45   // how far outside the base the flank bulges
        property real belly:    0.38   // how high that bulge sits
        property real neck:     0.86   // how high the tip control tucks in
        property real waist:    0.06   // and how close to the tip it sits

        // Deep at the base, bright at the tips. `inner` is the second, hotter
        // body the reference has burning inside the first.
        property bool inner: false

        property real phase: 0
        opacity: burning ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 260 } }

        // Fixed, unrelated multipliers. Anything periodic shared between
        // tongues shows up as a wave travelling along the fire.
        readonly property var fq:  [1.00, 1.37, 0.81, 1.62, 1.19, 0.93, 1.44]
        readonly property var fq2: [0.63, 0.92, 1.24, 0.77, 1.08, 1.35, 0.85]
        readonly property var off: [0.0,  2.1,  4.3,  1.2,  5.4,  3.1,  0.6]

        function outline() {
            var w = width, h = height, n = root.tongues, step = w / n;
            var tall = [], lean = [];

            for (var i = 0; i < n; i++) {
                var wob  = Math.sin(root.phase * root.fq[i % 7]  + root.off[i % 7]);
                var wob2 = Math.sin(root.phase * root.fq2[i % 7] + root.off[(i + 3) % 7]);
                // Middle tongues stand taller than the shoulders.
                var centre = 1 - Math.abs((i + 0.5) / n - 0.5) * 2;
                var span = root.reach * (root.shoulder + (1 - root.shoulder) * centre);
                tall.push(h * span * (0.82 + 0.18 * wob));
                lean.push(step * 0.22 * wob2);
            }

            var p = "M 0 " + h.toFixed(2);
            for (i = 0; i < n; i++) {
                var left = step * i, right = step * (i + 1);
                var tipX = left + step * 0.5 + lean[i];
                var ph   = tall[i];

                p += " C " + (left - step * root.flare).toFixed(2)
                   + " "   + (h - ph * root.belly).toFixed(2)
                   + ", "  + (tipX - step * root.waist).toFixed(2)
                   + " "   + (h - ph * root.neck).toFixed(2)
                   + ", "  + tipX.toFixed(2) + " " + (h - ph).toFixed(2);

                var last = (i === n - 1);
                var vh = last ? 0 : root.valley * Math.min(ph, tall[i + 1]);

                p += " C " + (tipX + step * root.waist).toFixed(2)
                   + " "   + (h - ph * root.neck).toFixed(2)
                   + ", "  + (right + step * root.flare).toFixed(2)
                   + " "   + (h - vh - ph * root.belly * 0.55).toFixed(2)
                   + ", "  + right.toFixed(2) + " " + (h - vh).toFixed(2);
            }
            return p + " L " + w.toFixed(2) + " " + h.toFixed(2) + " Z";
        }

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                // The bottom two stops fade to nothing. Without them the
                // outline closes along the foot of the item and the fire
                // reads as sitting on an invisible shelf — a straight edge is
                // the one thing a flame never has.
                fillGradient: LinearGradient {
                    x1: 0; y1: root.height; x2: 0; y2: 0
                    GradientStop { position: 0.00; color: root.inner ? "#00F4661A" : "#00A81704" }
                    GradientStop { position: 0.16; color: root.inner ? "#C8F4661A" : "#D2A81704" }
                    GradientStop { position: 0.40; color: root.inner ? "#FF9B2A"   : "#E04E0D" }
                    GradientStop { position: 0.72; color: root.inner ? "#FFD063"   : "#FF8A1E" }
                    GradientStop { position: 1.00; color: root.inner ? "#FFF1B8"   : "#FFC94A" }
                }
                PathSvg { path: root.outline() }
            }
        }

        // Stopped when cold, or a hidden fire keeps rebuilding a path string
        // sixty times a second for nothing.
        NumberAnimation on phase {
            from: 0; to: 2 * Math.PI
            duration: 3400
            loops: Animation.Infinite
            running: root.burning
        }
    }
  '';
}
