(function () {
  'use strict';

  // ── State ──────────────────────────────────────────────────────────────────

  var initialized  = false;
  var activeOverlay = null;
  var activeModal   = null;
  var triggerEl     = null;

  var FOCUSABLE = 'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])';

  // ── Helpers ────────────────────────────────────────────────────────────────

  function csrfToken() {
    var m = document.querySelector('meta[name="csrf-token"]');
    return m ? m.getAttribute('content') : '';
  }

  function escapeHtml(str) {
    return String(str || '').replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  function rarityLabel(rarity) {
    return { legendary: 'LEGENDARY', epic: 'EPIC', rare: 'RARE', common: 'NORMAL' }[rarity] || String(rarity).toUpperCase();
  }

  function categoryLabel(cat) {
    var map = { milestone: '節目', streak: '連続', score: 'スコア', growth: '成長', ranking: 'ランキング', skill: 'スキル', challenge: 'チャレンジ', special: '特別' };
    return map[cat] || String(cat);
  }

  // ── Emoji class（earned / locked 段階）────────────────────────────────────

  function emojiClass(data) {
    var base = 'badge-detail-modal__emoji badge-detail-modal__emoji--' + escapeHtml(data.rarity || 'common');
    if (data.earned) { return base; }
    var ratio = parseFloat(data.progress_ratio) || 0;
    if (ratio >= 0.8)  { return base + ' badge-detail-modal__emoji--locked-close'; }
    if (ratio >= 0.5)  { return base + ' badge-detail-modal__emoji--locked-near'; }
    return base + ' badge-detail-modal__emoji--locked';
  }

  // ── HTML builders ──────────────────────────────────────────────────────────

  function buildModalHtml(data) {
    return (
      '<div class="badge-detail-modal__drag-handle" aria-hidden="true"></div>' +
      '<button class="badge-detail-modal__close" type="button" aria-label="閉じる">&#215;</button>' +
      '<div class="badge-detail-modal__body">' +
        buildEmojiSection(data) +
        buildHeader(data) +
        (data.earned ? buildEarnedBody(data) : buildLockedBody(data)) +
      '</div>'
    );
  }

  function buildEmojiSection(data) {
    return (
      '<div class="badge-detail-modal__emoji-wrap">' +
        '<span class="' + emojiClass(data) + '" aria-hidden="true">' + escapeHtml(data.emoji) + '</span>' +
      '</div>'
    );
  }

  function buildHeader(data) {
    return (
      '<div class="badge-detail-modal__header">' +
        '<span class="badge-detail-modal__rarity-chip badge-detail-modal__rarity-chip--' + escapeHtml(data.rarity || 'common') + '">' +
          rarityLabel(data.rarity) +
        '</span>' +
        '<h2 class="badge-detail-modal__label">' + escapeHtml(data.label) + '</h2>' +
        '<span class="badge-detail-modal__category-tag">' + categoryLabel(data.category) + '</span>' +
      '</div>'
    );
  }

  // ── Earned body ────────────────────────────────────────────────────────────

  function buildEarnedBody(data) {
    var html = '';

    if (data.earned_at_label) {
      html += '<p class="badge-detail-modal__earned-date">&#10003; ' + escapeHtml(data.earned_at_label) + '</p>';
    }

    html += '<div class="badge-detail-modal__divider"></div>';

    if (data.growth_story) {
      html += (
        '<p class="badge-detail-modal__growth-story badge-detail-modal__growth-story--' + escapeHtml(data.rarity || 'common') + '">' +
          escapeHtml(data.growth_story) +
        '</p>'
      );
    }

    if (data.description) {
      html += '<p class="badge-detail-modal__description">' + escapeHtml(data.description) + '</p>';
    }

    // Pin + Share buttons
    var hasPin   = !!(data.show_pin && data.badge_id);
    var hasShare = !!(data.can_share && data.share_url);

    if (hasPin || hasShare) {
      html += '<div class="badge-detail-modal__actions">';

      if (hasPin) {
        var isPinned = data.pinned === true;
        html += (
          '<button type="button"' +
          ' class="badge-detail-modal__pin-btn' + (isPinned ? ' badge-detail-modal__pin-btn--active' : '') + '"' +
          ' data-badge-id="' + escapeHtml(String(data.badge_id)) + '"' +
          ' data-pin-url="' + escapeHtml(data.pin_url || '') + '"' +
          ' data-unpin-url="' + escapeHtml(data.unpin_url || '') + '"' +
          ' data-pinned="' + (isPinned ? 'true' : 'false') + '">' +
          (isPinned ? '&#9733; 固定済み' : '&#9734; 固定する') +
          '</button>'
        );
      }

      if (hasShare) {
        html += '<a class="badge-detail-modal__share-btn" href="' + escapeHtml(data.share_url) + '">&#128228; シェア</a>';
      }

      html += '</div>';
    }

    // Next badge（progression chain）
    if (data.next_badge && !data.next_badge.earned) {
      html += buildNextBadge(data);
    }

    return html;
  }

  // ── Locked body ────────────────────────────────────────────────────────────

  function buildLockedBody(data) {
    var ratio = parseFloat(data.progress_ratio) || 0;
    var html  = '';

    html += '<div class="badge-detail-modal__locked-badge"><span>&#128274;</span><span>未獲得</span></div>';

    if (ratio >= 0.5 && data.hint_text) {
      // Progress bar（ratio ≥ 0.5 で解禁）
      var percent = Math.round(ratio * 100);
      var isClose  = ratio >= 0.8;
      html += '<div class="badge-detail-modal__progress-section">';
      html += '<p class="badge-detail-modal__progress-hint-text">' + escapeHtml(data.hint_text) + '</p>';
      html += '<div class="badge-detail-modal__progress-bar-wrap">';
      html += '<div class="badge-detail-modal__progress-bar-track">';
      html += (
        '<div class="badge-detail-modal__progress-bar-fill' +
        ' badge-detail-modal__progress-bar-fill--' + escapeHtml(data.rarity || 'common') +
        (isClose ? ' badge-detail-modal__progress-bar-fill--close' : '') +
        '" style="width:' + percent + '%"></div>'
      );
      html += '</div>';
      html += '<span class="badge-detail-modal__progress-rate">' + percent + '%</span>';
      html += '</div>';
      if (isClose && data.detail_text) {
        html += '<p class="badge-detail-modal__progress-detail">' + escapeHtml(data.detail_text) + '</p>';
      }
      html += '</div>';
    } else {
      // ratio < 0.5: locked_description のみ（条件を明かしすぎない）
      html += '<p class="badge-detail-modal__locked-desc">' + escapeHtml(data.locked_description || data.description || '') + '</p>';
    }

    // CTA
    if (data.diagnose_url) {
      html += (
        '<div class="badge-detail-modal__cta-wrap">' +
          '<a class="badge-detail-modal__cta-btn" href="' + escapeHtml(data.diagnose_url) + '">' +
            escapeHtml(data.cta_label || '診断する →') +
          '</a>' +
        '</div>'
      );
    }

    return html;
  }

  // ── Next badge section ─────────────────────────────────────────────────────

  function buildNextBadge(data) {
    var nb  = data.next_badge;
    return (
      '<div class="badge-detail-modal__next-section">' +
        '<p class="badge-detail-modal__next-label">次に目指すバッジ</p>' +
        '<div class="badge-detail-modal__next-badge">' +
          '<span class="badge-detail-modal__next-emoji">' + escapeHtml(nb.emoji || '') + '</span>' +
          '<div class="badge-detail-modal__next-body">' +
            '<p class="badge-detail-modal__next-badge-label">' + escapeHtml(nb.label || '') + '</p>' +
            '<span class="badge-detail-modal__next-badge-rarity">' + rarityLabel(nb.rarity || 'common') + '</span>' +
          '</div>' +
          (data.diagnose_url
            ? '<a class="badge-detail-modal__next-cta" href="' + escapeHtml(data.diagnose_url) + '">' + escapeHtml(data.cta_label || '挑戦する →') + '</a>'
            : '') +
        '</div>' +
      '</div>'
    );
  }

  // ── Focus trap ─────────────────────────────────────────────────────────────

  function getFocusable(container) {
    return Array.prototype.filter.call(
      container.querySelectorAll(FOCUSABLE),
      function (el) { return !el.disabled && el.offsetParent !== null; }
    );
  }

  function trapFocus(e) {
    if (!activeModal || e.key !== 'Tab') { return; }
    var focusable = getFocusable(activeModal);
    if (focusable.length === 0) { e.preventDefault(); return; }
    var first = focusable[0];
    var last  = focusable[focusable.length - 1];
    if (e.shiftKey) {
      if (document.activeElement === first) { e.preventDefault(); last.focus(); }
    } else {
      if (document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  }

  // ── Open / Close ───────────────────────────────────────────────────────────

  function openModal(data, trigger) {
    if (activeOverlay) { return; }
    triggerEl = trigger;

    var overlay = document.createElement('div');
    overlay.className = 'badge-detail-overlay';

    var modal = document.createElement('div');
    modal.className = 'badge-detail-modal badge-detail-modal--' + (data.rarity || 'common');
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-modal', 'true');
    modal.setAttribute('aria-label', data.earned ? 'バッジ詳細' : '未獲得バッジの詳細');
    modal.innerHTML = buildModalHtml(data);

    overlay.appendChild(modal);
    document.body.appendChild(overlay);
    document.body.style.overflow = 'hidden';

    activeOverlay = overlay;
    activeModal   = modal;

    // Animate in（2-frame delay で CSS transition を確実に起動）
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        overlay.classList.add('badge-detail-overlay--visible');
        modal.classList.add('badge-detail-modal--visible');
      });
    });

    // Initial focus
    requestAnimationFrame(function () {
      var focusable = getFocusable(modal);
      if (focusable.length > 0) { focusable[0].focus(); }
    });

    overlay.addEventListener('click', function (e) {
      if (e.target === overlay) { closeModal(); }
    });

    modal.addEventListener('click', function (e) {
      handleModalClick(e, data);
    });
  }

  function closeModal() {
    if (!activeOverlay) { return; }
    var overlay = activeOverlay;
    var modal   = activeModal;
    var trigger = triggerEl;

    activeOverlay = null;
    activeModal   = null;
    triggerEl     = null;

    overlay.classList.remove('badge-detail-overlay--visible');
    modal.classList.remove('badge-detail-modal--visible');

    setTimeout(function () {
      document.body.style.overflow = '';
      if (overlay.parentNode) { overlay.parentNode.removeChild(overlay); }
      if (trigger && trigger.focus) { trigger.focus(); }
    }, 250);
  }

  // ── Modal internal click handler ───────────────────────────────────────────

  function handleModalClick(e, data) {
    if (e.target.closest('.badge-detail-modal__close')) {
      closeModal();
      return;
    }
    var pinBtn = e.target.closest('.badge-detail-modal__pin-btn');
    if (pinBtn) { handlePin(pinBtn); }
  }

  // ── Pin / Unpin API ────────────────────────────────────────────────────────

  function handlePin(btn) {
    var isPinned = btn.dataset.pinned === 'true';
    var url      = isPinned ? btn.dataset.unpinUrl : btn.dataset.pinUrl;
    if (!url) { return; }

    btn.disabled = true;

    fetch(url, {
      method:  'PATCH',
      headers: { 'X-CSRF-Token': csrfToken(), 'Accept': 'application/json' }
    })
      .then(function (res) { return res.json(); })
      .then(function (result) {
        if (result.ok) {
          var nowPinned = result.pinned;
          btn.dataset.pinned = nowPinned ? 'true' : 'false';
          btn.innerHTML = nowPinned ? '&#9733; 固定済み' : '&#9734; 固定する';
          btn.classList.toggle('badge-detail-modal__pin-btn--active', nowPinned);

          // Gallery カードの pin ボタンも同期
          var cardBtn = document.querySelector(
            '.achievement-badge-card__pin-btn[data-badge-id="' + btn.dataset.badgeId + '"]'
          );
          if (cardBtn) {
            cardBtn.dataset.pinned = nowPinned ? 'true' : 'false';
            cardBtn.textContent    = nowPinned ? '★' : '☆';
            cardBtn.title          = nowPinned ? '固定を解除する' : 'プロフィールに固定する';
            cardBtn.setAttribute('aria-label', cardBtn.title);
            cardBtn.classList.toggle('achievement-badge-card__pin-btn--active', nowPinned);
          }

          showPinToast(result.message, false);
        } else {
          showPinToast(result.message, true);
        }
      })
      .catch(function () { showPinToast('通信エラーが発生しました', true); })
      .finally(function () { btn.disabled = false; });
  }

  function showPinToast(message, isError) {
    var old = document.querySelector('.achievement-pin-toast');
    if (old) { old.remove(); }
    var toast = document.createElement('div');
    toast.className = 'achievement-pin-toast' + (isError ? ' achievement-pin-toast--error' : '');
    toast.textContent = message;
    document.body.appendChild(toast);
    requestAnimationFrame(function () { toast.classList.add('achievement-pin-toast--visible'); });
    setTimeout(function () { if (toast.parentNode) { toast.parentNode.removeChild(toast); } }, 2800);
  }

  // ── Global keyboard handlers ───────────────────────────────────────────────

  function onKeydown(e) {
    if (e.key === 'Escape' && activeOverlay) { closeModal(); return; }

    // Focus trap（Tab キー）
    trapFocus(e);

    // Card 上で Enter / Space → modal を開く
    if ((e.key === 'Enter' || e.key === ' ') && !activeOverlay) {
      var card = e.target.closest('.achievement-badge-card');
      if (card && e.target === card) {
        e.preventDefault();
        triggerOpen(card);
      }
    }
  }

  // ── Card click / keyboard open ─────────────────────────────────────────────

  function triggerOpen(card) {
    var raw = card.dataset.badgeModal;
    if (!raw) { return; }
    var data;
    try { data = JSON.parse(raw); } catch (_) { return; }
    openModal(data, card);
  }

  function onDocumentClick(e) {
    var card = e.target.closest('.achievement-badge-card');
    if (!card) { return; }
    // pin button / share link / 他の button・a タグへのクリックは無視
    if (e.target.closest('button') || e.target.closest('a')) { return; }
    triggerOpen(card);
  }

  // ── Turbolinks cleanup ─────────────────────────────────────────────────────

  function onBeforeCache() {
    if (!activeOverlay) { return; }
    document.body.style.overflow = '';
    if (activeOverlay.parentNode) { activeOverlay.parentNode.removeChild(activeOverlay); }
    activeOverlay = null;
    activeModal   = null;
    triggerEl     = null;
  }

  // ── Init（guard: listeners を1回だけ付ける）──────────────────────────────

  function init() {
    if (initialized) { return; }
    initialized = true;

    document.addEventListener('click',    onDocumentClick);
    document.addEventListener('keydown',  onKeydown);
    document.addEventListener('turbolinks:before-cache', onBeforeCache);
  }

  document.addEventListener('DOMContentLoaded', init);
  document.addEventListener('turbolinks:load',  init);
})();
