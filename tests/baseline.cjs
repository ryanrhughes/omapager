const assert = require('node:assert/strict'), load = require('./js-loader.cjs');
const M=load('Markup'), D=load('Detect'), S=load('Store');
const payload='<a href="https://paypal.com@evil.example">paypal.com</a>Your code is 1234';
assert.notEqual(M.liftSource(payload).source, 'paypal.com');
assert.notEqual(M.liftSource(payload).source, 'paypal.com@evil.example');
assert.equal(M.linkable('https://paypal.com@evil.example'), false);
assert.equal(D.scan('Verification', 'Your code is 938271').code, '938271');
assert.equal(D.scan('codes', 'your code is 482913, backup code is 771204').codes, '482913 771204');
assert.equal(D.scan('Build', '412 passed, 0 failed').code, '');
assert.equal(M.liftSource('<a href="https://app.slack.com">app.slack.com</a>Hello').source, 'app.slack.com');
assert.equal(M.forwardedApp('KDE Connect', 'WhatsApp').name, 'WhatsApp');
assert.ok(D.scan('', '+44 7911 123456').phone);
assert.equal(S.restored({key:'test'}).restored, true);

// Daemon-assigned ids resolve to live slot keys only. An id that matches a
// restored row, a non-live entry, or nothing at all must not resolve: the
// caller uses "" as "invoke nothing and close nothing".
const live=(key,originalId)=>({key,originalId,live:true});
const dead=(key,originalId)=>({key,originalId,live:false});
assert.equal(S.findLiveKey([live('n1',7)],'7'),'n1');
assert.equal(S.findLiveKey([live('n1',7)],7),'n1');
assert.equal(S.findLiveKey([live('n1',7),live('n2',8)],'8'),'n2');
assert.equal(S.findLiveKey([dead('n1',7),live('n2',7)],'7'),'n2');
assert.equal(S.findLiveKey([live('n1',7)],'8'),'');
assert.equal(S.findLiveKey([dead('n1',7)],'7'),'');
assert.equal(S.findLiveKey([],'1'),'');
assert.equal(S.findLiveKey(null,'1'),'');
assert.equal(S.findLiveKey([live('n1',4294967295)],'4294967295'),'n1');
// The 32-bit ceiling is load-bearing: without it, an id one past the
// protocol's width would resolve to a live row that carries that number.
assert.equal(S.findLiveKey([live('n1',4294967296)],'4294967296'),'');
for (const bad of ['',' 1','1 ','+1','-1','0','01','1.0','1e2','abc','NaN',1.5,null,undefined,{},[],'4294967296'])
  assert.equal(S.findLiveKey([live('n1',1)],bad),'');

// The live set is shaped by one pure function, so the shell can pass its
// "sender still has actions" predicate and the row shape stays pinned here.
assert.equal(JSON.stringify(S.liveEntries({n1:{originalId:7},n2:{originalId:8}}, k=>k==='n2')),
  JSON.stringify([{key:'n1',originalId:7,live:false},{key:'n2',originalId:8,live:true}]));
assert.equal(S.findLiveKey(S.liveEntries({n1:{originalId:7}}, ()=>true),'7'),'n1');
assert.equal(S.liveEntries(null).length, 0);
assert.equal(S.liveEntries({}).length, 0);
assert.equal(S.liveEntries({n1:{originalId:7}})[0].live, false);
console.log('baseline: passed');
