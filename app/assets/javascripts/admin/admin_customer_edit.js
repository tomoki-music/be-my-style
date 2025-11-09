// 管理者編集画面専用スクリプト
document.addEventListener("turbolinks:load", () => {
  const ownerSelect = document.querySelector("#customer_is_owner");
  const communityRow = document.querySelector("#community-row");

  if (!ownerSelect || !communityRow) return;

  const toggleCommunityRow = (value) => {
    if (value === "community_owner") {
      communityRow.style.display = "";
    } else {
      communityRow.style.display = "none";
    }
  };

  // 初期表示
  toggleCommunityRow(ownerSelect.value);

  // 選択変更時に切り替え
  ownerSelect.addEventListener("change", (e) => {
    toggleCommunityRow(e.target.value);
  });
});
