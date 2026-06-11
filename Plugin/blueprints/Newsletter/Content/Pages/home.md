---
title: "My Newsletter"
slug: home
description: "A newsletter about your topic"
---

<div class="newsletter-signup" id="newsletter-signup">
   <h2>Subscribe to My Newsletter</h2>
   <p>Get the latest issues delivered straight to your inbox.</p>
   <form action="YOUR_FORM_ACTION_URL" method="post">
      <input type="email" name="contact[email]" placeholder="your@email.com" required />
      <button type="submit">Subscribe</button>
   </form>
   <small style="display: block; margin-top: 0.75rem; color: var(--color-text-secondary); font-size: 0.8rem;">No spam, unsubscribe anytime. We respect your privacy.</small>
</div>
<div class="newsletter-signup newsletter-welcome" id="newsletter-welcome" style="display: none;">
   <h2>Welcome aboard!</h2>
   <p>Your subscription is confirmed. You'll receive the next issue straight to your inbox.</p>
   <p style="margin-bottom: 0;"><a href="/blog/" style="color: var(--color-accent); font-weight: 600;">Browse the archive →</a></p>
</div>
