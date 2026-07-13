// public/homes#top（未ログイン向けゲストLP）
// Turbolinks でページ遷移するたびに再初期化されるよう turbolinks:load で束ねる。
// .glp-page 配下だけを対象にし、他画面への影響を避ける。
document.addEventListener('turbolinks:load', () => {
  const page = document.querySelector('.glp-page');
  if (!page) return;

  const toggle = page.querySelector('.glp-menu-toggle');
  const nav = page.querySelector('.glp-main-nav');

  if (toggle && nav) {
    toggle.addEventListener('click', () => {
      const isOpen = nav.classList.toggle('glp-main-nav--open');
      toggle.setAttribute('aria-expanded', String(isOpen));
    });

    page.querySelectorAll('.glp-main-nav a').forEach((link) => {
      link.addEventListener('click', () => {
        nav.classList.remove('glp-main-nav--open');
        toggle.setAttribute('aria-expanded', 'false');
      });
    });
  }

  page.querySelectorAll('.glp-faq-question').forEach((button) => {
    button.addEventListener('click', () => {
      const expanded = button.getAttribute('aria-expanded') === 'true';
      const answer = button.nextElementSibling;

      page.querySelectorAll('.glp-faq-question').forEach((other) => {
        if (other !== button) {
          other.setAttribute('aria-expanded', 'false');
          if (other.nextElementSibling) other.nextElementSibling.style.maxHeight = null;
        }
      });

      button.setAttribute('aria-expanded', String(!expanded));
      if (answer) answer.style.maxHeight = expanded ? null : `${answer.scrollHeight}px`;
    });
  });

  const revealTargets = page.querySelectorAll('.glp-reveal');
  if (revealTargets.length && 'IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('glp-reveal--visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.14 });

    revealTargets.forEach((el) => observer.observe(el));
  } else {
    revealTargets.forEach((el) => el.classList.add('glp-reveal--visible'));
  }
});
