// path-key@3.1.1 downloaded from https://ga.jspm.io/npm:path-key@3.1.1/index.js

import e from"process";var r={};var t=e;const pathKey=(e={})=>{const r=e.env||t.env;const o=e.platform||t.platform;return"win32"!==o?"PATH":Object.keys(r).reverse().find(e=>"PATH"===e.toUpperCase())||"Path"};r=pathKey;r.default=pathKey;var o=r;export default o;

