document.addEventListener('turbolinks:load', function() {
  var form = document.querySelector('[data-assignment-form]');
  if (!form) return;

  var checkboxes = Array.prototype.slice.call(form.querySelectorAll('[data-assignment-checkbox]'));
  var summary = form.querySelector('[data-assignment-summary]');
  var description = form.querySelector('[data-assignment-description]');
  var remaining = form.querySelector('[data-assignment-remaining]');

  var isConnected = function(checkbox) {
    return checkbox.dataset.lineConnected === 'true';
  };

  var updateSummary = function() {
    var selected = checkboxes.filter(function(checkbox) { return checkbox.checked; });
    var connected = selected.filter(isConnected).length;
    var unconnected = selected.length - connected;

    if (summary) {
      summary.textContent = '選択中：' + selected.length + '名 / LINE連携済み：' + connected + '名 / 未連携：' + unconnected + '名。未連携の生徒にも課題は配布され、LINE通知だけスキップされます。';
    }
  };

  var updateRemaining = function() {
    if (!description || !remaining) return;

    remaining.textContent = '残り' + (1000 - description.value.length) + '文字';
  };

  form.querySelectorAll('[data-assignment-select]').forEach(function(button) {
    button.addEventListener('click', function() {
      var mode = button.dataset.assignmentSelect;
      checkboxes.forEach(function(checkbox) {
        checkbox.checked = mode === 'all' || (mode === 'connected' && isConnected(checkbox));
      });
      updateSummary();
    });
  });

  checkboxes.forEach(function(checkbox) {
    checkbox.addEventListener('change', updateSummary);
  });

  if (description) {
    description.addEventListener('input', updateRemaining);
  }

  updateSummary();
  updateRemaining();
});
