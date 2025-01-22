// npm-run-path@4.0.1 downloaded from https://ga.jspm.io/npm:npm-run-path@4.0.1/index.js

import e from"path";import t from"path-key";import o from"process";var n={};var r=o;const c=e;const s=t;const npmRunPath=e=>{e={cwd:r.cwd(),path:r.env[s()],execPath:r.execPath,...e};let t;let o=c.resolve(e.cwd);const n=[];while(t!==o){n.push(c.join(o,"node_modules/.bin"));t=o;o=c.resolve(o,"..")}const a=c.resolve(e.cwd,e.execPath,"..");n.push(a);return n.concat(e.path).join(c.delimiter)};n=npmRunPath;n.default=npmRunPath;n.env=e=>{e={env:r.env,...e};const t={...e.env};const o=s({env:t});e.path=t[o];t[o]=n(e);return t};var a=n;const p=n.env;export default a;export{p as env};

