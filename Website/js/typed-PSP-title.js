const nameText = "Get-DanPowerShellProfile";
const nameSpan = document.getElementById("name-PSP-title");
let i = 0;

function typeNameProfile() {
  if (i < nameText.length) {
    nameSpan.textContent += nameText.charAt(i);
    i++;
    setTimeout(typeNameProfile, 100);
  }
}
window.onload = typeNameProfile;
