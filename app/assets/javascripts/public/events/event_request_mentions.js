// イベントリクエスト欄(#input_request)へ、既存チャットの@メンションAutocomplete
// (chat_mention_autocomplete.js の root.ChatMentions.initTextarea)をそのまま接続する。
// 候補APIのURL・ログイン中ユーザーIDは#event-requestのdata属性から読み取る
// (chat_rooms/show.html.hamlの.chat-rooms-show-containerと同じ配線方法)。
document.addEventListener("turbolinks:load", function () {
  var container = document.getElementById("event-request");
  if (!container || typeof window.ChatMentions === "undefined") return;

  var input = document.getElementById("input_request");
  if (!input) return;

  var candidatesUrl = container.dataset.mentionCandidatesUrl;
  if (!candidatesUrl) return;

  var currentCustomerId = container.dataset.currentCustomerId;

  window.ChatMentions.initTextarea(input, candidatesUrl, currentCustomerId);
});
