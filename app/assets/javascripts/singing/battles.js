// Singing::Battles — copy-to-clipboard handler
// Handles [data-copy-target] buttons on the battle share page.
// Uses Clipboard API (secure context) with execCommand fallback for older browsers.
//
// Wrapped in an IIFE to keep copyText / markCopied out of global scope and
// avoid name collisions with identically-named helpers in other modules.
(function () {
  document.addEventListener('turbolinks:load', function () {
    document.querySelectorAll('[data-copy-target]').forEach(function (button) {
      // Guard against duplicate binding on Turbolinks soft-navigate
      if (button.dataset.copyReady === 'true') return;
      button.dataset.copyReady = 'true';

      button.addEventListener('click', function () {
        var targetId = button.dataset.copyTarget;
        var input    = document.getElementById(targetId);
        if (!input) return;

        var text = input.value;

        copyText(text)
          .then(function ()  { markCopied(button, true);  })
          .catch(function () { markCopied(button, false); });
      });
    });
  });

  // ---------- helpers ----------

  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }

    // Fallback: create an off-screen textarea, select it, then execCommand
    return new Promise(function (resolve, reject) {
      var textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.setAttribute('readonly', '');
      textarea.style.cssText = 'position:fixed;top:0;left:0;opacity:0;pointer-events:none;';
      document.body.appendChild(textarea);
      textarea.select();

      try {
        document.execCommand('copy') ? resolve() : reject(new Error('execCommand failed'));
      } catch (err) {
        reject(err);
      } finally {
        document.body.removeChild(textarea);
      }
    });
  }

  function markCopied(button, success) {
    var originalText = button.textContent;
    button.textContent = success ? 'コピーしました ✓' : 'コピーできませんでした';
    button.classList.add('is-copied');
    if (!success) button.classList.add('is-copy-error');

    window.setTimeout(function () {
      button.textContent = originalText;
      button.classList.remove('is-copied', 'is-copy-error');
    }, 1800);
  }
})();
