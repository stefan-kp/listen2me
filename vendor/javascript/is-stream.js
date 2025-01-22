// is-stream@2.0.1 downloaded from https://ga.jspm.io/npm:is-stream@2.0.1/index.js

var e={};const isStream=e=>null!==e&&"object"===typeof e&&"function"===typeof e.pipe;isStream.writable=e=>isStream(e)&&false!==e.writable&&"function"===typeof e._write&&"object"===typeof e._writableState;isStream.readable=e=>isStream(e)&&false!==e.readable&&"function"===typeof e._read&&"object"===typeof e._readableState;isStream.duplex=e=>isStream.writable(e)&&isStream.readable(e);isStream.transform=e=>isStream.duplex(e)&&"function"===typeof e._transform;e=isStream;var t=e;export default t;

