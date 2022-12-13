//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require rails-ujs
//= require activestorage
//= require turbolinks
//= require_tree .

$(document).on ("turbolinks:load", function(){
    $('.slider').slick({
      autoplay: true, //自動再生
      infinite: true, //スライドのループ有効化
      dots: true, //ドットのナビゲーションを表示
      autoplaySpeed: 4000, //再生スピード
      slidesToShow: 1, //表示するスライドの数
      slidesToScroll: 1, //スクロールで切り替わるスライドの数
      prevArrow: '<i class="fas fa-arrow-alt-circle-left"></i>',
      nextArrow: '<i class="fas fa-arrow-alt-circle-right"></i>',
      responsive: [{
        breakpoint: 768, //ブレークポイントが768px
        settings: {
          slidesToShow: 1, //表示するスライドの数
          slidesToScroll: 1, //スクロールで切り替わるスライドの数
        }
      }, {
        breakpoint: 480, //ブレークポイントが480px
        settings: {
          slidesToShow: 1, //表示するスライドの数
          slidesToScroll: 1, //スクロールで切り替わるスライドの数
        }
      }]
    });
  });