//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require rails-ujs
//= require activestorage
//= require turbolinks
//= require select2
//= require_tree .

function enable_select2() {
  $(document).ready(function() {
    $( ".js_select2" ).select2({
      width: 600,
      allowClear: true,
    });
  });
}