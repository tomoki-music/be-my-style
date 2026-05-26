(function () {
  "use strict";

  document.addEventListener("turbolinks:load", function () {
    var panel = document.querySelector(".srm-visibility-panel");
    if (!panel) return;

    var toggleBtn = panel.querySelector(".srm-btn--visibility-toggle");
    var feedback  = panel.querySelector(".srm-visibility-panel__feedback");
    var badge     = panel.querySelector(".srm-visibility-badge");
    var label     = panel.querySelector(".srm-visibility-panel__label");
    var shareArea = document.querySelector(".srm-share-area");
    var url       = panel.dataset.updateVisibilityUrl;
    var csrfMeta  = document.querySelector('meta[name="csrf-token"]');

    if (!toggleBtn || !url) return;

    toggleBtn.addEventListener("click", function () {
      var targetEnabled = toggleBtn.dataset.toggleTo === "true";

      toggleBtn.disabled = true;
      if (feedback) { feedback.textContent = ""; feedback.style.display = "none"; }

      fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfMeta ? csrfMeta.content : "",
          "Accept": "application/json"
        },
        body: JSON.stringify({ share_enabled: targetEnabled })
      })
        .then(function (res) { return res.json(); })
        .then(function (data) {
          var enabled = data.share_enabled;

          // badge
          if (badge) {
            badge.textContent = enabled ? "公開中" : "停止中";
            badge.className   = "srm-visibility-badge " + (enabled ? "srm-visibility-badge--on" : "srm-visibility-badge--off");
          }

          // label
          if (label) {
            label.textContent = enabled ? "共有リンクは有効です" : "この共有リンクは現在無効です";
          }

          // toggle button text / next action
          toggleBtn.textContent = enabled ? "共有を停止する" : "共有を再開する";
          toggleBtn.dataset.toggleTo = enabled ? "false" : "true";

          // share buttons visibility
          if (shareArea) {
            var btns     = shareArea.querySelector(".srm-share-area__btns");
            var disabled = shareArea.querySelector(".srm-share-area__disabled-note");

            if (enabled) {
              if (disabled) disabled.style.display = "none";
              if (btns) btns.style.display = "";
            } else {
              if (btns) btns.style.display = "none";
              if (disabled) disabled.style.display = "";
            }
          }

          if (feedback) {
            feedback.textContent = enabled ? "✓ 共有を再開しました" : "✓ 共有を停止しました";
            feedback.style.display = "inline";
            setTimeout(function () { feedback.style.display = "none"; }, 3000);
          }
        })
        .catch(function () {
          if (feedback) {
            feedback.textContent = "エラーが発生しました。再度お試しください。";
            feedback.style.display = "inline";
          }
        })
        .finally(function () {
          toggleBtn.disabled = false;
        });
    });
  });
})();
