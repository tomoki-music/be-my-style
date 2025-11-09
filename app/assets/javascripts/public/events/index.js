document.addEventListener("turbolinks:load", () => {
  const openBtn = document.querySelector("#open-create-event-modal");
  if (openBtn) {
    openBtn.addEventListener("click", (e) => {
      e.preventDefault();
      $("#createEventModal").modal("show");
    });
  }
});
