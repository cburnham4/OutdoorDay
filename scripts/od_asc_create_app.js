async () => {
  // Run after logged into https://appstoreconnect.apple.com/apps
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  const clickText = async (re) => {
    const el = [...document.querySelectorAll('button, a, [role="button"]')]
      .find(e => re.test((e.innerText || e.textContent || '').trim()));
    if (!el) return false;
    el.click();
    await sleep(800);
    return true;
  };
  // Try common New App entry points
  let opened = await clickText(/^New App$/i) || await clickText(/New App/i);
  await sleep(1500);
  const fillByLabel = (labelRe, value) => {
    const labels = [...document.querySelectorAll('label, span, div')];
    for (const lab of labels) {
      if (!labelRe.test((lab.innerText || '').trim())) continue;
      const root = lab.closest('div') || lab.parentElement;
      const input = root && root.querySelector('input, textarea, select');
      if (input) {
        const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
        if (input.tagName === 'SELECT') {
          const opt = [...input.options].find(o => o.text.includes(value) || o.value === value);
          if (opt) input.value = opt.value;
        } else {
          setter.call(input, value);
        }
        input.dispatchEvent(new Event('input', { bubbles: true }));
        input.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
      }
    }
    return false;
  };
  return {
    opened,
    url: location.href,
    body: (document.body.innerText || '').slice(0, 800),
    name: fillByLabel(/^Name$/i, 'Outdoor Day'),
    // Bundle ID / SKU filled after platform select — caller continues with snapshot
  };
}
