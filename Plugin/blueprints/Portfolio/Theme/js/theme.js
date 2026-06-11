document.addEventListener('DOMContentLoaded', function() {
   // Dark mode toggle
   var toggle = document.querySelector('.sk-theme-toggle');
   if (toggle) {
      toggle.addEventListener('click', function() {
         var current = document.documentElement.getAttribute('data-theme');
         var next = current === 'dark' ? 'light' : 'dark';
         document.documentElement.setAttribute('data-theme', next);
         localStorage.setItem('theme', next);
      });
   }

   // Mobile nav toggle
   var navToggle = document.querySelector('.sk-nav-toggle');
   var navList = document.querySelector('.sk-nav-list');
   if (navToggle && navList) {
      navToggle.addEventListener('click', function() {
         navList.classList.toggle('sk-nav-open');
         var expanded = navToggle.getAttribute('aria-expanded') === 'true';
         navToggle.setAttribute('aria-expanded', !expanded);
      });
   }
});
