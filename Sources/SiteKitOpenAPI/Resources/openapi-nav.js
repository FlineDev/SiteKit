// SiteKit OpenAPI sidebar enhancement. Progressive enhancement only: the rail is a plain,
// fully navigable list without JS; this script adds collapse/expand twists, a live filter
// box, scrolls the active item into view, and wires the mobile drawer toggle. Mirrors the
// DocC sidebar/filter scripts, adapted to the sk-openapi-* markup.
(function () {
   "use strict";

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

   // Inject a twist button into each group header so a group can be collapsed/expanded.
   // The header stays a link (it navigates to the tag page); only the twist toggles.
   function addCollapseTwists(nav) {
      var groups = nav.querySelectorAll(".sk-openapi-nav-group");
      groups.forEach(function (group) {
         var header = group.querySelector(".sk-openapi-nav-group-title");
         var items = group.querySelector(".sk-openapi-nav-items");
         if (!header || !items) {
            return;
         }
         var twist = document.createElement("button");
         twist.type = "button";
         twist.className = "sk-openapi-nav-twist";
         twist.setAttribute("aria-expanded", "true");
         twist.setAttribute("aria-label", "Toggle section");
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
      var toggle = document.createElement("button");
      toggle.type = "button";
      toggle.className = "sk-openapi-nav-toggle";
      toggle.setAttribute("aria-label", "Toggle navigation");
      toggle.setAttribute("aria-expanded", "false");
      toggle.textContent = "☰"; // ☰
      toggle.addEventListener("click", function () {
         var open = layout.classList.toggle("is-nav-open");
         toggle.setAttribute("aria-expanded", open ? "true" : "false");
      });
      appbar.insertBefore(toggle, appbar.firstChild);

      // Tapping a link closes the drawer so the destination page is visible.
      nav.addEventListener("click", function (event) {
         if (event.target.closest("a")) {
            layout.classList.remove("is-nav-open");
            toggle.setAttribute("aria-expanded", "false");
         }
      });
   }
})();
