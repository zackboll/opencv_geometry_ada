/* Package- and operation-level API browser for the Geometry GNATdoc index,
 * adapted from opencv_imgproc_ada. Progressive enhancement only: every entry
 * is a native link into the documentation frame and works without this
 * script. Destinations always come from the verified static entries and
 * package links, never from URL or search text. */
(() => {
  'use strict';
  const controls = document.getElementById('api-search-controls');
  const input = document.getElementById('api-search');
  const clear = document.getElementById('api-clear');
  const status = document.getElementById('api-results');
  const frame = document.querySelector('iframe[name="document-content"]');
  const units = Array.from(document.querySelectorAll('#compilation-units + ul a'));
  const entries = Array.from(document.querySelectorAll('#api-browser li[data-op]'));
  const categories = Array.from(document.querySelectorAll('#api-browser details'));
  const sections = Array.from(document.querySelectorAll('#api-browser section[data-package]'));
  if (!controls || !input || !clear || !status || !frame || !units.length ||
      !entries.length) {
    return;
  }
  controls.hidden = false;

  const show = href => frame.contentWindow.location.replace(href);
  const unitOf = name => units.find(unit => unit.textContent === name) || null;

  const filter = () => {
    const words = input.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
    let shown = 0;
    for (const entry of entries) {
      const match = words.every(word => entry.dataset.search.includes(word));
      entry.hidden = !match;
      if (match) shown += 1;
    }
    for (const category of categories) {
      const visible = category.querySelector('li[data-op]:not([hidden])') !== null;
      category.hidden = !visible;
      if (words.length) category.open = visible;
    }
    for (const section of sections) {
      section.hidden = section.querySelector('details:not([hidden])') === null;
    }
    status.textContent = !words.length ? ''
      : shown === 0 ? 'No matching declarations.'
      : `${shown} matching declaration${shown === 1 ? '' : 's'}.`;
  };

  const links = () => units.concat(entries.map(entry => entry.firstElementChild));

  const mark = link => {
    for (const other of links()) other.removeAttribute('aria-current');
    if (!link) return;
    link.setAttribute('aria-current', 'page');
    const details = link.closest('details');
    if (details) details.open = true;
  };

  const bookmark = (packageName, entry) => {
    const url = new URL(location.href);
    url.search = '';
    url.hash = '';
    url.searchParams.set('package', packageName);
    if (entry) {
      url.searchParams.set('op', entry.dataset.op);
      if (entry.dataset.overload) url.searchParams.set('overload', entry.dataset.overload);
    }
    return url.href;
  };

  /* Case-insensitive Ada name lookup; unknown requests select nothing. */
  const requested = () => {
    const params = new URLSearchParams(location.search);
    const packageName = (params.get('package') || '').toLowerCase();
    const op = (params.get('op') || '').toLowerCase();
    const overload = params.get('overload') || '1';
    if (op) {
      const entry = entries.find(item =>
        item.dataset.op.toLowerCase() === op &&
        (!packageName || item.dataset.package.toLowerCase() === packageName) &&
        (item.dataset.overload || '1') === overload) || null;
      return entry ? {packageName: entry.dataset.package, entry} : null;
    }
    if (packageName) {
      const unit = units.find(item => item.textContent.toLowerCase() === packageName);
      return unit ? {packageName: unit.textContent, entry: null} : null;
    }
    return null;
  };

  const restore = () => {
    const request = requested();
    if (request && request.entry) {
      mark(request.entry.firstElementChild);
      show(request.entry.firstElementChild.href);
      request.entry.firstElementChild.scrollIntoView({block: 'nearest'});
    } else if (request) {
      const unit = unitOf(request.packageName);
      mark(unit);
      show(unit.href);
    } else {
      mark(null);
      show(units[0].href);
    }
  };

  const plainClick = event => event.button === 0 && !event.metaKey && !event.ctrlKey &&
    !event.shiftKey && !event.altKey;

  for (const entry of entries) {
    entry.firstElementChild.addEventListener('click', event => {
      if (!plainClick(event)) return;
      event.preventDefault();
      mark(entry.firstElementChild);
      history.pushState(null, '', bookmark(entry.dataset.package, entry));
      show(entry.firstElementChild.href);
    });
  }
  for (const unit of units) {
    unit.addEventListener('click', event => {
      if (!plainClick(event)) return;
      event.preventDefault();
      mark(unit);
      history.pushState(null, '', bookmark(unit.textContent, null));
      show(unit.href);
    });
  }
  input.addEventListener('input', filter);
  clear.addEventListener('click', () => {
    input.value = '';
    filter();
    input.focus();
  });
  window.addEventListener('popstate', restore);
  /* Canonicalize the outer URL: a verified bookmark, or no request. */
  const request = requested();
  if (request) {
    history.replaceState(null, '', bookmark(request.packageName, request.entry));
  } else if (location.search) {
    const url = new URL(location.href);
    url.search = '';
    history.replaceState(null, '', url.href);
  }
  restore();
  filter();
})();
