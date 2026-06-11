document.addEventListener('DOMContentLoaded', function() {
   // Dark mode toggle
   const toggle = document.querySelector('.sk-theme-toggle');
   if (toggle) {
      toggle.addEventListener('click', function() {
         const current = document.documentElement.getAttribute('data-theme');
         const next = current === 'dark' ? 'light' : 'dark';
         document.documentElement.setAttribute('data-theme', next);
         localStorage.setItem('theme', next);
      });
   }

   // FAQ accordion – details/summary handles this natively

   // Mobile nav toggle
   const navToggle = document.querySelector('.sk-nav-toggle');
   const navList = document.querySelector('.sk-nav-list');
   if (navToggle && navList) {
      navToggle.addEventListener('click', function() {
         navList.classList.toggle('sk-nav-open');
         const expanded = navToggle.getAttribute('aria-expanded') === 'true';
         navToggle.setAttribute('aria-expanded', !expanded);
      });
   }
});
