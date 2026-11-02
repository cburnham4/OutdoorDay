async () => {
  // Run on https://appstoreconnect.apple.com/apps after login.
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  const textOf = (el) => ((el && (el.innerText || el.textContent)) || '').trim();
  const clickText = async (re) => {
    const el = [...document.querySelectorAll('button, a, [role="button"], span')]
      .find(e => re.test(textOf(e)));
    if (!el) return false;
    (el.closest('button,a,[role="button"]') || el).click();
    await sleep(1000);
    return true;
  };
  const setNative = (el, value) => {
    const proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
    const setter = Object.getOwnPropertyDescriptor(proto, 'value').set;
    el.focus();
    setter.call(el, value);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
  };
  if (!/appstoreconnect\.apple\.com\/apps/.test(location.href)) {
    return { err: 'not_on_apps', url: location.href, body: (document.body.innerText || '').slice(0, 300) };
  }
  let opened = await clickText(/^\+$/) || await clickText(/^New App$/i) || await clickText(/New App/i);
  await sleep(1200);
  // Platform iOS checkbox/radio
  const ios = [...document.querySelectorAll('input[type=checkbox],input[type=radio],label,span')]
    .find(e => /iOS/i.test(textOf(e)) || (e.value || '') === 'IOS');
  if (ios) { (ios.closest('label') || ios).click(); await sleep(400); }
  // Fill fields by nearby label text
  const fillNear = (labelRe, value) => {
    for (const lab of document.querySelectorAll('label, span, div, p')) {
      const t = textOf(lab);
      if (!labelRe.test(t) || t.length > 40) continue;
      let root = lab.closest('[class*="form"],[class*="Field"],[class*="row"],div') || lab.parentElement;
      for (let i = 0; i < 4 && root; i++, root = root.parentElement) {
        const input = root.querySelector('input:not([type=hidden]):not([type=checkbox]):not([type=radio]), textarea, select');
        if (!input) continue;
        if (input.tagName === 'SELECT') {
          const opt = [...input.options].find(o => o.text.includes(value) || o.value === value || /outdoor-day/i.test(o.text));
          if (opt) { input.value = opt.value; input.dispatchEvent(new Event('change', { bubbles: true })); return true; }
        } else { setNative(input, value); return true; }
      }
    }
    return false;
  };
  const nameOk = fillNear(/^Name$/i, 'Outdoor Day');
  const skuOk = fillNear(/^SKU$/i, 'outdoor-day-001');
  // Bundle ID select often labeled Bundle ID
  let bundleOk = fillNear(/Bundle ID/i, 'us.letshang.outdoor-day');
  if (!bundleOk) {
    const sel = [...document.querySelectorAll('select')].find(s => [...s.options].some(o => /outdoor-day/i.test(o.text + o.value)));
    if (sel) {
      const opt = [...sel.options].find(o => /outdoor-day/i.test(o.text + o.value));
      sel.value = opt.value; sel.dispatchEvent(new Event('change', { bubbles: true }));
      bundleOk = true;
    }
  }
  const createBtn = [...document.querySelectorAll('button')].find(b => /^(Create|Submit)$/i.test(textOf(b)));
  let clickedCreate = false;
  if (createBtn && nameOk && skuOk && bundleOk) {
    createBtn.click();
    clickedCreate = true;
    await sleep(2500);
  }
  return {
    opened, nameOk, skuOk, bundleOk,
    hasCreate: !!createBtn,
    clickedCreate,
    url: location.href,
    body: (document.body.innerText || '').slice(0, 900)
  };
}
