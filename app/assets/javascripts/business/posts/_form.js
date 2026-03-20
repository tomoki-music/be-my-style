document.addEventListener("turbolinks:load", () => {
  // =========================
  // タグ入力
  // =========================
  const input = document.getElementById("tag-input");
  const container = document.getElementById("tag-container");
  const hidden = document.getElementById("tag-hidden");
  const form = document.querySelector(".post-form");

  if (!input || !container || !hidden || !form) return;

  let tags = [];

  function renderTags() {
    container.innerHTML = "";

    tags.forEach((tag, index) => {
      const chip = document.createElement("div");
      chip.className = "tag-chip";

      chip.innerHTML = `
        ${tag}
        <span class="remove" data-index="${index}">×</span>
      `;

      container.appendChild(chip);
    });

    hidden.value = tags.join(" ");
  }

  // 初期タグ
  const existing = hidden.dataset.tags;
  if (existing) {
    tags = existing.split(/[\s,　]+/).filter(t => t.length > 0);
    renderTags();
  }

  // =========================
  // Enterでタグ追加
  // =========================
  input.addEventListener("keydown", (e) => {
    // IME変換中は無視（日本語入力対策）
    if (e.isComposing) return;

    if (e.key === "Enter") {
      e.preventDefault();
      e.stopPropagation();

      const value = input.value
        .replace(/　/g, " ")
        .trim();

      if (value && !tags.includes(value)) {
        tags.push(value);
        renderTags();
      }

      input.value = "";
    }
  });

  // =========================
  // フォーム送信ガード
  // =========================
  form.addEventListener("submit", (e) => {
    // タグ入力中にEnter押された場合の誤送信を防ぐ
    if (document.activeElement === input && input.value.trim() !== "") {
      e.preventDefault();

      const value = input.value
        .replace(/　/g, " ")
        .trim();

      if (value && !tags.includes(value)) {
        tags.push(value);
        renderTags();
      }

      input.value = "";
    }
  });

  // =========================
  // タグ削除
  // =========================
  container.addEventListener("click", (e) => {
    if (e.target.classList.contains("remove")) {
      const index = e.target.dataset.index;
      tags.splice(index, 1);
      renderTags();
    }
  });

});