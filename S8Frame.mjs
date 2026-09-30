// Kontrol S8 display frame: 16-byte header, run-length coded RGB565 pixel
// pairs, 8-byte footer. Format from the kontrol-s8-protocol notes
// (github.com/gusgustavodj/kontrol-s8-protocol, CC-BY-4.0). Pixels arrive
// big-endian RGB565 from Mixxx (<screen pixelType="RGB565" endian="big">).

export const WIDTH = 480;
export const HEIGHT = 272;
const PAIRS = (WIDTH * HEIGHT) / 2;
const MAX_RUN = 0xFFFF;

// screen: 0 = left, 1 = right. input: ArrayBuffer of WIDTH*HEIGHT*2 bytes.
export function encode(screen, input) {
    const bytes = new Uint8Array(input);
    if (bytes.length !== WIDTH * HEIGHT * 2) {
        throw new Error(`S8Frame: expected ${WIDTH * HEIGHT * 2} bytes, got ${bytes.length}`);
    }
    // One 32-bit word per pixel pair; only compared for equality, so the
    // host byte order does not matter.
    const words = new Uint32Array(bytes.buffer, bytes.byteOffset, PAIRS);
    // Worst case: alternating runs of 2 repeated pairs and 1 literal pair.
    const out = new Uint8Array(16 + PAIRS * 6 + 8);
    out.set([0x84, 0, screen, 0x60, 0, 0, 0, 0, 0, 0, 0, 0,
        WIDTH >> 8, WIDTH & 0xFF, HEIGHT >> 8, HEIGHT & 0xFF]);
    let o = 16;
    let i = 0;
    while (i < PAIRS) {
        let j = i + 1;
        while (j < PAIRS && words[j] === words[i] && j - i < MAX_RUN) {
            j++;
        }
        if (j - i >= 2) {
            const run = j - i;
            out[o++] = 0x01; out[o++] = 0; out[o++] = run >> 8; out[o++] = run & 0xFF;
            out.set(bytes.subarray(i * 4, i * 4 + 4), o); o += 4;
            i = j;
            continue;
        }
        // Literal run until the next pair that starts a repeat.
        const start = i;
        i++;
        while (i < PAIRS && i - start < MAX_RUN && !(i + 1 < PAIRS && words[i + 1] === words[i])) {
            i++;
        }
        const count = i - start;
        out[o++] = 0x00; out[o++] = 0; out[o++] = count >> 8; out[o++] = count & 0xFF;
        out.set(bytes.subarray(start * 4, i * 4), o); o += count * 4;
    }
    out.set([0x03, 0, 0, 0, 0x40, 0, screen, 0], o); o += 8;
    return out.buffer.slice(0, o);
}

// Inverse, for tests.
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
