(function () {
  "use strict";

  function getOrFetchShareUrl(btn, callback) {
    var existing = btn.dataset.existingShareUrl;
    if (existing && existing.length > 0) {
      callback(existing);
      return;
    }

    var url = btn.dataset.generateShareLinkUrl;
    var csrfToken = document.querySelector('meta[name="csrf-token"]');

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken ? csrfToken.content : "",
        "Accept": "application/json"
      }
    })
      .then(function (res) { return res.json(); })
      .then(function (data) {
        if (data.share_url) {
          btn.dataset.existingShareUrl = data.share_url;
          callback(data.share_url);
        }
      })
      .catch(function () {});
  }

  document.addEventListener("turbolinks:load", function () {
    var copyBtns = document.querySelectorAll(".srm-btn--share-link");
    copyBtns.forEach(function (btn) {
      btn.addEventListener("click", function () {
        getOrFetchShareUrl(btn, function (shareUrl) {
          navigator.clipboard.writeText(shareUrl).then(function () {
            var feedback = btn.closest(".srm-share-area").querySelector(".srm-share-area__copy-feedback");
            if (feedback) {
              feedback.style.display = "block";
              setTimeout(function () { feedback.style.display = "none"; }, 3000);
            }
            // also update LINE button if present
            var lineBtn = btn.closest(".srm-share-area__btns").querySelector(".srm-btn--line");
            if (lineBtn) lineBtn.dataset.existingShareUrl = shareUrl;
          });
        });
      });
    });

    var lineBtns = document.querySelectorAll(".srm-btn--line");
    lineBtns.forEach(function (btn) {
      btn.addEventListener("click", function (e) {
        e.preventDefault();
        var year = btn.dataset.shareYear;
        var base = btn.dataset.lineShareBase;
        getOrFetchShareUrl(btn, function (shareUrl) {
          var text = encodeURIComponent("🎤 My Singing Recap " + year + "\n今年の歌の成長をまとめました✨\n" + shareUrl);
          window.open(base + text, "_blank", "noopener,noreferrer");
        });
      });
    });
  });
})();
