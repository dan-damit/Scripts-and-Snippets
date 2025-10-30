fetch('entries.json')
    .then(res => res.json())
    .then(entries => {
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

        // Append outer wrapper to body
        outerWrapper.appendChild(buttonWrapper);

        // Insert wrapper after container
        container.after(outerWrapper);

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
        <button type="button" class="toggle">Decrypt</button>
      `;
            container.appendChild(section);
        });

        // Expand/Collapse toggle
        document.querySelectorAll('.toggle').forEach(btn => {
            btn.addEventListener('click', () => {
                const content = btn.previousElementSibling;
                const isVisible = content.style.display === 'block';
                content.style.display = isVisible ? 'none' : 'block';
                btn.textContent = isVisible ? 'Decrypt' : 'Re-encrypt';

                // Enhance code blocks when revealed
                if (!isVisible) enhanceCodeBlocks(content);
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

        // Copy button enhancer
        function enhanceCodeBlocks(scope = document) {
            scope.querySelectorAll('pre > code').forEach(code => {
                const pre = code.parentElement;
                if (pre.parentElement.classList.contains('code-wrapper')) return; // already wrapped

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
    });