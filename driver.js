const onlineBtn=document.getElementById("onlineBtn");

onlineBtn.onclick=async()=>{
 if(!window.driverUser)return;

 const current=window.driverProfile?.is_online===true;
 const next=!current;

 const {error}=await db.from("profiles")
 .update({is_online:next})
 .eq("id",window.driverUser.id);

 if(error){
  alert(error.message);
  return;
 }

 window.driverProfile.is_online=next;
 onlineBtn.textContent=next?"GO OFFLINE":"GO ONLINE";

 if(next)startDriverLocation();
 else stopDriverLocation();
};

document.getElementById("logoutBtn").onclick=async()=>{
 stopDriverLocation();
 await db.auth.signOut();
 location.reload();
};

document.getElementById("deleteBtn").onclick=async()=>{
 const ok=confirm("Delete your Rydo driver account?");
 if(!ok)return;

 alert("Account deletion must be completed through the secure account system.");
};

document.getElementById("passwordBtn").onclick=async()=>{
 const email=window.driverUser?.email;
 if(!email)return;

 const {error}=await db.auth.resetPasswordForEmail(email,{
  redirectTo:location.origin+"/driver.html"
 });

 alert(error?error.message:"Password reset email sent.");
};
