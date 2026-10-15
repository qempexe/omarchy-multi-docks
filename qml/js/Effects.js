.pragma library

// Auto-hide effects, shared by the docks and by the little previews in the
// settings. `t` runs from 0 (dock fully shown) to 1 (dock fully hidden) and
// may overshoot a little with the springy easings. `dist` is how far a sliding
// dock travels toward the screen edge.
//
//   off      distance moved toward the edge
//   opacity  of the whole dock
//   scale    uniform scale (origin: the edge, or the center for "pop")
//   fold     scale across the dock's thickness, squashed onto the edge
//   bg       how much of the background is drawn (wave fades it on its own)
function state(effect, t, dist) {
  const c = Math.max(0, Math.min(1, t));
  const s = { off: 0, opacity: 1, scale: 1, fold: 1, bg: 1, center: false };
  switch (effect) {
  case "fade":
    s.opacity = 1 - c;
    break;
  case "glide":
    s.off = t * dist;
    s.opacity = 1 - c;
    break;
  case "zoom":
    s.scale = Math.max(0.01, 1 - 0.4 * t);
    s.opacity = 1 - c;
    break;
  case "fold":
    s.fold = Math.max(0.01, 1 - t);
    s.opacity = 1 - 0.5 * c;
    break;
  case "pop":
    s.scale = Math.max(0.01, 1 - t);
    s.opacity = 1 - c;
    s.center = true;
    break;
  case "wave":
    s.bg = 1 - c;
    break;
  default:          // slide, bounce
    s.off = t * dist;
  }
  return s;
}

// Effects whose easing springs past the end point.
function springy(effect) { return effect === "bounce" || effect === "pop"; }

// Friendly names for the settings.
var labels = {
  slide: "Slide", fade: "Fade", glide: "Glide", zoom: "Zoom",
  fold: "Fold", bounce: "Bounce", pop: "Pop", wave: "Wave"
};
