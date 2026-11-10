document.addEventListener("turbolinks:load", () => {

  /* =========================
     ドメイン切替
  ========================= */

  const radios = document.querySelectorAll(".domain-radio");
  const music = document.querySelector(".music-fields");
  const business = document.querySelector(".business-fields");
  const learning = document.querySelector(".learning-fields");

  if (radios.length && music && business && learning) {

    const toggle = () => {
      const selectedEl = document.querySelector(".domain-radio:checked");
      const selected = selectedEl ? selectedEl.value : null;

      if (selected === "music") {
        music.style.display = "block";
        business.style.display = "none";
        learning.style.display = "none";
      } else if (selected === "business") {
        music.style.display = "none";
        business.style.display = "block";
        learning.style.display = "none";
      } else {
        music.style.display = "none";
        business.style.display = "none";
        learning.style.display = "block";
      }

      // active切替（UX強化🔥）
      document.querySelectorAll(".domain-card").forEach(card => {
        card.classList.remove("active");
      });

      const checked = document.querySelector(".domain-radio:checked");
      if (checked) {
        checked.closest(".domain-card").classList.add("active");
      }
    };

    radios.forEach(radio => {
      radio.addEventListener("change", toggle);
    });

    toggle(); // 初期表示
  }

});
