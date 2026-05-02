(function() {
  function showReactionToast(message) {
    var existing = document.getElementById('activity-reaction-toast');
    if (existing) {
      existing.remove();
    }

    var toast = document.createElement('div');
    toast.id = 'activity-reaction-toast';
    toast.className = 'activity-reaction-toast';
    toast.textContent = message;
    document.body.appendChild(toast);

    setTimeout(function() {
      toast.classList.add('activity-reaction-toast--out');
      setTimeout(function() {
        if (toast.parentNode) toast.remove();
      }, 320);
    }, 1600);
  }

  function popReactionBtn(btn) {
    btn.classList.remove('activity-reaction-btn--popping');
    // Force reflow to restart animation if same button clicked quickly
    void btn.offsetWidth;
    btn.classList.add('activity-reaction-btn--popping');

    btn.addEventListener('animationend', function cleanup() {
      btn.classList.remove('activity-reaction-btn--popping');
      btn.removeEventListener('animationend', cleanup);
    }, { once: true });
  }

  function animateCount(countEl) {
    countEl.classList.remove('reaction-count--pop');
    void countEl.offsetWidth;
    countEl.classList.add('reaction-count--pop');
    countEl.addEventListener('animationend', function() {
      countEl.classList.remove('reaction-count--pop');
    }, { once: true });
  }

  function initReactionButtons() {
    var csrfTokenEl = document.querySelector('meta[name="csrf-token"]');
    if (!csrfTokenEl) return;

    var csrfToken = csrfTokenEl.getAttribute('content');

    document.querySelectorAll('[data-reaction-url]').forEach(function(btn) {
      if (btn.dataset.reactionBound) return;
      btn.dataset.reactionBound = '1';

      btn.addEventListener('click', function(e) {
        e.preventDefault();
        var url = btn.dataset.reactionUrl;

        popReactionBtn(btn);
        btn.disabled = true;

        fetch(url, {
          method: 'POST',
          headers: {
            'X-CSRF-Token': csrfToken,
            'Accept': 'application/json',
            'Content-Type': 'application/json'
          }
        })
          .then(function(res) {
            if (!res.ok) throw new Error('reaction failed: ' + res.status);
            return res.json();
          })
          .then(function(data) {
            var countEl = btn.querySelector('.reaction-count');

            if (data.reacted) {
              btn.classList.add('activity-reaction-btn--active');
              showReactionToast('応援しました！');
            } else {
              btn.classList.remove('activity-reaction-btn--active');
              showReactionToast('応援を取り消しました');
            }

            if (countEl) {
              var newText = data.count > 0 ? String(data.count) : '';
              if (countEl.textContent !== newText) {
                countEl.textContent = newText;
                if (newText) animateCount(countEl);
              }
            } else if (data.count > 0) {
              var newCount = document.createElement('span');
              newCount.className = 'reaction-count';
              newCount.textContent = String(data.count);
              btn.appendChild(newCount);
              animateCount(newCount);
            }
          })
          .catch(function() {
            // ネットワーク・サーバーエラー時は表示を維持
          })
          .finally(function() {
            btn.disabled = false;
          });
      });
    });
  }

  document.addEventListener('turbolinks:load', initReactionButtons);
})();
