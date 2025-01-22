// node-fetch@2.7.0 downloaded from https://ga.jspm.io/npm:node-fetch@2.7.0/browser.js

var e="undefined"!==typeof globalThis?globalThis:"undefined"!==typeof self?self:global;var n={};var getGlobal=function(){if("undefined"!==typeof self)return self;if("undefined"!==typeof window)return window;if("undefined"!==typeof e)return e;throw new Error("unable to locate global object")};var f=getGlobal();n=n=f.fetch;f.fetch&&(n.default=f.fetch.bind(f));n.Headers=f.Headers;n.Request=f.Request;n.Response=f.Response;var t=n;const o=n.Headers,s=n.Request,r=n.Response;export{o as Headers,s as Request,r as Response,t as default};

