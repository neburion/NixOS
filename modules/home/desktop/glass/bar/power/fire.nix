{ ... }:

# Widgets/ArcFire.qml — a lit arc. The line burns; there is no fire behind it.
#
# The first version was a flame silhouette drawn behind the whole dial, which
# turned the widget into a fire with a gauge in it. This one is bound to one
# arc: tongues root on that arc's outer edge, along however much of it is
# filled, and nothing is drawn anywhere else. A ring at 40% burns for 40% of
# its travel.
#
# The tongue profile is built in arc-length space and then mapped to polar,
# which is why there is no Bezier here — control points do not survive that
# map, and a polyline at eight samples per tongue is already smoother than
# 26px can show.
#
# The profile is `1 - |2c-1|^cusp` with cusp below 1, which took three tries to
# arrive at. `sin(pi*c)^n` stays round on top however hard n is pushed, and a
# ring of round bumps is a cog; this one has concave flanks and an actual point
# at the apex. It is also zero at both ends of its slot, so every tongue meets
# the line rather than floating off it.
#
# Each tongue occupies only the middle `wfrac` of its slot, leaving bare line
# between them. Without that the tongues merge into a lumpy sausage — they were
# as wide as they were tall, and that aspect ratio reads as lumps no matter
# what the profile does. `wfrac` is the knob that decides sharp against bubbly,
# far more than `cusp` does: a third of the slot is a lick, half is a blister.
#
# `cusp` cannot go above 1. At exactly 1 the tongue is a straight-sided
# triangle; below it the flanks tuck in and the point gets finer; above it the
# apex goes TANGENTIALLY FLAT and rounds off, which is the opposite of what the
# name suggests.
#
# Sampling density does not matter, which is worth knowing before spending an
# afternoon on it — the apex sits at the centre of its slot and a sample always
# lands on it, so 8 points per slot and 24 render identically.
#
# Two details that make it fire rather than a starburst: `bend` pulls every
# tip toward vertical, because flames rise and a purely radial one at the
# bottom of a ring would point at the floor; and the gradient is RADIAL about
# the dial's own centre, so hot-at-the-root and pale-at-the-tip is true all
# the way round instead of only along one axis.

{
  quickshell.widgets.ArcFire = ''
    import QtQuick
    import QtQuick.Shapes

    Item {
        id: root

        property real centreX:    0
        property real centreY:    0
        property real radius:     0     // the arc's centre line
        property real thickness:  2     // the arc's own stroke width
        property real startAngle: 135
        property real sweepAngle: 0     // the lit length, not the full travel

        property color base:      "#FF5A3C"
        property real  amplitude: 4     // the tallest tongue

        // Shape. Defaults are the ones that survived the sweep; the only knob
        // a caller normally touches is `amplitude`.
        property real density:  0.38  // tongues per unit of radius
        property real wfrac:    0.32  // how much of its slot a tongue fills
        property real cusp:     0.75  // below 1 for a pointed apex
        property real skew:     0.70  // lean
        property real floorFrac: 0.30 // the shortest tongue, against the tallest
        property real bend:     0.85  // how hard tips are pulled upright
        property real lick:     3.0   // how far a tip drifts along the arc
        property int  samples:  12    // polyline points per tongue slot

        readonly property int tongues: Math.max(3, Math.round(radius * density))

        property bool burning: false

        opacity: burning ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 280 } }

        property real phase: 0

        // Unrelated multipliers. Anything periodic shared between tongues
        // shows up as a wave travelling around the ring.
        readonly property var fq:  [1.00, 1.37, 0.81, 1.62, 1.19, 0.93, 1.44]
        readonly property var fq2: [0.63, 0.92, 1.24, 0.77, 1.08, 1.35, 0.85]
        readonly property var off: [0.0,  2.1,  4.3,  1.2,  5.4,  3.1,  0.6]

        readonly property real root_: radius + thickness * 0.5

        function firePath() {
            if (root.sweepAngle <= 0 || root.amplitude <= 0) return "";

            var cx = root.centreX, cy = root.centreY;
            var r0 = root.root_;
            var K = Math.max(2, root.tongues);
            var N = K * root.samples;
            var rad = Math.PI / 180;

            var out = [], back = [];
            for (var j = 0; j <= N; j++) {
                var s = j / N;
                var t = s * K;
                var i = Math.min(K - 1, Math.floor(t));
                var u = t - i;

                var wob  = Math.sin(root.phase * root.fq[i % 7]  + root.off[i % 7]);
                var wob2 = Math.sin(root.phase * root.fq2[i % 7] + root.off[(i + 3) % 7]);

                var peak = root.amplitude
                         * (root.floorFrac + (1 - root.floorFrac) * (0.5 + 0.5 * wob));

                // Bare line either side of the tongue inside its own slot.
                var c = (u - (1 - root.wfrac) * 0.5) / root.wfrac;
                var h = 0;
                if (c > 0 && c < 1) {
                    var cs = Math.pow(c, root.skew);
                    h = peak * (1 - Math.pow(Math.abs(2 * cs - 1), root.cusp));
                }

                // The tip drifts along the arc as well as away from it.
                var a  = (root.startAngle + root.sweepAngle * s
                          + root.lick * wob2 * (h / root.amplitude)) * rad;
                var ab = (root.startAngle + root.sweepAngle * s) * rad;
                var rr = r0 + h;

                out.push([cx + rr * Math.cos(a), cy + rr * Math.sin(a) - root.bend * h]);
                back.push([cx + r0 * Math.cos(ab), cy + r0 * Math.sin(ab)]);
            }

            var p = "M " + out[0][0].toFixed(2) + " " + out[0][1].toFixed(2);
            for (j = 1; j <= N; j++) p += " L " + out[j][0].toFixed(2) + " " + out[j][1].toFixed(2);
            for (j = N; j >= 0; j--) p += " L " + back[j][0].toFixed(2) + " " + back[j][1].toFixed(2);
            return p + " Z";
        }

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: root.centreX; centerY: root.centreY
                    centerRadius: root.root_ + root.amplitude
                    focalX: root.centreX; focalY: root.centreY
                    // Position is a fraction of centerRadius, so the root of
                    // the flames has to be placed where the line actually is.
                    GradientStop {
                        position: root.root_ / (root.root_ + root.amplitude)
                        color: root.base
                    }
                    GradientStop {
                        position: root.root_ / (root.root_ + root.amplitude) * 0.30 + 0.52
                        color: "#FF9B2A"
                    }
                    GradientStop { position: 0.88; color: "#FFFFD166" }
                    GradientStop { position: 1.00; color: "#00FFE7B0" }
                }
                PathSvg { path: root.firePath() }
            }
        }

        // Stopped when cold, or a hidden fire rebuilds a path string sixty
        // times a second for nothing.
        NumberAnimation on phase {
            from: 0; to: 2 * Math.PI
            duration: 2600
            loops: Animation.Infinite
            running: root.burning
        }
    }
  '';
}
