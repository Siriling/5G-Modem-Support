/* Copyright (C) 2026 ainuoyan; GNU General Public License v3. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const {mergeParts} = require('../htdocs/luci-static/resources/sms-tool-inbox.js');
const source = fs.readFileSync(require.resolve('../htdocs/luci-static/resources/sms-tool-inbox-view.js'), 'utf8');
class Element {
    constructor(tag) { this.tag = tag; this.children = []; this.dataset = {}; this.style = {}; this.listeners = {}; }
    appendChild(child) { this.children.push(child); }
    insertCell() { const cell = new Element('td'); this.appendChild(cell); return cell; }
    replaceChildren(fragment) { this.children = fragment.children; }
    addEventListener(name, fn) { this.listeners[name] = fn; }
    querySelectorAll(selector) {
        const result = [];
        function visit(element) {
            if (element.tag === 'input' && (selector === 'input:checked' ? element.checked : !element.disabled)) result.push(element);
            for (const child of element.children) visit(child);
        }
        visit(this);
        return result;
    }
}
const flush = () => new Promise(resolve => setImmediate(resolve));
const message = (index, extra = {}) => Object.assign({index, sender: 'fixture', timestamp: '2026-10-10T12:00:00Z', content: '测试', released: true}, extra);
const snapshot = messages => ({ok: true, messages, merge: true, capacity: [], checked_at: Date.now() / 1000});
function setup(first) {
    const ids = ['smsMessages', 'smsStatus', 'smsRefresh', 'smsDelete', 'smsSelectAll', 'smsMergeStatus', 'smsCapacity'];
    const elements = Object.fromEntries(ids.map(id => [id, new Element(id)]));
    const timers = new Map(), responses = [first], calls = [], events = {};
    let nextTimer = 1;
    const root = {
        document: {getElementById: id => elements[id], createElement: tag => new Element(tag), createDocumentFragment: () => new Element('fragment')},
        SMSInbox: {mergeParts}, AbortController, URLSearchParams, confirm: () => true,
        addEventListener: (name, fn) => { events[name] = fn; },
        setTimeout: (fn, delay) => { const id = nextTimer++; timers.set(id, {fn, delay}); return id; },
        clearTimeout: id => timers.delete(id),
        fetch: async (url, options) => {
            calls.push({url, options});
            const item = responses.shift();
            assert.notEqual(item, undefined, 'unexpected request');
            if (item instanceof Error) throw item;
            const value = await item;
            return {ok: true, json: async () => { if (value === 'html-login') throw new SyntaxError('not JSON'); return value; }};
        }
    };
    vm.runInNewContext(source, root);
    const view = root.SMSInboxView.mount({readUrl: '/inbox', deleteUrl: '/delete', token: 'fixture-token'});
    return {elements, timers, responses, calls, events, view, poll: async () => {
        const entry = [...timers.entries()].find(([, timer]) => timer.delay === 5000);
        assert.ok(entry, 'auto refresh must be scheduled');
        timers.delete(entry[0]);
        await entry[1].fn();
    }};
}
let cases = 0;
async function test(run) { await run(); cases++; }
(async () => {
    await test(async () => {
        const state = setup(snapshot([message(1, {content: '<img src=x onerror=alert(1)>'})]));
        await flush();
        assert.equal(state.elements.smsMessages.children[0].children[3].textContent, '<img src=x onerror=alert(1)>');
        assert.equal(state.elements.smsMessages.children[0].children[2].textContent,
            new Date('2026-10-10T12:00:00Z').toLocaleString('zh-CN', {hour12: false}),
            'received times must display in the browser timezone');
        state.responses.push(snapshot([message(1), message(2)]));
        await state.poll();
        assert.equal(state.elements.smsMessages.children.length, 2, 'new arrival must appear without page reload');
        state.view.stop();
    });
    await test(async () => {
        const state = setup(snapshot([message(1)]));
        await flush();
        const abort = new Error('fixture timeout'); abort.name = 'AbortError';
        state.responses.push(abort);
        await state.poll();
        assert.equal(state.elements.smsMessages.children.length, 1, 'failed refresh must keep previous rows');
        assert.match(state.elements.smsStatus.textContent, /超时/);
        state.responses.push(snapshot([message(1), message(2)]));
        await state.poll();
        assert.equal(state.elements.smsMessages.children.length, 2, 'refresh must recover');
        state.responses.push('html-login');
        await state.poll();
        assert.match(state.elements.smsStatus.textContent, /登录/);
        assert.equal(state.elements.smsMessages.children.length, 2);
        state.view.stop();
    });
    await test(async () => {
        let release;
        const state = setup(new Promise(resolve => { release = resolve; }));
        await state.view.refresh();
        assert.equal(state.calls.length, 1, 'requests must not overlap');
        release(snapshot([]));
        await flush();
        assert.match(state.elements.smsMessages.children[0].children[0].textContent, /暂无短信/);
        state.events.pagehide();
        assert.equal(state.timers.size, 0, 'leaving the page must stop polling');
    });
    await test(async () => {
        const state = setup(snapshot([message(1)]));
        await flush();
        state.elements.smsMessages.querySelectorAll('input:not(:disabled)')[0].checked = true;
        state.responses.push(snapshot([message(1), message(2)]));
        await state.poll();
        assert.equal(state.elements.smsMessages.querySelectorAll('input:checked').length, 1);
        state.responses.push({ok: true}, snapshot([message(2)]));
        await state.elements.smsDelete.listeners.click();
        const deletion = state.calls.find(call => call.url === '/delete');
        assert.equal(deletion.options.method, 'POST');
        assert.equal(new URLSearchParams(deletion.options.body).get('token'), 'fixture-token');
        assert.equal(new URLSearchParams(deletion.options.body).get('ids'), '1', 'new arrivals must not be deleted');
        assert.equal(state.elements.smsMessages.children.length, 1);
        state.view.stop();
    });
    await test(async () => {
        const part = (index, number) => message(index, {reference: 7, part: number, total: 2});
        const state = setup(snapshot([part(1, 1)]));
        await flush();
        assert.match(state.elements.smsMessages.children[0].children[3].textContent, /未收全/);
        state.elements.smsMessages.querySelectorAll('input:not(:disabled)')[0].checked = true;
        state.responses.push(snapshot([part(1, 1), part(2, 2)]));
        await state.poll();
        assert.equal(state.elements.smsMessages.children.length, 1);
        assert.equal(state.elements.smsMessages.querySelectorAll('input:checked').length, 0,
            'later multipart segments must not be implicitly selected for deletion');
        state.responses.push(snapshot([message(3, {released: false})]));
        await state.poll();
        assert.equal(state.elements.smsMessages.querySelectorAll('input:not(:disabled)').length, 0,
            'pending backups must not be deletable');
        state.view.stop();
    });
    console.log(`SMS inbox view: ${cases} scenarios passed`);
})().catch(error => { console.error(error); process.exitCode = 1; });
