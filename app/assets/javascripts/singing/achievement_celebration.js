(function () {
  // レアリティ高い順
  var RARITY_ORDER = ['legendary', 'epic', 'rare', 'common'];
  var CONFETTI_COLORS = ['#f59e0b', '#ec4899', '#8b5cf6', '#10b981', '#3b82f6', '#ef4444', '#fbbf24'];

  var queue = [];
  var isShowing = false;

  // ── utils ───────────────────────────────────────────────────────────────────

  function rarityRank(rarity) {
    var idx = RARITY_ORDER.indexOf(rarity);
    return idx === -1 ? 999 : idx;
  }

  function escapeHtml(str) {
    return String(str || '').replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function celebrationKey(diagnosisId) {
    return 'achievement_celebrated_' + diagnosisId;
  }

  function alreadyCelebrated(diagnosisId) {
    try { return !!localStorage.getItem(celebrationKey(diagnosisId)); } catch (e) { return false; }
  }

  function markCelebrated(diagnosisId) {
    try { localStorage.setItem(celebrationKey(diagnosisId), '1'); } catch (e) {}
  }

  // ── fetch with retry ────────────────────────────────────────────────────────

  function fetchBadges(url, retries, onSuccess) {
    fetch(url, { headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } })
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (data) {
        var badges = (data && data.badges) || [];
        if (badges.length > 0) {
          onSuccess(badges);
        } else if (retries > 0) {
          setTimeout(function () { fetchBadges(url, retries - 1, onSuccess); }, 3000);
        }
      })
      .catch(function () {
        if (retries > 0) {
          setTimeout(function () { fetchBadges(url, retries - 1, onSuccess); }, 3000);
        }
      });
  }

  // ── queue ───────────────────────────────────────────────────────────────────

  function buildQueue(badges) {
    return badges.slice()
      .sort(function (a, b) { return rarityRank(a.rarity) - rarityRank(b.rarity); })
      .slice(0, 3);
  }

  function showNext(config) {
    if (queue.length === 0) { isShowing = false; return; }
    isShowing = true;
    var badge = queue.shift();

    if (badge.rarity === 'legendary' || badge.rarity === 'epic') {
      showModal(badge, config, function () {
        setTimeout(function () { showNext(config); }, 500);
      });
    } else {
      showToast(badge, config, function () {
        setTimeout(function () { showNext(config); }, 500);
      });
    }
  }

  // ── modal (legendary / epic) ─────────────────────────────────────────────────

  function showModal(badge, config, onClose) {
    var overlay = document.createElement('div');
    overlay.className = 'achievement-modal-overlay';

    var modal = document.createElement('div');
    modal.className = 'achievement-modal achievement-modal--' + badge.rarity;
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-label', 'バッジ獲得おめでとうございます');

    var confettiHtml = badge.rarity === 'legendary'
      ? '<div class="achievement-modal__confetti" aria-hidden="true">' + buildConfettiHtml() + '</div>'
      : '';

    modal.innerHTML = confettiHtml +
      '<div class="achievement-modal__inner">' +
        '<p class="achievement-modal__eyebrow">🎉 バッジ獲得！</p>' +
        '<span class="achievement-modal__badge-icon">' + escapeHtml(badge.emoji) + '</span>' +
        '<h2 class="achievement-modal__title">' + escapeHtml(badge.label) + '</h2>' +
        '<p class="achievement-modal__desc">' + escapeHtml(badge.description) + '</p>' +
        buildCtaHtml(badge, config) +
        '<button class="achievement-modal__close-btn" type="button">続ける →</button>' +
      '</div>';

    overlay.appendChild(modal);
    document.body.appendChild(overlay);
    document.body.style.overflow = 'hidden';

    // animate in
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        overlay.classList.add('achievement-modal-overlay--visible');
        modal.classList.add('achievement-modal--visible');
      });
    });

    // epic: 10秒 auto close
    var autoTimer = null;
    if (badge.rarity === 'epic') {
      autoTimer = setTimeout(closeModal, 10000);
    }

    function closeModal() {
      if (autoTimer) { clearTimeout(autoTimer); autoTimer = null; }
      overlay.classList.remove('achievement-modal-overlay--visible');
      modal.classList.remove('achievement-modal--visible');
      setTimeout(function () {
        document.body.style.overflow = '';
        if (overlay.parentNode) { overlay.parentNode.removeChild(overlay); }
        onClose();
      }, 320);
    }

    modal.querySelector('.achievement-modal__close-btn').addEventListener('click', closeModal);

    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) { closeModal(); }
    });

    function onKeydown(e) {
      if (e.key === 'Escape') {
        document.removeEventListener('keydown', onKeydown);
        closeModal();
      }
    }
    document.addEventListener('keydown', onKeydown);

    // turbolinks でページ離脱時に強制クリーンアップ
    document.addEventListener('turbolinks:before-cache', function cleanup() {
      document.removeEventListener('turbolinks:before-cache', cleanup);
      document.removeEventListener('keydown', onKeydown);
      if (overlay.parentNode) { overlay.parentNode.removeChild(overlay); }
      document.body.style.overflow = '';
    }, { once: true });
  }

  // ── toast (rare / common) ────────────────────────────────────────────────────

  function showToast(badge, config, onClose) {
    var isRare = badge.rarity === 'rare';
    var duration = isRare ? 5000 : 3000;

    var toast = document.createElement('div');
    toast.className = 'achievement-toast achievement-toast--' + badge.rarity;
    toast.setAttribute('role', 'status');
    toast.setAttribute('aria-live', 'polite');

    var closeBtn = isRare
      ? '<button class="achievement-toast__close" type="button" aria-label="閉じる">×</button>'
      : '';

    var descHtml = isRare
      ? '<span class="achievement-toast__desc">' + escapeHtml(badge.description) + '</span>'
      : '';

    toast.innerHTML =
      '<span class="achievement-toast__emoji">' + escapeHtml(badge.emoji) + '</span>' +
      '<span class="achievement-toast__text">' +
        '<strong class="achievement-toast__label">' + escapeHtml(badge.label) + '</strong>' +
        descHtml +
      '</span>' +
      closeBtn;

    document.body.appendChild(toast);

    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        toast.classList.add('achievement-toast--visible');
      });
    });

    function removeToast() {
      toast.classList.remove('achievement-toast--visible');
      setTimeout(function () {
        if (toast.parentNode) { toast.parentNode.removeChild(toast); }
        onClose();
      }, 350);
    }

    var timer = setTimeout(removeToast, duration);

    var closeBtnEl = toast.querySelector('.achievement-toast__close');
    if (closeBtnEl) {
      closeBtnEl.addEventListener('click', function () {
        clearTimeout(timer);
        removeToast();
      });
    }
  }

  // ── CTA html ────────────────────────────────────────────────────────────────

  function buildCtaHtml(badge, config) {
    var btns = [];

    if (config.canShare) {
      btns.push(
        '<a href="' + escapeHtml(config.sharePath) + '" class="achievement-modal__cta-btn achievement-modal__cta-btn--primary">' +
          '🎴 シェアカードを作る' +
        '</a>'
      );
    }

    if (config.canPin) {
      btns.push(
        '<a href="' + escapeHtml(config.badgesPath) + '" class="achievement-modal__cta-btn achievement-modal__cta-btn--secondary">' +
          '📌 プロフィールに固定する' +
        '</a>'
      );
    }

    btns.push(
      '<a href="' + escapeHtml(config.badgesPath) + '" class="achievement-modal__cta-btn achievement-modal__cta-btn--ghost">' +
        '🏅 バッジ一覧を見る' +
      '</a>'
    );

    return '<div class="achievement-modal__ctas">' + btns.join('') + '</div>';
  }

  // ── confetti html ────────────────────────────────────────────────────────────

  function buildConfettiHtml() {
    var html = '';
    for (var i = 0; i < 22; i++) {
      var color    = CONFETTI_COLORS[i % CONFETTI_COLORS.length];
      var left     = Math.floor(Math.random() * 100);
      var delay    = (Math.random() * 1.8).toFixed(2);
      var duration = (2.0 + Math.random() * 1.8).toFixed(2);
      html += '<span class="achievement-confetti__particle" style="' +
        'left:' + left + '%;' +
        'animation-delay:' + delay + 's;' +
        'animation-duration:' + duration + 's;' +
        'background:' + color + ';' +
      '"></span>';
    }
    return html;
  }

  // ── init ────────────────────────────────────────────────────────────────────

  function initAchievementCelebration() {
    var container = document.getElementById('achievement-celebration');
    if (!container) { return; }

    var diagnosisId = container.dataset.diagnosisId;
    if (!diagnosisId) { return; }

    if (alreadyCelebrated(diagnosisId)) { return; }

    var config = {
      apiUrl:     container.dataset.apiUrl,
      canShare:   container.dataset.canShare === 'true',
      canPin:     container.dataset.canPin === 'true',
      badgesPath: container.dataset.badgesPath,
      sharePath:  container.dataset.sharePath
    };

    // 3秒後に polling 開始（Job 完了を待つ）
    setTimeout(function () {
      fetchBadges(config.apiUrl, 3, function (badges) {
        markCelebrated(diagnosisId);
        queue = buildQueue(badges);

        // 0.8秒の間を置いて演出開始（急な出現を避ける）
        setTimeout(function () {
          if (!isShowing) { showNext(config); }
        }, 800);
      });
    }, 3000);
  }

  document.addEventListener('DOMContentLoaded', initAchievementCelebration);
  document.addEventListener('turbolinks:load', initAchievementCelebration);
})();
