// readable-stream@4.7.0 downloaded from https://ga.jspm.io/npm:readable-stream@4.7.0/lib/ours/browser.js

import{d as r,a as e}from"../../_/BKbv9ZRx.js";import"buffer";import"../../_/DV249By-.js";import"process";import"abort-controller";import"events";import"../../_/DY1DXnuF.js";import"string_decoder";var a={},s=false;function dew(){if(s)return a;s=true;const i=r();const t=e();const o=i.Readable.destroy;a=i.Readable;a._uint8ArrayToBuffer=i._uint8ArrayToBuffer;a._isUint8Array=i._isUint8Array;a.isDisturbed=i.isDisturbed;a.isErrored=i.isErrored;a.isReadable=i.isReadable;a.Readable=i.Readable;a.Writable=i.Writable;a.Duplex=i.Duplex;a.Transform=i.Transform;a.PassThrough=i.PassThrough;a.addAbortSignal=i.addAbortSignal;a.finished=i.finished;a.destroy=i.destroy;a.destroy=o;a.pipeline=i.pipeline;a.compose=i.compose;Object.defineProperty(i,"promises",{configurable:true,enumerable:true,get(){return t}});a.Stream=i.Stream;a.default=a;return a}const i=dew();var t=i._uint8ArrayToBuffer,o=i._isUint8Array,d=i.isDisturbed,n=i.isErrored,l=i.isReadable,u=i.Readable,p=i.Writable,b=i.Duplex,f=i.Transform,m=i.PassThrough,y=i.addAbortSignal,c=i.finished,h=i.destroy,A=i.pipeline,T=i.compose,_=i.Stream;export{b as Duplex,m as PassThrough,u as Readable,_ as Stream,f as Transform,p as Writable,o as _isUint8Array,t as _uint8ArrayToBuffer,y as addAbortSignal,T as compose,i as default,h as destroy,c as finished,d as isDisturbed,n as isErrored,l as isReadable,A as pipeline};

