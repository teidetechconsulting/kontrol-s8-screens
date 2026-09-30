// Decoder for tests (inverse of the encoder in KontrolS8Screen.qml).
export const WIDTH = 480;
export const HEIGHT = 272;

export function decode(frame) {
    const b = new Uint8Array(frame);
    const pixels = new Uint8Array(WIDTH * HEIGHT * 2);
    let o = 16, p = 0;
    while (b[o] !== 0x03) {
        const count = (b[o + 2] << 8) | b[o + 3];
        if (b[o] === 0x01) {
            for (let k = 0; k < count; k++) { pixels.set(b.subarray(o + 4, o + 8), p); p += 4; }
            o += 8;
        } else {
            pixels.set(b.subarray(o + 4, o + 4 + count * 4), p); p += count * 4;
            o += 4 + count * 4;
        }
    }
    return {screen: b[2], width: (b[12] << 8) | b[13], height: (b[14] << 8) | b[15], pixels: pixels.buffer, used: p};
}
