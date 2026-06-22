// SiteKit OpenAPI appbar theme toggle. Consistent with the base SiteKit (DocC) toggle:
//   - Default (no stored 'theme' key): follow the OS appearance. The inline head-init already
//     applied the initial data-theme; this script keeps following live OS changes via a
//     matchMedia listener until the user clicks.
//   - Click: flip the applied theme (light <-> dark), persist the opposite under localStorage
//     'theme', and stop following the OS.
// The key and values ('theme', 'light', 'dark') are identical to the head-init's, so the choice
// persists across page navigations and reloads and matches every other SiteKit surface.
// Progressive enhancement: without JS the button renders as inert HTML and clicking does not switch.
(function () {
   "use strict";

   var STORAGE_KEY = "theme";

   var toggle = document.querySelector(".sk-openapi-theme-toggle");
   if (!toggle) {
      return;
   }

   var mql = window.matchMedia("(prefers-color-scheme:dark)");
   var mqlListener = null;

   var MOON_ICON =
      "<svg width=\"17\" height=\"17\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
      + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
      + "<path d=\"M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z\"/></svg>";

   var SUN_ICON =
      "<svg width=\"17\" height=\"17\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
      + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
      + "<circle cx=\"12\" cy=\"12\" r=\"5\"/>"
      + "<line x1=\"12\" y1=\"1\" x2=\"12\" y2=\"3\"/><line x1=\"12\" y1=\"21\" x2=\"12\" y2=\"23\"/>"
      + "<line x1=\"4.22\" y1=\"4.22\" x2=\"5.64\" y2=\"5.64\"/><line x1=\"18.36\" y1=\"18.36\" x2=\"19.78\" y2=\"19.78\"/>"
      + "<line x1=\"1\" y1=\"12\" x2=\"3\" y2=\"12\"/><line x1=\"21\" y1=\"12\" x2=\"23\" y2=\"12\"/>"
      + "<line x1=\"4.22\" y1=\"19.78\" x2=\"5.64\" y2=\"18.36\"/><line x1=\"18.36\" y1=\"5.64\" x2=\"19.78\" y2=\"4.22\"/></svg>";

   function currentTheme() {
      return document.documentElement.getAttribute("data-theme") === "dark" ? "dark" : "light";
   }

   function applyTheme(value) {
      document.documentElement.setAttribute("data-theme", value);
   }

   function syncIcon() {
      toggle.innerHTML = currentTheme() === "dark" ? SUN_ICON : MOON_ICON;
   }

   function stopFollowingOS() {
      if (mqlListener) {
         mql.removeEventListener("change", mqlListener);
         mqlListener = null;
      }
   }

   toggle.addEventListener("click", function () {
      stopFollowingOS();
      var next = currentTheme() === "dark" ? "light" : "dark";
      localStorage.setItem(STORAGE_KEY, next);
      applyTheme(next);
      syncIcon();
   });

   syncIcon();

   if (!localStorage.getItem(STORAGE_KEY)) {
      mqlListener = function (event) {
         if (!localStorage.getItem(STORAGE_KEY)) {
            applyTheme(event.matches ? "dark" : "light");
            syncIcon();
         } else {
            stopFollowingOS();
         }
      };
      mql.addEventListener("change", mqlListener);
   }
})();
