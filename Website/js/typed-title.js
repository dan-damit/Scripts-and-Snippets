const nameText = "Welcome to the System...";
const nameSpan = document.getElementById("name-title");
let i = 0;

function typeTitle() {
    if (i < nameText.length) {
        nameSpan.textContent += nameText.charAt(i);
        i++;
        setTimeout(typeTitle, 100);
    }
}
window.onload = typeTitle;