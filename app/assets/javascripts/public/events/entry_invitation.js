// 演奏経験者へのエントリー依頼フォーム(#entry-invitation-form)。
// フォーム本体(見出し・送信ボタン)は楽曲表の外の <td> に置き、対象者のチェックボックス
// (.js-entry-invitation-checkbox)は楽曲表の各パート欄に置いて HTML5 の form= 属性で紐付ける。
// そのためチェックボックスはフォームの DOM 子孫ではなく、form.querySelectorAll では取得できない。
// form.elements(HTMLFormControlsCollection: form= で関連付けた外部要素も含む)を使う。
//
// URL の手組みはせず、ブラウザ標準の GET 送信に任せる。JS は以下の補助のみ:
//   - 未選択のまま送信しようとしたら止めて案内する
//   - 上限(MAX_TARGETS)を超えた選択を止める
//   - 二重送信(ダブルクリック)を防ぐ
// turbolinks 再描画に強いよう document へのイベント委譲で実装する(リスナーは1つだけ)。
// サーバー側(TargetResolver / BatchSender / Sender)が未選択・不正値・改ざん・上限を必ず再検証する。
(function () {
  var MAX_TARGETS = 100;

  function selectedCheckboxes(form) {
    return Array.prototype.filter.call(form.elements, function (element) {
      return element.classList &&
        element.classList.contains('js-entry-invitation-checkbox') &&
        element.checked;
    });
  }

  document.addEventListener('submit', function (event) {
    var form = event.target;
    if (!form || form.id !== 'entry-invitation-form') return;

    var selected = selectedCheckboxes(form);

    if (selected.length === 0) {
      event.preventDefault();
      window.alert('エントリーをお願いする人を、楽曲表のパート欄から1人以上選択してください。');
      return;
    }

    if (selected.length > MAX_TARGETS) {
      event.preventDefault();
      window.alert('一度に選択できるのは' + MAX_TARGETS + '人までです。数を減らして選び直してください。');
      return;
    }

    var button = form.querySelector('.js-entry-invitation-submit');
    if (button) {
      if (button.getAttribute('data-submitting') === '1') {
        event.preventDefault();
        return;
      }
      button.setAttribute('data-submitting', '1');
      button.setAttribute('aria-disabled', 'true');
      if ('value' in button) {
        button.value = '確認画面へ移動中...';
      } else {
        button.textContent = '確認画面へ移動中...';
      }
    }
  });
})();
