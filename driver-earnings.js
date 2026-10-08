async function loadDriverEarnings(){
 if(!window.driverUser)return;

 const {data,error}=await db.from("rides")
 .select("fare,driver_earnings,admin_earnings,status")
 .eq("driver_id",window.driverUser.id);

 if(error)return;

 let total=0,net=0,commission=0,completed=0,cancelled=0;

 (data||[]).forEach(r=>{
  if(r.status==="completed"){
   total+=Number(r.fare||0);
   net+=Number(r.driver_earnings||0);
   commission+=Number(r.admin_earnings||0);
   completed++;
  }

  if(r.status==="cancelled")cancelled++;
 });

 document.getElementById("totalEarnings").textContent="Rs. "+total;
 document.getElementById("netEarnings").textContent="Rs. "+net;
 document.getElementById("commission").textContent="Rs. "+commission;
 document.getElementById("completed").textContent=completed;
 document.getElementById("cancelled").textContent=cancelled;
}

window.loadDriverEarnings=loadDriverEarnings;
