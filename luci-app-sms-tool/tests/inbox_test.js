const assert = require('node:assert/strict');
const { mergeParts } = require('../htdocs/luci-static/resources/sms-tool-inbox.js');
const part = (index, reference, number, content, extra = {}) => Object.assign({
    index, sender: 'test', timestamp: '2026-10-09 12:00:00', reference,
    part: number, total: 2, content
}, extra);
const input = [part(2, 7, 2, '文£', { timestamp: '2026-10-09 12:00:01' }), part(1, 7, 1, '中')];
let result = mergeParts(input);
assert.equal(result.length, 1);
assert.equal(result[0].content, '中文£');
assert.equal(result[0].index, '1-2');
assert.deepEqual(result[0].missing_parts, []);
assert.equal(input[0].content, '文£');
result = mergeParts([part(1, 7, 1, 'A'), part(2, 8, 2, 'B')]);
assert.equal(result.length, 2, 'Different references must never merge');
assert.deepEqual(result[0].missing_parts, [2]);
assert.match(result[0].content, /缺少第 2 段/);
result = mergeParts([part(1, 7, 1, 'A'), part(2, 7, 2, 'B', { sender: 'another' })]);
assert.equal(result.length, 2, 'Different senders must never merge');
result = mergeParts([part(1, 7, 1, 'A'), part(2, 7, 1, 'B'), part(3, 7, 2, 'C')]);
assert.equal(result.length, 3, 'Ambiguous reference reuse must remain separate');
assert.equal(mergeParts([part(1, null, 1, 'A'), part(2, null, 2, 'B')]).length, 2);
assert.equal(mergeParts([]).length, 0);
assert.equal(mergeParts([part(1, 7, 1, 'A', {scope: 1}), part(2, 7, 2, 'B', {scope: 2})]).length, 2,
    'Different SIM scopes must never merge');
assert.equal(mergeParts([part(1, 7, 1, 'A', {released: true}), part(2, 7, 2, 'B', {released: false})])[0].released, false);
assert.equal(mergeParts([part(1, 7, 1, 'A', {released: true}), part(2, 7, 2, 'B', {released: true})])[0].released, true);
console.log('SMS inbox: 15 assertions passed');
