// SiteKit OpenAPI appbar search. Progressive enhancement: the search box does nothing without
// JS (the stylesheet hides it until openapi-nav.js adds html.js), so here it is wired to fetch
// the static search index once and filter it client-side. Full-text site search, separate from
// the nav filter in openapi-nav.js (which only hides rows already in the rail).
(function () {
   "use strict";

   var INDEX_URL = "/assets/search-index.json";

   function ready(fn) {
      if (document.readyState !== "loading") {
         fn();
      } else {
         document.addEventListener("DOMContentLoaded", fn);
      }
   }

   ready(function () {
      var input = document.querySelector("[data-openapi-search]");
      if (!input) {
         return;
      }
      var results = document.getElementById("sk-openapi-search-results");
      if (!results) {
         return;
      }

      var records = null;
      var loading = false;

      // Fetch the index lazily on first focus, so a reader who never searches pays nothing.
      function loadIndex() {
         if (records !== null || loading) {
            return;
         }
         loading = true;
         fetch(INDEX_URL)
            .then(function (response) {
               return response.ok ? response.json() : [];
            })
            .then(function (data) {
               records = Array.isArray(data) ? data : [];
               render(input.value);
            })
            .catch(function () {
               records = [];
            });
      }

      function matches(record, query) {
         var hay = (record.title + " " + (record.summary || "") + " " + record.url + " " + (record.method || "")).toLowerCase();
         return hay.indexOf(query) !== -1;
      }

      function render(rawQuery) {
         var query = (rawQuery || "").trim().toLowerCase();
         results.textContent = "";
         if (query === "" || records === null) {
            close();
            return;
         }
         var hits = [];
         for (var i = 0; i < records.length && hits.length < 12; i++) {
            if (matches(records[i], query)) {
               hits.push(records[i]);
            }
         }
         if (hits.length === 0) {
            close();
            return;
         }
         hits.forEach(function (record) {
            var link = document.createElement("a");
            link.className = "sk-openapi-search-hit";
            link.href = record.url;
            link.setAttribute("role", "option");
            if (record.method) {
               var badge = document.createElement("span");
               badge.className = "sk-openapi-method";
               badge.setAttribute("data-method", record.method.toLowerCase());
               badge.textContent = record.method;
               link.appendChild(badge);
            }
            var label = document.createElement("span");
            label.className = "sk-openapi-search-hit-label";
            label.textContent = record.title;
            link.appendChild(label);
            results.appendChild(link);
         });
         results.hidden = false;
         input.setAttribute("aria-expanded", "true");
      }

      function close() {
         results.hidden = true;
         input.setAttribute("aria-expanded", "false");
      }

      input.addEventListener("focus", loadIndex);
      input.addEventListener("input", function () {
         render(input.value);
      });
      // Esc clears and closes; clicking outside closes.
      input.addEventListener("keydown", function (event) {
         if (event.key === "Escape") {
            input.value = "";
            close();
         }
      });
      document.addEventListener("click", function (event) {
         if (!event.target.closest(".sk-openapi-search")) {
            close();
         }
      });
   });
})();
