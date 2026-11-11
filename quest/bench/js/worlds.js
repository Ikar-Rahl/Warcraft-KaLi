// Real screenshots from Ikar's client behind the trackers. They hold the game's own tracker and frozen tooltips, so
// each lists the rectangles to paint over and where to copy clean ground from, in the image's pixels.
window.Worlds = (function () {
  // The game's screen is 1200 UI units tall at Ikar's UI scale, whatever the resolution.
  const SCREEN_UNITS = 1200;

  const LIST = {
    "snow-day": { label: "Snow, day (brightest)", file: "art/world/snow-day.jpg", right: 5, erase: [
      { x: 3321, y: 491, w: 543, h: 243, fromY: 1000 },
      { x: 3441, y: 761, w: 158, h: 118, fromY: 1000 },
    ] },
    "snow-dusk": { label: "Snow, dusk", file: "art/world/snow-dusk.jpg", right: 5, erase: [
      { x: 3321, y: 491, w: 543, h: 349, fromY: 1000 },
      { x: 3359, y: 1704, w: 505, h: 326, fromX: 2902 },
    ] },
    "troll-camp": { label: "Troll camp", file: "art/world/troll-camp.jpg", right: 5, erase: [
      { x: 3321, y: 491, w: 543, h: 263, fromY: 1000 },
      { x: 3359, y: 1679, w: 505, h: 351, fromX: 2902 },
    ] },
    "snow-night": { label: "Snow, night", file: "art/world/snow-night.jpg", right: 5, erase: [
      { x: 3321, y: 491, w: 543, h: 243, fromY: 1000 },
    ] },
    "cave": { label: "Cave, with side bars", file: "art/world/cave.jpg", right: 55, erase: [
      { x: 3240, y: 500, w: 511, h: 690, fromX: 2720, feather: 8 },
      { x: 3493, y: 1742, w: 371, h: 288, fromX: 3120 },
    ] },
  };

  const images = new Map();

  function load(src) {
    if (!images.has(src)) {
      images.set(src, new Promise((resolve) => {
        const img = new Image();
        img.onload = () => resolve(img);
        img.onerror = () => resolve(null);
        img.src = src;
      }));
    }
    return images.get(src);
  }

  // Copies clean ground over the rectangle with soft edges, so no seam shows between the rows.
  function erase(ctx, img, { x, y, w, h, fromX = x, fromY = y, feather = 24 }) {
    const patch = document.createElement("canvas");
    patch.width = w;
    patch.height = h;
    const c = patch.getContext("2d");
    c.drawImage(img, fromX, fromY, w, h, 0, 0, w, h);
    c.globalCompositeOperation = "destination-in";
    [[w, 0, w], [0, h, h]].forEach(([x1, y1, length]) => {
      const fade = c.createLinearGradient(0, 0, x1, y1);
      fade.addColorStop(0, "rgba(0,0,0,0)");
      fade.addColorStop(feather / length, "#000");
      fade.addColorStop(1 - feather / length, "#000");
      fade.addColorStop(1, "rgba(0,0,0,0)");
      c.fillStyle = fade;
      c.fillRect(0, 0, w, h);
    });
    ctx.drawImage(patch, x, y);
  }

  // Draws at the game's true size against the top right corner, so the minimap and the tracker keep their real places.
  async function paint(canvas, id, src, rectangles = []) {
    canvas.dataset.world = id;
    const img = await load(src);
    if (!img || canvas.dataset.world !== id) return;
    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;
    canvas.style.height = SCREEN_UNITS + "px";
    canvas.style.width = SCREEN_UNITS * img.naturalWidth / img.naturalHeight + "px";
    const ctx = canvas.getContext("2d");
    ctx.drawImage(img, 0, 0);
    rectangles.forEach((rectangle) => erase(ctx, img, rectangle));
  }

  return { LIST, paint };
})();
