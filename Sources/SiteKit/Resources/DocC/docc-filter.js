/* SiteKit DocC sidebar tree filter.
   Lives at the bottom of the sidebar (.sk-docc-filter). Live-filters the navigation tree as the
   reader types: session rows that do not match the query are hidden, matched text is wrapped in
   <mark>, and every branch holding a match is opened.

   Cross-year reach: under the active-branch-only DOM only the current year's sessions are
   server-rendered, so a query typed from the docs root (or any non-matching year) would otherwise
   surface nothing outside the active year. To give the sidebar production-parity cross-year search
   WITHOUT dumping the whole catalog into the DOM, the filter searches the in-memory nav JSON – the
   same fetch-once promise docc-sidebar.js owns – for non-active years and renders ONLY the matching
   sessions into their year subtrees, auto-expanding only the years that hold a match. Match count,
   not tree size, drives the DOM work. A minimum query length plus a short debounce keep the first
   keystroke from triggering any cross-year render at all (the earlier in-DOM-only version pointed
   cross-year search at the ⌘K overlay precisely to avoid rendering the full tree on a keystroke;
   rendering match-only rows from the JSON resolves that without the mass-render cost).

   Progressive enhancement: with no JS the filter box is a static form element that does not filter;
   the tree stays fully accessible as static HTML links (each year row links to its expanded overview). */
(function () {
   "use strict";

   var layout = document.querySelector(".sk-docc-layout");
   if (!layout) return;

   var filterInput = layout.querySelector(".sk-docc-filter-input");
   var clearBtn = layout.querySelector(".sk-docc-filter-clear");
   if (!filterInput) return;

   // Shared helpers from docc-sidebar.js (loaded just before this script): the fetch-once nav-JSON
   // promise and the subtree-row builder. Reusing them means no second network fetch and rows that
   // are byte-identical to a lazy-hydrated branch (same icon-clone path via the hidden legend). Null
   // only if docc-sidebar.js did not run – the filter then degrades to in-DOM-only search.
   var nav = window.SKDocCNav || null;

   // A query shorter than this never filters (treated as empty), and matching is debounced, so the
   // first character typed never kicks off a cross-year render of the whole catalog.
   var MIN_QUERY = 2;
   var DEBOUNCE_MS = 150;

   // Shared contract with docc-sidebar.js: both read/write the same `hidden` + `aria-expanded`
   // attributes and key off `.sk-docc-nav-top`. While a query is active this filter owns branch
   // open-state (it opens every matching branch and suspends the accordion's single-open rule);
   // on clear it hands back to active-branch-only and the accordion's twist handlers resume.
   var topBranches = Array.from(layout.querySelectorAll(".sk-docc-nav-top"));

   function subtreeOfTop(top) {
      var twist = top.querySelector("[data-docc-subtree-toggle]");
      if (!twist) return null;
      var id = twist.getAttribute("aria-controls");
      return id ? document.getElementById(id) : null;
   }

   function setTopOpen(top, open) {
      var twist = top.querySelector("[data-docc-subtree-toggle]");
      var sub = subtreeOfTop(top);
      if (sub) {
         if (open) sub.removeAttribute("hidden");
         else sub.setAttribute("hidden", "");
      }
      if (twist) twist.setAttribute("aria-expanded", open ? "true" : "false");
   }

   // A subtree the cross-year search owns: a non-active year still in its unhydrated placeholder
   // state, or one this filter has already injected matching rows into. The in-DOM passes below skip
   // these (their visibility + open-state is driven entirely by the cross-year search) so the two
   // never fight over the same subtree. The active year, Contributors, and any year the reader
   // lazy-hydrated by hand have real rows in the DOM and stay with the in-DOM passes.
   function isCrossYearManaged(sub) {
      return !!sub && (sub.hasAttribute("data-docc-unhydrated") || sub.hasAttribute("data-docc-filter-injected"));
   }

   // The branch the server rendered open (the active one): the .sk-docc-nav-top whose subtree
   // carries no `hidden`. Captured once on load so clearing the query can restore exactly the
   // active-branch-only state – matching a fresh page load and no-JS.
   var initialOpenBranch = (function () {
      for (var i = 0; i < topBranches.length; i++) {
         var sub = subtreeOfTop(topBranches[i]);
         if (sub && !sub.hasAttribute("hidden")) return topBranches[i];
      }
      return null;
   })();

   // In-DOM filterable rows: server-rendered or user-hydrated session rows + year/loose rows. Rows
   // the cross-year search injected are excluded – they are always matches (re-rendered per keystroke
   // from the JSON), so the per-row hide/show pass must not touch them.
   function getFilterableItems() {
      return Array.from(layout.querySelectorAll(".sk-docc-nav-session, .sk-docc-nav-item"))
         .filter(function (li) { return !li.closest("[data-docc-filter-injected]"); });
   }

   // Search normalization (kept in sync across docc-filter.js, docc-search.js, docc-search-page.js):
   // fold typographic apostrophes/quotes to ASCII, strip apostrophes entirely, lowercase – so
   // "whats new", "what's new", and "What’s New" all hit the same titles. Matching runs on the
   // normalized strings; `map` carries each normalized character's original index so a highlight
   // range can be mapped back (stripping apostrophes shifts every offset after them).
   function normalizeWithMap(text) {
      var norm = "";
      var map = [];
      for (var i = 0; i < text.length; i++) {
         var ch = text.charAt(i);
         if (ch === "‘" || ch === "’") ch = "'";
         else if (ch === "“" || ch === "”") ch = "\"";
         if (ch === "'") continue;
         var lower = ch.toLowerCase();
         // Rarely more than one character (e.g. İ → i̇) – map each produced character to `i`.
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

   // Wrap the first occurrence of `query` (already normalized) in `text` with a <mark>; return the
   // modified text, or the original when there is no match. Matching runs on the normalized text
   // and the hit is mapped back onto the original string, so "whats" highlights "What’s" – with its
   // apostrophe – instead of marking a shifted range.
   function highlight(text, query) {
      if (!query) return text;
      var nm = normalizeWithMap(text);
      var idx = nm.norm.indexOf(query);
      if (idx < 0) return text;
      var start = nm.map[idx];
      var end = nm.map[idx + query.length - 1] + 1;
      return text.slice(0, start) + "<mark class=\"sk-docc-hl\">" + text.slice(start, end) + "</mark>" + text.slice(end);
   }

   // Store the original text content of each in-DOM filterable row's .sk-docc-nav-text
   // so we can restore it when the filter is cleared.
   var originalTexts = new WeakMap();

   function saveOriginals() {
      var items = getFilterableItems();
      items.forEach(function (li) {
         var textEl = li.querySelector(".sk-docc-nav-text");
         if (textEl && !originalTexts.has(li)) {
            originalTexts.set(li, textEl.innerHTML);
         }
      });
   }

   // Restore a cross-year subtree to the empty, hidden, unhydrated placeholder the server rendered,
   // so a later twist lazy-hydrates it exactly as on a fresh load (the active-branch-only contract).
   // A subtree that was never injected into is left untouched.
   function restorePlaceholder(sub) {
      if (!sub || !sub.hasAttribute("data-docc-filter-injected")) return;
      var year = sub.getAttribute("data-docc-filter-year") || sub.getAttribute("data-docc-unhydrated");
      sub.innerHTML = "";
      sub.classList.remove("sk-docc-nav-grouped");
      if (year) sub.setAttribute("data-docc-unhydrated", year);
      sub.removeAttribute("data-docc-filter-injected");
      sub.removeAttribute("data-docc-filter-year");
      sub.setAttribute("hidden", "");
   }

   // Build the inner HTML of ONLY the sessions in `yearData` whose title matches `query`, reusing
   // docc-sidebar.js's subtree builder so the rows (and their framework icons) are byte-identical to
   // a lazy-hydrated branch. Returns "" when the year holds no matching session.
   function matchingSubtreeInner(yearData, query) {
      var sessions = (yearData && yearData.sessions) || {};
      var filtered = {};
      var any = false;
      Object.keys(sessions).forEach(function (slug) {
         var session = sessions[slug];
         var title = session && session.title != null ? String(session.title) : "";
         if (normalizeForSearch(title).indexOf(query) >= 0) {
            filtered[slug] = session;
            any = true;
         }
      });
      if (!any) return "";
      // The shared builder emits a row only for slugs present in `sessions`, so passing the matching
      // subset keeps each topic group to its matching rows (and drops empty groups) for free.
      return nav.buildSubtreeInner({ groups: yearData.groups || [], sessions: filtered });
   }

   // Highlight the query inside every freshly-injected session row's text. The injected rows are
   // escaped, match-only, and rebuilt from scratch each keystroke, so none needs an original saved.
   function highlightInjected(sub, query) {
      Array.prototype.forEach.call(sub.querySelectorAll(".sk-docc-nav-session .sk-docc-nav-text"), function (textEl) {
         textEl.innerHTML = highlight(textEl.innerHTML, query);
      });
   }

   // Monotonic guard: every applyFilter call bumps this, and an in-flight cross-year response only
   // applies when its sequence still matches – so a stale fetch (the reader typed again, or cleared)
   // never paints outdated rows.
   var filterSeq = 0;

   // Search the in-memory nav JSON for every cross-year-managed branch and render only its matches.
   // Async (shares docc-sidebar.js's fetch-once promise). With no match a previously-injected branch
   // is restored to its pristine unhydrated placeholder so a later twist still lazy-hydrates it.
   function applyCrossYear(query, seq) {
      if (!nav || !nav.loadNavData || !nav.buildSubtreeInner) return;
      nav.loadNavData().then(function (data) {
         if (seq !== filterSeq) return; // a newer query (or a clear) superseded this one
         if (!data) return;
         topBranches.forEach(function (top) {
            var sub = subtreeOfTop(top);
            if (!isCrossYearManaged(sub)) return;
            var year = sub.getAttribute("data-docc-filter-year") || sub.getAttribute("data-docc-unhydrated");
            var labelEl = top.querySelector(".sk-docc-nav-row .sk-docc-nav-text");
            var labelMatch = labelEl ? normalizeForSearch(labelEl.textContent).indexOf(query) >= 0 : false;
            var yearData = year ? data[year] : null;
            var inner = yearData ? matchingSubtreeInner(yearData, query) : "";
            if (inner) {
               sub.innerHTML = inner;
               if ((yearData.groups || []).length > 0) sub.classList.add("sk-docc-nav-grouped");
               else sub.classList.remove("sk-docc-nav-grouped");
               // Take ownership of the subtree for the duration of the query: drop the unhydrated
               // marker (so a twist does not also full-hydrate it) and remember the year so a clear
               // can restore the placeholder exactly.
               sub.setAttribute("data-docc-filter-year", year);
               sub.setAttribute("data-docc-filter-injected", "");
               sub.removeAttribute("data-docc-unhydrated");
               highlightInjected(sub, query);
               top.hidden = false;
               setTopOpen(top, true);
            } else {
               // No session match this year: drop any prior injection back to the placeholder and
               // show the year row (collapsed) only when its own label matches.
               restorePlaceholder(sub);
               top.hidden = !labelMatch;
               setTopOpen(top, false);
            }
         });
      });
   }

   function applyFilter(q) {
      // Invalidate any in-flight cross-year response before recomputing.
      filterSeq += 1;
      var seq = filterSeq;
      var query = normalizeForSearch(q.trim());
      // A query below the minimum length behaves exactly like an empty one – no filtering, no render.
      if (query.length < MIN_QUERY) query = "";

      if (!query) {
         // Hand back to active-branch-only: remove every cross-year injection first so the tree
         // matches a fresh page load (and the no-JS fallback) before the in-DOM restore runs.
         Array.prototype.forEach.call(layout.querySelectorAll("[data-docc-filter-injected]"), restorePlaceholder);
      }

      saveOriginals();
      var items = getFilterableItems();

      items.forEach(function (li) {
         var link = li.querySelector(".sk-docc-nav-link, .sk-docc-nav-year");
         var textEl = li.querySelector(".sk-docc-nav-text");
         if (!link || !textEl) return;

         var original = originalTexts.get(li) || textEl.innerHTML;
         if (!query) {
            li.hidden = false;
            textEl.innerHTML = original;
            return;
         }

         var plainText = textEl.textContent || textEl.innerText || "";
         if (normalizeForSearch(plainText).indexOf(query) >= 0) {
            li.hidden = false;
            textEl.innerHTML = highlight(original, query);
         } else {
            li.hidden = true;
            textEl.innerHTML = original;
         }
      });

      // Also show/hide year-group <li>s based on whether any child session is visible.
      var yearItems = Array.from(layout.querySelectorAll(".sk-docc-nav-item"));
      yearItems.forEach(function (yearLi) {
         if (!query) {
            yearLi.hidden = false;
            return;
         }
         // Cross-year-managed years (non-active placeholders / filter-injected) have their
         // visibility driven by applyCrossYear; leave them to it.
         if (yearLi.classList.contains("sk-docc-nav-top") && isCrossYearManaged(subtreeOfTop(yearLi))) return;
         // A year row matches if its own title matches...
         var yearLink = yearLi.querySelector(".sk-docc-nav-year");
         var yearText = yearLink ? (yearLink.textContent || "") : "";
         var titleMatch = normalizeForSearch(yearText).indexOf(query) >= 0;
         // ...or at least one session row inside it is visible.
         var sessions = Array.from(yearLi.querySelectorAll(".sk-docc-nav-session"));
         var anyVisible = sessions.some(function (s) { return !s.hidden; });
         yearLi.hidden = !(titleMatch || anyVisible);
      });

      // Show/hide subgroup <li>s based on whether any contained session is visible.
      var subgroups = Array.from(layout.querySelectorAll(".sk-docc-nav-subgroup"));
      subgroups.forEach(function (sg) {
         if (!query) {
            sg.hidden = false;
            return;
         }
         // Subgroups inside a cross-year injection are match-only already; applyCrossYear owns them.
         if (sg.closest("[data-docc-filter-injected]")) return;
         var sessions = Array.from(sg.querySelectorAll(".sk-docc-nav-session"));
         sg.hidden = sessions.length > 0 && sessions.every(function (s) { return s.hidden; });
      });

      // Open every matching in-DOM top branch (the search exception: multiple branches open at once,
      // suspending the single-accordion rule); on clear, restore active-branch-only so only the
      // server-rendered branch stays open. Cross-year-managed branches are opened/closed by
      // applyCrossYear instead, from the match-only rows it injects.
      topBranches.forEach(function (top) {
         if (!query) {
            setTopOpen(top, top === initialOpenBranch);
            return;
         }
         var sub = subtreeOfTop(top);
         if (isCrossYearManaged(sub)) return;
         var labelEl = top.querySelector(".sk-docc-nav-row .sk-docc-nav-text");
         var labelMatch = labelEl ? normalizeForSearch(labelEl.textContent).indexOf(query) >= 0 : false;
         var hasVisibleDescendant = sub
            ? Array.from(sub.querySelectorAll(".sk-docc-nav-session")).some(function (s) { return !s.hidden; })
            : false;
         setTopOpen(top, labelMatch || hasVisibleDescendant);
      });

      // Cross-year search runs only with an active query; on clear the injections were already
      // dropped above, restoring the active-branch-only state.
      if (query) applyCrossYear(query, seq);
   }

   var debounceTimer = null;

   filterInput.addEventListener("input", function () {
      var q = filterInput.value;
      if (clearBtn) clearBtn.hidden = !q;
      if (debounceTimer) {
         clearTimeout(debounceTimer);
         debounceTimer = null;
      }
      // Clearing (or dropping below the minimum length) restores instantly – no debounce, no async
      // render – so deleting characters feels immediate and never schedules a stale cross-year paint.
      if (q.trim().length < MIN_QUERY) {
         applyFilter("");
         return;
      }
      debounceTimer = setTimeout(function () {
         debounceTimer = null;
         applyFilter(q);
      }, DEBOUNCE_MS);
   });

   if (clearBtn) {
      clearBtn.addEventListener("click", function () {
         filterInput.value = "";
         if (debounceTimer) {
            clearTimeout(debounceTimer);
            debounceTimer = null;
         }
         applyFilter("");
         clearBtn.hidden = true;
         filterInput.focus();
      });
   }
})();
