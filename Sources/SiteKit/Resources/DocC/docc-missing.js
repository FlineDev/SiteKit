/* SiteKit DocC missing-sessions show-more toggle.

   Each year's coverage row (`.sk-docc-coverage`) renders every stub card, but the
   cards beyond the fold carry `.sk-docc-missing-card--extra` and the row ends with a
   `.sk-docc-missing-more` button that starts `hidden`. This script collapses the
   overflow cards and reveals the button, then toggles them on click.

   Progressive enhancement: with no JS every card stays visible and the button never
   appears, so all stub sessions remain reachable (the page just scrolls longer). The
   reveal is an instant display toggle with no animation, so there is nothing for
   `prefers-reduced-motion` to suppress.

   The button's two labels ride on `data-docc-missing-label-more` / `-less`, so the
   visible text stays whatever the server localized – no English is baked into the
   script. Does nothing on pages without a `[data-docc-missing-more]` button. */
(function () {
   "use strict";

   var buttons = document.querySelectorAll("[data-docc-missing-more]");
   if (!buttons.length) return;

   Array.prototype.forEach.call(buttons, function (button) {
      var row = button.closest(".sk-docc-coverage");
      if (!row) return;

      // Only enhance rows that actually have folded cards. A row whose stubs all fit
      // within the fold should never have rendered a button, but guard anyway.
      var extras = row.querySelectorAll(".sk-docc-missing-card--extra");
      if (!extras.length) return;

      var labelMore = button.getAttribute("data-docc-missing-label-more") || button.textContent;
      var labelLess = button.getAttribute("data-docc-missing-label-less") || labelMore;

      // JS is present: collapse the overflow and surface the toggle.
      row.classList.add("is-collapsed");
      button.textContent = labelMore;
      button.setAttribute("aria-expanded", "false");
      button.hidden = false;

      button.addEventListener("click", function () {
         var collapsed = row.classList.toggle("is-collapsed");
         button.setAttribute("aria-expanded", collapsed ? "false" : "true");
         button.textContent = collapsed ? labelMore : labelLess;
      });
   });
})();
