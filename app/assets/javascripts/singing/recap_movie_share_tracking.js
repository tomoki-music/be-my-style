document.addEventListener("turbolinks:load", function () {
  var shareArea = document.querySelector(".srm-share-area[data-track-share-url]");
  if (!shareArea) return;

  var trackUrl = shareArea.dataset.trackShareUrl;

  function getCsrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  function trackShare(kind) {
    fetch(trackUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": getCsrfToken(),
        "X-Requested-With": "XMLHttpRequest"
      },
      body: JSON.stringify({ kind: kind })
    }).catch(function () {
      // tracking失敗はサイレントに無視する（UXを止めない）
    });
  }

  shareArea.querySelectorAll("[data-track-share-kind]").forEach(function (el) {
    el.addEventListener("click", function () {
      trackShare(el.dataset.trackShareKind);
    });
  });
});
