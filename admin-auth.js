const SUPABASE_URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const SUPABASE_KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const client=window.supabase.createClient(
  SUPABASE_URL,
  SUPABASE_KEY
);

window.supabaseClient=client;

const form=document.getElementById("adminLoginForm");
const btn=document.getElementById("adminLoginBtn");
const msg=document.getElementById("adminMessage");

async function adminLogin(e){
  e.preventDefault();

  const email=document.getElementById("adminEmail").value.trim();
  const password=document.getElementById("adminPassword").value;

  msg.textContent="Checking admin account...";
  btn.disabled=true;

  const {data,error}=await client.auth.signInWithPassword({
    email,
    password
  });

  if(error){
    msg.textContent=error.message;
    btn.disabled=false;
    return;
  }

  const {data:profile,error:pe}=await client
    .from("profiles")
    .select("full_name,role")
    .eq("id",data.user.id)
    .single();

  if(pe||!profile){
    msg.textContent="Could not load admin profile.";
    await client.auth.signOut();
    btn.disabled=false;
    return;
  }

  if(profile.role!=="admin"){
    msg.textContent="This account is not an admin.";
    await client.auth.signOut();
    btn.disabled=false;
    return;
  }

  /* ADMIN VERIFIED */
  document.getElementById("adminLogin").style.display="none";
  document.getElementById("adminApp").style.display="block";

  msg.textContent="";
  btn.disabled=false;

  document.querySelectorAll(".panel").forEach(p=>{
    p.style.display="none";
  });

  const first=document.getElementById("drivers");
  if(first) first.style.display="block";

  if(typeof loadDashboard==="function") loadDashboard();
}

form.addEventListener("submit",adminLogin);
