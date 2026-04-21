document.addEventListener("turbolinks:load", () => {
  const sortableBody = document.querySelector("[data-learning-sortable='true']");
  const trainingMasterSelect = document.querySelector("[data-learning-training-master-select]");
  const previewRoot = document.querySelector("[data-learning-training-master-preview]");

  if (trainingMasterSelect && previewRoot) {
    const emptyState = previewRoot.querySelector("[data-learning-training-master-empty]");
    const contentState = previewRoot.querySelector("[data-learning-training-master-content]");
    const metaNode = previewRoot.querySelector("[data-learning-training-master-meta]");
    const titleNode = previewRoot.querySelector("[data-learning-training-master-title]");
    const descriptionNode = previewRoot.querySelector("[data-learning-training-master-description]");
    const criteriaNode = previewRoot.querySelector("[data-learning-training-master-criteria]");
    const frequencyNode = previewRoot.querySelector("[data-learning-training-master-frequency]");
    const trainingMasters = JSON.parse(previewRoot.dataset.trainingMasters || "{}");

    const renderTrainingMasterPreview = () => {
      const selectedMaster = trainingMasters[trainingMasterSelect.value];

      if (!selectedMaster) {
        emptyState.hidden = false;
        contentState.hidden = true;
        return;
      }

      const { part, period, level, title, description, achievement_criteria, frequency } = selectedMaster;

      metaNode.textContent = [part, period, level].filter(Boolean).join(" / ");
      titleNode.textContent = title || "";
      descriptionNode.textContent = description || "未設定";
      criteriaNode.textContent = achievement_criteria || "未設定";
      frequencyNode.textContent = frequency ? `頻度: ${frequency}` : "頻度: 未設定";

      emptyState.hidden = true;
      contentState.hidden = false;
    };

    trainingMasterSelect.addEventListener("change", renderTrainingMasterPreview);
    renderTrainingMasterPreview();
  }

  if (!sortableBody || typeof Sortable === "undefined") {
    return;
  }

  const reorderUrl = sortableBody.dataset.reorderUrl;
  const token = document.querySelector("meta[name='csrf-token']")?.content;

  Sortable.create(sortableBody, {
    handle: ".learning-drag-handle",
    animation: 150,
    onEnd: () => {
      const orderedIds = Array.from(sortableBody.querySelectorAll("[data-training-id]")).map((row) => row.dataset.trainingId);

      fetch(reorderUrl, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "application/json"
        },
        body: JSON.stringify({ ordered_ids: orderedIds })
      });
    }
  });
});
