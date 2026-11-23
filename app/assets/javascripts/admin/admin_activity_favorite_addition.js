// 管理画面の活動報告一覧「いいねを追加」。送信前に対象の記事と追加件数を確認する
// (件数はセレクトで変わるため、固定文言の data-confirm ではなくここで組み立てる)。
(function () {
  'use strict';

  document.addEventListener('submit', function (event) {
    var form = event.target.closest && event.target.closest('[data-admin-favorite-addition]');
    if (!form) return;

    var select = form.querySelector('select[name="count"]');
    var count = select ? select.value : '';
    var message = '活動報告 ID ' + form.dataset.activityId + '「' + form.dataset.activityTitle + '」に、いいねを' +
      count + '件追加します。よろしいですか？\n（会員 ID 2〜10 のうち未登録のアカウントから ID の小さい順に追加します。通知・メールは送りません）';

    if (!window.confirm(message)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }, true);
})();
