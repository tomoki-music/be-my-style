// 演奏経験者へのエントリー依頼パネル。
// パネル全体が 1 つの GET フォーム(.entry-invitation-panel__form)で、曲・パートを
// またいで選択したチェックボックス(targets[])をブラウザ標準の GET 送信で確認画面へ渡す。
// URL の手組みはしない。JS は以下の補助のみ:
//   - 未選択のまま送信しようとしたら止めて案内する
//   - 二重送信(ダブルクリック)を防ぐ
// turbolinks の再描画に強いよう document へのイベント委譲で実装する。
// サーバー側(TargetResolver / BatchSender / Sender)が未選択・不正値・改ざんを必ず再検証する。
document.addEventListener('submit', function (event) {
  var form = event.target;
  if (!form || !form.classList || !form.classList.contains('entry-invitation-panel__form')) return;

  var button = form.querySelector('.js-entry-invitation-submit');
  var checked = form.querySelectorAll('.js-entry-invitation-checkbox:checked');

  if (checked.length === 0) {
    event.preventDefault();
    window.alert('エントリーをお願いする人を1人以上選択してください。');
    return;
  }

  if (button) {
    if (button.getAttribute('data-submitting') === '1') {
      event.preventDefault();
      return;
    }
    button.setAttribute('data-submitting', '1');
    button.setAttribute('aria-disabled', 'true');
    button.textContent = '確認画面へ移動中...';
  }
});
