// SiteKit OpenAPI sidebar enhancement. Progressive enhancement only: the rail is a plain,
// fully navigable list without JS; this script adds collapse/expand twists, a live filter
// box, scrolls the active item into view, and wires the mobile drawer toggle. Mirrors the
// DocC sidebar/filter scripts, adapted to the sk-openapi-* markup.
(function () {
   "use strict";

   // Cut-the-mustard: announce that JS is on as early as the script runs, before the
   // rail is touched. The stylesheet gates the mobile off-canvas drawer behind `html.js`,
   // so a JS-off narrow viewport keeps the rail in normal flow (reachable, not a drawer).
   document.documentElement.classList.add("js");

   function ready(fn) {
      if (document.readyState !== "loading") {
         fn();
      } else {
         document.addEventListener("DOMContentLoaded", fn);
      }
   }

   ready(function () {
      var nav = document.querySelector(".sk-openapi-nav");
      if (!nav) {
         return;
      }

      addCollapseTwists(nav);
      addFilter(nav);
      scrollActiveIntoView(nav);
      wireMobileDrawer(nav);
   });

   // Inject a twist button into each group's header row so a group can be collapsed/
   // expanded. The twist is inserted as a SIBLING of the title link (both children of
   // .sk-openapi-nav-group-header), never inside the <a> – a button nested in an anchor
   // is invalid (nested interactives). The title link still navigates to the tag page.
   function addCollapseTwists(nav) {
      var groups = nav.querySelectorAll(".sk-openapi-nav-group");
      groups.forEach(function (group, index) {
         var header = group.querySelector(".sk-openapi-nav-group-header");
         var title = group.querySelector(".sk-openapi-nav-group-title");
         var items = group.querySelector(".sk-openapi-nav-items");
         if (!header || !items) {
            return;
         }
         // Give the items list a stable id so the twist's aria-controls can point at the
         // region it shows/hides.
         if (!items.id) {
            items.id = "sk-openapi-nav-items-" + index;
         }
         var sectionName = title ? title.textContent.trim() : "section";
         var twist = document.createElement("button");
         twist.type = "button";
         twist.className = "sk-openapi-nav-twist";
         twist.setAttribute("aria-expanded", "true");
         twist.setAttribute("aria-controls", items.id);
         // Name the section so screen-reader users hear which group the twist toggles,
         // rather than the same generic label repeated for every group.
         twist.setAttribute("aria-label", "Toggle the " + sectionName + " section");
         twist.textContent = "▾"; // ▾
         twist.addEventListener("click", function (event) {
            event.preventDefault();
            event.stopPropagation();
            var collapsed = group.classList.toggle("is-collapsed");
            twist.setAttribute("aria-expanded", collapsed ? "false" : "true");
         });
         header.insertBefore(twist, header.firstChild);
      });
   }

   // Inject a filter input that live-filters nav items by substring and hides empty groups.
   function addFilter(nav) {
      var input = document.createElement("input");
      input.type = "search";
      input.className = "sk-openapi-nav-filter";
      input.placeholder = "Filter…";
      input.setAttribute("aria-label", "Filter navigation");

      var home = nav.querySelector(".sk-openapi-nav-home");
      if (home && home.nextSibling) {
         nav.insertBefore(input, home.nextSibling);
      } else {
         nav.insertBefore(input, nav.firstChild);
      }

      input.addEventListener("input", function () {
         var query = input.value.trim().toLowerCase();
         nav.querySelectorAll(".sk-openapi-nav-group").forEach(function (group) {
            var anyVisible = false;
            group.querySelectorAll(".sk-openapi-nav-item").forEach(function (item) {
               var label = item.textContent.toLowerCase();
               var match = query === "" || label.indexOf(query) !== -1;
               item.hidden = !match;
               if (match) {
                  anyVisible = true;
               }
            });
            // Hide a whole group when nothing inside it matches (and a query is active).
            group.hidden = query !== "" && !anyVisible;
         });
      });
   }

   // Keep the current page's item visible: scroll it into the rail's viewport on load.
   function scrollActiveIntoView(nav) {
      var active = nav.querySelector(".sk-openapi-nav-link.is-active");
      if (active && typeof active.scrollIntoView === "function") {
         active.scrollIntoView({ block: "nearest" });
      }
   }

   // Inject a hamburger toggle into the appbar that opens/closes the off-canvas rail on
   // narrow viewports. The CSS shows the toggle only under the responsive breakpoint.
   function wireMobileDrawer(nav) {
      var layout = document.querySelector(".sk-openapi-layout");
      var appbar = document.querySelector(".sk-openapi-appbar");
      if (!layout || !appbar) {
         return;
      }
      // Give the rail a stable id so the toggle's aria-controls can point at the region
      // it opens and closes.
      if (!nav.id) {
         nav.id = "sk-openapi-nav";
      }
      var toggle = document.createElement("button");
      toggle.type = "button";
      toggle.className = "sk-openapi-nav-toggle";
      toggle.setAttribute("aria-label", "Toggle navigation");
      toggle.setAttribute("aria-controls", nav.id);
      toggle.setAttribute("aria-expanded", "false");
      toggle.textContent = "☰"; // ☰

      var scrim = document.querySelector("[data-openapi-nav-scrim]");
      // The scrolling content region (landing cards, page body, footer) – everything that
      // sits behind the scrim when the drawer is open.
      var mainEl = document.querySelector(".sk-openapi-scroll");

      function setOpen(open) {
         layout.classList.toggle("is-nav-open", open);
         toggle.setAttribute("aria-expanded", open ? "true" : "false");
         if (scrim) {
            scrim.hidden = !open;
         }
         // Contain focus the way base SiteKit's docc-sidebar.js does: make the background
         // content inert (a native focus trap + aria-hidden rollup, so Tab cannot reach the
         // page content hidden behind the scrim), lock the body scroll, and mark the rail a
         // modal dialog. The appbar is intentionally NOT inert – it holds the toggle, the
         // drawer's own close control – so closing by hamburger keeps working; Escape and a
         // scrim tap close it too.
         if (mainEl) {
            mainEl.inert = open;
         }
         document.documentElement.style.overflow = open ? "hidden" : "";
         if (open) {
            nav.setAttribute("role", "dialog");
            nav.setAttribute("aria-modal", "true");
            // Move focus into the rail so keyboard users land in the just-opened drawer.
            nav.setAttribute("tabindex", "-1");
            nav.focus();
         } else {
            nav.removeAttribute("aria-modal");
            nav.removeAttribute("role");
            toggle.focus();
         }
      }

      toggle.addEventListener("click", function () {
         setOpen(!layout.classList.contains("is-nav-open"));
      });
      appbar.insertBefore(toggle, appbar.firstChild);

      // Tapping a link closes the drawer so the destination page is visible.
      nav.addEventListener("click", function (event) {
         if (event.target.closest("a")) {
            setOpen(false);
         }
      });

      // Backdrop tap and the Escape key close the drawer (only meaningful while it is open).
      if (scrim) {
         scrim.addEventListener("click", function () {
            setOpen(false);
         });
      }
      document.addEventListener("keydown", function (event) {
         if (event.key === "Escape" && layout.classList.contains("is-nav-open")) {
            setOpen(false);
         }
      });
   }
})();
