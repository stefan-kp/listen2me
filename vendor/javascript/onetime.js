// onetime@5.1.2 downloaded from https://ga.jspm.io/npm:onetime@5.1.2/index.js

import e from"mimic-fn";var n={};const t=e;const o=new WeakMap;const onetime=(e,n={})=>{if("function"!==typeof e)throw new TypeError("Expected a function");let r;let a=0;const c=e.displayName||e.name||"<anonymous>";const onetime=function(...t){o.set(onetime,++a);if(1===a){r=e.apply(this,t);e=null}else if(true===n.throw)throw new Error(`Function \`${c}\` can only be called once`);return r};t(onetime,e);o.set(onetime,a);return onetime};n=onetime;n.default=onetime;n.callCount=e=>{if(!o.has(e))throw new Error(`The given function \`${e.name}\` is not wrapped by the \`onetime\` package`);return o.get(e)};var r=n;const a=n.callCount;export default r;export{a as callCount};

