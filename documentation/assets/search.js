/* Search and per-page filtering for the scm library reference site.
 *
 * Data is provided by search-index.js as window.SEARCH_INDEX: an array of
 *   { k: "lib"|"sym", n: name, l: context label, id: lib-id, a: anchor }
 * Loaded as a plain <script> (not fetched) so the site works from file://. */
(function () {
  'use strict';

  var idx = window.SEARCH_INDEX || [];
  var input = document.getElementById('search');
  var box = document.getElementById('search-results');

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  function render(rawQuery) {
    if (!box) return;
    box.innerHTML = '';
    var query = rawQuery.trim().toLowerCase();
    if (!query) { box.style.display = 'none'; return; }

    var out = [];
    for (var i = 0; i < idx.length && out.length < 60; i++) {
      if (idx[i].n.toLowerCase().indexOf(query) !== -1) out.push(idx[i]);
    }
    if (!out.length) { box.style.display = 'none'; return; }

    out.forEach(function (e) {
      var a = document.createElement('a');
      a.className = 'search-result';
      a.href = e.k === 'lib' ? (e.id + '.html') : (e.id + '.html#' + e.a);
      a.innerHTML =
        '<span class="sr-kind sr-' + e.k + '">' + e.k + '</span>' +
        '<span class="sr-name">' + escapeHtml(e.n) + '</span>' +
        '<span class="sr-ctx">' + escapeHtml(e.l) + '</span>';
      box.appendChild(a);
    });
    box.style.display = 'block';
  }

  if (input && box) {
    input.addEventListener('input', function () { render(input.value); });
    input.addEventListener('keydown', function (ev) {
      if (ev.key === 'Enter') {
        var first = box.querySelector('a');
        if (first) window.location = first.getAttribute('href');
      } else if (ev.key === 'Escape') {
        box.style.display = 'none';
        input.blur();
      }
    });
    document.addEventListener('click', function (ev) {
      if (ev.target !== input && !box.contains(ev.target)) box.style.display = 'none';
    });
  }

  /* Per-library page: live filter the export entries. */
  var filter = document.getElementById('export-filter');
  if (filter) {
    filter.addEventListener('input', function () {
      var q = filter.value.trim().toLowerCase();
      var entries = document.querySelectorAll('.entry');
      for (var i = 0; i < entries.length; i++) {
        var name = (entries[i].getAttribute('data-name') || '').toLowerCase();
        entries[i].style.display = (!q || name.indexOf(q) !== -1) ? '' : 'none';
      }
    });
  }

  /* Highlight the entry linked to by the URL fragment. */
  if (window.location.hash) {
    var el = document.getElementById(window.location.hash.slice(1));
    if (el) {
      el.classList.add('target');
      el.scrollIntoView({ block: 'center' });
    }
  }
})();
