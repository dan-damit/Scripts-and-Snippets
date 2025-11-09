function typeBlogTitle(text) {
  const target = document.getElementById("typed-text");
  if (!target) return;

  target.textContent = "";
  let i = 0;

  function type() {
    if (i < text.length) {
      target.textContent += text.charAt(i);
      i++;
      setTimeout(type, 100);
    }
  }

  type();
}
