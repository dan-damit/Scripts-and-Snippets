document.addEventListener('DOMContentLoaded', () => {
    const printBtn = document.querySelector('.download-btn');
    if (printBtn) {
        printBtn.addEventListener('click', (e) => {
            e.preventDefault();
            window.print();
        });
    }
});