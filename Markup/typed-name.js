const nameText = "Dan Damit";
const nameSpan = document.getElementById("name-text");
let i = 0;

function typeName() {
    if (i < nameText.length) {
        nameSpan.textContent += nameText.charAt(i);
        i++;
        setTimeout(typeName, 100);
    }
}
window.onload = typeName;