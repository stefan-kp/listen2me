// shebang-command@2.0.0 downloaded from https://ga.jspm.io/npm:shebang-command@2.0.0/index.js

import t from"shebang-regex";var r={};const e=t;r=(t="")=>{const r=t.match(e);if(!r)return null;const[n,o]=r[0].replace(/#! ?/,"").split(" ");const p=n.split("/").pop();return"env"===p?o:o?`${p} ${o}`:p};var n=r;export default n;

