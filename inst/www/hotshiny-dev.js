/*
 * hotShiny dev client — loaded only when hot reload is enabled.
 *
 * Runs on top of the real shiny.js. On "hotshiny-reload" it receives the
 * freshly rendered page, compares it with the previous pristine render (both
 * carry structural data-hs-key attributes) and replaces only the keyed
 * subtrees that changed: unbind -> swap -> bind, restoring input values. New
 * <head> dependencies are loaded first. The websocket is never dropped, so
 * the server-side session (and its reactive state) survives.
 */
(function () {
  'use strict';

  var pristine = null; // last pristine render, as a <template>
  var KEY = 'data-hs-key';

  function parse(html) {
    var doc = new DOMParser().parseFromString(html, 'text/html');
    var tpl = document.createElement('template');
    tpl.innerHTML = doc.body ? doc.body.innerHTML : '';
    return { head: doc.head, body: tpl };
  }

  function keyed(root) {
    var map = new Map();
    root.content.querySelectorAll('[' + KEY + ']').forEach(function (el) {
      map.set(el.getAttribute(KEY), el);
    });
    return map;
  }

  // Compare an element's own markup (tag, attributes, text children and the
  // keys of its element children) ignoring the contents of keyed children.
  function shallowSignature(el) {
    var parts = [el.tagName];
    Array.prototype.slice.call(el.attributes).sort(function (a, b) {
      return a.name < b.name ? -1 : 1;
    }).forEach(function (a) { parts.push(a.name + '=' + a.value); });
    el.childNodes.forEach(function (c) {
      if (c.nodeType === 1) {
        parts.push(c.hasAttribute(KEY) ? '#' + c.getAttribute(KEY) : c.outerHTML);
      } else if (c.nodeType === 3) {
        parts.push('"' + c.nodeValue);
      }
    });
    return parts.join('\u0001');
  }

  // Keys of the topmost subtrees that differ between the two renders.
  function changedKeys(oldTpl, newTpl) {
    var oldMap = keyed(oldTpl);
    var out = [];
    var top = [];
    newTpl.content.childNodes.forEach(function (c) { if (c.nodeType === 1) top.push(c); });
    var oldTop = [];
    oldTpl.content.childNodes.forEach(function (c) { if (c.nodeType === 1) oldTop.push(c); });
    if (top.length !== oldTop.length) return null; // structure changed at the root
    (function walk(nodes) {
      nodes.forEach(function (n) {
        var k = n.getAttribute && n.getAttribute(KEY);
        if (!k) return;
        var o = oldMap.get(k);
        if (!o) { out.push(k); return; }
        if (o.outerHTML === n.outerHTML) return;
        if (shallowSignature(o) !== shallowSignature(n)) { out.push(k); return; }
        var kids = [];
        n.childNodes.forEach(function (c) { if (c.nodeType === 1 && c.hasAttribute(KEY)) kids.push(c); });
        walk(kids);
      });
    })(top);
    return out;
  }

  function inputSnapshot(root) {
    var saved = [];
    $(root).find('.shiny-bound-input').addBack('.shiny-bound-input').each(function () {
      var binding = $(this).data('shiny-input-binding');
      if (!binding || !this.id) return;
      try { saved.push({ id: this.id, name: binding.name, value: binding.getValue(this) }); } catch (e) {}
    });
    return saved;
  }

  function restoreInputs(saved) {
    saved.forEach(function (s) {
      var el = document.getElementById(s.id);
      if (!el) return;
      var binding = $(el).data('shiny-input-binding');
      if (!binding || binding.name !== s.name) return;
      var v = s.value;
      var msg;
      switch (s.name) {
        case 'shiny.actionButtonInput': return; // counts are server state
        case 'shiny.dateRangeInput': msg = { start: v && v[0], end: v && v[1] }; break;
        case 'shiny.sliderInput': msg = { value: v }; break;
        case 'shiny.fileInputBinding': return;
        default: msg = { value: v };
      }
      try { binding.receiveMessage(el, msg); } catch (e) {}
    });
  }

  function loadHeadDeps(head) {
    var have = new Set();
    document.querySelectorAll('script[src]').forEach(function (s) { have.add(s.getAttribute('src')); });
    document.querySelectorAll('link[href]').forEach(function (l) { have.add(l.getAttribute('href')); });
    var chain = Promise.resolve();
    head.querySelectorAll('link[rel="stylesheet"][href], style, script').forEach(function (el) {
      var src = el.getAttribute('src') || el.getAttribute('href');
      if (src && have.has(src)) return;
      if (!src && el.tagName === 'SCRIPT') return; // inline scripts already ran
      if (el.tagName === 'STYLE') {
        var same = Array.prototype.some.call(document.head.querySelectorAll('style'), function (s) {
          return s.textContent === el.textContent;
        });
        if (!same) document.head.appendChild(el.cloneNode(true));
        return;
      }
      chain = chain.then(function () {
        return new Promise(function (resolve) {
          var n = document.createElement(el.tagName.toLowerCase());
          Array.prototype.forEach.call(el.attributes, function (a) { n.setAttribute(a.name, a.value); });
          n.onload = n.onerror = function () { resolve(); };
          document.head.appendChild(n);
          if (el.tagName === 'LINK') resolve();
        });
      });
    });
    return chain;
  }

  function replaceKey(key, newTpl) {
    var live = document.querySelector('[' + KEY + '="' + CSS.escape(key) + '"]');
    var fresh = newTpl.content.querySelector('[' + KEY + '="' + CSS.escape(key) + '"]');
    if (!live || !fresh) return false;
    var saved = inputSnapshot(live);
    Shiny.unbindAll(live, true);
    var clone = fresh.cloneNode(true);
    live.replaceWith(clone);
    Shiny.initializeInputs(clone);
    Shiny.bindAll(clone);
    restoreInputs(saved);
    return true;
  }

  function replaceBody(newTpl) {
    var saved = inputSnapshot(document.body);
    Shiny.unbindAll(document.body, true);
    var keep = Array.prototype.filter.call(document.body.children, function (c) {
      return c.id === 'hotshiny-dev-overlay' || c.id === 'shiny-notification-panel' ||
        (c.tagName === 'SCRIPT');
    });
    document.body.innerHTML = '';
    document.body.appendChild(newTpl.content.cloneNode(true));
    keep.forEach(function (c) { document.body.appendChild(c); });
    Shiny.initializeInputs(document.body);
    Shiny.bindAll(document.body);
    restoreInputs(saved);
  }

  function applyReload(html) {
    var next = parse(html);
    return loadHeadDeps(next.head).then(function () {
      var keys = pristine ? changedKeys(pristine, next.body) : null;
      if (keys === null) {
        replaceBody(next.body);
      } else {
        keys.forEach(function (k) { if (!replaceKey(k, next.body)) keys = null; });
        if (keys === null) replaceBody(next.body);
      }
      pristine = next.body;
      window.hotShinyDev.lastChangedKeys = keys;
      if (keys && keys.length) flash(keys);
    });
  }

  // -- feedback --------------------------------------------------------------

  function overlay() {
    var el = document.getElementById('hotshiny-dev-overlay');
    if (!el) {
      el = document.createElement('div');
      el.id = 'hotshiny-dev-overlay';
      el.setAttribute('data-hotshiny-dev', '');
      el.style.cssText = 'position:fixed;bottom:12px;left:12px;z-index:100000;font:12px/1.4 ' +
        'ui-monospace,monospace;max-width:60vw;pointer-events:none';
      document.body.appendChild(el);
    }
    return el;
  }

  function toast(text, isError) {
    var el = overlay();
    el.innerHTML = '';
    var box = document.createElement('div');
    box.className = isError ? 'hotshiny-error' : 'hotshiny-ok';
    box.textContent = text;
    box.style.cssText = 'padding:6px 10px;border-radius:6px;color:#fff;white-space:pre-wrap;' +
      'background:' + (isError ? '#b00020' : 'rgba(30,30,30,.85)') + ';pointer-events:auto';
    el.appendChild(box);
    if (!isError) setTimeout(function () { if (box.parentNode) box.remove(); }, 1500);
  }

  function flash(keys) {
    keys.forEach(function (k) {
      var el = document.querySelector('[' + KEY + '="' + CSS.escape(k) + '"]');
      if (!el || !el.animate) return;
      el.animate([{ outline: '2px solid rgba(255,170,0,.9)' }, { outline: '2px solid rgba(255,170,0,0)' }],
        { duration: 700 });
    });
  }

  window.hotShinyDev = {
    reloads: 0,
    lastChangedKeys: null,
    applyReload: applyReload
  };

  $(document).on('shiny:connected', function () {
    Shiny.addCustomMessageHandler('hotshiny-reload', function (msg) {
      applyReload(msg.html).then(function () {
        window.hotShinyDev.reloads += 1;
      });
    });
    Shiny.addCustomMessageHandler('hotshiny-reloaded', function (msg) {
      toast('hot reloaded ' + msg.time, false);
      $(document).trigger('hotshiny:reloaded');
    });
    Shiny.addCustomMessageHandler('hotshiny-error', function (msg) {
      toast('hotShiny: ' + msg.message, true);
    });
  });

  // Keep a pristine copy of the current render to diff the next one against.
  fetch(window.location.href, { headers: { 'X-HotShiny-Pristine': '1' } })
    .then(function (r) { return r.text(); })
    .then(function (html) { if (!pristine) pristine = parse(html).body; })
    .catch(function () {});
})();
