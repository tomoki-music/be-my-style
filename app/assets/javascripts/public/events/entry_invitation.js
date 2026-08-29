// 演奏経験者へのエントリー依頼フォーム(#entry-invitation-form)。
// フォーム本体(見出し・送信ボタン)は楽曲表の外の <td> に置き、対象者のチェックボックス
// (.js-entry-invitation-checkbox)は楽曲表の各パート欄に置いて HTML5 の form= 属性で紐付ける。
// そのためチェックボックスはフォームの DOM 子孫ではなく、form.querySelectorAll では取得できない。
// form.elements(HTMLFormControlsCollection: form= で関連付けた外部要素も含む)を使う。
//
// このフォームのボタン(.js-entry-invitation-submit)は参加フォーム(#join_btn / #submit_join_form)
// とは完全に分離する。参加パート用 checkbox(event[join_part_ids][])には一切反応しない。
//
// JS は以下の補助のみ:
//   - 有効な .js-entry-invitation-checkbox の checked 件数でボタンの disabled を同期する
//     (disabled 候補はこのクラスを持たないため件数に含まれない)
//   - 未選択のまま送信しようとしたら止めて案内する
//   - 上限(MAX_TARGETS)を超えた選択を止める
//   - 二重送信(ダブルクリック)を防ぐ
// turbolinks 再描画・ブラウザバック(pageshow)でも状態がずれないよう document への
// イベント委譲で実装する(リスナーは1つだけ)。
// サーバー側(TargetParser / TargetResolver / BatchSender / Sender)が未選択・不正値・改ざん・上限を必ず再検証する。
(function () {
  var MAX_TARGETS = 100;
  var FORM_ID = 'entry-invitation-form';

  function form() {
    return document.getElementById(FORM_ID);
  }

  function submitButton(f) {
    return f ? f.querySelector('.js-entry-invitation-submit') : null;
  }

  // form.elements は form= 属性で外部関連付けした checkbox も含む。
  // disabled 候補は js-entry-invitation-checkbox クラスを持たないため自動的に除外される。
  function selectedCheckboxes(f) {
    return Array.prototype.filter.call(f.elements, function (element) {
      return element.classList &&
        element.classList.contains('js-entry-invitation-checkbox') &&
        element.checked;
    });
  }

  // 有効な依頼候補が1件以上 checked のときだけボタンを有効化する。
  // 送信処理中(data-submitting)は無効のまま維持する。
  function syncSubmitState() {
    var f = form();
    if (!f) return;
    var button = submitButton(f);
    if (!button) return;

    if (button.getAttribute('data-submitting') === '1') {
      button.disabled = true;
      return;
    }
    button.disabled = selectedCheckboxes(f).length === 0;
  }

  // 送信処理中フラグ・表示を戻す(turbolinks 遷移やブラウザバック後の再表示用)。
  function resetSubmitting() {
    var f = form();
    if (!f) return;
    var button = submitButton(f);
    if (!button) return;

    button.removeAttribute('data-submitting');
    button.removeAttribute('aria-disabled');
    if (button.dataset.originalLabel) {
      if ('value' in button) {
        button.value = button.dataset.originalLabel;
      } else {
        button.textContent = button.dataset.originalLabel;
      }
    }
  }

  // 依頼用 checkbox の change だけに反応する(参加用 event[join_part_ids][] は無視)。
  document.addEventListener('change', function (event) {
    var el = event.target;
    if (!el || !el.classList || !el.classList.contains('js-entry-invitation-checkbox')) return;
    syncSubmitState();
  });

  document.addEventListener('turbolinks:load', function () {
    resetSubmitting();
    syncSubmitState();
  });

  window.addEventListener('pageshow', function () {
    resetSubmitting();
    syncSubmitState();
  });

  document.addEventListener('submit', function (event) {
    var f = event.target;
    if (!f || f.id !== FORM_ID) return;

    var selected = selectedCheckboxes(f);

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

    var button = submitButton(f);
    if (button) {
      if (button.getAttribute('data-submitting') === '1') {
        event.preventDefault();
        return;
      }
      if (!button.dataset.originalLabel) {
        button.dataset.originalLabel = ('value' in button) ? button.value : button.textContent;
      }
      button.setAttribute('data-submitting', '1');
      button.setAttribute('aria-disabled', 'true');
      button.disabled = true;
      if ('value' in button) {
        button.value = '確認画面へ移動中...';
      } else {
        button.textContent = '確認画面へ移動中...';
      }
    }
  });
})();
