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
# The profile is `(1 - t^cusp)^flank` over `t = |2c-1|`, and it needs both
# exponents. `cusp` below 1 sharpens the apex; `flank` below 1 makes the
# tongue leave the line steeply instead of easing away from it. Together they
# give a flank that is convex at the base and concave under the tip — the S a
# flame has. One exponent alone gives either a triangle or a petal.
#
# Neither may go above 1. At exactly 1 the tongue is a straight-sided triangle;
# above it the curve goes TANGENTIALLY FLAT at that end, which rounds off the
# very thing the name says it sharpens.
#
# `density` carries more of the look than either exponent. It is tongues per
# unit of radius, so it holds the tongue WIDTH roughly constant as the dial
# grows, and width against height is what decides whether this reads as fire,
# as a row of petals or as a comb. Below about 0.5 the tongues are wider than
# they are tall and scallop; at 0.38 with gaps between they read as spikes on
# a wire.
#
# The version before this one tiled the arc into equal slots and drew one
# tongue in each. That can only ever look like a row of strings, however the
# individual tongue is shaped, because every tongue is the same width and
# equally spaced. Tongues now carry their own centre, width and height, they
# overlap, and the outline is the max of them — one uneven body, with a few
# heads standing out of it. `gamma` is what makes those heads rare: heights
# are raised to it, so most tongues sit low and a few reach.
#
# Sampling density does almost nothing — the apex sits near the centre of its
# slot and a sample lands close to it either way. Worth knowing before spending
# an afternoon on it.
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
        property real density:  1.8   // tongues per unit of radius
        property real cusp:     0.50  // below 1 for a pointed apex
        property real flank:    0.60  // below 1 for flanks that leave the line steeply
        property real bed:      0.12  // the sheath that runs the whole lit length
        property real skew:     0.70  // lean
        property real floorFrac: 0.10 // the shortest tongue, against the tallest
        property real gamma:    3.0   // how rare a tall head is
        property real spread:   0.9   // how much tongue widths vary
        property real jitter:   0.45  // how far a tongue sits off its nominal place
        property real bend:     0.85  // how hard tips are pulled upright
        property real lick:     3.0   // how far a tip drifts along the arc
        property int  samples:  8     // polyline points per tongue

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
        readonly property var fq3: [0.71, 1.13, 0.88, 1.47, 0.66, 1.29, 1.02]
        readonly property var of2: [1.7,  3.9,  0.4,  5.1,  2.6,  4.8,  1.1]

        readonly property real root_: radius + thickness * 0.5

        function firePath() {
            if (root.sweepAngle <= 0 || root.amplitude <= 0) return "";

            var cx = root.centreX, cy = root.centreY;
            var r0 = root.root_;
            var K = Math.max(2, root.tongues);
            var N = K * root.samples;
            var rad = Math.PI / 180;

            // Tongues are not slots. Each has its own centre, width and
            // height, they overlap, and the outline is the MAX of them. That
            // is the whole difference between one uneven body of fire with a
            // few heads standing out of it and a row of separate strings:
            // tiling the arc into equal slots can only ever produce the
            // second, however the individual tongue is shaped.
            var cen = [], halfw = [], tall = [], drift = [];
            var baseW = 1 / K;
            for (var i = 0; i < K; i++) {
                var w1 = Math.sin(root.phase * root.fq[i % 7]  + root.off[i % 7]);
                var w2 = Math.sin(root.phase * root.fq2[i % 7] + root.of2[i % 7]);
                var w3 = Math.sin(root.phase * root.fq3[i % 7] + root.off[(i + 3) % 7]);

                cen.push((i + 0.5) / K + baseW * root.jitter * w2);
                halfw.push(baseW * (0.55 + root.spread * (0.5 + 0.5 * w3)));
                // Raised to gamma, so most tongues sit low and a few reach.
                // Linear height gives an even hedge.
                tall.push(root.amplitude * (root.floorFrac + (1 - root.floorFrac)
                          * Math.pow(0.5 + 0.5 * w1, root.gamma)));
                drift.push(root.lick * w2);
            }

            var out = [], back = [];
            for (var j = 0; j <= N; j++) {
                var s = j / N;

                var h = root.bed * root.amplitude;
                var lean = 0;
                for (i = 0; i < K; i++) {
                    var d = (s - cen[i]) / halfw[i];
                    if (d <= -1 || d >= 1) continue;
                    var t = Math.abs(Math.pow((d + 1) * 0.5, root.skew) * 2 - 1);
                    var hh = tall[i] * Math.pow(1 - Math.pow(t, root.cusp), root.flank);
                    // Whichever tongue is tallest here owns this point, and
                    // its drift is what leans the tip.
                    if (hh > h) { h = hh; lean = drift[i]; }
                }

                var a  = (root.startAngle + root.sweepAngle * s
                          + lean * (h / root.amplitude)) * rad;
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
