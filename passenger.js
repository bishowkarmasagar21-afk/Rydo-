const URL="https://kqtvuorasqyzjbnlkkxs.supabase.co";
const KEY="sb_publishable_zZFJiy0YWZgOXFesVuAQcA_wd7rleMb";

const form=document.getElementById("loginForm");
const email=document.getElementById("email");
const password=document.getElementById("password");

const create=document.querySelector('a[href="#"]');

create.onclick=async e=>{
  e.preventDefault();

  const name=prompt("Enter your full name:");
  if(!name)return;

  const phone=prompt("Enter your phone number:");
  if(!phone)return;

  const r=await fetch(URL+"/auth/v1/signup",{
    method:"POST",
    headers:{
      apikey:KEY,
      "Content-Type":"application/json"
    },
    body:JSON.stringify({
      email:email.value,
      password:password.value
    })
  });

  const data=await r.json();

  if(!r.ok){
    alert(data.msg||data.error_description||"Registration failed");
    return;
  }

  if(data.user){
    await fetch(URL+"/rest/v1/profiles",{
      method:"POST",
      headers:{
        apikey:KEY,
        Authorization:"Bearer "+KEY,
        "Content-Type":"application/json",
        Prefer:"return=minimal"
      },
      body:JSON.stringify({
        id:data.user.id,
        full_name:name,
        phone:phone,
        role:"passenger"
      })
    });
  }

  alert("Account created. Please verify your account, then login.");
};

form.onsubmit=async e=>{
  e.preventDefault();

  const r=await fetch(URL+"/auth/v1/token?grant_type=password",{
    method:"POST",
    headers:{
      apikey:KEY,
      "Content-Type":"application/json"
    },
    body:JSON.stringify({
      email:email.value,
      password:password.value
    })
  });

  const data=await r.json();

  if(!r.ok){
    alert(data.error_description||"Login failed");
    return;
  }

  const p=await fetch(
    URL+"/rest/v1/profiles?id=eq."+data.user.id+"&select=is_verified,role",
    {
      headers:{
        apikey:KEY,
        Authorization:"Bearer "+data.access_token
      }
    }
  );

  const profile=await p.json();

  if(!profile.length||profile[0].role!=="passenger"){
    alert("Passenger account not found.");
    return;
  }

  if(profile[0].is_verified!==true){
    alert("Your account is not verified yet.");
    return;
  }

  localStorage.setItem("rydo_token",data.access_token);
  localStorage.setItem("rydo_user",data.user.id);

  alert("Login successful.");
};
