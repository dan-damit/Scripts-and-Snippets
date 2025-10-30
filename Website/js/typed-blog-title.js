const blogTitle = "Technician's Log";
const target = document.getElementById("typed-text");
let i = 0;

function typeBlogTitle() {
    if (i < blogTitle.length) {
        target.textContent += blogTitle.charAt(i);
        i++;
        setTimeout(typeBlogTitle, 100);
    }
}

window.onload = typeBlogTitle;