/* Copyright (C) 2026 ainuoyan; GNU General Public License v3. */
(function(root) {
    'use strict';

    function mount(options) {
        const document = root.document;
        const table = document.getElementById('smsMessages');
        const status = document.getElementById('smsStatus');
        const refreshButton = document.getElementById('smsRefresh');
        const deleteButton = document.getElementById('smsDelete');
        const selectAll = document.getElementById('smsSelectAll');
        let busy = false;
        let stopped = false;
        let timer;
        let request;

        function selectedIds() {
            return new Set(Array.from(table.querySelectorAll('input:checked'))
                .flatMap(input => input.dataset.ids.split(',')));
        }

        function render(data) {
            const selected = selectedIds();
            const messages = data.merge ? root.SMSInbox.mergeParts(data.messages) :
                data.messages.slice().sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
            const fragment = document.createDocumentFragment();
            for (const message of messages) {
                const row = document.createElement('tr');
                const checkboxCell = row.insertCell();
                const checkbox = document.createElement('input');
                checkbox.type = 'checkbox';
                checkbox.dataset.ids = String(message.index).split('-').join(',');
                checkbox.disabled = message.released !== true;
                checkbox.checked = !checkbox.disabled && checkbox.dataset.ids.split(',').every(id => selected.has(id));
                checkboxCell.appendChild(checkbox);
                row.insertCell().textContent = message.sender || '';
                const receivedAt = new Date(message.timestamp);
                row.insertCell().textContent = Number.isNaN(receivedAt.getTime()) ? (message.timestamp || '') :
                    receivedAt.toLocaleString('zh-CN', {hour12: false});
                const content = row.insertCell();
                content.style.whiteSpace = 'pre-wrap';
                content.textContent = message.error ? '这条短信暂时无法解码，原始数据已保留。' :
                    (message.missing_parts && message.missing_parts.length ?
                        '（长短信未收全：' + message.received_parts + '/' + message.total + ' 段）\n' : '') + (message.content || '');
                fragment.appendChild(row);
            }
            if (!messages.length) {
                const row = document.createElement('tr');
                const cell = row.insertCell();
                cell.colSpan = 4;
                cell.textContent = '暂无短信，收到后会自动显示。';
                fragment.appendChild(row);
            }
            table.replaceChildren(fragment);
            selectAll.checked = false;
            document.getElementById('smsMergeStatus').textContent =
                '本地保存 ' + messages.length + ' 条短信（' + data.messages.length + ' 个分段）';
            document.getElementById('smsCapacity').textContent = (data.capacity || []).map(item =>
                (item.storage === 'SM' ? 'SIM 卡' : '模组内存') + '：' + item.used + '/' + item.total).join('；') || '等待首次检查';
            if (data.error) status.textContent = data.error;
            else if (data.warning) status.textContent = data.warning;
            else if (!data.checked_at) status.textContent = '正在等待后台收件服务。';
            else if (Date.now() / 1000 - data.checked_at > 35) status.textContent = '后台收件暂未更新，已保存的短信仍可查看。';
            else status.textContent = '自动收件中 · 最近检查 ' + new Date(data.checked_at * 1000).toLocaleTimeString();
        }

        async function fetchJson(url, settings) {
            request = new root.AbortController();
            const timeout = root.setTimeout(() => request.abort(), 20000);
            try {
                const response = await root.fetch(url, Object.assign({
                    credentials: 'same-origin', cache: 'no-store', signal: request.signal
                }, settings));
                let data;
                try { data = await response.json(); }
                catch (_) { throw new Error('读取失败，请检查登录状态或稍后重试。'); }
                if (!response.ok || !data || data.ok !== true) throw new Error(data && data.error || '读取失败，请检查登录状态或稍后重试。');
                return data;
            } finally {
                root.clearTimeout(timeout);
                request = null;
            }
        }

        function schedule() {
            if (!stopped) timer = root.setTimeout(refresh, 5000);
        }

        function setBusy(value) {
            busy = value;
            refreshButton.disabled = deleteButton.disabled = value;
        }

        async function refresh() {
            if (busy || stopped) return;
            root.clearTimeout(timer);
            setBusy(true);
            try {
                const data = await fetchJson(options.readUrl);
                if (!Array.isArray(data.messages)) throw new Error('短信列表格式异常，已显示的短信保留。');
                if (!stopped) render(data);
            } catch (error) {
                if (!stopped) status.textContent = error.name === 'AbortError' ?
                    '刷新超时，已显示的短信保留，将自动重试。' : error.message;
            } finally {
                setBusy(false);
                schedule();
            }
        }

        refreshButton.addEventListener('click', refresh);
        selectAll.addEventListener('change', () => {
            for (const input of table.querySelectorAll('input:not(:disabled)')) input.checked = selectAll.checked;
        });
        deleteButton.addEventListener('click', async () => {
            if (busy) return;
            const ids = Array.from(selectedIds());
            if (!ids.length) { status.textContent = '请先选择已完成保存和缓冲区清理的短信。'; return; }
            if (!root.confirm('删除选中的本地短信记录？删除后无法恢复。')) return;
            root.clearTimeout(timer);
            setBusy(true);
            try {
                await fetchJson(options.deleteUrl, {method: 'POST', headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                }, body: new root.URLSearchParams({token: options.token, ids: ids.join(',')}).toString()});
                status.textContent = '所选本地记录已删除。';
            } catch (error) { status.textContent = error.message; }
            finally { setBusy(false); schedule(); }
            await refresh();
        });
        function stop() {
            stopped = true;
            root.clearTimeout(timer);
            if (request) request.abort();
        }
        root.addEventListener('pagehide', stop, {once: true});
        refresh();
        return {refresh, stop};
    }

    root.SMSInboxView = {mount};
    if (typeof module === 'object' && module.exports) module.exports = root.SMSInboxView;
})(typeof globalThis === 'object' ? globalThis : this);
