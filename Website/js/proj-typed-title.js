const nameText = "Current Projects...";
const nameSpan = document.getElementById("typed-title");
let i = 0;

function typeProjTitle() {
    if (i < nameText.length) {
        nameSpan.textContent += nameText.charAt(i);
        i++;
        setTimeout(typeProjTitle, 100);
    }
}
window.onload = typeProjTitle;