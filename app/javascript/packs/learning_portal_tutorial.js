document.addEventListener("DOMContentLoaded", () => {
  const tutorial = document.getElementById("portal-tutorial");
  if (!tutorial) return;

  const completeUrl = tutorial.dataset.completeUrl;
  let currentStep = 1;

  const showStep = (step) => {
    tutorial.querySelectorAll("[data-step]").forEach((el) => {
      el.style.display = el.dataset.step === String(step) ? "" : "none";
    });
  };

  tutorial.querySelector("[data-action='next']")?.addEventListener("click", () => {
    currentStep++;
    showStep(currentStep);
  });

  tutorial.querySelector("[data-action='complete']")?.addEventListener("click", () => {
    fetch(completeUrl, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
    }).finally(() => {
      tutorial.remove();
    });
  });
});
