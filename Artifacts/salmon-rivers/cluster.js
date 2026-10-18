(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.Cluster = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /* Greedy pin clustering on a grid. Points arrive best-first. The best unused point opens a group and takes every other unused point
     within `radius` pixels, except that the selected point is never grouped. This is the same rule the page used before, but a point
     only looks at its own cell and the eight around it, so the cost grows with the number of points, not its square. */
  function group(pts, radius, selectedId) {
    var cell = radius, grid = new Map(), i, p, k;
    for (i = 0; i < pts.length; i++) {
      p = pts[i];
      k = Math.floor(p.x / cell) + ',' + Math.floor(p.y / cell);
      var bucket = grid.get(k);
      if (bucket) bucket.push(i); else grid.set(k, [i]);
    }
    var used = new Uint8Array(pts.length), groups = [];
    for (i = 0; i < pts.length; i++) {
      if (used[i]) continue;
      p = pts[i];
      used[i] = 1;
      var g = [p];
      if (p.id !== selectedId) {
        var cx = Math.floor(p.x / cell), cy = Math.floor(p.y / cell), found = [];
        for (var dx = -1; dx <= 1; dx++) for (var dy = -1; dy <= 1; dy++) {
          var b = grid.get((cx + dx) + ',' + (cy + dy));
          if (!b) continue;
          for (var n = 0; n < b.length; n++) {
            var j = b[n];
            if (used[j] || pts[j].id === selectedId) continue;
            if (Math.hypot(p.x - pts[j].x, p.y - pts[j].y) < radius) found.push(j);
          }
        }
        found.sort(function (a, c) { return a - c; });
        for (n = 0; n < found.length; n++) { used[found[n]] = 1; g.push(pts[found[n]]); }
      }
      groups.push(g);
    }
    return groups;
  }

  return { group: group };
});
