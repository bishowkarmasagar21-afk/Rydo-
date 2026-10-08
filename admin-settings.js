document.getElementById("refreshBtn").onclick=()=>{
if(window.loadAdminDashboard)
loadAdminDashboard();

if(window.loadDrivers)
loadDrivers();

alert("Dashboard refreshed.");
};

document.getElementById("passwordBtn").onclick=async()=>{

const email=window.adminUser?.email;

if(!email){
alert("Admin session not found.");
return;
}

const {error}=await db.auth.resetPasswordForEmail(email,{
redirectTo:location.origin+"/admin.html"
});

alert(
error
?error.message
:"Password reset email sent."
);
};
