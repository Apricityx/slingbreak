(() => {
  'use strict';
  // Chrome 89 cannot mix CSS colours. RGB companion tokens let CSS do the same
  // sRGB interpolation with calc(), without observers, layout reads or per-frame JS.
  const channels = value => {
    const hex = String(value).trim().replace(/^#/, '');
    if (!/^(?:[\da-f]{3}|[\da-f]{6})$/i.test(hex)) throw new TypeError('Expected an opaque hex colour: ' + value);
    const full = hex.length === 3 ? hex.split('').map(c => c + c).join('') : hex;
    return [0, 2, 4].map(i => parseInt(full.slice(i, i + 2), 16));
  };
  const style = (name, value) => {
    const rgb = channels(value);
    return `${name}:${value};${rgb.map((n, i) => `${name}-${'rgb'[i]}:${n}`).join(';')};`;
  };
  const set = (element, name, value) => {
    const rgb = channels(value);
    element.style.setProperty(name, value);
    rgb.forEach((n, i) => element.style.setProperty(name + '-' + 'rgb'[i], n));
  };
  window.SlingColors = {channels, style, set};
})();
