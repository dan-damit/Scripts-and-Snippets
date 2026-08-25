const entriesPerPage = 8;
let allEntries = [];

fetch(`entries.json?ts=${Date.now()}`)
  .then((res) => res.json())
  .then((data) => {
    allEntries = data.entries.reverse();

    // Initialize global variables
    const allTags = [
      ...new Set(allEntries.flatMap((entry) => entry.tags)),
    ].sort(); // Unique sorted tags
    const paginationNav = document.getElementById("pagination-nav");
    const tagIndex = document.getElementById("tag-index");

    // Create outer wrapper for centering
    const outerWrapper = document.createElement("div");
    outerWrapper.className = "blog-global-buttons-wrapper";

    // Create a wrapper for global buttons
    const buttonWrapper = document.createElement("div");
    buttonWrapper.className = "button-wrapper";

    // Create global reset button
    const resetBtn = document.createElement("button");
    resetBtn.textContent = "Clear All Tags";
    resetBtn.className = "reset";
    resetBtn.type = "button";

    // Create global collapse all button
    const collapseAllBtn = document.createElement("button");
    collapseAllBtn.textContent = "Re-encrypt All Entries";
    collapseAllBtn.className = "collapse-all-button";
    collapseAllBtn.type = "button";

    // Initial render
    const params = new URLSearchParams(window.location.search);
    const currentPage = parseInt(params.get("page")) || 1;
    const activeTag = params.get("tag");

    if (activeTag) {
      const filtered = allEntries.filter((entry) =>
        entry.tags.includes(activeTag),
      );
      renderPage(filtered, currentPage, activeTag);
    } else {
      renderPage(allEntries, currentPage);
    }

    // Global reset button
    resetBtn.addEventListener("click", () => {
      history.replaceState(null, "", "?page=1");
      renderPage(allEntries, 1);
    });

    // Global collapse all button
    collapseAllBtn.addEventListener("click", () => {
      document.querySelectorAll(".blog-card").forEach((entry) => {
        const content = entry.querySelector(".content");
        const toggle = entry.querySelector(".toggle");
        if (content && toggle) {
          content.style.display = "none";
          toggle.textContent = "Decrypt";
        }
      });
    });

    // Populate tag buttons
    allTags.forEach((tag) => {
      const tagBtn = document.createElement("button");
      tagBtn.className = "tag-index-button";
      tagBtn.textContent = tag;
      tagBtn.type = "button";

      tagBtn.addEventListener("click", () => {
        const filtered = allEntries.filter((entry) => entry.tags.includes(tag));
        renderPage(filtered, 1, tag);
        console.log(`[TagIndex] ${tag} → ${filtered.length} entries`);
      });

      tagIndex.appendChild(tagBtn);
    });

    // Append buttons to wrapper
    buttonWrapper.appendChild(resetBtn);
    buttonWrapper.appendChild(collapseAllBtn);
    outerWrapper.appendChild(buttonWrapper);
    paginationNav.parentElement.insertBefore(outerWrapper, paginationNav);
  });

function renderPage(entries, page, activeTag = null) {
  const container = document.getElementById("blog-container");
  container.innerHTML = "";

  // Inject Technician's Log title
  const title = document.createElement("h1");
  title.id = "typed-title";
  title.innerHTML = `<span id="typed-text"></span><span class="cursor"></span>`;
  container.appendChild(title);
  typeBlogTitle("Technician's Log...");

  // Inject tag info if a tag is active
  if (activeTag) {
    const tagInfo = document.createElement("div");
    tagInfo.className = "tag-info";
    tagInfo.textContent = `Showing ${entries.length} entries tagged "${activeTag}"`;
    container.appendChild(tagInfo);
  }

  const start = (page - 1) * entriesPerPage;
  const end = start + entriesPerPage;
  const pageEntries = entries.slice(start, end);

  pageEntries.forEach((entry) => {
    const card = document.createElement("div");
    card.className = "blog-card";
    card.setAttribute("data-tags", entry.tags.join(","));

    card.innerHTML = `
      <h2 class="blog-title">${entry.date}: ${entry.title}</h2>
      <div class="tags">
        ${entry.tags.map((tag) => `<span class="tag">${tag}</span>`).join(" ")}
      </div>
      <div class="content" style="display:none;">${entry.content}</div>
      <button type="button" class="toggle">Decrypt</button>
    `;

    container.appendChild(card);
  });

  wireEntryInteractions();
  renderPaginationControls(entries.length, page, entriesPerPage, activeTag);
}

function wireEntryInteractions() {
  document.querySelectorAll(".toggle").forEach((btn) => {
    btn.addEventListener("click", () => {
      const content = btn.previousElementSibling;
      const isVisible = content.style.display === "block";
      content.style.display = isVisible ? "none" : "block";
      btn.textContent = isVisible ? "Decrypt" : "Re-encrypt";
      if (!isVisible) enhanceCodeBlocks(content);
    });
  });

  document.querySelectorAll(".tag").forEach((tag) => {
    tag.addEventListener("click", () => {
      const selected = tag.textContent;
      const filtered = allEntries.filter((entry) =>
        entry.tags.includes(selected),
      );
      renderPage(filtered, 1, selected);

      console.log(`[TagFilter] ${selected} → ${filtered.length} entries`);
    });
  });
}

function renderPaginationControls(
  totalEntries,
  currentPage,
  perPage,
  activeTag = null,
) {
  const totalPages = Math.ceil(totalEntries / perPage);
  const nav = document.getElementById("pagination-nav");
  nav.innerHTML = "";

  for (let i = 1; i <= totalPages; i++) {
    const btn = document.createElement("a");
    btn.textContent = `${i}`;
    btn.href = activeTag
      ? `?page=${i}&tag=${encodeURIComponent(activeTag)}`
      : `?page=${i}`;
    btn.className = "button-link";
    if (i === currentPage) btn.classList.add("active");

    nav.appendChild(btn);
  }
}

function enhanceCodeBlocks(scope = document) {
  scope.querySelectorAll("pre > code").forEach((code) => {
    const pre = code.parentElement;
    if (pre.parentElement.classList.contains("code-wrapper")) return;

    const wrapper = document.createElement("div");
    wrapper.className = "code-wrapper";

    const button = document.createElement("button");
    button.className = "copy-btn";
    button.textContent = "Copy";

    pre.parentElement.insertBefore(wrapper, pre);
    wrapper.appendChild(button);
    wrapper.appendChild(pre);

    // Apply syntax highlighting
    if (window.hljs) {
      hljs.highlightElement(code);

      // Add line numbers
      if (hljs.lineNumbersBlock) {
        hljs.lineNumbersBlock(code);
      }
    }

    button.addEventListener("click", () => {
      navigator.clipboard.writeText(code.innerText).then(() => {
        button.textContent = "Copied!";
        setTimeout(() => (button.textContent = "Copy"), 1500);
      });
    });
  });
}
