import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {decode, WIDTH, HEIGHT} from "./s8decode.mjs";

// Test the encoder exactly as it ships: extracted from the QML file.
const qml = readFileSync(new URL("../KontrolS8Screen.qml", import.meta.url), "utf8");
const body = qml.split("// S8FRAME-BEGIN")[1].split("// S8FRAME-END")[0];
const fns = new Function(body.replace(/^[^\n]*\n/, "") + "\nreturn {s8Encode, s8EncodeRaw};")();
const encoders = {rle: fns.s8Encode, raw: fns.s8EncodeRaw};

const size = WIDTH * HEIGHT * 2;

function roundTrip(name, fill) {
  for (const [kind, encode] of Object.entries(encoders)) {
    const px = new Uint8Array(size);
    fill(px);
    const frame = encode(1, px.buffer);
    const back = decode(frame);
    assert.equal(back.screen, 1, name + ": screen");
    assert.equal(back.width, WIDTH, name + ": width");
    assert.equal(back.height, HEIGHT, name + ": height");
    assert.equal(back.used, size, name + ": pixel count");
    assert.deepEqual(new Uint8Array(back.pixels), px, name + ": pixels");
    const f = new Uint8Array(frame);
    assert.deepEqual([...f.subarray(0, 4)], [0x84, 0, 1, 0x60], name + ": header");
    assert.deepEqual([...f.subarray(f.length - 8)], [0x03, 0, 0, 0, 0x40, 0, 1, 0], name + ": footer");
    console.log(`${(kind + " " + name).padEnd(14)} ok  ${f.length} bytes`);
  }
}

roundTrip("black", () => {});
roundTrip("noise", (px) => { for (let i = 0; i < px.length; i++) px[i] = (i * 2654435761) >>> 24; });
roundTrip("stripes", (px) => { for (let i = 0; i < px.length; i += 4) px.fill((i / 4) % 7 < 3 ? 0xF8 : 0x07, i, i + 4); });
roundTrip("mixed", (px) => { for (let i = 0; i < px.length; i++) px[i] = i % 960 < 480 ? 0x33 : (i * 31) & 0xFF; });
