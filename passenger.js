const URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const msg=document.getElementById("message");

document.getElementById("registerForm").onsubmit=async e=>{
 e.preventDefault();

 const name=document.getElementById("name").value.trim();
 const phone=document.getElementById("phone").value.trim();
 const email=document.getElementById("registerEmail").value.trim();
 const password=document.getElementById("registerPassword").value;
 const confirm=document.getElementById("confirmPassword").value;

 if(password!==confirm){
  msg.textContent="Passwords do not match.";
  return;
 }

 msg.textContent="Creating account...";

 try{
  const r=await fetch(URL+"/auth/v1/signup",{
   method:"POST",
   headers:{
    apikey:KEY,
    "Content-Type":"application/json"
   },
   body:JSON.stringify({
    email:email,
    password:password,
    data:{
     full_name:name,
     phone:phone,
     role:"passenger"
    }
   })
  });

  const data=await r.json();

  if(!r.ok){
   msg.textContent=
   data.msg||data.error_description||
   "Registration failed.";
   return;
  }

  msg.textContent=
  "Account created. Check your email.";

  document.getElementById("registerForm").reset();

 }catch(error){
  msg.textContent="Connection error.";
 }
};


document.getElementById("loginForm").onsubmit=async e=>{
 e.preventDefault();

 const email=document.getElementById("loginEmail").value.trim();
 const password=document.getElementById("loginPassword").value;

 msg.textContent="Logging in...";

 try{
  const r=await fetch(
   URL+"/auth/v1/token?grant_type=password",
   {
    method:"POST",
    headers:{
     apikey:KEY,
     "Content-Type":"application/json"
    },
    body:JSON.stringify({
     email:email,
     password:password
    })
   }
  );

  const data=await r.json();

  if(!r.ok){
   msg.textContent=
   data.error_description||
   "Login failed.";
   return;
  }

  localStorage.setItem(
   "rydo_token",
   data.access_token
  );

  localStorage.setItem(
   "rydo_user",
   data.user.id
  );

  window.location.href="passenger-ride.html";

 }catch(error){
  msg.textContent=
  "Connection error. Please try again.";
 }
};
