document.addEventListener("turbolinks:load", function(){

  const zones = document.querySelectorAll(".danger-zone");

  zones.forEach(zone => {

    const input = zone.querySelector(".danger-confirm-input");
    const button = zone.querySelector(".danger-delete-btn");

    if(!input || !button) return;

    input.addEventListener("input", function(){

      if(input.value === "DELETE"){
        button.style.pointerEvents = "auto";
        button.style.opacity = "1";
      }else{
        button.style.pointerEvents = "none";
        button.style.opacity = "0.5";
      }

    });

  });

});