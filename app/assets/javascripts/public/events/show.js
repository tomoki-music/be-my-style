function CheckJoin(){
  if(confirm('参加申請しますか？')){ 
      return true; 
  }else{
      alert('キャンセルされました'); 
      return false; 
  }
}