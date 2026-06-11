/* SiteKit DocC client-side full-text search.
   Drives the single global search affordance: the appbar ⌘K pill opens a modal
   overlay holding one search field, a rich results list, and a right-side preview
   panel. On first interaction the sharded index (manifest + shards) is lazily
   fetched, then each record's title and body excerpt are matched against the query;
   matches are listed as rich rows (framework icon + year eyebrow + title + 1-line
   description + note-type badge) with the query terms highlighted, and the focused /
   hovered row drives a preview panel (Apple description, a Watch-Video button when a
   video is present, a longer excerpt, and a "View more" link). This mirrors the
   dedicated search page so the quick-jump overlay matches the production experience.
   Progressive enhancement: with no JS the sidebar still navigates the whole catalog
   and the pill is inert. Localized strings ride on the input's data-* attributes so
   this script stays locale-agnostic. */
(function () {
   "use strict";

   var overlay = document.querySelector("[data-docc-search-overlay]");
   var input = document.querySelector(".sk-docc-search-input");
   var results = document.querySelector(".sk-docc-search-results");
   var countEl = document.querySelector(".sk-docc-search-count");
   var previewEl = document.querySelector("[data-docc-search-preview]");
   var seeAllFoot = document.querySelector("[data-docc-search-foot]");
   var seeAllLink = document.querySelector("[data-docc-search-seeall]");

   /* ── Keyboard-shortcut label swap ────────────────────────────────────────
      The shell renders ⌘K as the default hint (macOS). On non-Mac platforms swap
      every [data-docc-kbd] element to Ctrl+K at page-load time, before first paint. */
   var platform = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || "";
   /* Case-insensitive, and matches both the userAgentData spellings ("macOS", "iOS" – the
      values Chrome/Edge report) and the legacy navigator.platform spellings ("MacIntel",
      "iPhone", "iPad"). A case-sensitive /Mac/ would miss "macOS" and wrongly treat Mac
      Chrome/Edge as non-Apple, hiding ⌘K behind Ctrl+K. */
   var isMac = /mac|ios|iphone|ipad|ipod/i.test(platform);
   if (!isMac) {
      var kbdEls = document.querySelectorAll("[data-docc-kbd]");
      for (var k = 0; k < kbdEls.length; k++) {
         kbdEls[k].textContent = "Ctrl+K";
      }
   }

   /* Without the overlay there is nothing to wire (no-JS / non-DocC page). */
   if (!overlay || !input || !results) return;

   /* Localized result-count template + empty-state copy + preview labels, server-rendered
      onto the input as data-* attributes (keeps this script free of any English strings). */
   var countTemplate = input.getAttribute("data-docc-search-count") || "%lld results";
   var emptyTitle = input.getAttribute("data-docc-search-empty-title") || "No matches";
   var emptyBody = input.getAttribute("data-docc-search-empty-body") || "";
   var watchLabel = input.getAttribute("data-docc-search-watch") || "Watch Video";
   var moreLabel = input.getAttribute("data-docc-search-more") || "View more";
   var typeLabels = {
      ai: input.getAttribute("data-docc-label-ai") || "AI",
      community: input.getAttribute("data-docc-label-community") || "Community",
      stub: input.getAttribute("data-docc-label-stub") || "Stub"
   };

   /* Framework → gradient colors, for the colored icon square on each row + the preview.
      Emitted by the shell as an inline JSON block; absent → icons fall back to a neutral
      square. */
   var frameworkColors = {};
   var registryEl = overlay.querySelector("[data-docc-search-frameworks]");
   if (registryEl) {
      try { frameworkColors = JSON.parse(registryEl.textContent) || {}; } catch (e) { frameworkColors = {}; }
   }

   var lastFocus = null;

   /* The records currently painted (the visible slice) + the active query terms, so the
      hover / focus handlers can map a row back to its record and re-highlight the preview. */
   var visibleRecords = [];
   var activeTerms = [];

   /* ── Overlay open / close ────────────────────────────────────────────────
      Opening locks background scroll and moves focus into the field; closing
      restores both and clears the query so the next open starts fresh. */
   /* Siblings inside .sk-docc-layout that must become inert while the search
      overlay is open, so keyboard focus stays trapped inside the overlay modal.
      Mirrors the approach used by the sidebar drawer in docc-sidebar.js. */
   var layout = document.querySelector(".sk-docc-layout");

   function openSearch() {
      if (!overlay.hasAttribute("hidden")) return;
      lastFocus = document.activeElement;
      overlay.removeAttribute("hidden");
      document.documentElement.style.overflow = "hidden";
      /* Trap focus: prevent Tab from escaping into the page behind the backdrop. */
      if (layout) {
         var appbarEl = layout.querySelector(".sk-docc-appbar");
         var bodyEl = layout.querySelector(".sk-docc-body");
         if (appbarEl) appbarEl.inert = true;
         if (bodyEl) bodyEl.inert = true;
      }
      input.focus();
      input.select();
      loadIndex();
   }

   function closeSearch() {
      if (overlay.hasAttribute("hidden")) return;
      overlay.setAttribute("hidden", "");
      document.documentElement.style.overflow = "";
      /* Restore interactivity of siblings that were made inert on open. */
      if (layout) {
         var appbarEl = layout.querySelector(".sk-docc-appbar");
         var bodyEl = layout.querySelector(".sk-docc-body");
         if (appbarEl) appbarEl.inert = false;
         if (bodyEl) bodyEl.inert = false;
      }
      input.value = "";
      renderResults("");
      if (lastFocus && typeof lastFocus.focus === "function") lastFocus.focus();
   }

   var openBtns = document.querySelectorAll("[data-docc-search-open]");
   for (var p = 0; p < openBtns.length; p++) {
      openBtns[p].addEventListener("click", openSearch);
   }

   var closeBtns = overlay.querySelectorAll("[data-docc-search-close]");
   for (var c = 0; c < closeBtns.length; c++) {
      closeBtns[c].addEventListener("click", closeSearch);
   }

   /* "Try:" suggestion chips prefill the field and run the search immediately. */
   var chips = overlay.querySelectorAll("[data-docc-search-suggest]");
   for (var s = 0; s < chips.length; s++) {
      chips[s].addEventListener("click", function () {
         var term = this.getAttribute("data-docc-search-suggest") || "";
         input.value = term;
         input.focus();
         loadIndex().then(function () { renderResults(term); });
      });
   }

   /* ── Global ⌘K / Ctrl+K (+ ⌘⇧O) / Escape ─────────────────────────────────
      ⌘K opens the overlay from anywhere (unless the user is typing elsewhere); ⌘⇧O
      (Xcode / old-DocC "Open Quickly" muscle memory) opens it too; Escape closes it
      while open. */
   document.addEventListener("keydown", function (event) {
      var modifierHeld = isMac ? event.metaKey : event.ctrlKey;
      var key = event.key.toLowerCase();
      var opensSearch = (modifierHeld && key === "k") || (modifierHeld && event.shiftKey && key === "o");
      if (opensSearch) {
         var tag = document.activeElement && document.activeElement.tagName;
         var typing = tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT"
            || (document.activeElement && document.activeElement.isContentEditable);
         if (typing && document.activeElement !== input) return;
         event.preventDefault();
         openSearch();
         return;
      }
      if (event.key === "Escape" && !overlay.hasAttribute("hidden")) {
         event.preventDefault();
         closeSearch();
      }
   });

   /* ── Search normalization ──────────────────────────────────────────────────
      Kept in sync across docc-filter.js, docc-search.js, docc-search-page.js: fold
      typographic apostrophes/quotes to ASCII, strip apostrophes entirely, lowercase –
      so "whats new", "what's new", and "What’s New" all hit the same records. Matching
      runs on the normalized strings; `map` carries each normalized character's original
      index so highlight ranges can be mapped back (stripping apostrophes shifts every
      offset after them). */
   function normalizeWithMap(text) {
      var norm = "";
      var map = [];
      for (var i = 0; i < text.length; i++) {
         var ch = text.charAt(i);
         if (ch === "‘" || ch === "’") ch = "'";
         else if (ch === "“" || ch === "”") ch = "\"";
         if (ch === "'") continue;
         var lower = ch.toLowerCase();
         /* Rarely more than one character (e.g. İ → i̇) – map each produced character to `i`. */
         for (var j = 0; j < lower.length; j++) {
            norm += lower.charAt(j);
            map.push(i);
         }
      }
      return { norm: norm, map: map };
   }

   function normalizeForSearch(text) {
      return normalizeWithMap(String(text == null ? "" : text)).norm;
   }

   /* ── Search-index loading ────────────────────────────────────────────────── */
   var records = null;
   var loadPromise = null;

   function loadIndex() {
      if (loadPromise) return loadPromise;
      loadPromise = fetch("/assets/search/docc-search.json")
         .then(function (response) { return response.json(); })
         .then(function (manifest) {
            var shards = (manifest && manifest.shards) || [];
            return Promise.all(shards.map(function (url) {
               return fetch(url).then(function (response) { return response.json(); });
            }));
         })
         .then(function (shards) {
            records = Array.prototype.concat.apply([], shards);
            /* Normalize the searchable fields once per load: scoring touches every record
               on each keystroke, so folding at compare time would redo the same work
               thousands of times per character typed. */
            for (var i = 0; i < records.length; i++) {
               records[i].normTitle = normalizeForSearch(records[i].title || "");
               records[i].normText = normalizeForSearch(records[i].text || "");
            }
         })
         .catch(function () {
            records = [];
         });
      return loadPromise;
   }

   function scoreRecord(record, terms) {
      var score = 0;
      for (var i = 0; i < terms.length; i++) {
         var term = terms[i];
         if (record.normTitle.indexOf(term) !== -1) {
            score += 10;
         } else if (record.normText.indexOf(term) !== -1) {
            score += 1;
         } else {
            return 0; // every term must match somewhere
         }
      }
      return score;
   }

   function escapeHTML(value) {
      return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
   }

   /* Escape a value for use inside a double-quoted HTML attribute (href). escapeHTML alone
      leaves a literal `"` intact, which would break out of the attribute; this also escapes
      it. URLs here are server / frontmatter-derived, so this is defense-in-depth parity with
      DocCArticlePage's href escaping, not a known injection vector. */
   function escapeAttr(value) {
      return escapeHTML(value).replace(/"/g, "&quot;");
   }

   /* Wrap each query-term match in <mark>. Terms arrive normalized, so matching runs on
      the normalized text and every hit's range is mapped back onto the original string –
      "whats" still highlights "What’s" (apostrophe included) without shifting offsets.
      Overlapping ranges are merged before marking, then everything is HTML-escaped. */
   function highlight(text, terms) {
      text = String(text == null ? "" : text);
      var nm = normalizeWithMap(text);
      var ranges = [];
      for (var i = 0; i < terms.length; i++) {
         var term = terms[i];
         if (!term) continue;
         var idx = nm.norm.indexOf(term);
         while (idx !== -1) {
            ranges.push([nm.map[idx], nm.map[idx + term.length - 1] + 1]);
            idx = nm.norm.indexOf(term, idx + term.length);
         }
      }
      if (!ranges.length) return escapeHTML(text);
      ranges.sort(function (a, b) { return a[0] - b[0]; });
      var merged = [ranges[0]];
      for (var r = 1; r < ranges.length; r++) {
         var prev = merged[merged.length - 1];
         if (ranges[r][0] <= prev[1]) prev[1] = Math.max(prev[1], ranges[r][1]);
         else merged.push(ranges[r]);
      }
      var out = "";
      var pos = 0;
      for (var m = 0; m < merged.length; m++) {
         out += escapeHTML(text.slice(pos, merged[m][0]))
            + "<mark class=\"sk-docc-search-hl\">" + escapeHTML(text.slice(merged[m][0], merged[m][1])) + "</mark>";
         pos = merged[m][1];
      }
      return out + escapeHTML(text.slice(pos));
   }

   /* The session id is the slug segment right after the wwdcYY- prefix
      (/documentation/wwdc25-10060-meet-x/ → "10060"). */
   function sessionIDFromURL(url, year) {
      var parts = url.split("/").filter(Boolean);
      var slug = parts.length ? parts[parts.length - 1] : "";
      if (!year || slug.indexOf(year + "-") !== 0) return "";
      var rest = slug.slice(year.length + 1);
      var seg = rest.split("-")[0];
      return seg || "";
   }

   /* The "YEAR · sessionID" eyebrow for a record, or "" when it carries no year. */
   function eyebrowFor(record) {
      var year = record.year || "";
      if (!year) return "";
      var sid = sessionIDFromURL(record.url, year);
      return year.toUpperCase() + (sid ? " · " + sid : "");
   }

   /* A framework-keyed gradient square, or a neutral square when no colors are known. */
   function iconHTML(record) {
      var colors = record.framework ? frameworkColors[record.framework] : null;
      var style = "";
      if (colors && colors.length >= 2) {
         style = " style=\"background:linear-gradient(145deg," + colors[0] + "," + colors[1] + ")\"";
      } else if (colors && colors.length === 1) {
         style = " style=\"background:" + colors[0] + "\"";
      }
      return "<span class=\"sk-docc-sessitem-icon\"" + style + " aria-hidden=\"true\"></span>";
   }

   /* Clamp text to ~`limit` chars on a word boundary, appending an ellipsis when cut. */
   function clamp(text, limit) {
      text = (text || "").trim();
      if (text.length <= limit) return text;
      var cut = text.slice(0, limit);
      var lastSpace = cut.lastIndexOf(" ");
      if (lastSpace > limit * 0.5) cut = cut.slice(0, lastSpace);
      return cut + "…";
   }

   /* The body excerpt with the leading abstract stripped: `text` is built abstract-first
      (see DocCSearchIndex), so the panel would otherwise show the description twice. */
   function excerptFrom(record) {
      var text = (record.text || "").trim();
      var summary = (record.summary || "").trim();
      if (summary && text.indexOf(summary) === 0) {
         text = text.slice(summary.length).trim();
      }
      return text;
   }

   /* The one-line row description: the Apple abstract when present, else a body excerpt. */
   function rowBlurb(record) {
      var summary = (record.summary || "").trim();
      return clamp(summary || excerptFrom(record), 140);
   }

   /* One rich result row: framework icon + (eyebrow / title) + 1-line blurb + note-type
      badge + chevron. Matches the dedicated search page's sk-docc-sessitem visual language.
      `index` ties the row back to visibleRecords so hover / focus can drive the preview. */
   function rowHTML(record, terms, index) {
      var eyebrow = eyebrowFor(record);
      var type = record.type || "community";
      var badgeLabel = typeLabels[type] || type;
      var isStub = type === "stub";

      var head = "<div class=\"sk-docc-sessitem-head\">";
      if (eyebrow) head += "<span class=\"sk-docc-sessitem-eyebrow\">" + escapeHTML(eyebrow) + "</span>";
      head += "<span class=\"sk-docc-sessitem-title\">" + highlight(record.title || "", terms) + "</span>";
      head += "</div>";

      var blurb = rowBlurb(record);
      var main = "<div class=\"sk-docc-sessitem-main\">" + head;
      if (blurb) main += "<p class=\"sk-docc-sessitem-blurb\">" + highlight(blurb, terms) + "</p>";
      main += "<div class=\"sk-docc-sessitem-foot\">"
         + "<span class=\"sk-docc-note-badge sk-docc-note-badge--" + type + "\">" + escapeHTML(badgeLabel) + "</span>"
         + "</div>";
      main += "</div>";

      return "<li><a class=\"sk-docc-sessitem" + (isStub ? " is-stub" : "") + "\" href=\"" + escapeAttr(record.url) + "\""
         + " data-docc-search-idx=\"" + index + "\">"
         + iconHTML(record)
         + main
         + "<i class=\"sk-docc-sessitem-chev\" aria-hidden=\"true\">›</i>"
         + "</a></li>";
   }

   /* Small play triangle for the preview's Watch-Video button (mirrors the article page). */
   var playIconSVG = "<svg class=\"sk-docc-watch-ic\" viewBox=\"0 0 24 24\" width=\"14\" height=\"14\""
      + " fill=\"currentColor\" aria-hidden=\"true\"><path d=\"M8 5v14l11-7z\"/></svg>";

   /* Build the preview panel for a record: framework icon + eyebrow, title, the Apple
      abstract, an optional Watch-Video button, a longer excerpt, and a "View more" link.
      The whole panel is keyboard-reachable through the row that drives it (the row is the
      focusable element); the panel's "View more" link and the row share one destination. */
   function previewHTML(record) {
      if (!record) return "";
      var eyebrow = eyebrowFor(record);
      var head = "<div class=\"sk-docc-search-preview-head\">"
         + iconHTML(record)
         + (eyebrow ? "<span class=\"sk-docc-search-preview-eyebrow\">" + escapeHTML(eyebrow) + "</span>" : "")
         + "</div>";

      var html = "<div class=\"sk-docc-search-preview-card\">"
         + head
         + "<h3 class=\"sk-docc-search-preview-title\">" + highlight(record.title || "", activeTerms) + "</h3>";

      var summary = (record.summary || "").trim();
      if (summary) {
         html += "<p class=\"sk-docc-search-preview-desc\">" + highlight(summary, activeTerms) + "</p>";
      }

      if (record.video) {
         var minutes = (typeof record.minutes === "number") ? record.minutes : null;
         var label = watchLabel + (minutes !== null ? " (" + minutes + " min)" : "");
         html += "<a class=\"sk-docc-watch\" href=\"" + escapeAttr(record.video) + "\">" + playIconSVG + escapeHTML(label) + "</a>";
      }

      var excerpt = clamp(excerptFrom(record), 320);
      if (excerpt) {
         html += "<p class=\"sk-docc-search-preview-excerpt\">" + highlight(excerpt, activeTerms) + "</p>";
      }

      html += "<a class=\"sk-docc-search-preview-more\" href=\"" + escapeAttr(record.url) + "\">"
         + escapeHTML(moreLabel) + " <span aria-hidden=\"true\">→</span></a>";
      html += "</div>";
      return html;
   }

   /* Paint the preview panel from the record at `index` and mark its row active so the two
      panes stay visually in sync. Passing -1 clears the panel. */
   function showPreview(index) {
      if (!previewEl) return;
      var rows = results.querySelectorAll(".sk-docc-sessitem");
      for (var i = 0; i < rows.length; i++) {
         rows[i].classList.toggle("is-active", String(index) === rows[i].getAttribute("data-docc-search-idx"));
      }
      var record = (index >= 0 && index < visibleRecords.length) ? visibleRecords[index] : null;
      if (!record) {
         hidePreview();
         return;
      }
      previewEl.innerHTML = previewHTML(record);
      previewEl.hidden = false;
      /* The panel is now visible and holds the only Watch-Video link plus View more, both
         focusable inside the modal's focus trap, so it must be exposed to assistive tech.
         It is only ever shown alongside a focused row, so this does not double-announce. */
      previewEl.removeAttribute("aria-hidden");
   }

   /* Collapse and silence the preview panel: hidden from layout AND from assistive tech, so
      the empty shell is never announced as an unlabeled region. Paired with showPreview's
      removeAttribute on populate. */
   function hidePreview() {
      if (!previewEl) return;
      previewEl.hidden = true;
      previewEl.innerHTML = "";
      previewEl.setAttribute("aria-hidden", "true");
   }

   /* Keep the "See all results →" footer link's query in sync and reveal it once the
      reader has typed something, so the overlay can hand off to the full search page. */
   function updateSeeAll(rawQuery) {
      if (!seeAllFoot || !seeAllLink) return;
      var q = rawQuery.trim();
      var base = seeAllLink.getAttribute("data-docc-search-page-url") || seeAllLink.getAttribute("href");
      seeAllLink.setAttribute("href", q ? base + "?q=" + encodeURIComponent(q) : base);
      seeAllFoot.hidden = !q;
   }

   function clearResults() {
      results.hidden = true;
      results.innerHTML = "";
      visibleRecords = [];
      hidePreview();
      if (countEl) { countEl.hidden = true; countEl.textContent = ""; }
   }

   function renderResults(query) {
      updateSeeAll(query);
      /* Normalize before splitting so each term carries the same folding as the record
         fields. An apostrophe-only query normalizes to nothing and clears like an empty one. */
      var normalized = normalizeForSearch(query.trim());
      var terms = normalized ? normalized.split(/\s+/).filter(Boolean) : [];
      if (!terms.length || !records) {
         clearResults();
         return;
      }
      activeTerms = terms;
      var scored = [];
      for (var i = 0; i < records.length; i++) {
         var score = scoreRecord(records[i], terms);
         if (score > 0) scored.push({ record: records[i], score: score });
      }
      scored.sort(function (a, b) { return b.score - a.score; });
      var top = scored.slice(0, 20);

      if (top.length === 0) {
         visibleRecords = [];
         if (countEl) { countEl.hidden = true; countEl.textContent = ""; }
         hidePreview();
         results.innerHTML = "<li class=\"sk-docc-search-empty\">"
            + "<span class=\"sk-docc-search-empty-title\">" + escapeHTML(emptyTitle) + "</span>"
            + (emptyBody ? "<span class=\"sk-docc-search-empty-body\">" + escapeHTML(emptyBody) + "</span>" : "")
            + "</li>";
         results.hidden = false;
         return;
      }

      if (countEl) {
         countEl.hidden = false;
         countEl.textContent = countTemplate.replace("%lld", String(scored.length));
      }
      visibleRecords = top.map(function (item) { return item.record; });
      results.innerHTML = top.map(function (item, idx) { return rowHTML(item.record, terms, idx); }).join("");
      results.hidden = false;
      /* Auto-populate the preview from the first result so the panel is never empty. */
      showPreview(0);
   }

   /* Drive the preview from the hovered or keyboard-focused row (event delegation). */
   function previewFromEvent(event) {
      var row = event.target.closest ? event.target.closest(".sk-docc-sessitem") : null;
      if (!row) return;
      var idx = parseInt(row.getAttribute("data-docc-search-idx"), 10);
      if (!isNaN(idx)) showPreview(idx);
   }
   results.addEventListener("mouseover", previewFromEvent);
   results.addEventListener("focusin", previewFromEvent);

   var debounceTimer;
   input.addEventListener("input", function () {
      var value = input.value;
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () {
         loadIndex().then(function () { renderResults(value); });
      }, 120);
   });

   /* ── Arrow-key navigation within results ────────────────────────────────
      ArrowDown from the input focuses the first result row; ArrowDown/ArrowUp
      within rows moves focus to the next/previous, wrapping at the ends. Focus
      lands on the row anchor, whose focusin handler also updates the preview.
      This is the standard search-listbox ergonomic on top of Tab navigation. */
   var searchModal = overlay.querySelector(".sk-docc-search-modal");
   if (searchModal) {
      searchModal.addEventListener("keydown", function (event) {
         if (event.key !== "ArrowDown" && event.key !== "ArrowUp") return;
         var resultLinks = results ? Array.prototype.slice.call(results.querySelectorAll(".sk-docc-sessitem")) : [];
         if (!resultLinks.length) return;
         event.preventDefault();
         var focused = document.activeElement;
         var currentIdx = resultLinks.indexOf(focused);
         if (event.key === "ArrowDown") {
            if (focused === input || currentIdx === -1) {
               resultLinks[0].focus();
            } else {
               resultLinks[(currentIdx + 1) % resultLinks.length].focus();
            }
         } else {
            if (focused === input || currentIdx === -1) {
               resultLinks[resultLinks.length - 1].focus();
            } else {
               resultLinks[(currentIdx - 1 + resultLinks.length) % resultLinks.length].focus();
            }
         }
      });
   }
})();
