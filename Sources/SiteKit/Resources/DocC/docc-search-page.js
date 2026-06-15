/* SiteKit DocC dedicated search page.
   Hydrates /<prefix>/search/ : a deep-linkable, facet-filtered search over the SAME
   sharded full-text index the ⌘K overlay uses. Reads the query + facets from the URL
   (?q=&year=&type=&framework=; a facet param only applies while its chip group is
   rendered – params for hidden groups are inert), filters by free-text AND facets
   (AND across groups, single-select within a group), renders sk-docc-sessitem result
   rows with the query highlighted, keeps a live count on every facet chip, and writes
   the active state back into the URL so the page stays bookmarkable + shareable.
   Progressive enhancement: with no JS the search box and facet chips are inert and
   the sidebar still navigates. */
(function () {
   "use strict";

   var root = document.querySelector("[data-docc-search-page]");
   if (!root) return; /* Not the search page – nothing to wire. */

   var input = root.querySelector(".sk-docc-searchpage-input");
   var clearQueryBtn = root.querySelector("[data-docc-searchpage-clear-query]");
   var suggestRow = root.querySelector("[data-docc-searchpage-suggest]");
   var countEl = root.querySelector("[data-docc-searchpage-count]");
   var resultsEl = root.querySelector("[data-docc-searchpage-results]");
   var stateEl = root.querySelector("[data-docc-searchpage-state]");
   var clearAllBtn = root.querySelector("[data-docc-search-clear]");
   if (!input || !resultsEl) return;

   /* Localized templates/copy, server-rendered onto the input + root (keeps this script
      free of any English strings). */
   var countTemplate = input.getAttribute("data-docc-search-count") || "%lld results";
   var emptyTitle = input.getAttribute("data-docc-search-empty-title") || "No matches";
   var emptyBody = input.getAttribute("data-docc-search-empty-body") || "";
   var promptText = input.getAttribute("data-docc-search-prompt") || "";
   var loadingText = input.getAttribute("data-docc-search-loading") || "";
   var typeLabels = {
      ai: root.getAttribute("data-docc-label-ai") || "AI",
      community: root.getAttribute("data-docc-label-community") || "Community",
      stub: root.getAttribute("data-docc-label-stub") || "Stub"
   };

   /* Framework → gradient colors, for the colored icon square on each result row. */
   var frameworkColors = {};
   var registryEl = root.querySelector("[data-docc-search-frameworks]");
   if (registryEl) {
      try { frameworkColors = JSON.parse(registryEl.textContent) || {}; } catch (e) { frameworkColors = {}; }
   }

   /* The facet group names; each maps to the matching record field. Only the groups the
      server actually rendered into the aside participate: a group that is absent from the
      DOM (the note-type filter without its config opt-in, or a dimension no record carries)
      stays fully inert – its URL param is ignored on read and dropped on the next URL write.
      An invisible filter must never silently narrow the results. */
   var ALL_GROUPS = ["year", "type", "framework"];
   var GROUPS = ALL_GROUPS.filter(function (group) {
      return !!root.querySelector("[data-docc-facet-group=\"" + group + "\"]");
   });

   /* Active selection: empty string means "All" for that group. */
   var facets = { year: "", type: "", framework: "" };
   var query = "";

   /* Maximum rows painted into the DOM at once. The count line always reports the true
      total; only the rendered list is capped to keep a 2000+ result set light. */
   var MAX_ROWS = 200;

   /* ── URL <-> state ──────────────────────────────────────────────────────── */
   function readStateFromURL() {
      var params = new URLSearchParams(window.location.search);
      query = params.get("q") || "";
      for (var i = 0; i < GROUPS.length; i++) {
         var g = GROUPS[i];
         var key = g === "type" ? "type" : g; /* params already use q/year/type/framework */
         facets[g] = params.get(key) || "";
      }
      input.value = query;
   }

   function writeStateToURL() {
      var params = new URLSearchParams();
      if (query.trim()) params.set("q", query.trim());
      if (facets.year) params.set("year", facets.year);
      if (facets.type) params.set("type", facets.type);
      if (facets.framework) params.set("framework", facets.framework);
      var qs = params.toString();
      var newURL = window.location.pathname + (qs ? "?" + qs : "");
      window.history.replaceState(null, "", newURL);
   }

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

   /* ── Index loading (shared sharded index) ──────────────────────────────── */
   var records = null;
   var loadPromise = null;

   function loadIndex() {
      if (loadPromise) return loadPromise;
      loadPromise = fetch("/assets/search/docc-search.json")
         .then(function (response) { return response.json(); })
         .then(function (manifest) {
            var shards = (manifest && manifest.shards) || [];
            return Promise.all(shards.map(function (url) {
               return fetch(url).then(function (r) { return r.json(); });
            }));
         })
         .then(function (shards) {
            records = Array.prototype.concat.apply([], shards);
            /* Normalize the searchable fields once per load: scoring touches every record
               per keystroke AND per facet-chip count, so folding at compare time would
               redo the same work thousands of times per interaction. */
            for (var i = 0; i < records.length; i++) {
               records[i].normTitle = normalizeForSearch(records[i].title || "");
               records[i].normText = normalizeForSearch(records[i].text || "");
            }
         })
         .catch(function () { records = []; });
      return loadPromise;
   }

   /* ── Matching ───────────────────────────────────────────────────────────── */
   function recordField(record, group) {
      if (group === "year") return record.year || "";
      if (group === "type") return record.type || "";
      if (group === "framework") return record.framework || "";
      return "";
   }

   /* True when the record satisfies every active facet in `f` (a {group: value} map). */
   function matchesFacets(record, f) {
      for (var i = 0; i < GROUPS.length; i++) {
         var g = GROUPS[i];
         if (f[g] && recordField(record, g) !== f[g]) return false;
      }
      return true;
   }

   /* Relevance score: every term must hit the title or body; title hits rank higher.
      Returns 0 when a term is missing (record excluded). With no terms, returns 1 so the
      record passes the query gate while leaving facet/index order intact. */
   function scoreQuery(record, terms) {
      if (!terms.length) return 1;
      var score = 0;
      for (var i = 0; i < terms.length; i++) {
         var term = terms[i];
         if (record.normTitle.indexOf(term) !== -1) score += 10;
         else if (record.normText.indexOf(term) !== -1) score += 1;
         else return 0;
      }
      return score;
   }

   function queryTerms() {
      /* Normalize before splitting so each term carries the same folding as the record
         fields. An apostrophe-only query normalizes to no terms (treated as idle). */
      var normalized = normalizeForSearch(query.trim());
      return normalized ? normalized.split(/\s+/).filter(Boolean) : [];
   }

   /* Count of records that would match if facet `group` were set to `value`, holding the
      current query and the OTHER groups' selections fixed. Drives the live chip counts. */
   function countFor(group, value, terms) {
      if (!records) return 0;
      var probe = { year: facets.year, type: facets.type, framework: facets.framework };
      probe[group] = value;
      var n = 0;
      for (var i = 0; i < records.length; i++) {
         if (matchesFacets(records[i], probe) && scoreQuery(records[i], terms) > 0) n++;
      }
      return n;
   }

   /* ── Rendering ──────────────────────────────────────────────────────────── */
   function escapeHTML(value) {
      return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
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

   function blurbFrom(record) {
      var text = (record.text || "").trim();
      if (text.length <= 150) return text;
      var cut = text.slice(0, 150);
      var lastSpace = cut.lastIndexOf(" ");
      if (lastSpace > 80) cut = cut.slice(0, lastSpace);
      return cut + "…";
   }

   function rowHTML(record, terms) {
      var year = record.year || "";
      var eyebrow = "";
      if (year) {
         var sid = sessionIDFromURL(record.url, year);
         eyebrow = year.toUpperCase() + (sid ? " · " + sid : "");
      }
      var type = record.type || "community";
      var badgeLabel = typeLabels[type] || type;
      var isStub = type === "stub";

      var head = "<div class=\"sk-docc-sessitem-head\">";
      if (eyebrow) head += "<span class=\"sk-docc-sessitem-eyebrow\">" + escapeHTML(eyebrow) + "</span>";
      head += "<span class=\"sk-docc-sessitem-title\">" + highlight(record.title || "", terms) + "</span>";
      head += "</div>";

      var blurb = blurbFrom(record);
      var main = "<div class=\"sk-docc-sessitem-main\">" + head;
      if (blurb) main += "<p class=\"sk-docc-sessitem-blurb\">" + escapeHTML(blurb) + "</p>";
      main += "<div class=\"sk-docc-sessitem-foot\">"
         + "<span class=\"sk-docc-note-badge sk-docc-note-badge--" + type + "\">" + escapeHTML(badgeLabel) + "</span>"
         + "</div>";
      main += "</div>";

      return "<li><a class=\"sk-docc-sessitem" + (isStub ? " is-stub" : "") + "\" href=\"" + record.url + "\">"
         + iconHTML(record)
         + main
         + "<i class=\"sk-docc-sessitem-chev\" aria-hidden=\"true\">›</i>"
         + "</a></li>";
   }

   /* Reflect each chip's active state + live count, and the All chip per group. */
   function updateChips(terms) {
      var chips = root.querySelectorAll("[data-docc-facet]");
      for (var i = 0; i < chips.length; i++) {
         var chip = chips[i];
         var group = chip.getAttribute("data-docc-facet");
         var value = chip.getAttribute("data-docc-facet-value") || "";
         var active = facets[group] === value;
         chip.classList.toggle("is-active", active);
         chip.setAttribute("aria-pressed", active ? "true" : "false");
         var countSlot = chip.querySelector("[data-docc-facet-count]");
         if (countSlot) {
            var n = countFor(group, value, terms);
            countSlot.textContent = String(n);
         }
      }
   }

   function hasActiveFacet() {
      return !!(facets.year || facets.type || facets.framework);
   }

   function setState(html) {
      if (!stateEl) return;
      stateEl.innerHTML = html;
      stateEl.hidden = !html;
   }

   function render() {
      var terms = queryTerms();
      /* Idle keys off the normalized terms (not the raw field) so an apostrophe-only
         query shows the prompt instead of dumping the whole catalog through the
         empty-terms score gate. */
      var idle = !terms.length && !hasActiveFacet();

      /* Field + filter affordances. */
      if (clearQueryBtn) clearQueryBtn.hidden = !query.trim();
      if (clearAllBtn) clearAllBtn.hidden = idle;
      if (suggestRow) suggestRow.hidden = !idle;

      /* Loading shard fetch: only relevant once the reader has expressed intent. */
      if (!records) {
         if (idle) {
            resultsEl.hidden = true;
            resultsEl.innerHTML = "";
            if (countEl) { countEl.hidden = true; }
            setState("<p class=\"sk-docc-searchpage-prompt\">" + escapeHTML(promptText) + "</p>");
         } else {
            resultsEl.hidden = true;
            if (countEl) { countEl.hidden = true; }
            setState("<p class=\"sk-docc-searchpage-loading\">" + escapeHTML(loadingText) + "</p>");
         }
         return;
      }

      updateChips(terms);

      if (idle) {
         resultsEl.hidden = true;
         resultsEl.innerHTML = "";
         if (countEl) { countEl.hidden = true; countEl.textContent = ""; }
         setState("<p class=\"sk-docc-searchpage-prompt\">" + escapeHTML(promptText) + "</p>");
         return;
      }

      /* Filter by facets, then by the query (scored). */
      var scored = [];
      for (var i = 0; i < records.length; i++) {
         var record = records[i];
         if (!matchesFacets(record, facets)) continue;
         var score = scoreQuery(record, terms);
         if (score > 0) scored.push({ record: record, score: score });
      }
      /* Rank by score when a query is present; keep index order for facet-only browse. */
      if (terms.length) scored.sort(function (a, b) { return b.score - a.score; });

      if (scored.length === 0) {
         resultsEl.hidden = true;
         resultsEl.innerHTML = "";
         if (countEl) { countEl.hidden = true; countEl.textContent = ""; }
         setState(
            "<div class=\"sk-docc-search-empty\">"
            + "<span class=\"sk-docc-search-empty-title\">" + escapeHTML(emptyTitle) + "</span>"
            + (emptyBody ? "<span class=\"sk-docc-search-empty-body\">" + escapeHTML(emptyBody) + "</span>" : "")
            + "</div>"
         );
         return;
      }

      setState("");
      if (countEl) {
         countEl.hidden = false;
         countEl.textContent = countTemplate.replace("%lld", String(scored.length));
      }
      var rows = scored.slice(0, MAX_ROWS).map(function (item) { return rowHTML(item.record, terms); });
      resultsEl.innerHTML = rows.join("");
      resultsEl.hidden = false;
   }

   /* Ensure the index is loaded, then render. */
   function refresh() {
      writeStateToURL();
      if (!records) {
         render(); /* paint loading/prompt immediately */
         loadIndex().then(render);
      } else {
         render();
      }
   }

   /* ── Wiring ─────────────────────────────────────────────────────────────── */
   var debounceTimer;
   input.addEventListener("input", function () {
      query = input.value;
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(refresh, 120);
   });

   if (clearQueryBtn) {
      clearQueryBtn.addEventListener("click", function () {
         query = "";
         input.value = "";
         input.focus();
         refresh();
      });
   }

   if (clearAllBtn) {
      clearAllBtn.addEventListener("click", function () {
         query = "";
         input.value = "";
         facets = { year: "", type: "", framework: "" };
         refresh();
      });
   }

   var chips = root.querySelectorAll("[data-docc-facet]");
   for (var c = 0; c < chips.length; c++) {
      chips[c].addEventListener("click", function () {
         var group = this.getAttribute("data-docc-facet");
         var value = this.getAttribute("data-docc-facet-value") || "";
         /* Single-select within a group; clicking the active value toggles it back to All. */
         facets[group] = (facets[group] === value) ? "" : value;
         refresh();
      });
   }

   var suggestChips = root.querySelectorAll("[data-docc-search-suggest]");
   for (var s = 0; s < suggestChips.length; s++) {
      suggestChips[s].addEventListener("click", function () {
         query = this.getAttribute("data-docc-search-suggest") || "";
         input.value = query;
         input.focus();
         refresh();
      });
   }

   /* Initial paint from the URL (deep-link hydration). */
   readStateFromURL();
   refresh();
})();
