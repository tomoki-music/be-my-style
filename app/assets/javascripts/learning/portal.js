document.addEventListener("turbolinks:load", function() {
  var tutorial = document.getElementById("portal-tutorial");

  if (tutorial) {
    var completeUrl = tutorial.dataset.completeUrl;
    var currentStep = 1;

    var showStep = function(step) {
      tutorial.querySelectorAll("[data-step]").forEach(function(el) {
        el.style.display = el.dataset.step === String(step) ? "" : "none";
      });
    };

    var nextButton = tutorial.querySelector("[data-action='next']");
    if (nextButton) {
      nextButton.addEventListener("click", function() {
        currentStep += 1;
        showStep(currentStep);
      });
    }

    var completeButton = tutorial.querySelector("[data-action='complete']");
    if (completeButton) {
      completeButton.addEventListener("click", function() {
        var csrfMeta = document.querySelector('meta[name="csrf-token"]');
        var closeTutorial = function() {
          tutorial.remove();
        };

        fetch(completeUrl, {
          method: "POST",
          headers: {
            "X-CSRF-Token": csrfMeta ? csrfMeta.content : ""
          }
        }).then(closeTutorial).catch(closeTutorial);
      });
    }
  }

  document.querySelectorAll("[data-copy-url]").forEach(function(button) {
    button.addEventListener("click", function() {
      var url = button.dataset.copyUrl;
      if (!url) return;

      var showCopied = function() {
        var originalText = button.textContent;
        button.textContent = "コピーしました";
        window.setTimeout(function() {
          button.textContent = originalText;
        }, 1600);
      };

      var showPrompt = function() {
        window.prompt("生徒向けページURL", url);
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(url).then(showCopied).catch(showPrompt);
      } else {
        showPrompt();
      }
    });
  });
});
