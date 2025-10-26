fetch('entries.json')
    .then(res => res.json())
    .then(entries => {
        const container = document.getElementById('blog-container');

        // Create and insert the global reset button
        const resetBtn = document.createElement('button');
        resetBtn.textContent = 'Show All Entries';
        resetBtn.className = 'reset';
        resetBtn.type = 'button';
        container.after(resetBtn);

        // Render each blog entry
        entries.forEach(entry => {
            const section = document.createElement('article');
            section.className = 'entry';
            section.innerHTML = `
        <h2>${entry.date}: ${entry.title}</h2>
        <div class="tags">
          ${entry.tags.map(tag => `<span class="tag">${tag}</span>`).join(' ')}
        </div>
        <div class="content" style="display:none;">${entry.content}</div>
        <button class="toggle">Expand</button>
      `;
            container.appendChild(section);
        });

        // Expand/Collapse toggle
        document.querySelectorAll('.toggle').forEach(btn => {
            btn.addEventListener('click', () => {
                const content = btn.previousElementSibling;
                const isVisible = content.style.display === 'block';
                content.style.display = isVisible ? 'none' : 'block';
                btn.textContent = isVisible ? 'Expand' : 'Collapse';
            });
        });

        // Tag filtering
        document.querySelectorAll('.tag').forEach(tag => {
            tag.addEventListener('click', () => {
                const selected = tag.textContent;
                document.querySelectorAll('.entry').forEach(entry => {
                    const tags = Array.from(entry.querySelectorAll('.tag')).map(t => t.textContent);
                    entry.style.display = tags.includes(selected) ? 'block' : 'none';
                });
            });
        });

        // Global reset button
        resetBtn.addEventListener('click', () => {
            document.querySelectorAll('.entry').forEach(entry => {
                entry.style.display = 'block';
            });
        });
    });