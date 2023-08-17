$(document).on ("turbolinks:load", function(){
  $('.title-see-more').click(function(){
    $(this).closest("#title-js").find(".title-truncated").hide();
    $(this).closest("#title-js").find(".title-untruncated").show();
  });

  $('.keep-see-more').click(function(){
    $(this).closest("#kpt").find(".keep-truncated").hide();
    $(this).closest("#kpt").find(".keep-untruncated").show();
  });

  $('.problem-see-more').click(function(){
    $(this).closest("#kpt").find(".problem-truncated").hide();
    $(this).closest("#kpt").find(".problem-untruncated").show();
  });

  $('.try-see-more').click(function(){
    $(this).closest("#kpt").find(".try-truncated").hide();
    $(this).closest("#kpt").find(".try-untruncated").show();
  });
});
