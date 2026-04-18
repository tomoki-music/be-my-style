$(document).on ("turbolinks:load", function(){
  const steps = document.querySelectorAll(".step");

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry, index) => {
      if (entry.isIntersecting) {
        setTimeout(() => {
          entry.target.classList.add("is-visible");
        }, index * 150); // ←順番に出る
      }
    });
  }, {
    threshold: 0.2
  });

  steps.forEach(step => observer.observe(step));
});
