document.addEventListener("turbolinks:load", () => {

  /* =========================
     ドメイン切替
  ========================= */

  const radios = document.querySelectorAll(".domain-radio");
  const music = document.querySelector(".music-fields");
  const business = document.querySelector(".business-fields");

  if (radios.length && music && business) {

    const toggle = () => {
      const selectedEl = document.querySelector(".domain-radio:checked");
      const selected = selectedEl ? selectedEl.value : null;

      if (selected === "music") {
        music.style.display = "block";
        business.style.display = "none";
      } else {
        music.style.display = "none";
        business.style.display = "block";
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

  /* =========================
     画像プレビュー
  ========================= */

  const input = document.getElementById("image-input");
  const preview = document.getElementById("preview-image");

  if (input && preview) {
    input.addEventListener("change", e => {
      const file = e.target.files[0];
      if (!file) return;

      const reader = new FileReader();

      reader.onload = () => {
        preview.src = reader.result;
      };

      reader.readAsDataURL(file);
    });
  }

});