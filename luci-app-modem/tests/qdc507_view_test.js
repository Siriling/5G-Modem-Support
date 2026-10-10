// Test the real view function without a browser or modem access.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(process.argv[2] || 'luci-app-modem/luasrc/view/modem/modem_debug.htm', 'utf8');
const start = source.indexOf('\tfunction set_network_prefer_view');
const end = source.indexOf('\n\t// 设置网络偏好信息', start);
const elements = new Map();
const element = id => {
    if (!elements.has(id)) elements.set(id, { checked: false, innerHTML: '', style: {}, parentElement: { parentElement: { style: {} } } });
    return elements.get(id);
};
const context = {
    document: { getElementById: element },
    get_tab_enable_element: () => ({ getAttribute: () => 'network_prefer_tab' }),
    all_choose_prefer_custom_config: () => {},
    disabled_prefer_custom_config: () => {}
};
vm.createContext(context);
vm.runInContext(source.slice(start, end), context);
element('first_cache').checked = true;
context.set_network_prefer_view([
    { '2G': { enable: 0, band: {} } },
    { '3G': { enable: 0, band: {} } },
    { '4G': { enable: 1, band: [{ B3: 1 }, { B66: 0 }, { B71: 0 }] } }
], true);
assert.equal(element('cbi-4g_band_info').style.display, 'block');
assert.equal(element('band_prefer_button').parentElement.parentElement.style.display, '');
assert.match(element('4g_band_check').innerHTML, /band_prefer_config_b71/);
assert.equal(element('4g_current_prefer').innerHTML, 'B3 ');
assert.match(element('network_type_check').innerHTML, /prefer_config_2g/);
context.set_network_prefer_view([{ '4G': { enable: 1, band: [{ B3: 1 }] } }], false);
assert.equal(element('cbi-4g_band_info').style.display, 'none');
assert.equal(element('band_prefer_button').parentElement.parentElement.style.display, 'none');
const support = JSON.parse(fs.readFileSync(__dirname + '/../root/usr/share/modem/modem_support.json', 'utf8')).modem_support.usb.qdc507;
const commands = JSON.parse(fs.readFileSync(__dirname + '/../root/usr/share/modem/at_commands.json', 'utf8')).quick_commands;
assert.ok(Array.isArray(commands[support.manufacturer][support.platform]), 'Automatic quick commands require a list for the modem profile');
console.log('QDC507 view tests passed: 8');
