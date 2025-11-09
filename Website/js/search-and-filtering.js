/* Small client-side script for basic filtering + search */
(function () {
  const searchEl = document.getElementById("search");
  const tagButtons = document.querySelectorAll(".tag");
  const cards = Array.from(document.querySelectorAll(".card"));
  let activeFilter = "all";

  function normalize(str) {
    return (str || "").toLowerCase();
  }

  function matchesFilter(card, filter) {
    if (!filter || filter === "all") return true;
    const tags = (card.dataset.tags || "").split(",").map((s) => s.trim());
    return tags.includes(filter);
  }

  function matchesSearch(card, q) {
    if (!q) return true;
    const ql = normalize(q);
    const title = normalize(card.dataset.title);
    const desc = normalize(card.querySelector("p")?.textContent);
    const tags = normalize(card.dataset.tags);
    return title.includes(ql) || desc.includes(ql) || tags.includes(ql);
  }

  function update() {
    const q = searchEl.value.trim();
    cards.forEach((card) => {
      const show = matchesFilter(card, activeFilter) && matchesSearch(card, q);
      card.style.display = show ? "" : "none";
    });
  }

  // Tag button behavior
  tagButtons.forEach((btn) => {
    btn.addEventListener("click", () => {
      tagButtons.forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      activeFilter = btn.dataset.filter;
      update();
    });
  });

  // Search behavior (debounced)
  let debounce;
  searchEl.addEventListener("input", () => {
    clearTimeout(debounce);
    debounce = setTimeout(update, 150);
  });

  // Keyboard accessibility: Enter on tag toggles filter
  tagButtons.forEach((btn) => {
    btn.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        btn.click();
      }
    });
  });

  // Initial update to apply default filter
  update();
})();
