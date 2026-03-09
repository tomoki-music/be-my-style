document.addEventListener("turbolinks:load", function(){

  const input = document.getElementById("delete-confirm-input");
  const deleteBtn = document.getElementById("delete-event-btn");

  if(input && deleteBtn){

    deleteBtn.style.pointerEvents = "none";
    deleteBtn.style.opacity = "0.5";

    input.addEventListener("input", function(){

      if(this.value === "DELETE"){

        deleteBtn.style.pointerEvents = "auto";
        deleteBtn.style.opacity = "1";

      }else{

        deleteBtn.style.pointerEvents = "none";
        deleteBtn.style.opacity = "0.5";

      }

    });

  }

});