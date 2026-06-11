document.addEventListener('DOMContentLoaded', function () {
   // Syntax highlighting (if highlight.js is loaded)
   if (typeof hljs !== 'undefined') {
      hljs.highlightAll();
   }

   // Theme toggle (dark/light mode)
   var toggle = document.querySelector('.sk-theme-toggle');
   if (toggle) {
      toggle.addEventListener('click', function () {
         var current = document.documentElement.getAttribute('data-theme');
         var next = current === 'dark' ? 'light' : 'dark';
         document.documentElement.setAttribute('data-theme', next);
         localStorage.setItem('theme', next);
      });
   }
});
