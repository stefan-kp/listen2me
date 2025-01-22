// merge-stream@2.0.0 downloaded from https://ga.jspm.io/npm:merge-stream@2.0.0/index.js

import r from"stream";var e={};const{PassThrough:n}=r;e=function(){var r=[];var e=new n({objectMode:true});e.setMaxListeners(0);e.add=add;e.isEmpty=isEmpty;e.on("unpipe",remove);Array.prototype.slice.call(arguments).forEach(add);return e;function add(n){if(Array.isArray(n)){n.forEach(add);return this}r.push(n);n.once("end",remove.bind(null,n));n.once("error",e.emit.bind(e,"error"));n.pipe(e,{end:false});return this}function isEmpty(){return 0==r.length}function remove(n){r=r.filter((function(r){return r!==n}));!r.length&&e.readable&&e.end()}};var t=e;export default t;

