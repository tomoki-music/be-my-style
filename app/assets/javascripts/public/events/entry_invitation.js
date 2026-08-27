// 演奏経験者へのエントリー依頼パネル。
// 各「曲×募集中パート」ブロック(.entry-invitation)ごとに、チェックした経験者だけを集めて
// 確認画面へ遷移する。別の曲・別パートの選択状態は同じ .entry-invitation 内に閉じているため混在しない。
//
// turbolinks の再描画に強いよう document へのイベント委譲で実装する。
document.addEventListener('click', function (event) {
  var button = event.target.closest ? event.target.closest('.js-entry-invitation-submit') : null;
  if (!button) return;

  var block = button.closest('.entry-invitation');
  if (!block) return;

  var basePath = block.getAttribute('data-base-path');
  var checked = block.querySelectorAll('.js-entry-invitation-checkbox:checked');

  if (!basePath || checked.length === 0) {
    window.alert('エントリーをお願いする人を選択してください。');
    return;
  }

  var params = Array.prototype.map.call(checked, function (input) {
    return 'customer_ids[]=' + encodeURIComponent(input.value);
  });

  var separator = basePath.indexOf('?') === -1 ? '?' : '&';
  window.location.href = basePath + separator + params.join('&');
});
