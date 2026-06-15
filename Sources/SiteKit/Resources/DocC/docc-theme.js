/* SiteKit DocC appbar theme toggle.
   A single toggle button that mirrors the shared site toggle on fline.dev:
     - Default (no stored 'theme' key): follow the OS appearance. The site's
       headInlineScript already applied the right initial data-theme on <html>;
       this script keeps following live OS changes via a matchMedia listener
       until the user clicks.
     - Click: flip the currently-applied theme (light <-> dark), persist the
       opposite value under localStorage 'theme', and stop following the OS.

   The localStorage key and values ('theme', 'light', 'dark') are IDENTICAL to the
   ones the site's headInlineScript reads on every page load, so the choice persists
   across page navigations and reloads.

   The button icon reflects state: a moon while the page is light (clicking goes
   dark), a sun while the page is dark (clicking goes light). The icon is set on
   load and after every toggle.

   Progressive enhancement: when JS is absent the button renders as inert HTML and
   clicking does not switch the theme. */
(function () {
   "use strict";

   /* The storage key must match the site's headInlineScript so the two are consistent. */
   var STORAGE_KEY = "theme";

   var layout = document.querySelector(".sk-docc-layout");
   if (!layout) return;

   var toggle = layout.querySelector(".sk-docc-theme-toggle");
   if (!toggle) return;

   /* Track the MediaQueryList change listener so auto-follow can be unregistered on click. */
   var mql = window.matchMedia("(prefers-color-scheme:dark)");
   var mqlListener = null;

   /* Moon: shown while the page is light, signalling a click switches to dark. */
   var MOON_ICON =
      "<svg width=\"17\" height=\"17\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
      + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
      + "<path d=\"M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z\"/></svg>";

   /* Sun: shown while the page is dark, signalling a click switches to light. */
   var SUN_ICON =
      "<svg width=\"17\" height=\"17\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\""
      + " stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\">"
      + "<circle cx=\"12\" cy=\"12\" r=\"5\"/>"
      + "<line x1=\"12\" y1=\"1\" x2=\"12\" y2=\"3\"/><line x1=\"12\" y1=\"21\" x2=\"12\" y2=\"23\"/>"
      + "<line x1=\"4.22\" y1=\"4.22\" x2=\"5.64\" y2=\"5.64\"/><line x1=\"18.36\" y1=\"18.36\" x2=\"19.78\" y2=\"19.78\"/>"
      + "<line x1=\"1\" y1=\"12\" x2=\"3\" y2=\"12\"/><line x1=\"21\" y1=\"12\" x2=\"23\" y2=\"12\"/>"
      + "<line x1=\"4.22\" y1=\"19.78\" x2=\"5.64\" y2=\"18.36\"/><line x1=\"18.36\" y1=\"5.64\" x2=\"19.78\" y2=\"4.22\"/></svg>";

   /* The effective theme is whatever the head-init script applied to <html>. */
   function currentTheme() {
      return document.documentElement.getAttribute("data-theme") === "dark" ? "dark" : "light";
   }

   function applyTheme(value) {
      document.documentElement.setAttribute("data-theme", value);
   }

   /* Show the icon for the action the next click performs. */
   function syncIcon() {
      toggle.innerHTML = currentTheme() === "dark" ? SUN_ICON : MOON_ICON;
   }

   /* Remove the auto-follow listener once the user explicitly picks a mode. */
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

   /* Reflect the initial applied theme on load (head-init already set data-theme). */
   syncIcon();

   /* Auto default: with no stored key, keep following live OS changes until a click. */
   if (!localStorage.getItem(STORAGE_KEY)) {
      mqlListener = function (e) {
         /* Only apply while still in auto mode (no stored key). */
         if (!localStorage.getItem(STORAGE_KEY)) {
            applyTheme(e.matches ? "dark" : "light");
            syncIcon();
         } else {
            stopFollowingOS();
         }
      };
      mql.addEventListener("change", mqlListener);
   }
}());
