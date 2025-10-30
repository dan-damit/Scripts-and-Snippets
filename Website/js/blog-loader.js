const entriesPerPage = 10;
let allEntries = [];

fetch('entries.json')
    .then(res => res.json())
    .then(entries => {
        allEntries = entries;

        const container = document.getElementById('blog-container');

        // Create outer wrapper for centering
        const outerWrapper = document.createElement('div');
        outerWrapper.style.textAlign = 'center';

        // Create a wrapper for global buttons
        const buttonWrapper = document.createElement('div');
        buttonWrapper.className = 'button-wrapper';

        // Create global reset button
        const resetBtn = document.createElement('button');
        resetBtn.textContent = 'Clear All Tags';
        resetBtn.className = 'reset';
        resetBtn.type = 'button';

        // Create global collapse all button
        const collapseAllBtn = document.createElement('button');
        collapseAllBtn.textContent = 'Re-encrypt All Entries';
        collapseAllBtn.className = 'collapse-all-button';
        collapseAllBtn.type = 'button';

        // Append buttons to wrapper
        buttonWrapper.appendChild(resetBtn);
        buttonWrapper.appendChild(collapseAllBtn);
        outerWrapper.appendChild(buttonWrapper);

        // Insert wrapper after container
        container.after(outerWrapper);

        // Initial render
        const params = new URLSearchParams(window.location.search);
        const currentPage = parseInt(params.get("page")) || 1;
        renderPage(allEntries, currentPage);

        // Global reset button
        resetBtn.addEventListener('click', () => {
            document.querySelectorAll('.entry').forEach(entry => {
                entry.style.display = 'block';
            });
        });

        // Global collapse all button
        collapseAllBtn.addEventListener('click', () => {
            document.querySelectorAll('.entry').forEach(entry => {
                const content = entry.querySelector('.content');
                const toggle = entry.querySelector('.toggle');
                if (content && toggle) {
                    content.style.display = 'none';
                    toggle.textContent = 'Decrypt';
                }
            });
        });
    });

function renderPage(entries, page) {
    const container = document.getElementById('blog-container');
    container.innerHTML = "";

    // Inject Technician's Log title
    const title = document.createElement('h1');
    title.id = 'typed-title';
    title.innerHTML = `<span id="typed-text"></span><span class="cursor">_</span>`;
    container.appendChild(title);
    typeBlogTitle("Technician's Log");

    const start = (page - 1) * entriesPerPage;
    const end = start + entriesPerPage;
    const pageEntries = entries.slice(start, end);

    pageEntries.forEach(entry => {
        const section = document.createElement('article');
        section.className = 'entry';
        section.innerHTML = `
      <h2>${entry.date}: ${entry.title}</h2>
      <div class="tags">
        ${entry.tags.map(tag => `<span class="tag">${tag}</span>`).join(' ')}
      </div>
      <div class="content" style="display:none;">${entry.content}</div>
      <button type="button" class="toggle">Decrypt</button>
    `;
        container.appendChild(section);
    });

    wireEntryInteractions();
    renderPaginationControls(entries.length, page, entriesPerPage);
}

function wireEntryInteractions() {
    document.querySelectorAll('.toggle').forEach(btn => {
        btn.addEventListener('click', () => {
            const content = btn.previousElementSibling;
            const isVisible = content.style.display === 'block';
            content.style.display = isVisible ? 'none' : 'block';
            btn.textContent = isVisible ? 'Decrypt' : 'Re-encrypt';
            if (!isVisible) enhanceCodeBlocks(content);
        });
    });

    document.querySelectorAll('.tag').forEach(tag => {
        tag.addEventListener('click', () => {
            const selected = tag.textContent;
            document.querySelectorAll('.entry').forEach(entry => {
                const tags = Array.from(entry.querySelectorAll('.tag')).map(t => t.textContent);
                entry.style.display = tags.includes(selected) ? 'block' : 'none';
            });
        });
    });
}

function renderPaginationControls(totalEntries, currentPage, perPage) {
    const totalPages = Math.ceil(totalEntries / perPage);
    const nav = document.getElementById("pagination-nav");
    nav.innerHTML = "";

    for (let i = 1; i <= totalPages; i++) {
        const btn = document.createElement("a");
        btn.textContent = `${i}`;
        btn.href = `?page=${i}`;
        btn.className = "button-link";
        if (i === currentPage) btn.classList.add("active");

        nav.appendChild(btn);
    }
}

function enhanceCodeBlocks(scope = document) {
    scope.querySelectorAll('pre > code').forEach(code => {
        const pre = code.parentElement;
        if (pre.parentElement.classList.contains('code-wrapper')) return;

        const wrapper = document.createElement('div');
        wrapper.className = 'code-wrapper';

        const button = document.createElement('button');
        button.className = 'copy-btn';
        button.textContent = 'Copy';

        pre.parentElement.insertBefore(wrapper, pre);
        wrapper.appendChild(button);
        wrapper.appendChild(pre);

        button.addEventListener('click', () => {
            navigator.clipboard.writeText(code.innerText).then(() => {
                button.textContent = 'Copied!';
                setTimeout(() => button.textContent = 'Copy', 1500);
            });
        });
    });
}