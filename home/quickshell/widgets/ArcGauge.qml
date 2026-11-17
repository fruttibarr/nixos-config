import QtQuick
import "root:/"

// A small ring gauge. Reads a 0-100 value as a swept arc so CPU/RAM/temp can
// be scanned by shape at a glance instead of parsed as three numbers.
Item {
    id: root

    property real value: 0          // 0-100
    property string label: ""       // glyph drawn in the middle
    property color arcColor: Colors.primary
    property real thickness: 2.5
    property real labelSize: 9
    property color labelColor: Colors.textDim

    implicitWidth: 26
    implicitHeight: 26

    onValueChanged: canvas.requestPaint()
    onArcColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();

            const cx = width / 2;
            const cy = height / 2;
            const r = Math.min(width, height) / 2 - root.thickness;

            // Leave a gap at the bottom so the ring reads as a gauge.
            const start = Math.PI * 0.75;
            const sweep = Math.PI * 1.5;
            const frac = Math.max(0, Math.min(1, root.value / 100));

            ctx.lineCap = "round";
            ctx.lineWidth = root.thickness;

            ctx.beginPath();
            // A faint track reads better on the near-black island than
            // the opaque outline colour did.
            ctx.strokeStyle = Qt.rgba(
                Colors.text.r, Colors.text.g, Colors.text.b, 0.10);
            ctx.arc(cx, cy, r, start, start + sweep);
            ctx.stroke();

            if (frac > 0.001) {
                ctx.beginPath();
                ctx.strokeStyle = root.arcColor;
                ctx.arc(cx, cy, r, start, start + sweep * frac);
                ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.labelColor
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: root.labelSize
    }
}
