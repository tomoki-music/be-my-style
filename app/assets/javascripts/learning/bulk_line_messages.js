document.addEventListener('turbolinks:load', function() {
  var form = document.querySelector('[data-bulk-line-form]');
  if (!form) return;

  var checkboxes = Array.prototype.slice.call(form.querySelectorAll('[data-bulk-line-checkbox]'));
  var summary = form.querySelector('[data-bulk-line-summary]');
  var message = form.querySelector('[data-bulk-line-message]');
  var remaining = form.querySelector('[data-bulk-line-remaining]');

  var isConnected = function(checkbox) {
    return checkbox.dataset.lineConnected === 'true';
  };

  var updateSummary = function() {
    var selected = checkboxes.filter(function(checkbox) { return checkbox.checked; });
    var connected = selected.filter(isConnected).length;
    var unconnected = selected.length - connected;

    if (summary) {
      summary.textContent = '選択中：' + selected.length + '名 / LINE連携済み：' + connected + '名 / 未連携：' + unconnected + '名。送信対象はLINE連携済みの' + connected + '名です。';
    }
  };

  var updateRemaining = function() {
    if (!message || !remaining) return;

    remaining.textContent = '残り' + (500 - message.value.length) + '文字';
  };

  form.querySelectorAll('[data-bulk-line-select]').forEach(function(button) {
    button.addEventListener('click', function() {
      var mode = button.dataset.bulkLineSelect;
      checkboxes.forEach(function(checkbox) {
        checkbox.checked = mode === 'all' || (mode === 'connected' && isConnected(checkbox));
      });
      updateSummary();
    });
  });

  checkboxes.forEach(function(checkbox) {
    checkbox.addEventListener('change', updateSummary);
  });

  if (message) {
    message.addEventListener('input', updateRemaining);
  }

  updateSummary();
  updateRemaining();
});
