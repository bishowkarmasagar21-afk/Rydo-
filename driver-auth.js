const SUPABASE_URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";
const db=window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY);

const $=id=>document.getElementById(id);

$("loginTab").onclick=()=>{
 $("loginBox").classList.remove("hide");
 $("registerBox").classList.add("hide");
};

$("registerTab").onclick=()=>{
 $("loginBox").classList.add("hide");
 $("registerBox").classList.remove("hide");
};

$("registerBtn").onclick=async()=>{
 const name=$("name").value.trim();
 const phone=$("phone").value.trim();
 const email=$("email").value.trim();
 const password=$("password").value;
 const license=$("license").value.trim();

 if(!name||!phone||!email||!password||!license){
  $("registerMsg").textContent="Complete all required fields.";
  return;
 }

 const {data,error}=await db.auth.signUp({email,password});

 if(error){
  $("registerMsg").textContent=error.message;
  return;
 }

 const uid=data.user.id;

 const {error:pe}=await db.from("profiles").upsert({
  id:uid,
  full_name:name,
  phone:phone,
  role:"driver",
  driver_license:license,
  is_verified:false,
  is_online:false
 });

 if(pe){
  $("registerMsg").textContent=pe.message;
  return;
 }

 $("registerMsg").textContent=
 "Account created. Documents will be reviewed by Rydo Admin.";
};

$("loginBtn").onclick=async()=>{
 const email=$("loginEmail").value.trim();
 const password=$("loginPassword").value;

 const {data,error}=await db.auth.signInWithPassword({email,password});

 if(error){
  $("loginMsg").textContent=error.message;
  return;
 }

 const {data:p}=await db.from("profiles")
 .select("*").eq("id",data.user.id).maybeSingle();

 if(!p||p.role!=="driver"){
  $("loginMsg").textContent="This is not a driver account.";
  await db.auth.signOut();
  return;
 }

 if(p.is_verified!==true){
  $("loginMsg").textContent="Your driver account is waiting for verification.";
  await db.auth.signOut();
  return;
 }

 window.driverUser=data.user;
 window.driverProfile=p;

 $("auth").classList.add("hide");
 $("dashboard").classList.remove("hide");
 $("logoutBtn").classList.remove("hide");
 $("driverName").textContent=p.full_name||"RYDO Driver";

 if(window.loadDriverEarnings)loadDriverEarnings();
 if(window.loadRideRequests)loadRideRequests();
};
