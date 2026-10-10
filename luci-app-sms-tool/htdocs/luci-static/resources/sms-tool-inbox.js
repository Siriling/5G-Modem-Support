(function(root) {
    'use strict';

    function mergeParts(messages) {
        const groups = new Map();
        const result = [];
        for (const message of messages) {
            if (message.reference == null || !Number.isInteger(message.total) || message.total < 2 ||
                !Number.isInteger(message.part) || message.part < 1 || message.part > message.total) {
                result.push(Object.assign({}, message));
                continue;
            }
            const key = JSON.stringify([message.scope, message.sender, message.reference, message.total]);
            if (!groups.has(key)) groups.set(key, []);
            groups.get(key).push(message);
        }
        for (const segments of groups.values()) {
            const parts = new Map(segments.map(segment => [segment.part, segment]));
            // A reused reference with duplicate part numbers is ambiguous; keep it separate.
            if (parts.size !== segments.length) {
                result.push(...segments.map(segment => Object.assign({}, segment)));
                continue;
            }
            const ordered = [...segments].sort((a, b) => a.part - b.part);
            const merged = Object.assign({}, ordered[0]);
            const content = [];
            merged.index = ordered.map(segment => segment.index).join('-');
            merged.received_parts = ordered.length;
            merged.released = ordered.every(segment => segment.released === true);
            merged.missing_parts = [];
            for (let part = 1; part <= merged.total; part++) {
                if (parts.has(part)) content.push(parts.get(part).content);
                else {
                    merged.missing_parts.push(part);
                    content.push('\n[缺少第 ' + part + ' 段]\n');
                }
            }
            merged.content = content.join('');
            result.push(merged);
        }
        return result.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    }

    root.SMSInbox = { mergeParts };
    if (typeof module === 'object' && module.exports) module.exports = root.SMSInbox;
})(typeof globalThis === 'object' ? globalThis : this);
