/* SiteKit DocC off-canvas sidebar toggle.
   Below the CSS breakpoint the DocC sidebar is a drawer hidden off-screen. The
   hamburger button in the appbar opens it over a dark scrim; the close button,
   the scrim, the Escape key, or following a nav link closes it again. Progressive
   enhancement: with no JS the sidebar still works – it stacks above the content via
   the no-JS fallback CSS, so navigation is never blocked. */
(function () {
   "use strict";

   var layout = document.querySelector(".sk-docc-layout");
   if (!layout) return;

   // Mark the layout JS-enabled so the off-canvas CSS wins over the no-JS fallback
   // (which keeps the sidebar stacked + visible when this script never runs).
   layout.classList.add("sk-docc-js");

   var openBtn = layout.querySelector("[data-docc-sidebar-open]");
   var closeBtn = layout.querySelector("[data-docc-sidebar-close]");
   var scrim = layout.querySelector("[data-docc-sidebar-scrim]");
   var sidebar = layout.querySelector(".sk-docc-sidebar");

   function setOpen(open) {
      if (open) {
         layout.setAttribute("data-sidebar-open", "");
      } else {
         layout.removeAttribute("data-sidebar-open");
      }
      if (openBtn) openBtn.setAttribute("aria-expanded", open ? "true" : "false");
      if (scrim) scrim.hidden = !open;
      // Mark the open drawer as a modal dialog and make the rest of the page inert,
      // so keyboard + screen-reader users can't tab/browse into the content behind the
      // scrim (native focus trap + aria-hidden rollup via `inert`). aria-modal is
      // toggled (not static) so the desktop sidebar is never treated as a dialog.
      if (sidebar) {
         if (open) sidebar.setAttribute("aria-modal", "true");
         else sidebar.removeAttribute("aria-modal");
      }
      var mainEl = layout.querySelector("main");
      var appbarEl = layout.querySelector(".sk-docc-appbar");
      if (mainEl) mainEl.inert = open;
      // The appbar holds the burger + brand; inert it too so a keyboard user can't
      // tab out of the open drawer into the chrome behind the scrim.
      if (appbarEl) appbarEl.inert = open;
      // Lock background scroll only while the drawer is open, so the content behind
      // the scrim doesn't move under the user's finger. (overflow:hidden on <html>
      // does not stop iOS Safari rubber-band scroll; a full fix uses body{position:fixed}.)
      document.documentElement.style.overflow = open ? "hidden" : "";
   }

   function open() {
      setOpen(true);
      // Move focus into the drawer for keyboard + screen-reader users.
      if (closeBtn) {
         closeBtn.focus();
      } else if (sidebar) {
         sidebar.focus();
      }
   }

   function close() {
      setOpen(false);
      if (openBtn) openBtn.focus();
   }

   if (openBtn) openBtn.addEventListener("click", open);
   if (closeBtn) closeBtn.addEventListener("click", close);
   if (scrim) scrim.addEventListener("click", close);

   // Tapping any nav link closes the drawer so the user lands on the new page with
   // the content visible (not stuck behind the still-open sidebar).
   if (sidebar) {
      sidebar.addEventListener("click", function (event) {
         var link = event.target.closest("a.sk-docc-nav-link");
         if (link) close();
      });
   }

   document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && layout.hasAttribute("data-sidebar-open")) {
         close();
      }
   });

   /* ── Single-accordion subtree controller + lazy-hydrate ────────────────────
      Every top item (.sk-docc-nav-top) has a twist [data-docc-subtree-toggle] that
      controls the subtree named by its aria-controls. At most one top branch is open
      at a time (the accordion) – EXCEPT while the bottom filter has an active query,
      when docc-filter.js opens all matching branches and suspends this rule.

      Active-branch-only DOM: only the current year's sessions are server-rendered. A
      non-active year's subtree is an empty placeholder marked data-docc-unhydrated; on
      first twist-open the JS fetches /assets/docc-sidebar-nav.json once (memoized),
      builds rows that match the renderer's markup, injects them, then opens. Navigate
      fallback only when the fetch fails or the year is missing – never a dead twist.

      Shared contract with docc-filter.js: both scripts read/write the same `hidden` +
      `aria-expanded` attributes and key off `.sk-docc-nav-top`; neither owns a state
      object. No-JS fallback: the active branch is server-rendered open (no `hidden`,
      aria-expanded="true") and every twist is an <a> to its branch overview, so with no
      JS the twist natively navigates to an overview rendered expanded (never a dead
      control); with JS this handler intercepts the click and toggles/hydrates inline. */
   var tops = Array.prototype.slice.call(layout.querySelectorAll(".sk-docc-nav-top"));

   function subtreeOf(top) {
      var twist = top.querySelector("[data-docc-subtree-toggle]");
      if (!twist) return null;
      var id = twist.getAttribute("aria-controls");
      return id ? document.getElementById(id) : null;
   }

   function setBranchOpen(top, open) {
      var twist = top.querySelector("[data-docc-subtree-toggle]");
      var sub = subtreeOf(top);
      if (sub) {
         if (open) sub.removeAttribute("hidden");
         else sub.setAttribute("hidden", "");
      }
      if (twist) twist.setAttribute("aria-expanded", open ? "true" : "false");
   }

   function navigateRow(top) {
      var navLink = top.querySelector("a.sk-docc-nav-link");
      if (navLink && navLink.href) window.location.href = navLink.href;
   }

   // Accordion: open this branch, close every other top branch.
   function openAccordion(top) {
      tops.forEach(function (other) {
         if (other !== top) setBranchOpen(other, false);
      });
      setBranchOpen(top, true);
   }

   /* ── Lazy-hydrate plumbing ─────────────────────────────────────────────────
      The nav JSON is fetched at most once per visit and shared by every twist via a
      single memoized promise. Hydrated rows mirror DocCSidebarRenderer's session-row
      markup; the framework icon is cloned from an already-inlined in-DOM icon of the
      same framework (the FA <i> is swapped for an inline <svg> at build time, so
      re-emitting an <i class="fa-…"> would render nothing), falling back to the
      renderer's neutral placeholder when that framework is not present on the page. */
   var navDataPromise = null;
   function loadNavData() {
      if (!navDataPromise) {
         navDataPromise = fetch("/assets/docc-sidebar-nav.json").then(function (resp) {
            if (!resp.ok) throw new Error("docc-sidebar-nav.json " + resp.status);
            return resp.json();
         });
      }
      return navDataPromise;
   }

   var stubTitle = sidebar ? sidebar.getAttribute("data-docc-stub-title") : null;

   // Inlined framework icons already on the page, keyed by framework, so hydrated rows
   // reuse the exact same SVG markup the server-rendered rows use.
   var iconByFramework = {};
   Array.prototype.forEach.call(
      layout.querySelectorAll(".sk-docc-nav-fw-icon[data-framework]"),
      function (el) {
         var fw = el.getAttribute("data-framework");
         if (fw && !iconByFramework[fw]) iconByFramework[fw] = el.outerHTML;
      }
   );

   function escapeHTML(value) {
      return String(value)
         .replace(/&/g, "&amp;")
         .replace(/"/g, "&quot;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;");
   }

   function iconHTML(framework) {
      if (framework && iconByFramework[framework]) return iconByFramework[framework];
      // Matches DocCSidebarRenderer's no-framework fallback byte-for-byte.
      return '<span class="sk-docc-nav-icon" aria-hidden="true"></span>';
   }

   function sessionRowHTML(session) {
      var stubClass = session.isStub ? " sk-docc-nav-stub" : "";
      var stubAttr = session.isStub && stubTitle ? ' title="' + escapeHTML(stubTitle) + '"' : "";
      return '<li class="sk-docc-nav-session' + stubClass + '">'
         + '<a class="sk-docc-nav-link" href="' + escapeHTML(session.url) + '"' + stubAttr + ">"
         + iconHTML(session.framework)
         + '<span class="sk-docc-nav-text">' + escapeHTML(session.title) + "</span></a></li>";
   }

   // Build a year's subtree inner HTML, mirroring DocCSidebarRenderer: a flat list when the
   // year has no topic groups, otherwise subgroup headers + an ungrouped remainder. Sorted
   // slug order equals the renderer's slug-sorted children order.
   function buildSubtreeInner(yearData) {
      var sessions = yearData.sessions || {};
      var groups = yearData.groups || [];
      var sortedSlugs = Object.keys(sessions).sort();

      if (groups.length === 0) {
         return sortedSlugs
            .map(function (slug) { return sessionRowHTML(sessions[slug]); })
            .join("");
      }

      var placed = {};
      var html = "";
      groups.forEach(function (group) {
         var rows = "";
         (group.slugs || []).forEach(function (slug) {
            if (sessions[slug]) {
               placed[slug] = true;
               rows += sessionRowHTML(sessions[slug]);
            }
         });
         if (rows) {
            html += '<li class="sk-docc-nav-subgroup">'
               + '<span class="sk-docc-nav-subgroup-h">' + escapeHTML(group.title) + "</span>"
               + '<ul class="sk-docc-nav-sessions">' + rows + "</ul></li>";
         }
      });
      var ungrouped = sortedSlugs
         .filter(function (slug) { return !placed[slug]; })
         .map(function (slug) { return sessionRowHTML(sessions[slug]); })
         .join("");
      if (ungrouped) html += '<li class="sk-docc-nav-subgroup">' + ungrouped + "</li>";
      return html;
   }

   function hydrateAndOpen(top, sub) {
      var year = sub.getAttribute("data-docc-unhydrated");
      loadNavData()
         .then(function (data) {
            var yearData = data && data[year];
            var inner = yearData ? buildSubtreeInner(yearData) : "";
            // Year missing, or present but empty: never open a dead/empty list – navigate the
            // row link to the overview, which server-renders the branch expanded.
            if (!inner) {
               navigateRow(top);
               return;
            }
            sub.innerHTML = inner;
            if ((yearData.groups || []).length > 0) sub.classList.add("sk-docc-nav-grouped");
            sub.removeAttribute("data-docc-unhydrated");
            openAccordion(top);
         })
         .catch(function () {
            // Fetch failed – fall back to navigating the row link (never a dead twist).
            navigateRow(top);
         });
   }

   tops.forEach(function (top) {
      var twist = top.querySelector("[data-docc-subtree-toggle]");
      if (!twist) return;
      twist.addEventListener("click", function (event) {
         // The twist is an <a> pointing at the branch overview so it navigates with no JS.
         // With JS we own the interaction: cancel the navigation and hydrate/toggle inline.
         // The explicit navigateRow() fallbacks below still navigate when there is nothing
         // to open (fetch failed, year missing), so the row is never a dead control.
         event.preventDefault();
         var sub = subtreeOf(top);
         var isOpen = sub && !sub.hasAttribute("hidden");
         if (isOpen) {
            // Plain toggle-off; closing the only-open branch leaves none open (allowed).
            setBranchOpen(top, false);
            return;
         }
         // Non-active year placeholder: hydrate from the nav JSON on first open, then accordion.
         if (sub && sub.hasAttribute("data-docc-unhydrated")) {
            hydrateAndOpen(top, sub);
            return;
         }
         // A genuinely empty, unmarked subtree has nothing to open – navigate the row link.
         if (!sub || sub.children.length === 0) {
            navigateRow(top);
            return;
         }
         openAccordion(top);
      });
   });

   /* ── Shared with docc-filter.js ─────────────────────────────────────────────
      The bottom filter (loaded right after this script) gives the sidebar cross-year reach: it
      searches the same in-memory nav JSON for non-active years and renders only the matching rows.
      Handing it the fetch-once promise plus the row builder keeps that to ONE network fetch and makes
      a cross-year filter match byte-identical to a lazy-hydrated row – same markup, same framework
      icon cloned from the hidden legend. Both scripts cooperate through the same `hidden` +
      `aria-expanded` contract; neither owns a state object. */
   window.SKDocCNav = {
      loadNavData: loadNavData,
      buildSubtreeInner: buildSubtreeInner,
   };
})();
