/* SiteKit DocC TOC scroll-spy and smooth-scroll.
   Keeps exactly one .sk-docc-toc-item highlighted with the `is-active` class:
   whichever scroll-spy target is the last one at or above the top of the
   independently-scrolling .sk-docc-scroll container.

   Targets are derived from the TOC links themselves: each `a.sk-docc-toc-item`
   whose href starts with `#` resolves to `document.getElementById(id)`. This
   makes the script element-agnostic – it works for article pages (h2/h3 ids)
   and for the home page (section.sk-docc-home-section ids) without any
   additional branching.

   Clicking a TOC item smooth-scrolls the matching element into view within the
   independently-scrolling .sk-docc-scroll container (respecting scroll-margin-top).

   Progressive enhancement: with no JS the anchor links still jump to their
   targets and the `is-active` class is simply never set. Does nothing when
   there is no .sk-docc-toc on the page (short notes without a rail). */
(function () {
   "use strict";

   var layout = document.querySelector(".sk-docc-layout");
   if (!layout) return;

   var toc = layout.querySelector(".sk-docc-toc");
   if (!toc) return;

   var scroller = layout.querySelector(".sk-docc-scroll");
   if (!scroller) return;

   // Collect scroll-spy targets by resolving the TOC link hrefs. The targets are
   // the actual DOM elements the TOC links point at, in document order. This
   // works for article pages (h2/h3 ids) and for the home page (section ids)
   // without any special-casing – the links already encode the target ids.
   function getTargets() {
      var links = Array.from(toc.querySelectorAll("a.sk-docc-toc-item"));
      var targets = [];
      links.forEach(function (a) {
         var href = a.getAttribute("href");
         if (!href || href.charAt(0) !== "#") return;
         var el = document.getElementById(href.slice(1));
         if (el) targets.push(el);
      });
      // Sort in document order so the scroll-spy walk is top-to-bottom.
      targets.sort(function (a, b) {
         var pos = a.compareDocumentPosition(b);
         return (pos & Node.DOCUMENT_POSITION_FOLLOWING) ? -1 : 1;
      });
      return targets;
   }

   // Find the TOC anchor for a given element id.
   function tocLink(id) {
      return toc.querySelector("a.sk-docc-toc-item[href=\"#" + id + "\"]");
   }

   // Set the active TOC item. Clears all others first.
   function setActive(id) {
      var items = Array.from(toc.querySelectorAll(".sk-docc-toc-item"));
      items.forEach(function (a) { a.classList.remove("is-active"); });
      if (!id) return;
      var link = tocLink(id);
      if (link) link.classList.add("is-active");
   }

   // Scroll-spy: walk targets in order and find the last one whose top edge
   // is at or above a threshold inside the scroll viewport. A 90px threshold
   // gives comfortable lead-time so the active item updates before the target
   // fully disappears under the appbar (matches the prototype's `offsetTop - 90`
   // heuristic). Start with the first target as the default so the very top of
   // the page always has something active.
   function computeActive(targets) {
      if (!targets.length) return null;
      // Near-bottom guard: on a genuinely scrollable page, once the scroller reaches
      // (or comes within a few px of) the very bottom of its content, the last target
      // is always active. This handles short pages where the first group heading is
      // never close enough to the top of the viewport for the threshold loop to advance
      // past it. The scrollable check is essential: on a page that does not overflow,
      // scrollTop + clientHeight always equals scrollHeight, so without it the guard
      // would wrongly pin the LAST target active while the user is viewing the top.
      var scrollable = scroller.scrollHeight - scroller.clientHeight > 4;
      if (scrollable && scroller.scrollTop + scroller.clientHeight >= scroller.scrollHeight - 4) {
         return targets[targets.length - 1].id;
      }
      var threshold = scroller.scrollTop + 90;
      var cur = targets[0].id;
      for (var i = 0; i < targets.length; i++) {
         var el = targets[i];
         // offsetTop relative to the scroll container. Walk up the DOM to
         // accumulate the element's offset from the scroller.
         var top = 0;
         var node = el;
         while (node && node !== scroller) {
            top += node.offsetTop;
            node = node.offsetParent;
         }
         if (top <= threshold) {
            cur = el.id;
         } else {
            break;
         }
      }
      return cur;
   }

   // Wire scroll-spy via a passive scroll listener on the scrolling container.
   var targetsCache = null;
   function onScroll() {
      if (!targetsCache) targetsCache = getTargets();
      setActive(computeActive(targetsCache));
   }

   scroller.addEventListener("scroll", onScroll, { passive: true });

   // Initialise active item immediately (covers the case where the page loads
   // mid-scroll, e.g. via a fragment URL).
   targetsCache = getTargets();
   setActive(computeActive(targetsCache));

   // TOC item clicks: smooth-scroll the target element into view within the
   // independently-scrolling .sk-docc-scroll container. The native anchor
   // behaviour would scroll the window/document, which does nothing here because
   // the page body itself does not scroll – only .sk-docc-scroll does.
   Array.from(toc.querySelectorAll("a.sk-docc-toc-item")).forEach(function (a) {
      a.addEventListener("click", function (evt) {
         var href = a.getAttribute("href");
         if (!href || href.charAt(0) !== "#") return;
         var id = href.slice(1);
         var target = document.getElementById(id);
         if (!target) return;
         evt.preventDefault();

         // Accumulate offsetTop relative to the scroller so we land at the
         // correct position inside the independently-scrolling container. Then
         // subtract scroll-margin-top (24px, declared in docc.css) so the
         // target does not sit flush against the appbar after the jump.
         var top = 0;
         var node = target;
         while (node && node !== scroller) {
            top += node.offsetTop;
            node = node.offsetParent;
         }
         var marginTop = parseInt(window.getComputedStyle(target).scrollMarginTop, 10) || 24;
         scroller.scrollTo({ top: top - marginTop, behavior: "smooth" });

         // Immediately reflect the clicked item as active so feedback is instant
         // even before the scroll event fires.
         setActive(id);
      });
   });
})();
