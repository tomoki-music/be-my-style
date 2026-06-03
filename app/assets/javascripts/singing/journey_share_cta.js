(function () {
  "use strict";

  document.addEventListener("turbolinks:load", function () {
    var copyBtns = document.querySelectorAll(".journey-share-cta__btn--copy");
    copyBtns.forEach(function (btn) {
      btn.addEventListener("click", function () {
        var url = btn.dataset.copyUrl;
        if (!url) return;

        navigator.clipboard.writeText(url).then(function () {
          var feedback = btn.closest(".journey-share-cta").querySelector(".journey-share-cta__copy-feedback");
          if (feedback) {
            feedback.style.display = "block";
            setTimeout(function () { feedback.style.display = "none"; }, 3000);
          }
        }).catch(function () {
          var textArea = document.createElement("textarea");
          textArea.value = url;
          textArea.style.position = "fixed";
          textArea.style.left = "-9999px";
          document.body.appendChild(textArea);
          textArea.focus();
          textArea.select();
          try { document.execCommand("copy"); } catch (_) {}
          document.body.removeChild(textArea);

          var feedback = btn.closest(".journey-share-cta").querySelector(".journey-share-cta__copy-feedback");
          if (feedback) {
            feedback.style.display = "block";
            setTimeout(function () { feedback.style.display = "none"; }, 3000);
          }
        });
      });
    });
  });
})();
