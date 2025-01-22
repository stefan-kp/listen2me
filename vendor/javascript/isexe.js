// isexe@2.0.0 downloaded from https://ga.jspm.io/npm:isexe@2.0.0/index.js

import e from"fs";import t from"process";var r={};var n=t;r=isexe;isexe.sync=sync;var i=e;function checkPathExt(e,t){var r=void 0!==t.pathExt?t.pathExt:n.env.PATHEXT;if(!r)return true;r=r.split(";");if(-1!==r.indexOf(""))return true;for(var i=0;i<r.length;i++){var a=r[i].toLowerCase();if(a&&e.substr(-a.length).toLowerCase()===a)return true}return false}function checkStat(e,t,r){return!(!e.isSymbolicLink()&&!e.isFile())&&checkPathExt(t,r)}function isexe(e,t,r){i.stat(e,(function(n,i){r(n,!n&&checkStat(i,e,t))}))}function sync(e,t){return checkStat(i.statSync(e),e,t)}var a=r;var c={};var o=t;c=isexe$1;isexe$1.sync=sync$1;var s=e;function isexe$1(e,t,r){s.stat(e,(function(e,n){r(e,!e&&checkStat$1(n,t))}))}function sync$1(e,t){return checkStat$1(s.statSync(e),t)}function checkStat$1(e,t){return e.isFile()&&checkMode(e,t)}function checkMode(e,t){var r=e.mode;var n=e.uid;var i=e.gid;var a=void 0!==t.uid?t.uid:o.getuid&&o.getuid();var c=void 0!==t.gid?t.gid:o.getgid&&o.getgid();var s=parseInt("100",8);var f=parseInt("010",8);var u=parseInt("001",8);var v=s|f;var d=r&u||r&f&&i===c||r&s&&n===a||r&v&&0===a;return d}var f=c;var u="undefined"!==typeof globalThis?globalThis:"undefined"!==typeof self?self:global;var v={};var d=t;var l=e;var h;h="win32"===d.platform||u.TESTING_WINDOWS?a:f;v=isexe$2;isexe$2.sync=sync$2;function isexe$2(e,t,r){if("function"===typeof t){r=t;t={}}if(!r){if("function"!==typeof Promise)throw new TypeError("callback not provided");return new Promise((function(r,n){isexe$2(e,t||{},(function(e,t){e?n(e):r(t)}))}))}h(e,t||{},(function(e,n){if(e&&("EACCES"===e.code||t&&t.ignoreErrors)){e=null;n=false}r(e,n)}))}function sync$2(e,t){try{return h.sync(e,t||{})}catch(e){if(t&&t.ignoreErrors||"EACCES"===e.code)return false;throw e}}var y=v;export default y;

